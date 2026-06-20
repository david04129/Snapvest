//
//  DailyReferenceCloseResolver.swift
//  Snapvest
//
//  日漲跌基準：asset_price_history 中 strict 早於 current_close_date 的最近一筆收盤。
//

import Foundation

enum DailyReferenceCloseResolver {
    nonisolated static let historyPreviousCloseSource = "asset_price_history"
    nonisolated private static let bootstrapPreviousCloseSources: Set<String> = ["fugle", "yahoo", "coingecko"]

    struct ReferenceClose: Equatable, Sendable {
        let price: Decimal
        let closeDate: Date
    }

    nonisolated static func isBootstrapPreviousSource(_ source: String?) -> Bool {
        guard let source else { return false }
        return bootstrapPreviousCloseSources.contains(source)
    }

    nonisolated static func isHistoryBackedPreviousSource(_ source: String?) -> Bool {
        source == historyPreviousCloseSource
    }

    nonisolated static func isTrustedPreviousSource(_ source: String?) -> Bool {
        isHistoryBackedPreviousSource(source) || isBootstrapPreviousSource(source)
    }

    /// 供本機快照：history 或 fetch-or-create 寫入的 trusted previous。
    static func trustedSnapshotReference(
        from snapshot: AssetPriceSnapshot,
        anchorKey: String? = nil
    ) -> ReferenceClose? {
        guard isTrustedPreviousSource(snapshot.previousPriceSource),
              let previous = snapshot.previousPrice,
              previous > 0,
              let closeDate = snapshot.previousCloseDate else {
            return nil
        }
        let beforeKey = anchorKey ?? anchorDateKey(for: snapshot)
        let closeKey = TradingDayCalendar.dateKey(for: closeDate, assetType: snapshot.assetType)
        guard closeKey < beforeKey else { return nil }
        return ReferenceClose(price: previous, closeDate: closeDate)
    }

    static func anchorDateKey(for snapshot: AssetPriceSnapshot, now: Date = Date()) -> String {
        if let currentCloseDate = snapshot.currentCloseDate {
            return TradingDayCalendar.dateKey(for: currentCloseDate, assetType: snapshot.assetType)
        }
        return TradingDayCalendar.marketTodayKey(assetType: snapshot.assetType, now: now)
    }

    /// 以 snapshot.current_close_date 為基準，但若 current 價與 history 中較新交易日收盤吻合，則升級錨點。
    static func effectiveAnchorDateKey(
        for snapshot: AssetPriceSnapshot,
        exactHistoryByDate: [String: Decimal],
        historyDateKeys: [String],
        now: Date = Date()
    ) -> String {
        let snapshotKey = snapshot.currentCloseDate.map {
            TradingDayCalendar.dateKey(for: $0, assetType: snapshot.assetType)
        }
        let marketToday = TradingDayCalendar.marketTodayKey(assetType: snapshot.assetType, now: now)
        var anchor = snapshotKey ?? marketToday

        guard let current = snapshot.currentPrice else {
            return anchor
        }

        let matchingKeys = historyDateKeys.filter { key in
            guard key <= marketToday else { return false }
            guard exactHistoryByDate[key] == current else { return false }
            if let snapshotKey { return key >= snapshotKey }
            return true
        }
        if let latestMatch = matchingKeys.max() {
            anchor = max(anchor, latestMatch)
        }

        return anchor
    }

    private static func max(_ lhs: String, _ rhs: String) -> String {
        lhs >= rhs ? lhs : rhs
    }

    /// 從 history 找 strict 早於 anchorKey 的最近一筆收盤。
    static func resolveFromHistory(
        assetType: AssetType,
        exactHistoryByDate: [String: Decimal],
        historyDateKeys: [String],
        beforeAnchorKey: String
    ) -> ReferenceClose? {
        let earlierKeys = historyDateKeys
            .filter { $0 < beforeAnchorKey }
            .sorted()
            .reversed()
        for key in earlierKeys {
            guard let price = exactHistoryByDate[key], price > 0,
                  let closeDate = TradingDayCalendar.date(fromKey: key, assetType: assetType) else {
                continue
            }
            return ReferenceClose(price: price, closeDate: closeDate)
        }
        return nil
    }

