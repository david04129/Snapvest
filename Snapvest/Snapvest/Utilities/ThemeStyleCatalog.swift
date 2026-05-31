//
//  ThemeStyleCatalog.swift
//  Snapvest
//
//  各風格 × 淺／深的完整色票定義。
//

import SwiftUI

enum ThemeStyleCatalog {
    static func palette(style: ThemeStyleID, isDarkMode: Bool) -> ThemePalette {
        switch style {
        case .steadyFinance:
            return isDarkMode ? steadyFinanceDark : steadyFinanceLight
        case .vividContrast:
            return isDarkMode ? vividContrastDark : vividContrastLight
        }
    }

    // MARK: - 沉穩理財（與改版前 light / dark 相同）

    static let steadyFinanceLight = ThemePalette(
        stockUSColor: Color(hex: "#2563EB"),
        stockUSDeep: Color(hex: "#1D4ED8"),
        stockUSLight: Color(hex: "#2563EB").opacity(0.16),
        stockTWColor: Color(hex: "#F2C078"),
        stockTWDeepAmber: Color(hex: "#F2C078"),
        stockTWLight: Color(hex: "#F2C078").opacity(0.22),
        cryptoColor: Color(hex: "#DB2777"),
        cryptoDeep: Color(hex: "#BE185D"),
        cryptoLight: Color(hex: "#DB2777").opacity(0.22),
        pieChartTWColors: [
            Color(hex: "#F2C078"), Color(hex: "#D97706"), Color(hex: "#F59E0B"),
            Color(hex: "#B45309"), Color(hex: "#92400E"), Color(hex: "#FBBF24")
        ],
        pieChartUSColors: [
            Color(hex: "#2563EB"), Color(hex: "#3B82F6"), Color(hex: "#1D4ED8"),
            Color(hex: "#60A5FA"), Color(hex: "#93C5FD"), Color(hex: "#BFDBFE")
        ],
        pieChartCryptoColors: [
            Color(hex: "#DB2777"), Color(hex: "#EC4899"), Color(hex: "#F472B6"),
            Color(hex: "#BE185D"), Color(hex: "#9D174D"), Color(hex: "#FBCFE8")
        ],
        holdingChartColors: [
            Color(hex: "#DB2777"), Color(hex: "#7ED957"), Color(hex: "#F2C078"),
            Color(hex: "#7C3AED"), Color(hex: "#0891B2"), Color(hex: "#4F46E5"),
            Color(hex: "#EA580C"), Color(hex: "#DB2777"), Color(hex: "#CA8A04"),
            Color(hex: "#64748B")
        ],
        allocationTwdCash: Color(hex: "#4CAF36"),
        allocationUsdCash: Color(hex: "#B7E99A"),
        allocationStockUS: Color(hex: "#2563EB"),
        allocationStockTW: Color(hex: "#F2C078"),
        allocationCrypto: Color(hex: "#DB2777"),
        pieChartVibrantColors: [
            Color(hex: "#DB2777"), Color(hex: "#7ED957"), Color(hex: "#F2C078"),
            Color(hex: "#7C3AED"), Color(hex: "#0891B2"), Color(hex: "#4F46E5"),
            Color(hex: "#EA580C"), Color(hex: "#DB2777"), Color(hex: "#CA8A04"),
            Color(hex: "#64748B")
        ],
        colorOptionsForPicker: [
            Color(hex: "#4CAF36"), Color(hex: "#7ED957"), Color(hex: "#B7E99A"),
            Color(hex: "#F2C078"),
            Color(hex: "#0F766E"), Color(hex: "#0D9488"), Color(hex: "#14B8A6"),
            Color(hex: "#2563EB"), Color(hex: "#3B82F6"), Color(hex: "#D97706"),
            Color(hex: "#F59E0B"), Color(hex: "#64748B")
        ],
        appPrimary: Color(hex: "#4CAF36"),
        appSecondary: Color(hex: "#7ED957"),
        mainBackground: Color(hex: "#F4F6F8"),
        cardBackground: Color.white,
        secondaryBackground: Color(hex: "#EEF2F6"),
        tertiaryBackground: Color(hex: "#F4F6F8"),
        profitGreen: Color(hex: "#4CAF36"),
        lossRed: Color(hex: "#DC2626"),
        primaryText: Color(hex: "#111827"),
        secondaryText: Color(hex: "#64748B"),
        tertiaryText: Color(hex: "#94A3B8"),
        separator: Color(hex: "#E2E8F0"),
        borderLight: Color(hex: "#CBD5E1"),
        disabledBackground: Color(hex: "#EEF2F6"),
        overlayDark: Color.black.opacity(0.85),
        shadowLow: Color.black.opacity(0.03),
        shadowMedium: Color.black.opacity(0.05),
        shadowSoft: Color(hex: "#0F172A").opacity(0.06),
        shadowCard: Color(hex: "#0F172A").opacity(0.08),
        shadowHigh: Color(hex: "#0F172A").opacity(0.1),
        actionForeground: Color.white,
        placeholderFill: Color(hex: "#E2E8F0"),
        chartBackdropLight: Color(hex: "#EEF2F6"),
        chartBackdropDark: Color(hex: "#E2E8F0").opacity(0.35),
        cashAccountColor: Color(hex: "#64748B"),
        homeNetWorthAccent: Color(hex: "#4CAF36"),
        homeInvestmentsAccent: Color(hex: "#4F46E5"),
        homeCashAccent: Color(hex: "#64748B"),
        manualAssetColor: Color(hex: "#7C3AED"),
        manualAssetLight: Color(hex: "#7C3AED").opacity(0.16)
    )

