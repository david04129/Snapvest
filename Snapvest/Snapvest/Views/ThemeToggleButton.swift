//
//  ThemeToggleButton.swift
//  Snapvest
//
//  淺色 / 深色模式、漲跌配色切換按鈕
//

import SwiftUI

struct ThemeToggleButton: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: { theme.toggleDarkMode() }) {
            Image(systemName: theme.isDarkMode ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.appPrimary.opacity(theme.isDarkMode ? 0.22 : 0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.isDarkMode ? "切換為淺色模式" : "切換為深色模式")
    }
}

struct HomeAmountPrivacyToggleButton: View {
    @ObservedObject private var privacy = HomePrivacyManager.shared

    var body: some View {
        Button(action: { privacy.toggleAmountHidden() }) {
            Image(systemName: privacy.isAmountHidden ? "eye.slash" : "eye")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.appPrimary.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            privacy.isAmountHidden
                ? "目前隱藏金額，點擊顯示金額"
                : "目前顯示金額，點擊隱藏金額"
        )
    }
}

struct MarketColorConventionToggleButton: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    private var upColor: Color {
        theme.isRedUpGreenDown ? Color.lossRed : Color.profitGreen
    }
    
    var body: some View {
        Button(action: { theme.toggleMarketColorConvention() }) {
            ZStack {
                Circle()
                    .fill(upColor.opacity(0.16))
                    .frame(width: 32, height: 32)
                
                Image(systemName: MarketDirectionSymbol.systemName(isUp: true))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(upColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            theme.isRedUpGreenDown
                ? "目前為紅漲綠跌，點擊切換為綠漲紅跌"
                : "目前為綠漲紅跌，點擊切換為紅漲綠跌"
        )
    }
}
