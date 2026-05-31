//
//  PortfolioMutationCoordinator.swift
//  Snapvest
//
//  資料變更 → 重建／增量快照 → 套用各 Tab ViewModel；loading 涵蓋整段流程。
//

import Foundation

@MainActor
final class PortfolioMutationRefreshRequest: NSObject {
    let userId: String
    let affectedAccountIds: Set<String>
    let affectedSymbols: [SymbolInfo]
    let forceFullRebuild: Bool
    let realizedGainLossDeltaByCurrency: [Currency: Decimal]
    let showsLoadingOverlay: Bool
    let loadingTitle: String
    let loadingMessage: String

    init(
        userId: String,
        affectedAccountIds: Set<String> = [],
        affectedSymbols: [SymbolInfo] = [],
        forceFullRebuild: Bool = false,
        realizedGainLossDeltaByCurrency: [Currency: Decimal] = [:],
        showsLoadingOverlay: Bool = true,
        loadingTitle: String = "正在更新資料…",
        loadingMessage: String = "重新計算帳戶、持股與總資產"
    ) {
        self.userId = userId
        self.affectedAccountIds = affectedAccountIds
        self.affectedSymbols = affectedSymbols
        self.forceFullRebuild = forceFullRebuild
        self.realizedGainLossDeltaByCurrency = realizedGainLossDeltaByCurrency
        self.showsLoadingOverlay = showsLoadingOverlay
        self.loadingTitle = loadingTitle
        self.loadingMessage = loadingMessage
    }
}

enum PortfolioMutationCoordinator {
    struct LoadingMessage {
        var title: String
        var message: String
    }

    /// 重建快照並套用至各 Tab（由 `transactionsDidChange` 觸發）。
    static func performRefresh(
        _ request: PortfolioMutationRefreshRequest,
        portfolioViewModel: PortfolioViewModel,
        accountsViewModel: AccountsViewModel,
        assetsViewModel: AssetsViewModel,
        dataService: DataServiceProtocol? = nil
    ) async {
        let resolvedDataService = dataService ?? MockDataService.shared

        if request.showsLoadingOverlay {
            postRefreshBegan(title: request.loadingTitle, message: request.loadingMessage)
        }
        defer {
            if request.showsLoadingOverlay {
                postRefreshEnded()
            }
        }

        invalidateAccountDetailPresentationCache(for: request)

        await rebuildSnapshots(request: request, dataService: resolvedDataService)

        let rebuildAllDetailCaches = request.forceFullRebuild || request.affectedAccountIds.isEmpty
        let cacheAccountIds: Set<String>? = rebuildAllDetailCaches ? nil : request.affectedAccountIds
        await LaunchCoordinator.applyPersistedState(
            userId: request.userId,
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: accountsViewModel,
            assetsViewModel: assetsViewModel,
            dataService: resolvedDataService,
            rebuildAccountDetailCache: true,
            accountDetailCacheAccountIds: cacheAccountIds
        )

        NotificationCenter.default.post(
            name: .snapshotsDidUpdate,
            object: nil,
            userInfo: [SnapshotUpdateUserInfoKey.alreadyApplied: true]
        )
    }

    /// 執行資料變更後，以全螢幕 loading 完成 rebuild + apply。
    @discardableResult
    static func perform(
        userId: String,
        loading: LoadingMessage,
        portfolioViewModel: PortfolioViewModel,
        accountsViewModel: AccountsViewModel,
        assetsViewModel: AssetsViewModel,
        dataService: DataServiceProtocol? = nil,
        affectedAccountIds: Set<String> = [],
        forceFullRebuild: Bool = true,
        operation: () async -> Bool
    ) async -> Bool {
        postRefreshBegan(title: loading.title, message: loading.message)
        defer { postRefreshEnded() }

        guard await operation() else { return false }

        let request = PortfolioMutationRefreshRequest(
            userId: userId,
            affectedAccountIds: affectedAccountIds,
            forceFullRebuild: forceFullRebuild,
            showsLoadingOverlay: false
        )
        await performRefresh(
            request,
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: accountsViewModel,
            assetsViewModel: assetsViewModel,
            dataService: dataService
        )
        return true
    }

    /// 在重建快照前先清掉舊持股快取，避免 loading 期間詳情頁仍顯示已刪除的標的。
    private static func invalidateAccountDetailPresentationCache(for request: PortfolioMutationRefreshRequest) {
        if request.forceFullRebuild || request.affectedAccountIds.isEmpty {
            AccountDetailPresentationStore.clear()
        } else {
            AccountDetailPresentationStore.remove(accountIds: request.affectedAccountIds)
        }
    }

    private static func rebuildSnapshots(
        request: PortfolioMutationRefreshRequest,
        dataService: DataServiceProtocol
    ) async {
        if !request.forceFullRebuild, !request.affectedAccountIds.isEmpty {
            do {
                _ = try await SnapshotUpdater.updateSnapshotsIncrementally(
                    userId: request.userId,
                    affectedAccountIds: request.affectedAccountIds,
                    affectedSymbols: request.affectedSymbols,
                    realizedGainLossDeltaByCurrency: request.realizedGainLossDeltaByCurrency,
                    dataService: dataService,
                    priceService: PriceService(dataService: dataService)
                )
                await TrackedSymbolSync.sync(symbols: request.affectedSymbols)
                dataService.persistLocalStore(for: request.userId)
                return
            } catch {
                #if DEBUG
                print("[PortfolioMutationCoordinator] incremental snapshot failed: \(error.localizedDescription)")
                #endif
            }
        }

        await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: request.userId,
            dataService: dataService,
            trackSymbols: request.affectedSymbols,
            updatePriceMetadata: false,
            deferRemoteWork: true,
            postsUpdateNotification: false
        )
    }

    private static func postRefreshBegan(title: String, message: String) {
        NotificationCenter.default.post(
            name: .portfolioMutationRefreshBegan,
            object: nil,
            userInfo: [
                PortfolioMutationRefreshUserInfoKey.title: title,
                PortfolioMutationRefreshUserInfoKey.message: message
            ]
        )
    }

    private static func postRefreshEnded() {
        NotificationCenter.default.post(name: .portfolioMutationRefreshEnded, object: nil)
    }
}
