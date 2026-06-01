//
//  DailyPriceHistoryCache.swift
//  Snapvest
//
//  Session 內快取持股 history，供日漲跌與今日損益計算。
//

import Foundation

enum DailyPriceHistoryCache {
    private static var batch: SupabasePriceBatch?
    private static var loadedAt: Date?
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
        let start = calendar.date(byAdding: .day, value: -21, to: end) ?? end
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

    static func invalidate() {
        batch = nil
        loadedAt = nil
    }
}
