//
//  HoldingNavigationItem.swift
//  Snapvest
//
//  個股詳情導航 payload（資產 Tab、帳戶詳情共用）
//

import Foundation

struct HoldingNavigationItem: Identifiable, Hashable {
    let id: String
    let aggregatedHolding: AggregatedHoldingSnapshot
    let assetPriceSnapshot: AssetPriceSnapshot?
    let totalAssets: Decimal
    let totalInvestments: Decimal
    
    init(
        aggregatedHolding: AggregatedHoldingSnapshot,
        assetPriceSnapshot: AssetPriceSnapshot?,
        totalAssets: Decimal,
        totalInvestments: Decimal
    ) {
        self.id = aggregatedHolding.id
        self.aggregatedHolding = aggregatedHolding
        self.assetPriceSnapshot = assetPriceSnapshot
        self.totalAssets = totalAssets
        self.totalInvestments = totalInvestments
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(aggregatedHolding.lastUpdated)
        hasher.combine(aggregatedHolding.totalQuantity)
        hasher.combine(aggregatedHolding.version)
        hasher.combine(totalAssets)
        hasher.combine(totalInvestments)
    }
    
    /// 持股資料變更時須判定為不同 item，詳情頁才會刷新
    static func == (lhs: HoldingNavigationItem, rhs: HoldingNavigationItem) -> Bool {
        lhs.id == rhs.id
            && lhs.aggregatedHolding == rhs.aggregatedHolding
            && lhs.assetPriceSnapshot == rhs.assetPriceSnapshot
            && lhs.totalAssets == rhs.totalAssets
            && lhs.totalInvestments == rhs.totalInvestments
    }
}

enum HoldingNavigationBuilder {
    @MainActor
    static func load(
        userId: String,
        assetType: AssetType,
        symbol: String,
        dataService: DataServiceProtocol? = nil,
        priceService: PriceServiceProtocol? = nil
    ) async throws -> HoldingNavigationItem? {
        let service = dataService ?? MockDataService.shared
        let prices = priceService ?? PriceService(dataService: service)
        
        let inputs = try await PieChartDataLoader.load(
            userId: userId,
            dataService: service,
            priceService: prices
        )
        
        guard let aggregated = inputs.aggregatedHoldings.first(where: {
            $0.assetType == assetType && $0.symbol == symbol
        }) else {
            return nil
        }
        
        let totals = portfolioTotals(from: inputs)
        let priceSnapshot = inputs.assetPriceSnapshots.first {
            $0.assetType == assetType && $0.symbol == symbol
        }
        
        return HoldingNavigationItem(
            aggregatedHolding: aggregated,
            assetPriceSnapshot: priceSnapshot,
            totalAssets: totals.totalAssets,
            totalInvestments: totals.totalInvestments
        )
    }
    
    static func make(
        aggregatedHolding: AggregatedHoldingSnapshot,
        assetPriceSnapshots: [AssetPriceSnapshot],
        totalAssets: Decimal,
        totalInvestments: Decimal
    ) -> HoldingNavigationItem {
        let priceSnapshot = assetPriceSnapshots.first {
            $0.assetType == aggregatedHolding.assetType && $0.symbol == aggregatedHolding.symbol
        }
        return HoldingNavigationItem(
            aggregatedHolding: aggregatedHolding,
            assetPriceSnapshot: priceSnapshot,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments
        )
    }
    
    static func portfolioTotals(from inputs: PieChartInputs) -> (totalAssets: Decimal, totalInvestments: Decimal) {
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)
        var totalInvestments: Decimal = 0
        for holding in inputs.aggregatedHoldings {
            guard let marketValue = HoldingChartMetrics.marketValueTWD(
                holding: holding,
                priceMap: priceMap,
                rate: inputs.usdToTwdRate
            ) else { continue }
            totalInvestments += marketValue
        }
        let totalCash = inputs.twdCash + inputs.usdCash * inputs.usdToTwdRate
        return (totalInvestments + totalCash, totalInvestments)
    }
}
