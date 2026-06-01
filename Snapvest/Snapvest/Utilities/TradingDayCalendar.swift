//
//  TradingDayCalendar.swift
//  Snapvest
//
//  各市場本地曆日（收盤日／昨收查詢用）。
//

import Foundation

enum TradingDayCalendar {
    private static let posix = Locale(identifier: "en_US_POSIX")

    static func timeZone(for assetType: AssetType) -> TimeZone {
        switch assetType {
        case .stockUS:
            return TimeZone(identifier: "America/New_York") ?? .current
        case .stockTW, .crypto, .cash:
            return TimeZone(identifier: "Asia/Taipei") ?? .current
        }
    }

    static func dateKey(for date: Date, assetType: AssetType) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = posix
        formatter.timeZone = timeZone(for: assetType)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfDay(date, assetType: assetType))
    }

    static func date(fromKey key: String, assetType: AssetType) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = posix
        formatter.timeZone = timeZone(for: assetType)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key).map { startOfDay($0, assetType: assetType) }
    }

    static func marketTodayKey(assetType: AssetType, now: Date = Date()) -> String {
        dateKey(for: now, assetType: assetType)
    }

    static func startOfDay(_ date: Date, assetType: AssetType) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone(for: assetType)
        return calendar.startOfDay(for: date)
    }
}