    static let steadyFinanceDark = ThemePalette(
        stockUSColor: Color(hex: "#60A5FA"),
        stockUSDeep: Color(hex: "#93C5FD"),
        stockUSLight: Color(hex: "#60A5FA").opacity(0.22),
        stockTWColor: Color(hex: "#F2C078"),
        stockTWDeepAmber: Color(hex: "#F2C078"),
        stockTWLight: Color(hex: "#F2C078").opacity(0.24),
        cryptoColor: Color(hex: "#F472B6"),
        cryptoDeep: Color(hex: "#FB7185"),
        cryptoLight: Color(hex: "#F472B6").opacity(0.22),
        pieChartTWColors: [
            Color(hex: "#F2C078"), Color(hex: "#FBBF24"), Color(hex: "#F59E0B"),
            Color(hex: "#D97706"), Color(hex: "#B45309"), Color(hex: "#FCD34D")
        ],
        pieChartUSColors: [
            Color(hex: "#3B82F6"), Color(hex: "#60A5FA"), Color(hex: "#93C5FD"),
            Color(hex: "#BFDBFE"), Color(hex: "#DBEAFE"), Color(hex: "#EFF6FF")
        ],
        pieChartCryptoColors: [
            Color(hex: "#F472B6"), Color(hex: "#FB7185"), Color(hex: "#EC4899"),
            Color(hex: "#DB2777"), Color(hex: "#BE185D"), Color(hex: "#FBCFE8")
        ],
        holdingChartColors: [
            Color(hex: "#F472B6"), Color(hex: "#B7E99A"), Color(hex: "#F2C078"),
            Color(hex: "#A78BFA"), Color(hex: "#22D3EE"), Color(hex: "#818CF8"),
            Color(hex: "#FB923C"), Color(hex: "#F472B6"), Color(hex: "#FACC15"),
            Color(hex: "#94A3B8")
        ],
        allocationTwdCash: Color(hex: "#7ED957"),
        allocationUsdCash: Color(hex: "#B7E99A"),
        allocationStockUS: Color(hex: "#60A5FA"),
        allocationStockTW: Color(hex: "#F2C078"),
        allocationCrypto: Color(hex: "#F472B6"),
        pieChartVibrantColors: [
            Color(hex: "#F472B6"), Color(hex: "#B7E99A"), Color(hex: "#F2C078"),
            Color(hex: "#A78BFA"), Color(hex: "#22D3EE"), Color(hex: "#818CF8"),
            Color(hex: "#FB923C"), Color(hex: "#F472B6"), Color(hex: "#FACC15"),
            Color(hex: "#94A3B8")
        ],
        colorOptionsForPicker: [
            Color(hex: "#7ED957"), Color(hex: "#B7E99A"), Color(hex: "#F2C078"),
            Color(hex: "#2DD4BF"), Color(hex: "#14B8A6"), Color(hex: "#5EEAD4"),
            Color(hex: "#60A5FA"), Color(hex: "#38BDF8"), Color(hex: "#93C5FD"),
            Color(hex: "#FBBF24"), Color(hex: "#FCD34D"), Color(hex: "#94A3B8")
        ],
        appPrimary: Color(hex: "#7ED957"),
        appSecondary: Color(hex: "#B7E99A"),
        mainBackground: Color(hex: "#0B1220"),
        cardBackground: Color(hex: "#1E293B"),
        secondaryBackground: Color(hex: "#334155"),
        tertiaryBackground: Color(hex: "#0F172A"),
        profitGreen: Color(hex: "#7ED957"),
        lossRed: Color(hex: "#F87171"),
        primaryText: Color(hex: "#F1F5F9"),
        secondaryText: Color(hex: "#94A3B8"),
        tertiaryText: Color(hex: "#64748B"),
        separator: Color(hex: "#334155"),
        borderLight: Color(hex: "#475569"),
        disabledBackground: Color(hex: "#1E293B"),
        overlayDark: Color.black.opacity(0.92),
        shadowLow: Color.black.opacity(0.2),
        shadowMedium: Color.black.opacity(0.28),
        shadowSoft: Color.black.opacity(0.32),
        shadowCard: Color.black.opacity(0.38),
        shadowHigh: Color.black.opacity(0.45),
        actionForeground: Color(hex: "#0F172A"),
        placeholderFill: Color(hex: "#334155"),
        chartBackdropLight: Color(hex: "#1E293B"),
        chartBackdropDark: Color(hex: "#334155").opacity(0.6),
        cashAccountColor: Color(hex: "#94A3B8"),
        homeNetWorthAccent: Color(hex: "#7ED957"),
        homeInvestmentsAccent: Color(hex: "#818CF8"),
        homeCashAccent: Color(hex: "#94A3B8"),
        manualAssetColor: Color(hex: "#A78BFA"),
        manualAssetLight: Color(hex: "#A78BFA").opacity(0.22)
    )

