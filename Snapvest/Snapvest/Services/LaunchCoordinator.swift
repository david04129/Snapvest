//
//  LaunchCoordinator.swift
//  Snapvest
//
//  Splash 冷啟動：依 CloudSnapshotRefreshPolicy 決定是否拉雲端，灌入各 Tab。
//

import Foundation

enum LaunchCoordinator {
    @MainActor
    static func run(
        userId: String,
        portfolioViewModel: PortfolioViewModel,
        accountsViewModel: AccountsViewModel,
        assetsViewModel: AssetsViewModel,
        dataService: DataServiceProtocol? = nil,
        priceService: PriceServiceProtocol? = nil
    ) async -> LaunchResult {
        let resolvedDataService = dataService ?? MockDataService.shared
        let resolvedPriceService = priceService ?? PriceService(dataService: resolvedDataService)
        let canUseLocal = LocalLaunchReadiness.canEnterApp(userId: userId)
        
        guard SupabaseConfig.isConfigured else {
            _ = SymbolCatalogStore.ensureBootstrappedFromBundleIfNeeded()
            await LocalDailyTrendBackfillService.runIfNeeded(
                userId: userId,
                dataService: resolvedDataService
            )
            await applyPersistedState(
                userId: userId,
                portfolioViewModel: portfolioViewModel,
                accountsViewModel: accountsViewModel,
                assetsViewModel: assetsViewModel,
                dataService: resolvedDataService
            )
            if canUseLocal, LocalLaunchReadiness.hasValuationSnapshot(userId: userId) {
                return .degraded(notice: "尚未連線雲端，已使用本機資料。")
            }
            return .success
        }

        await SupabaseAuthService.shared.warmUp()
        _ = SymbolCatalogStore.ensureBootstrappedFromBundleIfNeeded()
        async let catalogSyncTask = SymbolCatalogSyncService.syncIfNeeded()

        if (resolvedDataService as? MockDataService)?.isDemoModeActive == true {
            await LocalDailyTrendBackfillService.runIfNeeded(
                userId: userId,
                dataService: resolvedDataService
            )
            await applyPersistedState(
                userId: userId,
                portfolioViewModel: portfolioViewModel,
                accountsViewModel: accountsViewModel,
                assetsViewModel: assetsViewModel,
                dataService: resolvedDataService
            )
            _ = await catalogSyncTask
            return .success
        }

        let refreshEvaluation = await CloudSnapshotRefreshPolicy.evaluate(
            userId: userId,
            dataService: resolvedDataService
        )

        var degradedNotice: String?

        if refreshEvaluation.shouldRunSnapshotRebuild {
            let syncSucceeded = await SnapshotRefreshCoordinator.rebuildAndNotify(
                userId: userId,
                dataService: resolvedDataService,
                priceService: resolvedPriceService,
                updatePriceMetadata: refreshEvaluation.shouldFetchCloudPrices,
                localPricesOnly: refreshEvaluation.preferLocalPricesOnly
            )

            if !syncSucceeded {
                if canUseLocal, LocalLaunchReadiness.hasValuationSnapshot(userId: userId) {
                    degradedNotice = "無法同步最新股價，已使用本機資料。"
                } else {
                    return .blocked(
                        message: """
                        無法連線雲端同步股價與資料。
                        請確認網路後再試，或稍後重新開啟 App。
                        """,
                        allowsRetry: true
                    )
                }
            }
        } else {
            #if DEBUG
            print("[LaunchCoordinator] skip cloud rebuild: metadata aligned, local snapshots ready")
            #endif
        }
        
        await LocalDailyTrendBackfillService.runIfNeeded(
            userId: userId,
            dataService: resolvedDataService
        )

        await applyPersistedState(
            userId: userId,
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: accountsViewModel,
            assetsViewModel: assetsViewModel,
            dataService: resolvedDataService
        )

        _ = await catalogSyncTask
        
        if let degradedNotice {
            return .degraded(notice: degradedNotice)
        }
        return .success
    }

