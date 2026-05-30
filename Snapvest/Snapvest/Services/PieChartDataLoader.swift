//
//  PieChartDataLoader.swift
//  Snapvest
//
//  圓餅圖資料：持股快照 + 股價 + 現金
//

import Foundation

struct PieChartInputs {
    var usdToTwdRate: Decimal
    var cashByCurrency: [Currency: Decimal]
    var twdRateByCurrency: [Currency: Decimal]
    var aggregatedHoldings: [AggregatedHoldingSnapshot]
    var assetPriceSnapshots: [AssetPriceSnapshot]
    var manualAssets: [ManualAsset] = []

    var twdCash: Decimal {
        cashByCurrency[.TWD] ?? 0
    }

    var usdCash: Decimal {
        cashByCurrency[.USD] ?? 0
    }

    func cashValueInTWD(currency: Currency, amount: Decimal) -> Decimal? {
        if currency == .TWD { return amount }
        guard let rate = twdRateByCurrency[currency], rate > 0 else { return nil }
        return amount * rate
    }

    var totalCashTWD: Decimal {
        cashByCurrency.reduce(Decimal.zero) { partial, item in
            partial + (cashValueInTWD(currency: item.key, amount: item.value) ?? 0)
        }
    }

    var includedManualAssets: [ManualAsset] {
        manualAssets.filter { $0.isIncludedInTotalAssets }
    }

    var investmentManualAssets: [ManualAsset] {
        includedManualAssets.filter { $0.isIncludedInInvestments }
    }

    var totalManualAssetsTWD: Decimal {
        includedManualAssets.reduce(Decimal.zero) { partial, asset in
            partial + (ManualAssetMetrics.valueTWD(asset: asset, rates: twdRateByCurrency) ?? 0)
        }
    }

    var totalManualInvestmentsTWD: Decimal {
        investmentManualAssets.reduce(Decimal.zero) { partial, asset in
            partial + (ManualAssetMetrics.valueTWD(asset: asset, rates: twdRateByCurrency) ?? 0)
        }
    }
}

enum PieChartDataLoader {
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
        let manualAssets = try await dataService.fetchManualAssets(userId: userId)
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

        var twdRateByCurrency: [Currency: Decimal] = [
            .TWD: 1,
            .USD: usdToTwdRate
        ]
        for currency in cashByCurrency.keys where currency != .TWD && currency != .USD {
            if let rate = try? await dataService.fetchExchangeRate(from: currency, to: .TWD, date: nil)?.rate,
               rate > 0 {
                twdRateByCurrency[currency] = rate
            }
        }

        for currency in manualAssets.map(\.currency) where currency != .TWD && currency != .USD {
            if twdRateByCurrency[currency] != nil { continue }
            if let rate = try? await dataService.fetchExchangeRate(from: currency, to: .TWD, date: nil)?.rate,
               rate > 0 {
                twdRateByCurrency[currency] = rate
            }
        }

        return PieChartInputs(
            usdToTwdRate: usdToTwdRate,
            cashByCurrency: cashByCurrency,
            twdRateByCurrency: twdRateByCurrency,
            aggregatedHoldings: aggregated,
            assetPriceSnapshots: prices,
            manualAssets: manualAssets
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
