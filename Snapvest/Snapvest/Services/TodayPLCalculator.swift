//
//  TodayPLCalculator.swift
//  Snapvest
//
//  今日損益（持股市值相對上一交易日收盤）。
//

import Foundation

struct TodayPLCategorySummary: Identifiable, Equatable {
    let assetType: AssetType
    let changeTWD: Decimal
    let changePercent: Decimal
    let priorMarketValueTWD: Decimal

    var id: String { assetType.rawValue }
    var displayName: String { assetType.displayName }
}

struct TodayPLSummary: Equatable {
    let totalChangeTWD: Decimal
    let totalChangePercent: Decimal
    let priorMarketValueTWD: Decimal
    let categories: [TodayPLCategorySummary]
    let hasData: Bool

    static let empty = TodayPLSummary(
        totalChangeTWD: 0,
        totalChangePercent: 0,
        priorMarketValueTWD: 0,
        categories: [],
        hasData: false
    )
}

enum TodayPLCalculator {
    private static let categoryOrder: [AssetType] = AssetCategoryFilterSelection.displayOrder

    static func calculate(from inputs: PieChartInputs?) async -> TodayPLSummary {
        guard let inputs else { return .empty }

        let rate = inputs.usdToTwdRate
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)

        var changeByType: [AssetType: Decimal] = [:]
        var priorByType: [AssetType: Decimal] = [:]

        for holding in inputs.aggregatedHoldings {
            guard holding.assetType != .cash else { continue }

            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let snapshot = priceMap[key],
                  let current = snapshot.currentPrice ?? snapshot.displayPrice,
                  current > 0 else { continue }

            guard let reference = DailyReferenceCloseResolver.effectivePreviousClose(
                snapshot: snapshot
            ), reference.price > 0 else { continue }

            let changeOriginal = holding.totalQuantity * (current - reference.price)
            let priorOriginal = holding.totalQuantity * reference.price

            changeByType[holding.assetType, default: 0] += toTWD(changeOriginal, currency: holding.currency, rate: rate)
            priorByType[holding.assetType, default: 0] += toTWD(priorOriginal, currency: holding.currency, rate: rate)
        }

        let totalChange = changeByType.values.reduce(0, +)
        let totalPrior = priorByType.values.reduce(0, +)
        let totalPercent = totalPrior > 0 ? (totalChange / totalPrior) * 100 : 0

        let categories = categoryOrder.compactMap { type -> TodayPLCategorySummary? in
            let change = changeByType[type] ?? 0
            let prior = priorByType[type] ?? 0
            guard prior > 0 || change != 0 else { return nil }
            let percent = prior > 0 ? (change / prior) * 100 : 0
            return TodayPLCategorySummary(
                assetType: type,
                changeTWD: change,
                changePercent: percent,
                priorMarketValueTWD: prior
            )
        }

        return TodayPLSummary(
            totalChangeTWD: totalChange,
            totalChangePercent: totalPercent,
            priorMarketValueTWD: totalPrior,
            categories: categories,
            hasData: totalPrior > 0
        )
    }

    private static func toTWD(_ amount: Decimal, currency: Currency, rate: Decimal) -> Decimal {
        switch currency {
        case .TWD:
            return amount
        case .USD:
            return amount * rate
        default:
            return amount
        }
    }
}