    @MainActor
    static func applyPersistedState(
        userId: String,
        portfolioViewModel: PortfolioViewModel,
        accountsViewModel: AccountsViewModel,
        assetsViewModel: AssetsViewModel,
        dataService: DataServiceProtocol? = nil,
        rebuildAccountDetailCache: Bool = true,
        accountDetailCacheAccountIds: Set<String>? = nil
    ) async {
        let resolvedDataService = dataService ?? MockDataService.shared
        let usdToTwdRate: Decimal
        if let exchangeRate = try? await resolvedDataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil),
           exchangeRate.rate > 0 {
            ExchangeRateSessionCache.update(usdToTwd: exchangeRate.rate, updatedAt: exchangeRate.rateDate)
            usdToTwdRate = exchangeRate.rate
        } else {
            usdToTwdRate = ExchangeRateSessionCache.usdToTwd ?? 0
        }

        let accounts = (try? await resolvedDataService.fetchAccounts(userId: userId)) ?? []
        let liabilities = await loadLiabilitiesForWarmup(
            accounts: accounts,
            dataService: resolvedDataService
        )
        var accountSnapshots: [AccountSnapshot] = []
        for account in accounts where !account.accountType.isLiabilityAccount && !account.isArchived {
            if let snapshot = try? await resolvedDataService.fetchAccountSnapshot(accountId: account.id) {
                accountSnapshots.append(snapshot)
            }
        }
        let manualAssets = (try? await resolvedDataService.fetchManualAssets(userId: userId)) ?? []
        await ExchangeRateSessionCache.warmForPortfolio(
            accounts: accounts,
            liabilities: liabilities,
            accountSnapshots: accountSnapshots,
            manualAssets: manualAssets,
            dataService: resolvedDataService,
            usdToTwdRate: usdToTwdRate
        )

        await portfolioViewModel.prepareFromPersisted(userId: userId, usdToTwdRate: usdToTwdRate)
        if let accountDetailCacheAccountIds, !accountDetailCacheAccountIds.isEmpty {
            await accountsViewModel.applyChangedAccountsFromPersisted(
                userId: userId,
                affectedAccountIds: accountDetailCacheAccountIds,
                usdToTwdRate: usdToTwdRate,
                liabilities: portfolioViewModel.liabilities
            )
        } else {
            await accountsViewModel.applyFromPersisted(
                userId: userId,
                usdToTwdRate: usdToTwdRate,
                liabilities: portfolioViewModel.liabilities
            )
        }
        await assetsViewModel.applyFromPersisted(userId: userId, usdToTwdRate: usdToTwdRate)

        guard rebuildAccountDetailCache else {
            return
        }

        if let accountDetailCacheAccountIds {
            AccountDetailPresentationStore.remove(accountIds: accountDetailCacheAccountIds)
            for account in accounts where accountDetailCacheAccountIds.contains(account.id) {
                guard !account.accountType.isLiabilityAccount,
                      !account.isArchived,
                      let snapshot = try? await resolvedDataService.fetchAccountSnapshot(accountId: account.id) else {
                    continue
                }
                let holdings = await AccountDetailHoldingsBuilder.build(
                    from: snapshot,
                    accountId: account.id,
                    dataService: resolvedDataService
                )
                AccountDetailPresentationStore.replace(holdings, for: account.id)
            }
        } else {
            let holdingsMap = await AccountDetailHoldingsBuilder.buildAll(
                accounts: accounts,
                dataService: resolvedDataService
            )
            AccountDetailPresentationStore.replaceAll(holdingsMap)
        }
    }

    @MainActor
    private static func loadLiabilitiesForWarmup(
        accounts: [Account],
        dataService: DataServiceProtocol
    ) async -> [Liability] {
        var allLiabilities: [Liability] = []
        for account in accounts {
            if let accountLiabilities = try? await dataService.fetchLiabilities(accountId: account.id) {
                allLiabilities.append(contentsOf: accountLiabilities)
            }
        }
        return allLiabilities
    }
}
