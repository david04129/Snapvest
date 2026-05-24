//
//  HomeTrendChartSessionCache.swift
//  Snapvest
//
//  走勢圖 Supabase 查詢結果：避免切 Tab 重建時重複 loading。
//

import Foundation

@MainActor
enum HomeTrendChartSessionCache {
    private(set) static var trendPoints: [TrendChartPoint] = []
    private(set) static var loadFailed = false
    private static var cachedUserId: String?

    static func isLoaded(for userId: String) -> Bool {
        cachedUserId == userId
    }

    static func apply(userId: String, points: [TrendChartPoint], failed: Bool) {
        cachedUserId = userId
        trendPoints = points
        loadFailed = failed
    }

    static func invalidate() {
        cachedUserId = nil
        trendPoints = []
        loadFailed = false
    }
}
