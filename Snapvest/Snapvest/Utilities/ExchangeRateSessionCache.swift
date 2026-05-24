//
//  ExchangeRateSessionCache.swift
//  Snapvest
//
//  Splash 拉到的 USD/TWD 匯率 session 快取，避免明細頁重複等 Supabase。
//

import Foundation

enum ExchangeRateSessionCache {
    private(set) static var usdToTwd: Decimal?

    static func update(usdToTwd rate: Decimal) {
        guard rate > 0 else { return }
        usdToTwd = rate
    }

    static func clear() {
        usdToTwd = nil
    }
}