    // MARK: - 清晰對比（僅調整台股／美股／加密與相關圖表色）

    static let vividContrastLight = steadyFinanceLight.withMarketAssetColors(
        stockTW: Color(hex: "#0D9488"),
        stockTWDeep: Color(hex: "#0F766E"),
        stockTWLight: Color(hex: "#0D9488").opacity(0.22),
        stockUS: Color(hex: "#EA580C"),
        stockUSDeep: Color(hex: "#C2410C"),
        stockUSLight: Color(hex: "#EA580C").opacity(0.16),
        crypto: Color(hex: "#DB2777"),
        cryptoDeep: Color(hex: "#BE185D"),
        cryptoLight: Color(hex: "#DB2777").opacity(0.22),
        pieChartTW: [
            Color(hex: "#0D9488"), Color(hex: "#14B8A6"), Color(hex: "#2DD4BF"),
            Color(hex: "#0F766E"), Color(hex: "#115E59"), Color(hex: "#5EEAD4")
        ],
        pieChartUS: [
            Color(hex: "#EA580C"), Color(hex: "#F97316"), Color(hex: "#FB923C"),
            Color(hex: "#C2410C"), Color(hex: "#9A3412"), Color(hex: "#FDBA74")
        ],
        pieChartCrypto: [
            Color(hex: "#DB2777"), Color(hex: "#EC4899"), Color(hex: "#F472B6"),
            Color(hex: "#BE185D"), Color(hex: "#9D174D"), Color(hex: "#FBCFE8")
        ],
        allocationStockTW: Color(hex: "#0D9488"),
        allocationStockUS: Color(hex: "#EA580C"),
        allocationCrypto: Color(hex: "#DB2777"),
        holdingChartAccentIndices: (tw: 2, us: 0, crypto: 1),
        holdingChartTW: Color(hex: "#0D9488"),
        holdingChartUS: Color(hex: "#EA580C"),
        holdingChartCrypto: Color(hex: "#DB2777"),
        pickerAccentTW: Color(hex: "#0D9488"),
        pickerAccentUS: Color(hex: "#EA580C")
    )

