//
//  SnapshotRefreshCoordinator.swift
//  Snapvest
//
//  統一重建快照、持久化、並通知各 Tab 刷新。
//

import Foundation

enum SnapshotRefreshCoordinator {
    private static var rebuildGeneration: UInt = 0
    private static var inFlightRebuild: Task<Bool, Never>?

    /// 還原備份前呼叫，使進行中的 rebuild 結果不會覆寫還原後的本機資料。
    @MainActor
    static func invalidateInFlightRebuild() {
        rebuildGeneration &+= 1
    }

    @MainActor
    @discardableResult
    static func rebuildAndNotify(
        userId: String,
        dataService: DataServiceProtocol? = nil,
        priceService: PriceServiceProtocol? = nil,
        trackSymbols: [SymbolInfo] = [],
        syncPortfolioPreviousCloses: Bool = false,
        updatePriceMetadata: Bool = true,
        deferRemoteWork: Bool = false,
        postsUpdateNotification: Bool = true
    ) async -> Bool {
        if let inFlight = inFlightRebuild {
            _ = await inFlight.value
        }

        rebuildGeneration &+= 1
        let generation = rebuildGeneration

        let task = Task { @MainActor in
            await performRebuildAndNotify(
                userId: userId,
                dataService: dataService,
                priceService: priceService,
                trackSymbols: trackSymbols,
                syncPortfolioPreviousCloses: syncPortfolioPreviousCloses,
                updatePriceMetadata: updatePriceMetadata,
                deferRemoteWork: deferRemoteWork,
                postsUpdateNotification: postsUpdateNotification,
                generation: generation
            )
        }
        inFlightRebuild = task
        defer { inFlightRebuild = nil }
        return await task.value
    }

    @MainActor
    private static func performRebuildAndNotify(
        userId: String,
        dataService: DataServiceProtocol?,
        priceService: PriceServiceProtocol?,
        trackSymbols: [SymbolInfo],
        syncPortfolioPreviousCloses: Bool,
        updatePriceMetadata: Bool,
        deferRemoteWork: Bool,
        postsUpdateNotification: Bool,
        generation: UInt
    ) async -> Bool {
        guard generation == rebuildGeneration else { return false }

        let resolvedDataService = dataService ?? MockDataService.shared
        let resolvedPriceService = priceService ?? PriceService(dataService: resolvedDataService)
        let shouldTrackSymbols = !trackSymbols.isEmpty
        do {
            _ = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: resolvedDataService,
                priceService: resolvedPriceService
            )
            guard generation == rebuildGeneration else { return false }

            if let demoDataService = resolvedDataService as? MockDataService,
               demoDataService.isDemoModeActive {
                await DemoPresentationReconciler.reconcile(
                    userId: userId,
                    dataService: demoDataService
                )
            }

            if deferRemoteWork, shouldTrackSymbols || updatePriceMetadata {
                let symbols = trackSymbols
                Task { @MainActor in
                    if shouldTrackSymbols {
                        await TrackedSymbolSync.sync(symbols: symbols)
                    }
                    if updatePriceMetadata {
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
                if updatePriceMetadata {
                    await SupabasePriceService.recordSuccessfulPriceSync(
                        userId: userId,
                        dataService: resolvedDataService
                    )
                }
            }

            guard generation == rebuildGeneration else { return false }

            resolvedDataService.persistLocalStore(for: userId)
            DailyPriceHistoryCache.invalidate()

            let previousCloseTargets: [SymbolInfo]
            if syncPortfolioPreviousCloses {
                previousCloseTargets = await PortfolioSymbolCollector.holdingSymbols(
                    userId: userId,
                    dataService: resolvedDataService
                )
            } else if !trackSymbols.isEmpty {
                previousCloseTargets = trackSymbols
            } else {
                previousCloseTargets = []
            }
            if !previousCloseTargets.isEmpty {
                _ = await DailyPreviousCloseSync.apply(
                    for: previousCloseTargets,
                    dataService: resolvedDataService
                )
            }

            guard generation == rebuildGeneration else { return false }

            if postsUpdateNotification {
                NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
            }
            return true
        } catch SupabaseError.rateLimited(let retryAfterSeconds) {
            await MainActor.run {
                ManualRefreshCooldown.shared.showRateLimited(retryAfterSeconds: retryAfterSeconds)
            }
            print("[SnapshotRefreshCoordinator] rebuild rate limited: \(retryAfterSeconds ?? -1)s")
            return false
        } catch {
            print("[SnapshotRefreshCoordinator] rebuild failed: \(error.localizedDescription)")
            return false
        }
    }
}
