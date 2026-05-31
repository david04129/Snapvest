//
//  TotalAssetsShareCalculator.swift
//  Snapvest
//
//  管理分頁：佔總資產比例（分母與首頁 totalAssets 一致，未納入者不計入分子）。
//

import Foundation

enum TotalAssetsShareCalculator {
    /// 佔總資產百分比（0–100）。`numeratorTWD` 應為納入總資產的 TWD 金額；負債傳入正值。
    static func sharePercent(numeratorTWD: Decimal, totalAssetsTWD: Decimal) -> Decimal {
        guard totalAssetsTWD > 0, numeratorTWD > 0 else { return 0 }
        return (numeratorTWD / totalAssetsTWD) * 100
    }

    static func sharePercentFromDisplay(
        numeratorDisplay: Decimal,
        totalAssetsDisplay: Decimal
    ) -> Decimal {
        guard totalAssetsDisplay > 0, numeratorDisplay > 0 else { return 0 }
        return (numeratorDisplay / totalAssetsDisplay) * 100
    }

    static func displayAmount(fromTWD twd: Decimal, twdPerBaseCurrency: Decimal) -> Decimal {
        guard twdPerBaseCurrency > 0 else { return twd }
        return twd / twdPerBaseCurrency
    }

    static func totalAssetsTWD(totalAssetsDisplay: Decimal, twdPerBaseCurrency: Decimal) -> Decimal {
        guard twdPerBaseCurrency > 0 else { return totalAssetsDisplay }
        return totalAssetsDisplay * twdPerBaseCurrency
    }
}