    static let vividContrastDark = steadyFinanceDark.withMarketAssetColors(
        stockTW: Color(hex: "#2DD4BF"),
        stockTWDeep: Color(hex: "#5EEAD4"),
        stockTWLight: Color(hex: "#2DD4BF").opacity(0.24),
        stockUS: Color(hex: "#FB923C"),
        stockUSDeep: Color(hex: "#FDBA74"),
        stockUSLight: Color(hex: "#FB923C").opacity(0.22),
        crypto: Color(hex: "#F472B6"),
        cryptoDeep: Color(hex: "#FB7185"),
        cryptoLight: Color(hex: "#F472B6").opacity(0.22),
        pieChartTW: [
            Color(hex: "#2DD4BF"), Color(hex: "#5EEAD4"), Color(hex: "#14B8A6"),
            Color(hex: "#0D9488"), Color(hex: "#0F766E"), Color(hex: "#99F6E4")
        ],
        pieChartUS: [
            Color(hex: "#FB923C"), Color(hex: "#FDBA74"), Color(hex: "#F97316"),
            Color(hex: "#EA580C"), Color(hex: "#C2410C"), Color(hex: "#FED7AA")
        ],
        pieChartCrypto: [
            Color(hex: "#F472B6"), Color(hex: "#FB7185"), Color(hex: "#EC4899"),
            Color(hex: "#DB2777"), Color(hex: "#BE185D"), Color(hex: "#FBCFE8")
        ],
        allocationStockTW: Color(hex: "#2DD4BF"),
        allocationStockUS: Color(hex: "#FB923C"),
        allocationCrypto: Color(hex: "#F472B6"),
        holdingChartAccentIndices: (tw: 2, us: 6, crypto: 3),
        holdingChartTW: Color(hex: "#2DD4BF"),
        holdingChartUS: Color(hex: "#FB923C"),
        holdingChartCrypto: Color(hex: "#F472B6"),
        pickerAccentTW: Color(hex: "#2DD4BF"),
        pickerAccentUS: Color(hex: "#FB923C")
    )
}

// MARK: - 僅覆寫資產類別色（其餘沿用 base 風格）

private extension ThemePalette {
    struct MarketAssetColorOverrides {
        let stockTW: Color
        let stockTWDeep: Color
        let stockTWLight: Color
        let stockUS: Color
        let stockUSDeep: Color
        let stockUSLight: Color
        let crypto: Color
        let cryptoDeep: Color
        let cryptoLight: Color
        let pieChartTW: [Color]
        let pieChartUS: [Color]
        let pieChartCrypto: [Color]
        let allocationStockTW: Color
        let allocationStockUS: Color
        let allocationCrypto: Color
        let holdingChartAccentIndices: (tw: Int, us: Int, crypto: Int)
        let holdingChartTW: Color
        let holdingChartUS: Color
        let holdingChartCrypto: Color
        let pickerAccentTW: Color
        let pickerAccentUS: Color
    }

    func withMarketAssetColors(
        stockTW: Color,
        stockTWDeep: Color,
        stockTWLight: Color,
        stockUS: Color,
        stockUSDeep: Color,
        stockUSLight: Color,
        crypto: Color,
        cryptoDeep: Color,
        cryptoLight: Color,
        pieChartTW: [Color],
        pieChartUS: [Color],
        pieChartCrypto: [Color],
        allocationStockTW: Color,
        allocationStockUS: Color,
        allocationCrypto: Color,
        holdingChartAccentIndices: (tw: Int, us: Int, crypto: Int),
        holdingChartTW: Color,
        holdingChartUS: Color,
        holdingChartCrypto: Color,
        pickerAccentTW: Color,
        pickerAccentUS: Color
    ) -> ThemePalette {
        withMarketAssetColors(
            MarketAssetColorOverrides(
                stockTW: stockTW,
                stockTWDeep: stockTWDeep,
                stockTWLight: stockTWLight,
                stockUS: stockUS,
                stockUSDeep: stockUSDeep,
                stockUSLight: stockUSLight,
                crypto: crypto,
                cryptoDeep: cryptoDeep,
                cryptoLight: cryptoLight,
                pieChartTW: pieChartTW,
                pieChartUS: pieChartUS,
                pieChartCrypto: pieChartCrypto,
                allocationStockTW: allocationStockTW,
                allocationStockUS: allocationStockUS,
                allocationCrypto: allocationCrypto,
                holdingChartAccentIndices: holdingChartAccentIndices,
                holdingChartTW: holdingChartTW,
                holdingChartUS: holdingChartUS,
                holdingChartCrypto: holdingChartCrypto,
                pickerAccentTW: pickerAccentTW,
                pickerAccentUS: pickerAccentUS
            )
        )
    }

