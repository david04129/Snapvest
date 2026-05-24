//
//  ColorTheme.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

// MARK: - 集中化顏色集合（隨 ThemeManager 切換淺色 / 深色，方向 A）
enum AppColors {
    private static var p: ThemePalette { ThemeManager.shared.palette }
    
    // 美股（藍系，與 appPrimary 青綠品牌色分離）
    static var stockUSColor: Color { p.stockUSColor }
    static var stockUSDeep: Color { p.stockUSDeep }
    static var stockUSLight: Color { p.stockUSLight }
    
    // 台股（琥珀系）
    static var stockTWColor: Color { p.stockTWColor }
    static var stockTWDeepAmber: Color { p.stockTWDeepAmber }
    static var stockTWLight: Color { p.stockTWLight }
    
    // 加密（青綠系，與品牌同族）
    static var cryptoColor: Color { p.cryptoColor }
    static var cryptoDeep: Color { p.cryptoDeep }
    static var cryptoLight: Color { p.cryptoLight }
    
    /// 舊名稱相容：文字強調色
    static var stockTWDeepBlue: Color { p.stockTWDeepAmber }
    static var stockUSDeepGreen: Color { p.stockUSDeep }
    static var stockUSDeepPurple: Color { p.stockUSDeep }
    static var cryptoDeepBrown: Color { p.cryptoDeep }
    
    static var pieChartTWColors: [Color] { p.pieChartTWColors }
    static var pieChartUSColors: [Color] { p.pieChartUSColors }
    static var pieChartCryptoColors: [Color] { p.pieChartCryptoColors }
    
    /// 績效圖、圓餅圖共用十色
    static var holdingChartColors: [Color] { p.holdingChartColors }
    
    static func holdingChartColor(at index: Int) -> Color {
        let palette = holdingChartColors
        guard !palette.isEmpty else { return secondaryText }
        return palette[index % palette.count]
    }
    
    static var allocationTwdCash: Color { p.allocationTwdCash }
    static var allocationUsdCash: Color { p.allocationUsdCash }
    static var allocationStockUS: Color { p.allocationStockUS }
    static var allocationStockTW: Color { p.allocationStockTW }
    static var allocationCrypto: Color { p.allocationCrypto }
    
    static var pieChartVibrantColors: [Color] { p.pieChartVibrantColors }
    static var pieChartColors: [Color] { p.holdingChartColors }
    static var colorOptionsForPicker: [Color] { p.colorOptionsForPicker }
    
    static var appPrimary: Color { p.appPrimary }
    static var appSecondary: Color { p.appSecondary }
    
    static var mainBackground: Color { p.mainBackground }
    static var cardBackground: Color { p.cardBackground }
    static var secondaryBackground: Color { p.secondaryBackground }
    static var tertiaryBackground: Color { p.tertiaryBackground }
    
    static var cashTWDColor: Color { p.stockTWColor }
    static var cashUSDColor: Color { p.stockUSColor }
    
    static var profitGreen: Color { p.profitGreen }
    static var lossRed: Color { p.lossRed }
    
    /// 漲（預設綠；紅漲綠跌時為紅）
    static var marketUp: Color {
        ThemeManager.shared.isRedUpGreenDown ? p.lossRed : p.profitGreen
    }
    
    /// 跌（預設紅；紅漲綠跌時為綠）
    static var marketDown: Color {
        ThemeManager.shared.isRedUpGreenDown ? p.profitGreen : p.lossRed
    }
    
    static func marketColor(for change: Decimal) -> Color {
        change >= 0 ? marketUp : marketDown
    }
    
    static func marketColor(isPositive: Bool) -> Color {
        isPositive ? marketUp : marketDown
    }
    
    static var primaryText: Color { p.primaryText }
    static var secondaryText: Color { p.secondaryText }
    static var tertiaryText: Color { p.tertiaryText }
    
