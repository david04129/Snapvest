//
//  HoldingChartMetrics.swift
//  Snapvest
//
//  持股市值／未實現損益（台幣）— 圓餅圖、績效圖共用
//

import SwiftUI

struct HoldingPerformanceRow: Identifiable {
    let id: String
    let displayName: String
    let unrealizedGainLossTWD: Decimal
    let returnPercent: Decimal
    let color: Color
    
    var gainLossDouble: Double {
        NSDecimalNumber(decimal: unrealizedGainLossTWD).doubleValue
    }
    
    var returnPercentDouble: Double {
        NSDecimalNumber(decimal: returnPercent).doubleValue
    }
}

enum PerformanceDisplayMode: String, CaseIterable, Identifiable {
    case gainLoss = "損益金額"
    case returnRate = "報酬率"
    
    var id: String { rawValue }
}

enum HoldingChartMetrics {
    static func priceMap(from snapshots: [AssetPriceSnapshot]) -> [String: AssetPriceSnapshot] {
        var map: [String: AssetPriceSnapshot] = [:]
        for s in snapshots {
            map["\(s.assetType.rawValue)_\(s.symbol)"] = s
        }
        return map
    }
    
    static func marketValueTWD(
        holding: AggregatedHoldingSnapshot,
        priceMap: [String: AssetPriceSnapshot],
        rate: Decimal
    ) -> Decimal? {
        let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
        guard let price = priceMap[key]?.displayPrice else { return nil }
        let mv = holding.totalQuantity * price
        if holding.currency == .TWD { return mv }
        if holding.currency == .USD { return mv * rate }
        return nil
    }
    
    static func totalCostTWD(holding: AggregatedHoldingSnapshot, rate: Decimal) -> Decimal? {
        if holding.currency == .TWD { return holding.totalCost }
        if holding.currency == .USD { return holding.totalCost * rate }
        return nil
    }
    
    static func colorForHolding(_ holding: AggregatedHoldingSnapshot, index: Int) -> Color {
        let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
        if UserDefaults.standard.data(forKey: key) != nil {
            return HoldingColorPreferences.getColor(for: holding.symbol, assetType: holding.assetType)
        }
        let palette: [Color]
        switch holding.assetType {
        case .stockTW: palette = AppColors.pieChartTWColors
        case .stockUS: palette = AppColors.pieChartUSColors
        case .crypto: palette = AppColors.pieChartCryptoColors
        case .cash: palette = AppColors.pieChartVibrantColors
        }
        return palette[index % palette.count]
    }
    
    /// 各檔未實現績效（台幣），已依損益由高到低排序
    static func performanceRows(inputs: PieChartInputs) -> [HoldingPerformanceRow] {
        let rate = inputs.usdToTwdRate
        let priceMap = priceMap(from: inputs.assetPriceSnapshots)
        var rows: [HoldingPerformanceRow] = []
        var index = 0
        for h in inputs.aggregatedHoldings {
            guard h.assetType != .cash,
                  let marketValueTWD = marketValueTWD(holding: h, priceMap: priceMap, rate: rate),
                  let costTWD = totalCostTWD(holding: h, rate: rate) else { continue }
            let gainLoss = marketValueTWD - costTWD
            let pct: Decimal = costTWD > 0 ? (gainLoss / costTWD) * 100 : 0
            let displayName: String
            if h.assetType == .stockTW, let n = h.name, !n.isEmpty { displayName = n }
            else { displayName = h.symbol }
            rows.append(HoldingPerformanceRow(
                id: "\(h.assetType.rawValue)_\(h.symbol)",
                displayName: displayName,
                unrealizedGainLossTWD: gainLoss,
                returnPercent: pct,
                color: colorForHolding(h, index: index)
            ))
            index += 1
        }
        return rows.sorted {
            NSDecimalNumber(decimal: $0.unrealizedGainLossTWD).doubleValue >
            NSDecimalNumber(decimal: $1.unrealizedGainLossTWD).doubleValue
        }
    }
}
