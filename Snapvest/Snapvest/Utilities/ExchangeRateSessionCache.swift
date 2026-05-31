//
//  ExchangeRateSessionCache.swift
//  Snapvest
//
//  Session 級匯率表（各幣 → TWD），Splash／管理列表／快照重建時預熱，UI 共用。
//

import Foundation

enum ExchangeRateSessionCache {
    private(set) static var rateTable: CurrencyRateTable = CurrencyRateTable()
    private(set) static var usdToTwdUpdatedAt: Date?

    static var usdToTwd: Decimal? {
        twdPer(.USD)
    }

    static func twdPer(_ currency: Currency) -> Decimal? {
        if currency == .TWD { return 1 }
        guard let rate = rateTable.twdPerCurrency[currency], rate > 0 else { return nil }
        return rate
    }

    static func merge(_ table: CurrencyRateTable) {
        var merged = rateTable.twdPerCurrency
        for (currency, rate) in table.twdPerCurrency where rate > 0 {
            merged[currency] = rate
        }
        merged[.TWD] = 1
        rateTable = CurrencyRateTable(twdPerCurrency: merged)
    }

    static func mergeTwdRate(currency: Currency, rate: Decimal) {
        guard currency != .TWD, rate > 0 else { return }
        merge(CurrencyRateTable(twdPerCurrency: [currency: rate, .TWD: 1]))
    }

    static func update(usdToTwd rate: Decimal, updatedAt: Date? = nil) {
        mergeTwdRate(currency: .USD, rate: rate)
        if let updatedAt {
            usdToTwdUpdatedAt = updatedAt
        }
    }

    static func clear() {
        rateTable = CurrencyRateTable()
        usdToTwdUpdatedAt = nil
    }

    /// 補齊缺少的幣別匯率並寫入 session；回傳合併後的完整表。
    @MainActor
    static func loadRateTable(
        currencies: Set<Currency>,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async -> CurrencyRateTable {
        var rates = rateTable.twdPerCurrency
        rates[.TWD] = 1
        if usdToTwdRate > 0 {
            rates[.USD] = usdToTwdRate
        }

        for currency in currencies where currency != .TWD {
            if let existing = rates[currency], existing > 0 { continue }
            if let rate = try? await dataService.fetchExchangeRate(from: currency, to: .TWD, date: nil)?.rate,
               rate > 0 {
                rates[currency] = rate
            }
        }

        let table = CurrencyRateTable(twdPerCurrency: rates)
        merge(table)
        return rateTable
    }

    @MainActor
    static func warmForPortfolio(
        accounts: [Account],
        liabilities: [Liability] = [],
        accountSnapshots: [AccountSnapshot] = [],
        manualAssets: [ManualAsset] = [],
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async {
        var currencies = Set(accounts.map(\.currency))
        currencies.formUnion(liabilities.map(\.currency))
        currencies.formUnion(manualAssets.map(\.currency))
        for snapshot in accountSnapshots {
            snapshot.holdings?.forEach { currencies.insert($0.currency) }
        }
        _ = await loadRateTable(
            currencies: currencies,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        )
    }
}
