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
    private static let customThemeActiveKey = "snapvest.isCustomThemeActive"

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

    /// 預設底稿（沉穩理財／清晰對比）；自訂模式時仍作為未覆寫欄位的來源
    @Published private(set) var selectedStyle: ThemeStyleID {
        didSet {
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: Self.styleStorageKey)
        }
    }

    /// 啟用後套用淺色／深色自訂覆寫
    @Published private(set) var isCustomThemeActive: Bool {
        didSet {
            UserDefaults.standard.set(isCustomThemeActive, forKey: Self.customThemeActiveKey)
        }
    }

    @Published private(set) var lightCustomOverrides: ThemeCustomColorOverrides {
        didSet {
            ThemeCustomColorStore.save(lightCustomOverrides, isDarkMode: false)
            bumpCustomAppearanceRevision()
        }
    }

    @Published private(set) var darkCustomOverrides: ThemeCustomColorOverrides {
        didSet {
            ThemeCustomColorStore.save(darkCustomOverrides, isDarkMode: true)
            bumpCustomAppearanceRevision()
        }
    }

    @Published private(set) var customAppearanceRevision = 0

    /// 供 ContentView 等強制刷新整棵 UI 樹
    var appearanceRefreshToken: String {
        [
            selectedStyle.rawValue,
            isDarkMode ? "dark" : "light",
            isRedUpGreenDown ? "redUp" : "greenUp",
            isCustomThemeActive ? "customOn" : "customOff",
            "r\(customAppearanceRevision)"
        ].joined(separator: "-")
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.darkModeStorageKey) == nil {
            isDarkMode = true
        } else {
            isDarkMode = UserDefaults.standard.bool(forKey: Self.darkModeStorageKey)
        }
        isRedUpGreenDown = UserDefaults.standard.bool(forKey: Self.redUpStorageKey)
        if AppFeatureFlags.showsThemeStylePicker {
            if let raw = UserDefaults.standard.string(forKey: Self.styleStorageKey),
               let style = ThemeStyleID(rawValue: raw) {
                selectedStyle = style
            } else {
                selectedStyle = .steadyFinance
            }
            isCustomThemeActive = UserDefaults.standard.bool(forKey: Self.customThemeActiveKey)
            lightCustomOverrides = ThemeCustomColorStore.load(isDarkMode: false)
            darkCustomOverrides = ThemeCustomColorStore.load(isDarkMode: true)
        } else {
            selectedStyle = .steadyFinance
            isCustomThemeActive = false
            lightCustomOverrides = ThemeCustomColorOverrides()
            darkCustomOverrides = ThemeCustomColorOverrides()
        }
    }

    var palette: ThemePalette {
        guard AppFeatureFlags.showsThemeStylePicker else {
            return ThemeStyleCatalog.palette(style: .steadyFinance, isDarkMode: isDarkMode)
        }
        let base = ThemeStyleCatalog.palette(style: selectedStyle, isDarkMode: isDarkMode)
        guard isCustomThemeActive else { return base }
        let custom = isDarkMode ? darkCustomOverrides : lightCustomOverrides
        return ThemeStyleCatalog.applying(custom: custom, to: base, isDarkMode: isDarkMode)
    }

    var hasAnyCustomOverrides: Bool {
        !lightCustomOverrides.isEmpty || !darkCustomOverrides.isEmpty
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

    /// 選擇預設風格：離開自訂模式並清空所有覆寫與持股自訂色。
    func selectPresetStyle(_ style: ThemeStyleID) {
        isCustomThemeActive = false
        clearAllCustomOverrides()
        HoldingColorPreferences.clearAll()
        selectedStyle = style
    }

    func setStyle(_ style: ThemeStyleID) {
        selectPresetStyle(style)
    }

    /// 進入自訂模式：套用目前淺／深對應的自訂色（無覆寫時等同底稿）。
    func activateCustomTheme() {
        isCustomThemeActive = true
    }

    func customOverrides(forDarkMode dark: Bool) -> ThemeCustomColorOverrides {
        dark ? darkCustomOverrides : lightCustomOverrides
    }

    func setCustomColor(_ color: Color?, for keyPath: WritableKeyPath<ThemeCustomColorOverrides, String?>, isDarkMode dark: Bool) {
        isCustomThemeActive = true
        if dark {
            var updated = darkCustomOverrides
            updated.setColor(color, for: keyPath)
            darkCustomOverrides = updated
        } else {
            var updated = lightCustomOverrides
            updated.setColor(color, for: keyPath)
            lightCustomOverrides = updated
        }
    }

    func clearCustomOverrides(isDarkMode dark: Bool) {
        if dark {
            darkCustomOverrides = ThemeCustomColorOverrides()
        } else {
            lightCustomOverrides = ThemeCustomColorOverrides()
        }
        if lightCustomOverrides.isEmpty, darkCustomOverrides.isEmpty {
            isCustomThemeActive = false
        }
    }

    func clearAllCustomOverrides() {
        lightCustomOverrides = ThemeCustomColorOverrides()
        darkCustomOverrides = ThemeCustomColorOverrides()
        ThemeCustomColorStore.clearBoth()
    }

    func exportCustomColorDescription(editingDarkMode dark: Bool) -> String {
        let base = ThemeStyleCatalog.palette(style: selectedStyle, isDarkMode: dark)
        let custom = dark ? darkCustomOverrides : lightCustomOverrides
        let resolved = ThemeStyleCatalog.applying(custom: custom, to: base, isDarkMode: dark)
        return custom.exportDescription(
            baseStyleName: selectedStyle.displayName,
            appearanceModeLabel: dark ? "深色自訂" : "淺色自訂",
            resolvedPalette: resolved
        )
    }

    private func bumpCustomAppearanceRevision() {
        customAppearanceRevision += 1
    }

    /// 舊 API 相容
    func toggle() {
        toggleDarkMode()
    }
}
