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
    let costBasisTWD: Decimal?

    init(
        id: String,
        displayName: String,
        unrealizedGainLossTWD: Decimal,
        returnPercent: Decimal,
        color: Color,
        costBasisTWD: Decimal? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.unrealizedGainLossTWD = unrealizedGainLossTWD
        self.returnPercent = returnPercent
        self.color = color
        self.costBasisTWD = costBasisTWD
    }
    
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
    
    static func colorForHolding(_ holding: AggregatedHoldingSnapshot, inputs: PieChartInputs) -> Color {
        let itemId = "\(holding.assetType.rawValue)_\(holding.symbol)"
        return chartColor(forItemId: itemId, inputs: inputs)
    }
    
    /// 依固定 item id 取色，切換圓餅圖模式時同一持股顏色不變
    static func chartColor(forItemId itemId: String, inputs: PieChartInputs) -> Color {
        if let slot = categoryChartColorSlot[itemId] {
            return AppColors.holdingChartColor(at: slot)
        }
        if PieChartGroupingEngine.isCashItemId(itemId),
           let index = dynamicCashItemIds(inputs: inputs).firstIndex(of: itemId) {
            return AppColors.holdingChartColor(at: index)
        }
        if itemId.hasPrefix("manual_asset_"),
           let index = stableManualAssetItemIds(inputs: inputs).firstIndex(of: itemId) {
            return AppColors.holdingChartColor(at: stableHoldingItemIds(inputs: inputs).count + index)
        }
        if UserDefaults.standard.data(forKey: itemId) != nil,
           let holding = holding(matchingItemId: itemId, inputs: inputs) {
            return HoldingColorPreferences.getColor(for: holding.symbol, assetType: holding.assetType)
        }
        let sortedIds = stableHoldingItemIds(inputs: inputs)
        let index = sortedIds.firstIndex(of: itemId) ?? 0
        return AppColors.holdingChartColor(at: index)
    }
    
    private static let categoryChartColorSlot: [String: Int] = [
        "twd_cash": 0,
        "usd_cash": 4,
        "aud_cash": 5,
        "jpy_cash": 6,
        "eur_cash": 7,
        "hkd_cash": 8,
        "cny_cash": 9,
        "stock_us": 1,
        "stock_tw": 2,
        "crypto": 3,
        "manual_assets": 10
    ]
    
    private static func dynamicCashItemIds(inputs: PieChartInputs) -> [String] {
        Currency.baseCurrencyOptions.compactMap { currency in
            guard (inputs.cashByCurrency[currency] ?? 0) > 0 else { return nil }
            return PieChartGroupingEngine.cashItemId(for: currency)
        }
    }

    private static func stableHoldingItemIds(inputs: PieChartInputs) -> [String] {
        inputs.aggregatedHoldings
            .filter { $0.assetType != .cash }
            .map { "\($0.assetType.rawValue)_\($0.symbol)" }
            .sorted()
    }

    private static func stableManualAssetItemIds(inputs: PieChartInputs) -> [String] {
        inputs.includedManualAssets
            .map { ManualAssetMetrics.itemId(for: $0) }
            .sorted()
    }
    
    private static func holding(
        matchingItemId itemId: String,
        inputs: PieChartInputs
    ) -> AggregatedHoldingSnapshot? {
        inputs.aggregatedHoldings.first {
            $0.assetType != .cash && "\($0.assetType.rawValue)_\($0.symbol)" == itemId
        }
    }
    
    /// 各檔未實現績效（台幣），已依損益由高到低排序
    static func performanceRows(inputs: PieChartInputs) -> [HoldingPerformanceRow] {
        let rate = inputs.usdToTwdRate
        let priceMap = priceMap(from: inputs.assetPriceSnapshots)
        var rows: [HoldingPerformanceRow] = []
        for h in inputs.aggregatedHoldings {
            guard h.assetType != .cash,
                  let marketValueTWD = marketValueTWD(holding: h, priceMap: priceMap, rate: rate),
                  let costTWD = totalCostTWD(holding: h, rate: rate) else { continue }
            let gainLoss = marketValueTWD - costTWD
            let pct: Decimal = costTWD > 0 ? (gainLoss / costTWD) * 100 : 0
            let displayName: String
            if h.assetType == .stockTW {
                displayName = SymbolListService.displayName(
                    assetType: h.assetType,
                    symbol: h.symbol,
                    storedName: h.name
                )
            } else {
                displayName = h.symbol
            }
            rows.append(HoldingPerformanceRow(
                id: "\(h.assetType.rawValue)_\(h.symbol)",
                displayName: displayName,
                unrealizedGainLossTWD: gainLoss,
                returnPercent: pct,
                color: colorForHolding(h, inputs: inputs),
                costBasisTWD: costTWD
            ))
        }
        for asset in inputs.investmentManualAssets {
            guard let gainLoss = ManualAssetMetrics.gainLossTWD(asset: asset, rates: inputs.twdRateByCurrency),
                  let costTWD = ManualAssetMetrics.costTWD(asset: asset, rates: inputs.twdRateByCurrency),
                  let returnPercent = ManualAssetMetrics.returnPercent(asset: asset, rates: inputs.twdRateByCurrency) else {
                continue
            }
            let itemId = ManualAssetMetrics.itemId(for: asset)
            rows.append(HoldingPerformanceRow(
                id: itemId,
                displayName: asset.name,
                unrealizedGainLossTWD: gainLoss,
                returnPercent: returnPercent,
                color: chartColor(forItemId: itemId, inputs: inputs),
                costBasisTWD: costTWD
            ))
        }
        return rows.sorted {
            NSDecimalNumber(decimal: $0.unrealizedGainLossTWD).doubleValue >
            NSDecimalNumber(decimal: $1.unrealizedGainLossTWD).doubleValue
        }
    }
}
