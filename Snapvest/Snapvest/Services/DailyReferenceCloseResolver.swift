//
//  DailyReferenceCloseResolver.swift
//  Snapvest
//
//  上一個「有 history 收盤」的交易日作為日漲跌基準（休市日自動往前沿用）。
//

import Foundation

enum DailyReferenceCloseResolver {
    struct ReferenceClose: Equatable {
        let price: Decimal
        let closeDate: Date
    }

    /// 從 history 找「嚴格早於今日（市場本地曆日）」最近一筆收盤。
    static func resolvePreviousSessionClose(
        assetType: AssetType,
        symbol: String,
        exactHistoryByDate: [String: Decimal],
        historyDateKeys: [String],
        snapshot: AssetPriceSnapshot?,
        now: Date = Date()
    ) -> ReferenceClose? {
        let todayKey = TradingDayCalendar.marketTodayKey(assetType: assetType, now: now)

        let earlierKeys = historyDateKeys
            .filter { $0 < todayKey }
            .sorted()
            .reversed()
        for key in earlierKeys {
            guard let price = exactHistoryByDate[key], price > 0,
                  let closeDate = TradingDayCalendar.date(fromKey: key, assetType: assetType) else {
                continue
            }
            return ReferenceClose(price: price, closeDate: closeDate)
        }

        return fallbackFromSnapshot(snapshot, assetType: assetType, todayKey: todayKey)
    }

    /// 供 UI／今日損益：優先 snapshot 已對齊的 previous，否則 history。
    static func effectivePreviousClose(
        snapshot: AssetPriceSnapshot,
        exactHistoryByDate: [String: Decimal]? = nil,
        historyDateKeys: [String]? = nil,
        now: Date = Date()
    ) -> ReferenceClose? {
        let todayKey = TradingDayCalendar.marketTodayKey(assetType: snapshot.assetType, now: now)
        let current = snapshot.currentPrice ?? snapshot.displayPrice
        let stalePreviousEqualsCurrent = snapshot.previousPrice != nil
            && current != nil
            && snapshot.previousPrice == current

        if let exactHistoryByDate, let historyDateKeys,
           let fromHistory = resolvePreviousSessionClose(
               assetType: snapshot.assetType,
               symbol: snapshot.symbol,
               exactHistoryByDate: exactHistoryByDate,
               historyDateKeys: historyDateKeys,
               snapshot: snapshot,
               now: now
           ) {
            if stalePreviousEqualsCurrent || fromHistory.price != current {
                return fromHistory
            }
        }

        if let previous = snapshot.previousPrice,
           previous > 0,
           let closeDate = snapshot.previousCloseDate {
            let closeKey = TradingDayCalendar.dateKey(for: closeDate, assetType: snapshot.assetType)
            if closeKey < todayKey, !stalePreviousEqualsCurrent {
                return ReferenceClose(price: previous, closeDate: closeDate)
            }
        }

        if let exactHistoryByDate, let historyDateKeys {
            return resolvePreviousSessionClose(
                assetType: snapshot.assetType,
                symbol: snapshot.symbol,
                exactHistoryByDate: exactHistoryByDate,
                historyDateKeys: historyDateKeys,
                snapshot: snapshot,
                now: now
            )
        }

        return fallbackFromSnapshot(snapshot, assetType: snapshot.assetType, todayKey: todayKey)
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

    private static func fallbackFromSnapshot(
        _ snapshot: AssetPriceSnapshot?,
        assetType: AssetType,
        todayKey: String
    ) -> ReferenceClose? {
        guard let snapshot,
              let previous = snapshot.previousPrice,
              previous > 0,
              let closeDate = snapshot.previousCloseDate else {
            return nil
        }
        let closeKey = TradingDayCalendar.dateKey(for: closeDate, assetType: assetType)
        guard closeKey < todayKey else { return nil }
        return ReferenceClose(price: previous, closeDate: closeDate)
    }
}
