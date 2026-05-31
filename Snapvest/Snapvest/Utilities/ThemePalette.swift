//
//  ThemePalette.swift
//  Snapvest
//
//  單套完整色票；實際數值見 ThemeStyleCatalog。
//

import SwiftUI

struct ThemePalette {
    let stockUSColor: Color
    let stockUSDeep: Color
    let stockUSLight: Color

    let stockTWColor: Color
    let stockTWDeepAmber: Color
    let stockTWLight: Color

    let cryptoColor: Color
    let cryptoDeep: Color
    let cryptoLight: Color

    let pieChartTWColors: [Color]
    let pieChartUSColors: [Color]
    let pieChartCryptoColors: [Color]

    /// 績效圖、圓餅圖（細項）共用十色輪播
    let holdingChartColors: [Color]
    let allocationTwdCash: Color
    let allocationUsdCash: Color
    let allocationStockUS: Color
    let allocationStockTW: Color
    let allocationCrypto: Color
    let pieChartVibrantColors: [Color]
    let colorOptionsForPicker: [Color]

    let appPrimary: Color
    let appSecondary: Color

    let mainBackground: Color
    let cardBackground: Color
    let secondaryBackground: Color
    let tertiaryBackground: Color

    let profitGreen: Color
    let lossRed: Color

    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color

    let separator: Color
    let borderLight: Color
    let disabledBackground: Color
    let overlayDark: Color

    let shadowLow: Color
    let shadowMedium: Color
    let shadowSoft: Color
    let shadowCard: Color
    let shadowHigh: Color

    let actionForeground: Color
    let placeholderFill: Color
    let chartBackdropLight: Color
    let chartBackdropDark: Color
    let cashAccountColor: Color

    /// 首頁淨資產／總資產（與品牌主色一致）
    let homeNetWorthAccent: Color
    /// 首頁投資資產大類（與美股／台股市場色分離）
    let homeInvestmentsAccent: Color
    /// 首頁現金大類（與品牌綠分離）
    let homeCashAccent: Color

    /// 其他資產（靛紫，與美股藍分離）
    let manualAssetColor: Color
    let manualAssetLight: Color
}
