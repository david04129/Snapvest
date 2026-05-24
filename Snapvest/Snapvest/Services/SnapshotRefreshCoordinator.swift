//
//  SnapshotRefreshCoordinator.swift
//  Snapvest
//
//  統一重建快照、持久化、並通知各 Tab 刷新。
//

import Foundation

enum SnapshotRefreshCoordinator {
    @MainActor
    static func rebuildAndNotify(
        userId: String,
        dataService: DataServiceProtocol = MockDataService.shared,
        priceService: PriceServiceProtocol? = nil,
        syncPortfolio: Bool = true
    ) async {
        let resolvedPriceService = priceService ?? PriceService(dataService: dataService)
        do {
            let bundle = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: dataService,
                priceService: resolvedPriceService
            )
            if syncPortfolio {
                await PortfolioStateSync.sync(
                    userId: userId,
                    dataService: dataService,
                    priceService: resolvedPriceService,
                    bundle: bundle
                )
            }
            dataService.persistLocalStore(for: userId)
            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
        } catch {
            print("[SnapshotRefreshCoordinator] rebuild failed: \(error.localizedDescription)")
        }
    }
}
