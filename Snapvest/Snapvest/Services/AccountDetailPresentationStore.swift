//
//  AccountDetailPresentationStore.swift
//  Snapvest
//
//  帳戶明細持股列表 session 快取（Splash／帳戶 Tab 套用 B 時預建）。
//

import Foundation

@MainActor
enum AccountDetailPresentationStore {
    private(set) static var holdingsByAccountId: [String: [HoldingSnapshot]] = [:]

    static func replaceAll(_ map: [String: [HoldingSnapshot]]) {
        holdingsByAccountId = map
    }

    static func holdings(for accountId: String) -> [HoldingSnapshot]? {
        holdingsByAccountId[accountId]
    }

    static func clear() {
        holdingsByAccountId = [:]
    }
}

enum AccountDetailHoldingsBuilder {
    @MainActor
    static func buildAll(
        accounts: [Account],
        dataService: DataServiceProtocol
    ) async -> [String: [HoldingSnapshot]] {
        var map: [String: [HoldingSnapshot]] = [:]
        for account in accounts where !account.accountType.isLiabilityAccount && !account.isArchived {
            guard let snapshot = try? await dataService.fetchAccountSnapshot(accountId: account.id) else {
                continue
            }
            map[account.id] = await build(from: snapshot, accountId: account.id, dataService: dataService)
        }
        return map
    }

    @MainActor
    static func build(
        from accountSnapshot: AccountSnapshot,
        accountId: String,
        dataService: DataServiceProtocol
    ) async -> [HoldingSnapshot] {
        let items = accountSnapshot.holdings ?? []
        guard !items.isEmpty else { return [] }

        var built: [HoldingSnapshot] = []
        built.reserveCapacity(items.count)
        for item in items {
            let priceSnapshot = try? await dataService.fetchAssetPriceSnapshot(
                assetType: item.assetType,
                symbol: item.symbol
            )
            let holding = Holding(
                id: item.id,
                accountId: accountId,
                assetType: item.assetType,
                symbol: item.symbol,
                name: item.name,
                quantity: item.quantity,
                averageCost: item.averageCost,
                currency: item.currency,
                lastUpdated: item.lastUpdated
            )
            built.append(
                HoldingSnapshot(
                    id: item.id,
                    holding: holding,
                    currentPrice: priceSnapshot?.displayPrice,
                    currentPriceDate: priceSnapshot?.displayPriceDate
                )
            )
        }
        return built
    }
}
