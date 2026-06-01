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
        trackSymbols: [SymbolInfo] = [],
        updatePriceMetadata: Bool = true,
        deferRemoteWork: Bool = false,
        postsUpdateNotification: Bool = true
    ) async -> Bool {
        let resolvedDataService = dataService ?? MockDataService.shared
        let resolvedPriceService = priceService ?? PriceService(dataService: resolvedDataService)
        let isDemoMode = (resolvedDataService as? MockDataService)?.isDemoModeActive == true
        let shouldTrackSymbols = !trackSymbols.isEmpty && !isDemoMode
        do {
            _ = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: resolvedDataService,
                priceService: resolvedPriceService
            )
            if deferRemoteWork, shouldTrackSymbols || (updatePriceMetadata && !isDemoMode) {
                let symbols = trackSymbols
                Task { @MainActor in
                    if shouldTrackSymbols {
                        await TrackedSymbolSync.sync(symbols: symbols)
                    }
                    if updatePriceMetadata, !isDemoMode {
                        await SupabasePriceService.recordSuccessfulPriceSync(
                            userId: userId,
                            dataService: resolvedDataService
                        )
                    }
                }
            } else {
                if shouldTrackSymbols {
                    await TrackedSymbolSync.sync(symbols: trackSymbols)
                }
                if updatePriceMetadata, !isDemoMode {
                    await SupabasePriceService.recordSuccessfulPriceSync(
                        userId: userId,
                        dataService: resolvedDataService
                    )
                }
            }
            resolvedDataService.persistLocalStore(for: userId)
            DailyPriceHistoryCache.invalidate()
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