    static var separator: Color { p.separator }
    static var borderLight: Color { p.borderLight }
    
    static var disabledBackground: Color { p.disabledBackground }
    static var disabledForeground: Color { p.secondaryText.opacity(0.6) }
    static var overlayDark: Color { p.overlayDark }
    
    static var shadowLow: Color { p.shadowLow }
    static var shadowMedium: Color { p.shadowMedium }
    static var shadowSoft: Color { p.shadowSoft }
    static var shadowCard: Color { p.shadowCard }
    static var shadowHigh: Color { p.shadowHigh }
    
    static var strokeSubtle: Color { p.primaryText.opacity(ThemeManager.shared.isDarkMode ? 0.12 : 0.1) }
    static var strokeMuted: Color { p.primaryText.opacity(ThemeManager.shared.isDarkMode ? 0.22 : 0.2) }
    
    static var noticeForeground: Color { p.appPrimary }
    static var noticeBackground: Color { p.appPrimary.opacity(0.12) }
    
    static var actionEditBackground: Color { p.appPrimary }
    static var actionDestructiveBackground: Color { p.lossRed }
    static var actionForeground: Color { p.actionForeground }
    
    static var chipBackground: Color { p.appPrimary.opacity(0.14) }
    static var placeholderFill: Color { p.placeholderFill }
    static var chartBackdropLight: Color { p.chartBackdropLight }
    static var chartBackdropDark: Color { p.chartBackdropDark }
    static var cashAccountColor: Color { p.cashAccountColor }
}

/// iOS 風格的顏色主題（為舊有呼叫提供相容入口）
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static var appPrimary: Color { AppColors.appPrimary }
    static var appSecondary: Color { AppColors.appSecondary }
    
    static var mainBackground: Color { AppColors.mainBackground }
    static var cardBackground: Color { AppColors.cardBackground }
    static var secondaryBackground: Color { AppColors.secondaryBackground }
    static var tertiaryBackground: Color { AppColors.tertiaryBackground }
    
    static var profitGreen: Color { AppColors.profitGreen }
    static var lossRed: Color { AppColors.lossRed }
    static var marketUp: Color { AppColors.marketUp }
    static var marketDown: Color { AppColors.marketDown }
    
    static func marketColor(for change: Decimal) -> Color {
        AppColors.marketColor(for: change)
    }
    
    static func marketColor(isPositive: Bool) -> Color {
        AppColors.marketColor(isPositive: isPositive)
    }
    
    static var stockTWColor: Color { AppColors.stockTWColor }
    static var stockTWDeepBlue: Color { AppColors.stockTWDeepBlue }
    static var stockTWDeepAmber: Color { AppColors.stockTWDeepAmber }
    static var stockUSColor: Color { AppColors.stockUSColor }
    static var stockUSDeepGreen: Color { AppColors.stockUSDeepGreen }
    static var stockUSDeepPurple: Color { AppColors.stockUSDeepPurple }
    static var stockUSDeep: Color { AppColors.stockUSDeep }
    static var cryptoColor: Color { AppColors.cryptoColor }
    static var cryptoDeepBrown: Color { AppColors.cryptoDeepBrown }
    static var cryptoDeep: Color { AppColors.cryptoDeep }
    
    static var primaryText: Color { AppColors.primaryText }
    static var secondaryText: Color { AppColors.secondaryText }
    static var tertiaryText: Color { AppColors.tertiaryText }
    
    static var separator: Color { AppColors.separator }
    static var borderLight: Color { AppColors.borderLight }
    
    static var pieChartColors: [Color] { AppColors.pieChartColors }
    static var pieChartVibrantColors: [Color] { AppColors.pieChartVibrantColors }
    static var colorOptionsForPicker: [Color] { AppColors.colorOptionsForPicker }
    static var allocationTwdCash: Color { AppColors.allocationTwdCash }
    static var allocationUsdCash: Color { AppColors.allocationUsdCash }
}
