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
        case .forestMint:
            return isDarkMode ? forestMintDark : forestMintLight
        case .sunsetGlow:
            return isDarkMode ? sunsetGlowDark : sunsetGlowLight
        case .oceanCool:
            return isDarkMode ? oceanCoolDark : oceanCoolLight
        case .jewelTone:
            return isDarkMode ? jewelToneDark : jewelToneLight
        case .auroraVivid:
            return isDarkMode ? auroraVividDark : auroraVividLight
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

    // MARK: - 森林薄荷（翡翠台股、天藍美股、萊姆加密 + 薄荷底與品牌色）

    static let forestMintLight = fullStylePalette(
        base: steadyFinanceLight,
        isDark: false,
        tokens: FullStyleTokens(
            mainBackground: "#F0FAF4",
            cardBackground: "#FFFFFF",
            secondaryBackground: "#E3F2EA",
            appPrimary: "#059669",
            stockTW: ("#059669", "#047857", ["#059669", "#10B981", "#34D399", "#047857", "#065F46", "#6EE7B7"]),
            stockUS: ("#0284C7", "#0369A1", ["#0284C7", "#0EA5E9", "#38BDF8", "#0369A1", "#075985", "#BAE6FD"]),
            crypto: ("#65A30D", "#4D7C0F", ["#65A30D", "#84CC16", "#A3E635", "#4D7C0F", "#3F6212", "#D9F99D"]),
            homeNetWorth: "#059669",
            homeInvestments: "#0284C7",
            homeCash: "#5B7C6B",
            holdingAccent: (tw: 2, us: 0, crypto: 1)
        )
    )

    static let forestMintDark = fullStylePalette(
        base: steadyFinanceDark,
        isDark: true,
        tokens: FullStyleTokens(
            mainBackground: "#0A1410",
            cardBackground: "#152820",
            secondaryBackground: "#1E3D30",
            appPrimary: "#34D399",
            stockTW: ("#34D399", "#6EE7B7", ["#34D399", "#6EE7B7", "#10B981", "#059669", "#047857", "#A7F3D0"]),
            stockUS: ("#38BDF8", "#7DD3FC", ["#38BDF8", "#7DD3FC", "#0EA5E9", "#0284C7", "#0369A1", "#E0F2FE"]),
            crypto: ("#A3E635", "#BEF264", ["#A3E635", "#BEF264", "#84CC16", "#65A30D", "#4D7C0F", "#ECFCCB"]),
            homeNetWorth: "#34D399",
            homeInvestments: "#38BDF8",
            homeCash: "#7D9B8E",
            holdingAccent: (tw: 2, us: 6, crypto: 3)
        )
    )

    // MARK: - 暮色暖彩（玫瑰台股、紫系美股、琥珀加密 + 暖色底）

    static let sunsetGlowLight = fullStylePalette(
        base: steadyFinanceLight,
        isDark: false,
        tokens: FullStyleTokens(
            mainBackground: "#FFF8F5",
            cardBackground: "#FFFFFF",
            secondaryBackground: "#FEECF0",
            appPrimary: "#E11D48",
            stockTW: ("#E11D48", "#BE123C", ["#E11D48", "#F43F5E", "#FB7185", "#BE123C", "#9F1239", "#FECDD3"]),
            stockUS: ("#7C3AED", "#6D28D9", ["#7C3AED", "#8B5CF6", "#A78BFA", "#6D28D9", "#5B21B6", "#DDD6FE"]),
            crypto: ("#D97706", "#B45309", ["#D97706", "#F59E0B", "#FBBF24", "#B45309", "#92400E", "#FDE68A"]),
            homeNetWorth: "#E11D48",
            homeInvestments: "#7C3AED",
            homeCash: "#B45309",
            holdingAccent: (tw: 3, us: 0, crypto: 1)
        )
    )

    static let sunsetGlowDark = fullStylePalette(
        base: steadyFinanceDark,
        isDark: true,
        tokens: FullStyleTokens(
            mainBackground: "#140A0E",
            cardBackground: "#261820",
            secondaryBackground: "#352430",
            appPrimary: "#FB7185",
            stockTW: ("#FB7185", "#FDA4AF", ["#FB7185", "#FDA4AF", "#F43F5E", "#E11D48", "#BE123C", "#FFE4E6"]),
            stockUS: ("#A78BFA", "#C4B5FD", ["#A78BFA", "#C4B5FD", "#8B5CF6", "#7C3AED", "#6D28D9", "#EDE9FE"]),
            crypto: ("#FBBF24", "#FCD34D", ["#FBBF24", "#FCD34D", "#F59E0B", "#D97706", "#B45309", "#FEF3C7"]),
            homeNetWorth: "#FB7185",
            homeInvestments: "#A78BFA",
            homeCash: "#D4A574",
            holdingAccent: (tw: 2, us: 6, crypto: 4)
        )
    )

    // MARK: - 海洋清涼（青藍台股、深藍美股、靛紫加密 + 海藍底）

    static let oceanCoolLight = fullStylePalette(
        base: steadyFinanceLight,
        isDark: false,
        tokens: FullStyleTokens(
            mainBackground: "#F0F9FC",
            cardBackground: "#FFFFFF",
            secondaryBackground: "#E0F2FE",
            appPrimary: "#0891B2",
            stockTW: ("#0891B2", "#0E7490", ["#0891B2", "#06B6D4", "#22D3EE", "#0E7490", "#155E75", "#A5F3FC"]),
            stockUS: ("#1E40AF", "#1E3A8A", ["#1E40AF", "#2563EB", "#3B82F6", "#1E3A8A", "#172554", "#BFDBFE"]),
            crypto: ("#6366F1", "#4F46E5", ["#6366F1", "#818CF8", "#A5B4FC", "#4F46E5", "#4338CA", "#E0E7FF"]),
            homeNetWorth: "#0891B2",
            homeInvestments: "#1E40AF",
            homeCash: "#64748B",
            holdingAccent: (tw: 2, us: 0, crypto: 1)
        )
    )

    static let oceanCoolDark = fullStylePalette(
        base: steadyFinanceDark,
        isDark: true,
        tokens: FullStyleTokens(
            mainBackground: "#081018",
            cardBackground: "#122030",
            secondaryBackground: "#1A3048",
            appPrimary: "#22D3EE",
            stockTW: ("#22D3EE", "#67E8F9", ["#22D3EE", "#67E8F9", "#06B6D4", "#0891B2", "#0E7490", "#CFFAFE"]),
            stockUS: ("#60A5FA", "#93C5FD", ["#60A5FA", "#93C5FD", "#3B82F6", "#2563EB", "#1D4ED8", "#DBEAFE"]),
            crypto: ("#818CF8", "#A5B4FC", ["#818CF8", "#A5B4FC", "#6366F1", "#4F46E5", "#4338CA", "#EEF2FF"]),
            homeNetWorth: "#22D3EE",
            homeInvestments: "#60A5FA",
            homeCash: "#94A3B8",
            holdingAccent: (tw: 2, us: 6, crypto: 3)
        )
    )

    // MARK: - 寶石質感（紅寶台股、藍寶美股、祖母綠加密 + 紫調底）

    static let jewelToneLight = fullStylePalette(
        base: steadyFinanceLight,
        isDark: false,
        tokens: FullStyleTokens(
            mainBackground: "#F8F6FA",
            cardBackground: "#FFFFFF",
            secondaryBackground: "#EEEAF5",
            appPrimary: "#7C3AED",
            stockTW: ("#BE123C", "#9F1239", ["#BE123C", "#E11D48", "#F43F5E", "#9F1239", "#881337", "#FECDD3"]),
            stockUS: ("#1D4ED8", "#1E40AF", ["#1D4ED8", "#2563EB", "#3B82F6", "#1E40AF", "#1E3A8A", "#BFDBFE"]),
            crypto: ("#047857", "#065F46", ["#047857", "#059669", "#10B981", "#065F46", "#064E3B", "#A7F3D0"]),
            homeNetWorth: "#BE123C",
            homeInvestments: "#1D4ED8",
            homeCash: "#64748B",
            holdingAccent: (tw: 3, us: 0, crypto: 1)
        )
    )

    static let jewelToneDark = fullStylePalette(
        base: steadyFinanceDark,
        isDark: true,
        tokens: FullStyleTokens(
            mainBackground: "#0C0A14",
            cardBackground: "#1A1630",
            secondaryBackground: "#262040",
            appPrimary: "#A78BFA",
            stockTW: ("#F43F5E", "#FB7185", ["#F43F5E", "#FB7185", "#E11D48", "#BE123C", "#9F1239", "#FFE4E6"]),
            stockUS: ("#3B82F6", "#60A5FA", ["#3B82F6", "#60A5FA", "#2563EB", "#1D4ED8", "#1E40AF", "#DBEAFE"]),
            crypto: ("#10B981", "#34D399", ["#10B981", "#34D399", "#059669", "#047857", "#065F46", "#D1FAE5"]),
            homeNetWorth: "#F43F5E",
            homeInvestments: "#3B82F6",
            homeCash: "#94A3B8",
            holdingAccent: (tw: 2, us: 6, crypto: 4)
        )
    )

    // MARK: - 極光靛紫（紫系台股、青綠美股、橘系加密 + 極光底）

    static let auroraVividLight = fullStylePalette(
        base: steadyFinanceLight,
        isDark: false,
        tokens: FullStyleTokens(
            mainBackground: "#F5F3FF",
            cardBackground: "#FFFFFF",
            secondaryBackground: "#EDE9FE",
            appPrimary: "#9333EA",
            stockTW: ("#9333EA", "#7E22CE", ["#9333EA", "#A855F7", "#C084FC", "#7E22CE", "#6B21A8", "#E9D5FF"]),
            stockUS: ("#0D9488", "#0F766E", ["#0D9488", "#14B8A6", "#2DD4BF", "#0F766E", "#115E59", "#99F6E4"]),
            crypto: ("#EA580C", "#C2410C", ["#EA580C", "#F97316", "#FB923C", "#C2410C", "#9A3412", "#FED7AA"]),
            homeNetWorth: "#9333EA",
            homeInvestments: "#0D9488",
            homeCash: "#64748B",
            holdingAccent: (tw: 1, us: 2, crypto: 0)
        )
    )

    static let auroraVividDark = fullStylePalette(
        base: steadyFinanceDark,
        isDark: true,
        tokens: FullStyleTokens(
            mainBackground: "#0C0A18",
            cardBackground: "#181530",
            secondaryBackground: "#252040",
            appPrimary: "#C084FC",
            stockTW: ("#C084FC", "#D8B4FE", ["#C084FC", "#D8B4FE", "#A855F7", "#9333EA", "#7E22CE", "#F3E8FF"]),
            stockUS: ("#2DD4BF", "#5EEAD4", ["#2DD4BF", "#5EEAD4", "#14B8A6", "#0D9488", "#0F766E", "#CCFBF1"]),
            crypto: ("#FB923C", "#FDBA74", ["#FB923C", "#FDBA74", "#F97316", "#EA580C", "#C2410C", "#FFEDD5"]),
            homeNetWorth: "#C084FC",
            homeInvestments: "#2DD4BF",
            homeCash: "#94A3B8",
            holdingAccent: (tw: 3, us: 2, crypto: 6)
        )
    )

    // MARK: - 完整風格（背景、品牌、首頁強調、台股／美股／加密）

    private struct FullStyleTokens {
        let mainBackground: String
        let cardBackground: String
        let secondaryBackground: String
        let appPrimary: String
        let stockTW: (main: String, deep: String, pie: [String])
        let stockUS: (main: String, deep: String, pie: [String])
        let crypto: (main: String, deep: String, pie: [String])
        let homeNetWorth: String
        let homeInvestments: String
        let homeCash: String
        let holdingAccent: (tw: Int, us: Int, crypto: Int)
    }

    private static func fullStylePalette(
        base: ThemePalette,
        isDark: Bool,
        tokens: FullStyleTokens
    ) -> ThemePalette {
        let twColor = Color(hex: tokens.stockTW.main)
        let usColor = Color(hex: tokens.stockUS.main)
        let cryptoColor = Color(hex: tokens.crypto.main)
        let twLightOpacity: CGFloat = isDark ? 0.24 : 0.22
        let usLightOpacity: CGFloat = isDark ? 0.22 : 0.16
        let cryptoLightOpacity: CGFloat = isDark ? 0.22 : 0.22

        return base
            .withBackgroundColors(
                main: Color(hex: tokens.mainBackground),
                card: Color(hex: tokens.cardBackground),
                secondary: Color(hex: tokens.secondaryBackground)
            )
            .withBrandPrimary(Color(hex: tokens.appPrimary), isDarkMode: isDark)
            .withMarketAssetColors(
                stockTW: twColor,
                stockTWDeep: Color(hex: tokens.stockTW.deep),
                stockTWLight: twColor.opacity(twLightOpacity),
                stockUS: usColor,
                stockUSDeep: Color(hex: tokens.stockUS.deep),
                stockUSLight: usColor.opacity(usLightOpacity),
                crypto: cryptoColor,
                cryptoDeep: Color(hex: tokens.crypto.deep),
                cryptoLight: cryptoColor.opacity(cryptoLightOpacity),
                pieChartTW: tokens.stockTW.pie.map { Color(hex: $0) },
                pieChartUS: tokens.stockUS.pie.map { Color(hex: $0) },
                pieChartCrypto: tokens.crypto.pie.map { Color(hex: $0) },
                allocationStockTW: twColor,
                allocationStockUS: usColor,
                allocationCrypto: cryptoColor,
                holdingChartAccentIndices: tokens.holdingAccent,
                holdingChartTW: twColor,
                holdingChartUS: usColor,
                holdingChartCrypto: cryptoColor,
                pickerAccentTW: twColor,
                pickerAccentUS: usColor
            )
            .withHomeAccents(
                netWorth: Color(hex: tokens.homeNetWorth),
                investments: Color(hex: tokens.homeInvestments),
                cash: Color(hex: tokens.homeCash)
            )
    }
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

    func withBackgroundColors(main: Color, card: Color, secondary: Color) -> ThemePalette {
        ThemePalette(
            stockUSColor: stockUSColor,
            stockUSDeep: stockUSDeep,
            stockUSLight: stockUSLight,
            stockTWColor: stockTWColor,
            stockTWDeepAmber: stockTWDeepAmber,
            stockTWLight: stockTWLight,
            cryptoColor: cryptoColor,
            cryptoDeep: cryptoDeep,
            cryptoLight: cryptoLight,
            pieChartTWColors: pieChartTWColors,
            pieChartUSColors: pieChartUSColors,
            pieChartCryptoColors: pieChartCryptoColors,
            holdingChartColors: holdingChartColors,
            allocationTwdCash: allocationTwdCash,
            allocationUsdCash: allocationUsdCash,
            allocationStockUS: allocationStockUS,
            allocationStockTW: allocationStockTW,
            allocationCrypto: allocationCrypto,
            pieChartVibrantColors: pieChartVibrantColors,
            colorOptionsForPicker: colorOptionsForPicker,
            appPrimary: appPrimary,
            appSecondary: appSecondary,
            mainBackground: main,
            cardBackground: card,
            secondaryBackground: secondary,
            tertiaryBackground: main,
            profitGreen: profitGreen,
            lossRed: lossRed,
            primaryText: primaryText,
            secondaryText: secondaryText,
            tertiaryText: tertiaryText,
            separator: separator,
            borderLight: borderLight,
            disabledBackground: secondary,
            overlayDark: overlayDark,
            shadowLow: shadowLow,
            shadowMedium: shadowMedium,
            shadowSoft: shadowSoft,
            shadowCard: shadowCard,
            shadowHigh: shadowHigh,
            actionForeground: actionForeground,
            placeholderFill: placeholderFill,
            chartBackdropLight: secondary,
            chartBackdropDark: secondary.opacity(0.35),
            cashAccountColor: cashAccountColor,
            homeNetWorthAccent: homeNetWorthAccent,
            homeInvestmentsAccent: homeInvestmentsAccent,
            homeCashAccent: homeCashAccent,
            manualAssetColor: manualAssetColor,
            manualAssetLight: manualAssetLight
        )
    }

    func withBrandPrimary(_ primary: Color, isDarkMode: Bool) -> ThemePalette {
        let secondary = primary.themeScaledBrightness(isDarkMode ? 0.1 : 0.08)
        return ThemePalette(
            stockUSColor: stockUSColor,
            stockUSDeep: stockUSDeep,
            stockUSLight: stockUSLight,
            stockTWColor: stockTWColor,
            stockTWDeepAmber: stockTWDeepAmber,
            stockTWLight: stockTWLight,
            cryptoColor: cryptoColor,
            cryptoDeep: cryptoDeep,
            cryptoLight: cryptoLight,
            pieChartTWColors: pieChartTWColors,
            pieChartUSColors: pieChartUSColors,
            pieChartCryptoColors: pieChartCryptoColors,
            holdingChartColors: holdingChartColors,
            allocationTwdCash: allocationTwdCash,
            allocationUsdCash: allocationUsdCash,
            allocationStockUS: allocationStockUS,
            allocationStockTW: allocationStockTW,
            allocationCrypto: allocationCrypto,
            pieChartVibrantColors: pieChartVibrantColors,
            colorOptionsForPicker: colorOptionsForPicker,
            appPrimary: primary,
            appSecondary: secondary,
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

    func withHomeAccents(netWorth: Color, investments: Color, cash: Color) -> ThemePalette {
        ThemePalette(
            stockUSColor: stockUSColor,
            stockUSDeep: stockUSDeep,
            stockUSLight: stockUSLight,
            stockTWColor: stockTWColor,
            stockTWDeepAmber: stockTWDeepAmber,
            stockTWLight: stockTWLight,
            cryptoColor: cryptoColor,
            cryptoDeep: cryptoDeep,
            cryptoLight: cryptoLight,
            pieChartTWColors: pieChartTWColors,
            pieChartUSColors: pieChartUSColors,
            pieChartCryptoColors: pieChartCryptoColors,
            holdingChartColors: holdingChartColors,
            allocationTwdCash: allocationTwdCash,
            allocationUsdCash: allocationUsdCash,
            allocationStockUS: allocationStockUS,
            allocationStockTW: allocationStockTW,
            allocationCrypto: allocationCrypto,
            pieChartVibrantColors: pieChartVibrantColors,
            colorOptionsForPicker: colorOptionsForPicker,
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
            homeNetWorthAccent: netWorth,
            homeInvestmentsAccent: investments,
            homeCashAccent: cash,
            manualAssetColor: manualAssetColor,
            manualAssetLight: manualAssetLight
        )
    }
}

// MARK: - 自訂覆寫（呼叫既有群組 API）

extension ThemeStyleCatalog {
    static func applying(
        custom overrides: ThemeCustomColorOverrides,
        to base: ThemePalette,
        isDarkMode: Bool
    ) -> ThemePalette {
        guard !overrides.isEmpty else { return base }

        var palette = base

        if overrides.mainBackground != nil
            || overrides.cardBackground != nil
            || overrides.secondaryBackground != nil {
            let main = overrides.mainBackground.flatMap { Color(hex: $0) } ?? palette.mainBackground
            let card = overrides.cardBackground.flatMap { Color(hex: $0) } ?? palette.cardBackground
            let secondary = overrides.secondaryBackground.flatMap { Color(hex: $0) } ?? palette.secondaryBackground
            palette = palette.withBackgroundColors(main: main, card: card, secondary: secondary)
        }

        if let primary = overrides.appPrimary.flatMap({ Color(hex: $0) }) {
            palette = palette.withBrandPrimary(primary, isDarkMode: isDarkMode)
        }

        if overrides.stockTW != nil || overrides.stockUS != nil || overrides.crypto != nil {
            palette = palette.withMarketAssetColors(
                combinedMarketOverrides(overrides: overrides, base: base, isDarkMode: isDarkMode)
            )
        }

        let netWorth = overrides.homeNetWorth.flatMap { Color(hex: $0) } ?? palette.homeNetWorthAccent
        let investments = overrides.homeInvestments.flatMap { Color(hex: $0) } ?? palette.homeInvestmentsAccent
        let cash = overrides.homeCash.flatMap { Color(hex: $0) } ?? palette.homeCashAccent
        if overrides.homeNetWorth != nil || overrides.homeInvestments != nil || overrides.homeCash != nil {
            palette = palette.withHomeAccents(netWorth: netWorth, investments: investments, cash: cash)
        }

        return palette
    }

    private static func combinedMarketOverrides(
        overrides: ThemeCustomColorOverrides,
        base: ThemePalette,
        isDarkMode: Bool
    ) -> ThemePalette.MarketAssetColorOverrides {
        let indices = holdingAccentIndices(in: base)
        let lightOpacity: CGFloat = isDarkMode ? 0.24 : 0.22

        func pack(_ anchor: Color) -> (main: Color, deep: Color, light: Color, pie: [Color]) {
            (
                anchor,
                anchor.themeScaledBrightness(-0.14),
                anchor.opacity(lightOpacity),
                anchor.themePiePaletteVariants()
            )
        }

        let twAnchor = overrides.stockTW.flatMap { Color(hex: $0) } ?? base.stockTWColor
        let usAnchor = overrides.stockUS.flatMap { Color(hex: $0) } ?? base.stockUSColor
        let cryptoAnchor = overrides.crypto.flatMap { Color(hex: $0) } ?? base.cryptoColor

        let tw = pack(twAnchor)
        let us = pack(usAnchor)
        let cr = pack(cryptoAnchor)

        return ThemePalette.MarketAssetColorOverrides(
            stockTW: tw.main,
            stockTWDeep: overrides.stockTW != nil ? tw.deep : base.stockTWDeepAmber,
            stockTWLight: overrides.stockTW != nil ? tw.light : base.stockTWLight,
            stockUS: us.main,
            stockUSDeep: overrides.stockUS != nil ? us.deep : base.stockUSDeep,
            stockUSLight: overrides.stockUS != nil ? us.light : base.stockUSLight,
            crypto: cr.main,
            cryptoDeep: overrides.crypto != nil ? cr.deep : base.cryptoDeep,
            cryptoLight: overrides.crypto != nil ? cr.light : base.cryptoLight,
            pieChartTW: overrides.stockTW != nil ? tw.pie : base.pieChartTWColors,
            pieChartUS: overrides.stockUS != nil ? us.pie : base.pieChartUSColors,
            pieChartCrypto: overrides.crypto != nil ? cr.pie : base.pieChartCryptoColors,
            allocationStockTW: overrides.stockTW != nil ? tw.main : base.allocationStockTW,
            allocationStockUS: overrides.stockUS != nil ? us.main : base.allocationStockUS,
            allocationCrypto: overrides.crypto != nil ? cr.main : base.allocationCrypto,
            holdingChartAccentIndices: indices,
            holdingChartTW: overrides.stockTW != nil ? tw.main : base.holdingChartColors[indices.tw],
            holdingChartUS: overrides.stockUS != nil ? us.main : base.holdingChartColors[indices.us],
            holdingChartCrypto: overrides.crypto != nil ? cr.main : base.holdingChartColors[indices.crypto],
            pickerAccentTW: overrides.stockTW != nil ? tw.main : base.stockTWColor,
            pickerAccentUS: overrides.stockUS != nil ? us.main : base.stockUSColor
        )
    }

    private static func holdingAccentIndices(in palette: ThemePalette) -> (tw: Int, us: Int, crypto: Int) {
        let holding = palette.holdingChartColors
        func index(matching color: Color, in values: [Color], fallback: Int) -> Int {
            guard let target = color.themeHexString else { return fallback }
            if let found = values.firstIndex(where: { $0.themeHexString == target }) {
                return found
            }
            return fallback
        }
        return (
            tw: index(matching: palette.stockTWColor, in: holding, fallback: 2),
            us: index(matching: palette.stockUSColor, in: holding, fallback: 0),
            crypto: index(matching: palette.cryptoColor, in: holding, fallback: 1)
        )
    }
}
