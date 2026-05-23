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
                
                Image(systemName: "arrow.up")
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
