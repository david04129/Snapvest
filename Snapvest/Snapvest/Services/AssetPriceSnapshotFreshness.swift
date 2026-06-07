//
//  AssetPriceSnapshotFreshness.swift
//  Snapvest
//
//  判斷 asset_price_snapshots 是否過期（prefetch / fetch-or-create 用）。
//

import Foundation

enum AssetPriceSnapshotFreshness {
    /// 買進 prefetch：current_close_date 須落在今日或近幾個曆日內（週一仍接受週五收盤）。
    nonisolated static func isStaleForLiveQuote(_ snapshot: AssetPriceSnapshot, now: Date = Date()) -> Bool {
        switch snapshot.assetType {
        case .stockTW, .stockUS:
            return isEquityCloseDateStale(assetType: snapshot.assetType, closeDate: snapshot.currentCloseDate, now: now)
        case .crypto:
            guard let updatedAt = snapshot.currentUpdatedAt else { return true }
            return now.timeIntervalSince(updatedAt) > 3600
        case .cash:
            return true
        }
    }

    nonisolated static func isEquityCloseDateStale(
        assetType: AssetType,
        closeDate: Date?,
        now: Date = Date()
    ) -> Bool {
        guard let closeDate else { return true }
        let closeKey = TradingDayCalendar.dateKey(for: closeDate, assetType: assetType)
        return !acceptableCloseDateKeys(for: assetType, now: now).contains(closeKey)
    }

    nonisolated static func acceptableCloseDateKeys(for assetType: AssetType, now: Date = Date()) -> Set<String> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TradingDayCalendar.timeZone(for: assetType)
        let anchor = TradingDayCalendar.startOfDay(now, assetType: assetType)
        var keys = Set<String>()
        // 今日 + 往前 3 曆日：週一仍接受週五（中間週末無收盤日）
        for offset in 0...3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: anchor) else { continue }
            keys.insert(TradingDayCalendar.dateKey(for: day, assetType: assetType))
        }
        return keys
    }
}
