//
//  LaunchCoordinator.swift
//  Snapvest
//
//  Splash 冷啟動：對齊 price_update_metadata、必要時 rebuild，灌入各 Tab。
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
        
        let needsRebuild = await needsSnapshotRebuild(userId: userId, dataService: resolvedDataService)
        let shouldSyncPrices = await SupabasePriceService.shouldFetchPrices(
            userId: userId,
            dataService: resolvedDataService
        )
        let shouldPullCloudPrices = SupabaseConfig.isConfigured
        
        var degradedNotice: String?
        
        if needsRebuild || shouldSyncPrices || shouldPullCloudPrices {
            let syncSucceeded = await SnapshotRefreshCoordinator.rebuildAndNotify(
                userId: userId,
                dataService: resolvedDataService,
                priceService: resolvedPriceService
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

    @MainActor
    private static func needsSnapshotRebuild(userId: String, dataService: DataServiceProtocol) async -> Bool {
        let accounts = (try? await dataService.fetchAccounts(userId: userId)) ?? []
        let activeAssetAccounts = accounts.filter {
            !$0.accountType.isLiabilityAccount && !$0.isArchived
        }
        let manualAssets = (try? await dataService.fetchManualAssets(userId: userId)) ?? []
        let hasIncludedManualAssets = manualAssets.contains { $0.isIncludedInTotalAssets }

        guard let home = try? await dataService.fetchHomeDashboardSnapshot(userId: userId) else {
            return !accounts.isEmpty || hasIncludedManualAssets
        }

        if activeAssetAccounts.isEmpty && !hasIncludedManualAssets {
            return false
        }

        if home.totalAssets <= 0 {
            return true
        }

        if hasIncludedManualAssets,
           let structureUpdatedAt = dataService.fetchStructureUpdatedAt(userId: userId),
           structureUpdatedAt > home.lastUpdated {
            return true
        }

        if manualAssets.contains(where: { $0.isIncludedInTotalAssets && !$0.isIncludedInInvestments }),
           home.totalInvestments == home.totalAssets - home.totalCash {
            return true
        }

        for account in activeAssetAccounts {
            if (try? await dataService.fetchAccountSnapshot(accountId: account.id)) == nil {
                return true
            }
        }

        let aggregated = (try? await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)) ?? []
        if !aggregated.isEmpty {
            for holding in aggregated {
                if (try? await dataService.fetchAssetPriceSnapshot(
                    assetType: holding.assetType,
                    symbol: holding.symbol
                )) == nil {
                    return true
                }
            }
        }

        return false
    }
}
