//
//  PieChartDataLoader.swift
//  Snapvest
//
//  圓餅圖資料：持股快照 + 股價 + 現金
//

import Foundation

struct PieChartInputs {
    var twdCash: Decimal
    var usdCash: Decimal
    var usdToTwdRate: Decimal
    var aggregatedHoldings: [AggregatedHoldingSnapshot]
    var assetPriceSnapshots: [AssetPriceSnapshot]
}

enum PieChartDataLoader {
    @MainActor
    static func load(
        userId: String,
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol
    ) async throws -> PieChartInputs {
        let rate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 32
        let accounts = try await dataService.fetchAccounts(userId: userId)
        var accountSnapshots: [AccountSnapshot] = []
        for account in accounts {
            if let s = try await dataService.fetchAccountSnapshot(accountId: account.id) {
                accountSnapshots.append(s)
            }
        }
        
        var aggregated = try await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
        let symbolInfos = await symbolInfosForPie(
            userId: userId,
            dataService: dataService,
            accountSnapshots: accountSnapshots,
            aggregated: aggregated
        )
        var prices: [AssetPriceSnapshot] = []
        if SupabaseConfig.isConfigured, !symbolInfos.isEmpty {
            prices = (try? await SupabasePriceService.fetchPrices(symbols: symbolInfos)) ?? []
        }
        if prices.isEmpty, !symbolInfos.isEmpty {
            prices = try await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)
        }
        if aggregated.isEmpty || accountSnapshots.isEmpty || prices.isEmpty {
            let bundle = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: dataService,
                priceService: priceService
            )
            aggregated = bundle.aggregatedHoldings
            prices = bundle.assetPriceSnapshots
            accountSnapshots = bundle.accountSnapshots
        }
        
        var cashByCurrency: [Currency: Decimal] = [:]
        var accountMap: [String: Account] = [:]
        for a in accounts { accountMap[a.id] = a }
        for snap in accountSnapshots {
            guard let account = accountMap[snap.accountId], account.accountType != .debt else { continue }
            if let existing = cashByCurrency[account.currency] {
                cashByCurrency[account.currency] = existing + snap.cashBalance
            } else {
                cashByCurrency[account.currency] = snap.cashBalance
            }
        }
        
        return PieChartInputs(
            twdCash: cashByCurrency[.TWD] ?? 0,
            usdCash: cashByCurrency[.USD] ?? 0,
            usdToTwdRate: rate,
            aggregatedHoldings: aggregated,
            assetPriceSnapshots: prices
        )
    }
    
    private static func symbolInfosForPie(
        userId: String,
        dataService: DataServiceProtocol,
        accountSnapshots: [AccountSnapshot],
        aggregated: [AggregatedHoldingSnapshot]
    ) async -> [SymbolInfo] {
        if let userSnapshot = try? await dataService.fetchUserHoldingsSnapshot(userId: userId),
           !userSnapshot.symbols.isEmpty {
            return userSnapshot.symbols
        }
        if !aggregated.isEmpty {
            return aggregated.map { SymbolInfo(assetType: $0.assetType, symbol: $0.symbol) }
        }
        var infos: [SymbolInfo] = []
        var seen = Set<String>()
        for snap in accountSnapshots {
            guard let holdings = snap.holdings else { continue }
            for h in holdings {
                let key = "\(h.assetType.rawValue)_\(h.symbol)"
                if seen.insert(key).inserted {
                    infos.append(SymbolInfo(assetType: h.assetType, symbol: h.symbol))
                }
            }
        }
        return infos
    }
}
