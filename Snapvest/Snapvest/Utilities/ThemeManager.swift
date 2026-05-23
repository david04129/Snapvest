//
//  ThemeManager.swift
//  Snapvest
//
//  淺色 / 深色主題、漲跌配色（UserDefaults 持久化）
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let darkModeStorageKey = "snapvest.isDarkMode"
    private static let redUpStorageKey = "snapvest.isRedUpGreenDown"
    
    @Published private(set) var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Self.darkModeStorageKey)
        }
    }
    
    /// false（預設）= 綠漲紅跌；true = 紅漲綠跌
    @Published private(set) var isRedUpGreenDown: Bool {
        didSet {
            UserDefaults.standard.set(isRedUpGreenDown, forKey: Self.redUpStorageKey)
        }
    }
    
    /// 供 ContentView 強制刷新整棵 UI 樹
    var appearanceRefreshToken: String {
        "\(isDarkMode)-\(isRedUpGreenDown)"
    }
    
    private init() {
        isDarkMode = UserDefaults.standard.bool(forKey: Self.darkModeStorageKey)
        isRedUpGreenDown = UserDefaults.standard.bool(forKey: Self.redUpStorageKey)
    }
    
    var palette: ThemePalette {
        isDarkMode ? .dark : .light
    }
    
    func toggleDarkMode() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isDarkMode.toggle()
        }
    }
    
    func toggleMarketColorConvention() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isRedUpGreenDown.toggle()
        }
    }
    
    /// 舊 API 相容
    func toggle() {
        toggleDarkMode()
    }
}
