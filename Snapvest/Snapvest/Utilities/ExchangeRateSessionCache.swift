//
//  ExchangeRateSessionCache.swift
//  Snapvest
//
//  Splash 拉到的 USD/TWD 匯率 session 快取，避免明細頁重複等 Supabase。
//

import Foundation

enum ExchangeRateSessionCache {
    private(set) static var usdToTwd: Decimal?
    private(set) static var usdToTwdUpdatedAt: Date?

    static func update(usdToTwd rate: Decimal, updatedAt: Date? = nil) {
        guard rate > 0 else { return }
        usdToTwd = rate
        if let updatedAt {
            usdToTwdUpdatedAt = updatedAt
        }
    }

    static func clear() {
        usdToTwd = nil
        usdToTwdUpdatedAt = nil
    }
}
