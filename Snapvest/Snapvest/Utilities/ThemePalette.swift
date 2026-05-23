//
//  ThemePalette.swift
//  Snapvest
//
//  淺色 / 深色兩套色票（方向 A：沉穩理財）
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
    
    // MARK: - 淺色（方向 A）
    static let light = ThemePalette(
        stockUSColor: Color(hex: "#2563EB"),
        stockUSDeep: Color(hex: "#1D4ED8"),
        stockUSLight: Color(hex: "#2563EB").opacity(0.16),
        stockTWColor: Color(hex: "#D97706"),
        stockTWDeepAmber: Color(hex: "#B45309"),
        stockTWLight: Color(hex: "#D97706").opacity(0.18),
        cryptoColor: Color(hex: "#0D9488"),
        cryptoDeep: Color(hex: "#0F766E"),
        cryptoLight: Color(hex: "#0D9488").opacity(0.16),
        pieChartTWColors: [
            Color(hex: "#D97706"), Color(hex: "#F59E0B"), Color(hex: "#B45309"),
            Color(hex: "#92400E"), Color(hex: "#78350F"), Color(hex: "#FBBF24")
        ],
        pieChartUSColors: [
            Color(hex: "#2563EB"), Color(hex: "#3B82F6"), Color(hex: "#1D4ED8"),
            Color(hex: "#60A5FA"), Color(hex: "#93C5FD"), Color(hex: "#BFDBFE")
        ],
        pieChartCryptoColors: [
            Color(hex: "#0D9488"), Color(hex: "#14B8A6"), Color(hex: "#0F766E"),
            Color(hex: "#2DD4BF"), Color(hex: "#5EEAD4"), Color(hex: "#99F6E4")
        ],
        allocationTwdCash: Color(hex: "#059669"),
        allocationUsdCash: Color(hex: "#34D399"),
        allocationStockUS: Color(hex: "#2563EB"),
        allocationStockTW: Color(hex: "#D97706"),
        allocationCrypto: Color(hex: "#0D9488"),
        pieChartVibrantColors: [
            Color(hex: "#0F766E"), Color(hex: "#2563EB"), Color(hex: "#D97706"),
            Color(hex: "#0D9488"), Color(hex: "#059669"), Color(hex: "#1D4ED8"),
            Color(hex: "#14B8A6"), Color(hex: "#B45309"), Color(hex: "#34D399"),
            Color(hex: "#3B82F6"), Color(hex: "#F59E0B"), Color(hex: "#2DD4BF"),
            Color(hex: "#64748B"), Color(hex: "#DC2626"), Color(hex: "#CA8A04")
        ],
        colorOptionsForPicker: [
            Color(hex: "#0F766E"), Color(hex: "#0D9488"), Color(hex: "#14B8A6"),
            Color(hex: "#2563EB"), Color(hex: "#3B82F6"), Color(hex: "#60A5FA"),
            Color(hex: "#D97706"), Color(hex: "#F59E0B"), Color(hex: "#B45309"),
            Color(hex: "#059669"), Color(hex: "#64748B"), Color(hex: "#94A3B8")
        ],
        appPrimary: Color(hex: "#0F766E"),
        appSecondary: Color(hex: "#0D9488"),
        mainBackground: Color(hex: "#F4F6F8"),
        cardBackground: Color.white,
        secondaryBackground: Color(hex: "#EEF2F6"),
        tertiaryBackground: Color(hex: "#F4F6F8"),
        profitGreen: Color(hex: "#059669"),
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
        cashAccountColor: Color(hex: "#64748B")
    )
    
    // MARK: - 深色（方向 A，同語意提高亮度）
    static let dark = ThemePalette(
        stockUSColor: Color(hex: "#60A5FA"),
        stockUSDeep: Color(hex: "#93C5FD"),
        stockUSLight: Color(hex: "#60A5FA").opacity(0.22),
        stockTWColor: Color(hex: "#FBBF24"),
        stockTWDeepAmber: Color(hex: "#FCD34D"),
        stockTWLight: Color(hex: "#FBBF24").opacity(0.2),
        cryptoColor: Color(hex: "#2DD4BF"),
        cryptoDeep: Color(hex: "#5EEAD4"),
        cryptoLight: Color(hex: "#2DD4BF").opacity(0.2),
        pieChartTWColors: [
            Color(hex: "#FBBF24"), Color(hex: "#F59E0B"), Color(hex: "#D97706"),
            Color(hex: "#B45309"), Color(hex: "#92400E"), Color(hex: "#FCD34D")
        ],
        pieChartUSColors: [
            Color(hex: "#3B82F6"), Color(hex: "#60A5FA"), Color(hex: "#93C5FD"),
            Color(hex: "#BFDBFE"), Color(hex: "#DBEAFE"), Color(hex: "#EFF6FF")
        ],
        pieChartCryptoColors: [
            Color(hex: "#14B8A6"), Color(hex: "#2DD4BF"), Color(hex: "#5EEAD4"),
            Color(hex: "#99F6E4"), Color(hex: "#0D9488"), Color(hex: "#0F766E")
        ],
        allocationTwdCash: Color(hex: "#34D399"),
        allocationUsdCash: Color(hex: "#6EE7B7"),
        allocationStockUS: Color(hex: "#60A5FA"),
        allocationStockTW: Color(hex: "#FBBF24"),
        allocationCrypto: Color(hex: "#2DD4BF"),
        pieChartVibrantColors: [
            Color(hex: "#2DD4BF"), Color(hex: "#60A5FA"), Color(hex: "#FBBF24"),
            Color(hex: "#14B8A6"), Color(hex: "#34D399"), Color(hex: "#93C5FD"),
            Color(hex: "#5EEAD4"), Color(hex: "#F59E0B"), Color(hex: "#6EE7B7"),
            Color(hex: "#38BDF8"), Color(hex: "#FCD34D"), Color(hex: "#99F6E4"),
            Color(hex: "#94A3B8"), Color(hex: "#F87171"), Color(hex: "#4ADE80")
        ],
        colorOptionsForPicker: [
            Color(hex: "#2DD4BF"), Color(hex: "#14B8A6"), Color(hex: "#5EEAD4"),
            Color(hex: "#60A5FA"), Color(hex: "#38BDF8"), Color(hex: "#93C5FD"),
            Color(hex: "#FBBF24"), Color(hex: "#FCD34D"), Color(hex: "#F59E0B"),
            Color(hex: "#34D399"), Color(hex: "#94A3B8"), Color(hex: "#CBD5E1")
        ],
        appPrimary: Color(hex: "#2DD4BF"),
        appSecondary: Color(hex: "#5EEAD4"),
        mainBackground: Color(hex: "#0B1220"),
        cardBackground: Color(hex: "#1E293B"),
        secondaryBackground: Color(hex: "#334155"),
        tertiaryBackground: Color(hex: "#0F172A"),
        profitGreen: Color(hex: "#34D399"),
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
        cashAccountColor: Color(hex: "#94A3B8")
    )
}
