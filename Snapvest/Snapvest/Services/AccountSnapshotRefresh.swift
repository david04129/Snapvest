//
//  AccountSnapshotRefresh.swift
//  Snapvest
//
//  帳戶 CRUD 後僅重算結構，不拉雲端股價。
//

import Foundation

enum AccountSnapshotRefresh {
    @MainActor
    static func afterCashAccountChange(
        userId: String,
        affectedAccountId: String,
        dataService: DataServiceProtocol
    ) async throws {
        _ = try await SnapshotUpdater.updateSnapshotsIncrementally(
            userId: userId,
            affectedAccountIds: [affectedAccountId],
            affectedSymbols: [],
            dataService: dataService,
            priceService: PriceService(dataService: dataService)
        )
        dataService.persistLocalStore(for: userId)
        NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
    }

    @MainActor
    static func afterAccountRemovedOrArchived(
        userId: String,
        deletedAccountIds: Set<String> = [],
        dataService: DataServiceProtocol
    ) async throws {
        _ = try await SnapshotUpdater.rebuildSnapshotsUsingLocalPricesOnly(
            userId: userId,
            deletedAccountIds: deletedAccountIds,
            dataService: dataService,
            priceService: PriceService(dataService: dataService)
        )
        dataService.persistLocalStore(for: userId)
        NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
    }
}
