//
//  ThemeManager.swift
//  Snapvest
//
//  淺色 / 深色、資產配色風格、漲跌配色（UserDefaults 持久化）
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let darkModeStorageKey = "snapvest.isDarkMode"
    private static let redUpStorageKey = "snapvest.isRedUpGreenDown"
    private static let styleStorageKey = "snapvest.themeStyleID"

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

    @Published private(set) var selectedStyle: ThemeStyleID {
        didSet {
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: Self.styleStorageKey)
        }
    }

    /// 供 ContentView 等強制刷新整棵 UI 樹
    var appearanceRefreshToken: String {
        "\(selectedStyle.rawValue)-\(isDarkMode)-\(isRedUpGreenDown)"
    }

    private init() {
        isDarkMode = UserDefaults.standard.bool(forKey: Self.darkModeStorageKey)
        isRedUpGreenDown = UserDefaults.standard.bool(forKey: Self.redUpStorageKey)
        if let raw = UserDefaults.standard.string(forKey: Self.styleStorageKey),
           let style = ThemeStyleID(rawValue: raw) {
            selectedStyle = style
        } else {
            selectedStyle = .steadyFinance
        }
    }

    var palette: ThemePalette {
        ThemeStyleCatalog.palette(style: selectedStyle, isDarkMode: isDarkMode)
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
    }

    func setDarkMode(_ enabled: Bool) {
        guard isDarkMode != enabled else { return }
        isDarkMode = enabled
    }

    func toggleMarketColorConvention() {
        isRedUpGreenDown.toggle()
    }

    func setRedUpGreenDown(_ enabled: Bool) {
        guard isRedUpGreenDown != enabled else { return }
        isRedUpGreenDown = enabled
    }

    func setStyle(_ style: ThemeStyleID) {
        guard selectedStyle != style else { return }
        selectedStyle = style
    }

    /// 舊 API 相容
    func toggle() {
        toggleDarkMode()
    }
}
