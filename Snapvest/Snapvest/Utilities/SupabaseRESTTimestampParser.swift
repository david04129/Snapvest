//
//  SupabaseRESTTimestampParser.swift
//  Snapvest
//
//  PostgreSQL / Supabase REST 時間字串（UTC ISO8601 或台北本地 TIMESTAMP）。
//

import Foundation

enum SupabaseRESTTimestampParser {
    nonisolated static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTime
        ]
        withFraction.timeZone = TimeZone(identifier: "UTC")
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        withoutFraction.timeZone = TimeZone(identifier: "UTC")
        if let parsed = withFraction.date(from: string) ?? withoutFraction.date(from: string) {
            return parsed
        }

        let taipeiLocal = DateFormatter()
        taipeiLocal.locale = Locale(identifier: "en_US_POSIX")
        taipeiLocal.timeZone = TimeZone(identifier: "Asia/Taipei")
        taipeiLocal.dateFormat = string.contains("T") ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd HH:mm:ss"
        return taipeiLocal.date(from: String(string.prefix(19)))
    }

    /// PostgreSQL DATE（yyyy-MM-dd）
    nonisolated static func parseCloseDate(_ string: String?) -> Date? {
        guard let string, string.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(string.prefix(10)))
    }

    nonisolated static func closeDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
