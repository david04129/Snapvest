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
        let rate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
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
            let fetched = (try? await SupabasePriceService.fetchPrices(symbols: symbolInfos)) ?? []
            prices = await PriceSnapshotMerger.mergeIncoming(fetched, dataService: dataService)
        } else if !symbolInfos.isEmpty {
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
            dataService.persistLocalValuation(for: userId)
        }
        
        var cashByCurrency: [Currency: Decimal] = [:]
        var accountMap: [String: Account] = [:]
        for a in accounts { accountMap[a.id] = a }
        for snap in accountSnapshots {
            guard let account = accountMap[snap.accountId], !account.accountType.isLiabilityAccount else { continue }
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

    /// 僅讀本機估值 B（Splash／Tab 套用，不拉 Supabase、不 rebuild）
    @MainActor
    static func loadFromPersisted(
        userId: String,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async throws -> PieChartInputs {
        let accounts = try await dataService.fetchAccounts(userId: userId)
        var accountSnapshots: [AccountSnapshot] = []
        for account in accounts {
            if let snapshot = try await dataService.fetchAccountSnapshot(accountId: account.id) {
                accountSnapshots.append(snapshot)
            }
        }

        let aggregated = try await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
        let symbolInfos = await symbolInfosForPie(
            userId: userId,
            dataService: dataService,
            accountSnapshots: accountSnapshots,
            aggregated: aggregated
        )
        let prices = try await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)

        var cashByCurrency: [Currency: Decimal] = [:]
        var accountMap: [String: Account] = [:]
        for account in accounts { accountMap[account.id] = account }
        for snapshot in accountSnapshots {
            guard let account = accountMap[snapshot.accountId], !account.accountType.isLiabilityAccount else { continue }
            if let existing = cashByCurrency[account.currency] {
                cashByCurrency[account.currency] = existing + snapshot.cashBalance
            } else {
                cashByCurrency[account.currency] = snapshot.cashBalance
            }
        }

        return PieChartInputs(
            twdCash: cashByCurrency[.TWD] ?? 0,
            usdCash: cashByCurrency[.USD] ?? 0,
            usdToTwdRate: usdToTwdRate,
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
