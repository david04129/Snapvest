//
//  ThemeToggleButton.swift
//  Snapvest
//
//  淺色 / 深色模式切換按鈕
//

import SwiftUI

struct ThemeToggleButton: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: { theme.toggle() }) {
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
