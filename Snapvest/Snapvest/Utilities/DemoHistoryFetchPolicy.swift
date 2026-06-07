//
//  DemoHistoryFetchPolicy.swift
//  Snapvest
//
//  示範模式僅拉最近 1～2 天 history（昨收／今日損益），避免進示範時大量流量。
//

import Foundation

enum DemoHistoryFetchPolicy {
    /// 一般模式：僅 HoldingDetail／DailyPreviousCloseSync（demo／備份）用；冷啟／下拉不拉 21 天。
    static var previousCloseLookbackDays: Int {
        MockDataService.shared.isDemoModeActive ? 2 : 21
    }

    static var isDemoModeActive: Bool {
        MockDataService.shared.isDemoModeActive
    }
}
