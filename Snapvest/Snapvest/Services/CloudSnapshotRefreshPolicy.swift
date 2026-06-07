//
//  CloudSnapshotRefreshPolicy.swift
//  Snapvest
//
//  冷啟／下拉：metadata 未變且本機價齊 → skip 雲端 batch；結構缺快照 → 可只用本機價重算。
//

import Foundation

enum CloudSnapshotRefreshPolicy {
    struct Evaluation: Equatable {
        let needsStructureRebuild: Bool
        let shouldSyncPricesFromMetadata: Bool
        let hasMissingLocalPrices: Bool

        /// 是否需要向 Supabase 拉現價（includeCurrent batch）。
        var shouldFetchCloudPrices: Bool {
            shouldSyncPricesFromMetadata || hasMissingLocalPrices
        }

        /// 是否需要跑 SnapshotUpdater（含結構重算或補價）。
        var shouldRunSnapshotRebuild: Bool {
            needsStructureRebuild || shouldFetchCloudPrices
        }

        /// 結構需重算但 metadata 未變、本機價齊 → 不打雲端，只重算快照。
        var preferLocalPricesOnly: Bool {
            needsStructureRebuild && !shouldFetchCloudPrices
        }
    }

    @MainActor
    static func evaluate(userId: String, dataService: DataServiceProtocol) async -> Evaluation {
        let needsStructureRebuild = await needsStructureRebuild(userId: userId, dataService: dataService)
        let shouldSyncPricesFromMetadata: Bool
        if SupabaseConfig.isConfigured {
            shouldSyncPricesFromMetadata = await SupabasePriceService.shouldFetchPrices(
                userId: userId,
                dataService: dataService
            )
        } else {
            shouldSyncPricesFromMetadata = false
        }
        let hasMissingLocalPrices = await hasMissingLocalPrices(userId: userId, dataService: dataService)
        return Evaluation(
            needsStructureRebuild: needsStructureRebuild,
            shouldSyncPricesFromMetadata: shouldSyncPricesFromMetadata,
            hasMissingLocalPrices: hasMissingLocalPrices
        )
    }

    @MainActor
    static func hasMissingLocalPrices(userId: String, dataService: DataServiceProtocol) async -> Bool {
        guard let holdings = try? await dataService.fetchUserHoldingsSnapshot(userId: userId),
              !holdings.symbols.isEmpty else {
            return false
        }

        for symbol in holdings.symbols where symbol.assetType != .cash {
            guard let snapshot = try? await dataService.fetchAssetPriceSnapshot(
                assetType: symbol.assetType,
                symbol: symbol.symbol
            ),
                  let price = snapshot.displayPrice,
                  price > 0 else {
                return true
            }
        }
        return false
    }

    @MainActor
    static func needsStructureRebuild(userId: String, dataService: DataServiceProtocol) async -> Bool {
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