    /// 供 backfill／寫入本機昨收：以 snapshot.current_close_date 為錨（無則用 market 今日）。
    static func resolvePreviousSessionClose(
        assetType: AssetType,
        symbol: String,
        exactHistoryByDate: [String: Decimal],
        historyDateKeys: [String],
        snapshot: AssetPriceSnapshot?,
        now: Date = Date()
    ) -> ReferenceClose? {
        if let snapshot {
            return resolveDisplayReferenceClose(
                snapshot: snapshot,
                exactHistoryByDate: exactHistoryByDate,
                historyDateKeys: historyDateKeys,
                now: now
            )
        }

        let anchorKey = TradingDayCalendar.marketTodayKey(assetType: assetType, now: now)
        return resolveFromHistory(
            assetType: assetType,
            exactHistoryByDate: exactHistoryByDate,
            historyDateKeys: historyDateKeys,
            beforeAnchorKey: anchorKey
        )
    }

    /// history 優先；trusted 僅在 history 缺資料且未過期時使用。
    private static func resolveDisplayReferenceClose(
        snapshot: AssetPriceSnapshot,
        exactHistoryByDate: [String: Decimal]?,
        historyDateKeys: [String]?,
        now: Date
    ) -> ReferenceClose? {
        let historyKeys = historyDateKeys ?? []
        let anchorKey: String
        if let exactHistoryByDate, !historyKeys.isEmpty {
            anchorKey = effectiveAnchorDateKey(
                for: snapshot,
                exactHistoryByDate: exactHistoryByDate,
                historyDateKeys: historyKeys,
                now: now
            )
        } else {
            anchorKey = anchorDateKey(for: snapshot, now: now)
        }

        if let exactHistoryByDate, !historyKeys.isEmpty,
           let fromHistory = resolveFromHistory(
               assetType: snapshot.assetType,
               exactHistoryByDate: exactHistoryByDate,
               historyDateKeys: historyKeys,
               beforeAnchorKey: anchorKey
           ) {
            return fromHistory
        }

        if let trusted = trustedSnapshotReference(from: snapshot, anchorKey: anchorKey),
           !isTrustedPreviousStale(
               snapshot: snapshot,
               anchorKey: anchorKey,
               historyDateKeys: historyKeys
           ) {
            return trusted
        }

        if isBootstrapPreviousSource(snapshot.previousPriceSource),
           let previous = snapshot.previousPrice,
           previous > 0,
           let closeDate = snapshot.previousCloseDate {
            let closeKey = TradingDayCalendar.dateKey(for: closeDate, assetType: snapshot.assetType)
            if closeKey < anchorKey {
                return ReferenceClose(price: previous, closeDate: closeDate)
            }
        }

        return nil
    }

    /// trusted 昨收與 anchor 之間若還有 history 交易日，視為過期。
    static func isTrustedPreviousStale(
        snapshot: AssetPriceSnapshot,
        anchorKey: String,
        historyDateKeys: [String]
    ) -> Bool {
        guard isTrustedPreviousSource(snapshot.previousPriceSource),
              let previousCloseDate = snapshot.previousCloseDate else {
            return false
        }
        let trustedKey = TradingDayCalendar.dateKey(for: previousCloseDate, assetType: snapshot.assetType)
        return historyDateKeys.contains { $0 > trustedKey && $0 < anchorKey }
    }

    /// 供 UI／今日損益：history → 未過期 trusted 本機昨收 → fetch-or-create bootstrap。
    static func effectivePreviousClose(
        snapshot: AssetPriceSnapshot,
        exactHistoryByDate: [String: Decimal]? = nil,
        historyDateKeys: [String]? = nil,
        now: Date = Date()
    ) -> ReferenceClose? {
        resolveDisplayReferenceClose(
            snapshot: snapshot,
            exactHistoryByDate: exactHistoryByDate,
            historyDateKeys: historyDateKeys,
            now: now
        )
    }

    static func dailyChange(
        snapshot: AssetPriceSnapshot,
        exactHistoryByDate: [String: Decimal]? = nil,
        historyDateKeys: [String]? = nil,
        now: Date = Date()
    ) -> (amount: Decimal, percent: Decimal)? {
        guard let current = snapshot.currentPrice ?? snapshot.displayPrice,
              current > 0 else {
            return nil
        }
        guard let reference = effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: exactHistoryByDate,
            historyDateKeys: historyDateKeys,
            now: now
        ), reference.price > 0 else {
            return nil
        }
        let change = current - reference.price
        return (change, (change / reference.price) * 100)
    }
}
