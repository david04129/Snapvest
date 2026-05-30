//
//  SnapshotRefreshCoordinator.swift
//  Snapvest
//
//  統一重建快照、持久化、並通知各 Tab 刷新。
//

import Foundation

enum SnapshotRefreshCoordinator {
    @MainActor
    @discardableResult
    static func rebuildAndNotify(
        userId: String,
        dataService: DataServiceProtocol? = nil,
        priceService: PriceServiceProtocol? = nil,
        syncPortfolio: Bool = true,
        updatePriceMetadata: Bool = true,
        deferRemoteWork: Bool = false,
        postsUpdateNotification: Bool = true
    ) async -> Bool {
        let resolvedDataService = dataService ?? MockDataService.shared
        let resolvedPriceService = priceService ?? PriceService(dataService: resolvedDataService)
        let isDemoMode = (resolvedDataService as? MockDataService)?.isDemoModeActive == true
        do {
            let bundle = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: resolvedDataService,
                priceService: resolvedPriceService
            )
            if deferRemoteWork, !isDemoMode, (syncPortfolio || updatePriceMetadata) {
                Task { @MainActor in
                    if syncPortfolio {
                        await PortfolioStateSync.sync(
                            userId: userId,
                            dataService: resolvedDataService,
                            priceService: resolvedPriceService,
                            bundle: bundle
                        )
                    }
                    if updatePriceMetadata {
                        await SupabasePriceService.recordSuccessfulPriceSync(
                            userId: userId,
                            dataService: resolvedDataService
                        )
                    }
                }
            } else if syncPortfolio, !isDemoMode {
                await PortfolioStateSync.sync(
                    userId: userId,
                    dataService: resolvedDataService,
                    priceService: resolvedPriceService,
                    bundle: bundle
                )
            }
            if updatePriceMetadata, !isDemoMode, !deferRemoteWork {
                await SupabasePriceService.recordSuccessfulPriceSync(
                    userId: userId,
                    dataService: resolvedDataService
                )
            }
            resolvedDataService.persistLocalStore(for: userId)
            if postsUpdateNotification {
                NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
            }
            return true
        } catch {
            print("[SnapshotRefreshCoordinator] rebuild failed: \(error.localizedDescription)")
            return false
        }
    }
}
