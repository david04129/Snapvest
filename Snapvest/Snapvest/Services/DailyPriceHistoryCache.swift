//
//  DailyPriceHistoryCache.swift
//  Snapvest
//
//  Session 內快取多日 history（保留供 DailyPreviousCloseSync／備份等；UI 不再讀取）。
//

import Foundation

enum DailyPriceHistoryCache {
    private static var batch: SupabasePriceBatch?
    private static var loadedAt: Date?
    private static var cachedSymbolKeys: Set<String>?
    private static let ttl: TimeInterval = 5 * 60

    static func historyContext(for symbols: [SymbolInfo]) async -> (
        exactByBatchKey: [String: [String: Decimal]],
        dateKeys: [String]
    ) {
        guard SupabaseConfig.isConfigured, !symbols.isEmpty else {
            return ([:], [])
        }

        let now = Date()
        if let batch, let loadedAt, now.timeIntervalSince(loadedAt) < ttl,
           !batch.dateKeys.isEmpty {
            return (batch.historicalPricesByKeyAndDate, batch.dateKeys)
        }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now)
        let lookbackDays = DemoHistoryFetchPolicy.previousCloseLookbackDays
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: end) ?? end
        guard let fetched = try? await SupabasePriceService.fetchBatchPrices(
            symbols: symbols,
            historyStartDate: start,
            historyEndDate: end,
            includeCurrent: false
        ) else {
            return ([:], [])
        }

        batch = fetched
        loadedAt = now
        cachedSymbolKeys = Set(symbols.map {
            SupabasePriceService.batchKey(assetType: $0.assetType, symbol: $0.symbol)
        })
        return (fetched.historicalPricesByKeyAndDate, fetched.dateKeys)
    }

    static func exactHistory(
        assetType: AssetType,
        symbol: String,
        from context: (exactByBatchKey: [String: [String: Decimal]], dateKeys: [String])
    ) -> [String: Decimal] {
        let key = SupabasePriceService.batchKey(assetType: assetType, symbol: symbol)
        return context.exactByBatchKey[key] ?? [:]
    }

    /// 僅在持股 symbol 集合變更時清 cache（新加一檔不清全 portfolio）。
    static func invalidateIfSymbolSetChanged(_ symbols: [SymbolInfo]) {
        let keys = Set(symbols.map {
            SupabasePriceService.batchKey(assetType: $0.assetType, symbol: $0.symbol)
        })
        if let cachedSymbolKeys, cachedSymbolKeys == keys {
            return
        }
        invalidate()
        cachedSymbolKeys = keys
    }

    static func invalidate() {
        batch = nil
        loadedAt = nil
    }
}
