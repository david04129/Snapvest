//
//  HomeTrendChartSessionCache.swift
//  Snapvest
//
//  走勢圖 Supabase 歷史查詢結果：避免切 Tab 重建時重複 loading。
//  當日即時點不在此快取，由 TrendChartPointMerger 與本機快照合併。
//

import Foundation

@MainActor
enum HomeTrendChartSessionCache {
    struct Snapshot {
        let historicalPoints: [TrendChartPoint]
        let loadFailed: Bool
        let cachedUserId: String?
    }
    
    private(set) static var historicalPoints: [TrendChartPoint] = []
    private(set) static var loadFailed = false
    private static var cachedUserId: String?

    static func isLoaded(for userId: String) -> Bool {
        cachedUserId == userId
    }

    static func applyHistorical(userId: String, points: [TrendChartPoint], failed: Bool) {
        cachedUserId = userId
        historicalPoints = points
        loadFailed = failed
    }
    
    static func snapshot() -> Snapshot {
        Snapshot(
            historicalPoints: historicalPoints,
            loadFailed: loadFailed,
            cachedUserId: cachedUserId
        )
    }
    
    static func restore(_ snapshot: Snapshot) {
        cachedUserId = snapshot.cachedUserId
        historicalPoints = snapshot.historicalPoints
        loadFailed = snapshot.loadFailed
    }

    static func invalidate() {
        cachedUserId = nil
        historicalPoints = []
        loadFailed = false
    }
}