    func withMarketAssetColors(_ overrides: MarketAssetColorOverrides) -> ThemePalette {
        var holding = holdingChartColors
        let twIndex = overrides.holdingChartAccentIndices.tw
        let usIndex = overrides.holdingChartAccentIndices.us
        let cryptoIndex = overrides.holdingChartAccentIndices.crypto
        if twIndex < holding.count { holding[twIndex] = overrides.holdingChartTW }
        if usIndex < holding.count { holding[usIndex] = overrides.holdingChartUS }
        if cryptoIndex < holding.count { holding[cryptoIndex] = overrides.holdingChartCrypto }

        var vibrant = pieChartVibrantColors
        if twIndex < vibrant.count { vibrant[twIndex] = overrides.holdingChartTW }
        if usIndex < vibrant.count { vibrant[usIndex] = overrides.holdingChartUS }
        if cryptoIndex < vibrant.count { vibrant[cryptoIndex] = overrides.holdingChartCrypto }

        var picker = colorOptionsForPicker
        if picker.count > 3 { picker[3] = overrides.pickerAccentTW }
        if picker.count > 7 { picker[7] = overrides.pickerAccentUS }

        return ThemePalette(
            stockUSColor: overrides.stockUS,
            stockUSDeep: overrides.stockUSDeep,
            stockUSLight: overrides.stockUSLight,
            stockTWColor: overrides.stockTW,
            stockTWDeepAmber: overrides.stockTWDeep,
            stockTWLight: overrides.stockTWLight,
            cryptoColor: overrides.crypto,
            cryptoDeep: overrides.cryptoDeep,
            cryptoLight: overrides.cryptoLight,
            pieChartTWColors: overrides.pieChartTW,
            pieChartUSColors: overrides.pieChartUS,
            pieChartCryptoColors: overrides.pieChartCrypto,
            holdingChartColors: holding,
            allocationTwdCash: allocationTwdCash,
            allocationUsdCash: allocationUsdCash,
            allocationStockUS: overrides.allocationStockUS,
            allocationStockTW: overrides.allocationStockTW,
            allocationCrypto: overrides.allocationCrypto,
            pieChartVibrantColors: vibrant,
            colorOptionsForPicker: picker,
            appPrimary: appPrimary,
            appSecondary: appSecondary,
            mainBackground: mainBackground,
            cardBackground: cardBackground,
            secondaryBackground: secondaryBackground,
            tertiaryBackground: tertiaryBackground,
            profitGreen: profitGreen,
            lossRed: lossRed,
            primaryText: primaryText,
            secondaryText: secondaryText,
            tertiaryText: tertiaryText,
            separator: separator,
            borderLight: borderLight,
            disabledBackground: disabledBackground,
            overlayDark: overlayDark,
            shadowLow: shadowLow,
            shadowMedium: shadowMedium,
            shadowSoft: shadowSoft,
            shadowCard: shadowCard,
            shadowHigh: shadowHigh,
            actionForeground: actionForeground,
            placeholderFill: placeholderFill,
            chartBackdropLight: chartBackdropLight,
            chartBackdropDark: chartBackdropDark,
            cashAccountColor: cashAccountColor,
            homeNetWorthAccent: homeNetWorthAccent,
            homeInvestmentsAccent: homeInvestmentsAccent,
            homeCashAccent: homeCashAccent,
            manualAssetColor: manualAssetColor,
            manualAssetLight: manualAssetLight
        )
    }
}
