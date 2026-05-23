//
//  ThemePalette.swift
//  Snapvest
//
//  淺色 / 深色兩套色票
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
    
    // MARK: - 淺色（現有配色）
    static let light = ThemePalette(
        stockUSColor: Color(hex: "#1E3A8A"),
        stockUSDeep: Color(hex: "#1E3A8A"),
        stockUSLight: Color(hex: "#1E3A8A").opacity(0.18),
        stockTWColor: Color(hex: "#FACC15"),
        stockTWDeepAmber: Color(hex: "#CA8A04"),
        stockTWLight: Color(hex: "#FACC15").opacity(0.2),
        cryptoColor: Color(hex: "#7C3AED"),
        cryptoDeep: Color(hex: "#6D28D9"),
        cryptoLight: Color(hex: "#7C3AED").opacity(0.18),
        pieChartTWColors: [
            Color(hex: "#FACC15"), Color(hex: "#FBBF24"), Color(hex: "#F59E0B"),
            Color(hex: "#D97706"), Color(hex: "#B45309"), Color(hex: "#92400E")
        ],
        pieChartUSColors: [
            Color(hex: "#1E3A8A"), Color(hex: "#2563EB"), Color(hex: "#3B82F6"),
            Color(hex: "#60A5FA"), Color(hex: "#93C5FD"), Color(hex: "#BFDBFE")
        ],
        pieChartCryptoColors: [
            Color(hex: "#7C3AED"), Color(hex: "#8B5CF6"), Color(hex: "#A78BFA"),
            Color(hex: "#C4B5FD"), Color(hex: "#DDD6FE"), Color(hex: "#EDE9FE")
        ],
        allocationTwdCash: Color(hex: "#10B981"),
        allocationUsdCash: Color(hex: "#34D399"),
        allocationStockUS: Color(hex: "#F59E0B"),
        allocationStockTW: Color(hex: "#EC4899"),
        allocationCrypto: Color(hex: "#8B5CF6"),
        pieChartVibrantColors: [
            Color(hex: "#1E3A8A"), Color(hex: "#FACC15"), Color(hex: "#7C3AED"),
            Color(hex: "#2563EB"), Color(hex: "#CA8A04"), Color(hex: "#8B5CF6"),
            Color(hex: "#3B82F6"), Color(hex: "#F59E0B"), Color(hex: "#6D28D9"),
            Color(hex: "#60A5FA"), Color(hex: "#B45309"), Color(hex: "#A78BFA"),
            Color(hex: "#0D9488"), Color(hex: "#059669"), Color(hex: "#DC2626")
        ],
        colorOptionsForPicker: [
            Color(hex: "#1E3A8A"), Color(hex: "#2563EB"), Color(hex: "#3B82F6"),
            Color(hex: "#60A5FA"), Color(hex: "#93C5FD"),
            Color(hex: "#FACC15"), Color(hex: "#FBBF24"), Color(hex: "#F59E0B"),
            Color(hex: "#D97706"), Color(hex: "#B45309"),
            Color(hex: "#7C3AED"), Color(hex: "#8B5CF6"), Color(hex: "#A78BFA"),
            Color(hex: "#64748B"), Color(hex: "#94A3B8")
        ],
        appPrimary: Color(hex: "#1E3A8A"),
        appSecondary: Color(hex: "#2563EB"),
        mainBackground: Color(hex: "#F8FAFC"),
        cardBackground: Color.white,
        secondaryBackground: Color(hex: "#F1F5F9"),
        tertiaryBackground: Color(hex: "#F8FAFC"),
        profitGreen: Color(hex: "#16A34A"),
        lossRed: Color(hex: "#DC2626"),
        primaryText: Color(hex: "#0F172A"),
        secondaryText: Color(hex: "#64748B"),
        tertiaryText: Color(hex: "#94A3B8"),
        separator: Color(hex: "#E2E8F0"),
        borderLight: Color(hex: "#CBD5E1"),
        disabledBackground: Color(hex: "#F1F5F9"),
        overlayDark: Color.black.opacity(0.85),
        shadowLow: Color.black.opacity(0.03),
        shadowMedium: Color.black.opacity(0.05),
        shadowSoft: Color.black.opacity(0.06),
        shadowCard: Color.black.opacity(0.08),
        shadowHigh: Color.black.opacity(0.1),
        actionForeground: Color.white,
        placeholderFill: Color(hex: "#E2E8F0"),
        chartBackdropLight: Color(hex: "#F1F5F9"),
        chartBackdropDark: Color(hex: "#E2E8F0").opacity(0.3),
        cashAccountColor: Color(hex: "#64748B")
    )
    
    // MARK: - 深色
    static let dark = ThemePalette(
        stockUSColor: Color(hex: "#60A5FA"),
        stockUSDeep: Color(hex: "#93C5FD"),
        stockUSLight: Color(hex: "#60A5FA").opacity(0.25),
        stockTWColor: Color(hex: "#FBBF24"),
        stockTWDeepAmber: Color(hex: "#FCD34D"),
        stockTWLight: Color(hex: "#FBBF24").opacity(0.22),
        cryptoColor: Color(hex: "#A78BFA"),
        cryptoDeep: Color(hex: "#C4B5FD"),
        cryptoLight: Color(hex: "#A78BFA").opacity(0.22),
        pieChartTWColors: [
            Color(hex: "#FBBF24"), Color(hex: "#F59E0B"), Color(hex: "#D97706"),
            Color(hex: "#B45309"), Color(hex: "#92400E"), Color(hex: "#78350F")
        ],
        pieChartUSColors: [
            Color(hex: "#3B82F6"), Color(hex: "#60A5FA"), Color(hex: "#93C5FD"),
            Color(hex: "#BFDBFE"), Color(hex: "#DBEAFE"), Color(hex: "#EFF6FF")
        ],
        pieChartCryptoColors: [
            Color(hex: "#8B5CF6"), Color(hex: "#A78BFA"), Color(hex: "#C4B5FD"),
            Color(hex: "#DDD6FE"), Color(hex: "#EDE9FE"), Color(hex: "#F5F3FF")
        ],
        allocationTwdCash: Color(hex: "#34D399"),
        allocationUsdCash: Color(hex: "#6EE7B7"),
        allocationStockUS: Color(hex: "#FBBF24"),
        allocationStockTW: Color(hex: "#F472B6"),
        allocationCrypto: Color(hex: "#A78BFA"),
        pieChartVibrantColors: [
            Color(hex: "#60A5FA"), Color(hex: "#FBBF24"), Color(hex: "#A78BFA"),
            Color(hex: "#38BDF8"), Color(hex: "#FCD34D"), Color(hex: "#C4B5FD"),
            Color(hex: "#34D399"), Color(hex: "#F59E0B"), Color(hex: "#818CF8"),
            Color(hex: "#93C5FD"), Color(hex: "#F97316"), Color(hex: "#E879F9"),
            Color(hex: "#2DD4BF"), Color(hex: "#4ADE80"), Color(hex: "#F87171")
        ],
        colorOptionsForPicker: [
            Color(hex: "#60A5FA"), Color(hex: "#38BDF8"), Color(hex: "#93C5FD"),
            Color(hex: "#BFDBFE"), Color(hex: "#DBEAFE"),
            Color(hex: "#FBBF24"), Color(hex: "#FCD34D"), Color(hex: "#F59E0B"),
            Color(hex: "#F97316"), Color(hex: "#FB923C"),
            Color(hex: "#A78BFA"), Color(hex: "#C4B5FD"), Color(hex: "#E879F9"),
            Color(hex: "#94A3B8"), Color(hex: "#CBD5E1")
        ],
        appPrimary: Color(hex: "#38BDF8"),
        appSecondary: Color(hex: "#60A5FA"),
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
