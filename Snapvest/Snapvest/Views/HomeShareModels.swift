//
//  HomeShareModels.swift
//  Snapvest
//
//  首頁圖表分享：選項與渲染設定
//

import SwiftUI

enum HomeShareChartKind: String, CaseIterable, Identifiable {
    case trend = "走勢圖"
    case pie = "圓餅圖"
    case performance = "績效圖"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .trend: return "chart.xyaxis.line"
        case .pie: return "chart.pie.fill"
        case .performance: return "chart.bar.xaxis"
        }
    }
}

struct HomeShareRenderConfig {
    let hideAmounts: Bool
    let isDarkMode: Bool
    let currency: Currency
    let generatedAt: Date

    let includeTrend: Bool
    let trendPoints: [TrendChartPoint]
    let trendMetricMode: TrendMetricMode
    let trendTimeRange: DateRangePreset
    let trendCustomStart: Date
    let trendCustomEnd: Date

    let includePie: Bool
    let pieInputs: PieChartInputs?
    let pieMode: PieChartDisplayMode
    let pieIsGroupingEnabled: Bool
    let pieShowsLegend: Bool
    let pieShowsSliceLabels: Bool
    /// 與首頁圓餅圖明細同步的群組展開狀態
    let pieExpandedGroupIds: Set<String>
    let totalAssets: Decimal
    let totalInvestments: Decimal

    let includePerformance: Bool
    let performanceMode: PerformanceDisplayMode

    var selectedKinds: [HomeShareChartKind] {
        var kinds: [HomeShareChartKind] = []
        if includeTrend { kinds.append(.trend) }
        if includePie { kinds.append(.pie) }
        if includePerformance { kinds.append(.performance) }
        return kinds
    }

    func isAvailable(_ kind: HomeShareChartKind) -> Bool {
        switch kind {
        case .trend:
            return trendPoints.count >= 2
        case .pie:
            guard let pieInputs else { return false }
            let base = PieChartGroupingModeSupport.effectiveBaseItems(
                mode: pieMode,
                inputs: pieInputs,
                isGroupingEnabled: pieIsGroupingEnabled
            )
            let display = PieChartGroupingEngine.applyGroups(
                baseItems: base,
                groups: PieChartGroupingStore.shared.groups,
                mode: pieMode,
                isGroupingEnabled: pieIsGroupingEnabled
            )
            return !display.isEmpty
        case .performance:
            guard let pieInputs else { return false }
            let groups = PieChartGroupingStore.shared.groups
            let rows = PieChartGroupingModeSupport.performanceRows(
                inputs: pieInputs,
                groups: groups,
                pieMode: pieMode,
                isGroupingEnabled: pieIsGroupingEnabled
            )
            return !rows.isEmpty
        }
    }

    func subtitle(for kind: HomeShareChartKind) -> String {
        switch kind {
        case .trend:
            return "\(trendMetricMode.rawValue) · \(trendTimeRange.rawValue)"
        case .pie:
            return pieMode.rawValue
        case .performance:
            return performanceMode.rawValue
        }
    }

    /// 分享用走勢點：優先使用目前區間；不足時改用全部資料
    var effectiveTrendPoints: [TrendChartPoint] {
        let filtered = TrendChartDataFilter.filtered(
            points: trendPoints,
            range: trendTimeRange,
            customStart: trendCustomStart,
            customEnd: trendCustomEnd
        )
        if filtered.count >= 2 { return filtered }
        return trendPoints.count >= 2 ? trendPoints : filtered
    }
}
