//
//  ThemeCustomColorOverrides.swift
//  Snapvest
//
//  淺色／深色各一套的自訂配色覆寫（僅存使用者改過的欄位）。
//

import SwiftUI

struct ThemeCustomColorOverrides: Codable, Equatable {
    var mainBackground: String?
    var cardBackground: String?
    var secondaryBackground: String?

    /// 品牌主色（按鈕、Tab、強調；並連動 appSecondary）
    var appPrimary: String?

    var stockTW: String?
    var stockUS: String?
    var crypto: String?

    var homeNetWorth: String?
    var homeInvestments: String?
    var homeCash: String?

    var isEmpty: Bool {
        mainBackground == nil
            && cardBackground == nil
            && secondaryBackground == nil
            && appPrimary == nil
            && stockTW == nil
            && stockUS == nil
            && crypto == nil
            && homeNetWorth == nil
            && homeInvestments == nil
            && homeCash == nil
    }

    mutating func clear() {
        self = ThemeCustomColorOverrides()
    }

    func color(for keyPath: WritableKeyPath<ThemeCustomColorOverrides, String?>) -> Color? {
        self[keyPath: keyPath].flatMap { Color(hex: $0) }
    }

    mutating func setColor(_ color: Color?, for keyPath: WritableKeyPath<ThemeCustomColorOverrides, String?>) {
        self[keyPath: keyPath] = color?.themeHexString
    }

    /// 供貼給開發／AI 的人類可讀摘要
    func exportDescription(
        baseStyleName: String,
        appearanceModeLabel: String,
        resolvedPalette: ThemePalette
    ) -> String {
        var lines: [String] = []
        lines.append("Walleaf 自訂配色")
        lines.append("底稿風格：\(baseStyleName)")
        lines.append("編輯對象：\(appearanceModeLabel)")
        lines.append("")

        appendLine("背景 · 主背景", mainBackground, fallback: resolvedPalette.mainBackground, to: &lines)
        appendLine("背景 · 卡片", cardBackground, fallback: resolvedPalette.cardBackground, to: &lines)
        appendLine("背景 · 次層", secondaryBackground, fallback: resolvedPalette.secondaryBackground, to: &lines)
        appendLine("品牌 · 主色", appPrimary, fallback: resolvedPalette.appPrimary, to: &lines)
        appendLine("投資 · 台股（含圓餅／圖表群組）", stockTW, fallback: resolvedPalette.stockTWColor, to: &lines)
        appendLine("投資 · 美股（含圓餅／圖表群組）", stockUS, fallback: resolvedPalette.stockUSColor, to: &lines)
        appendLine("投資 · 加密（含圓餅／圖表群組）", crypto, fallback: resolvedPalette.cryptoColor, to: &lines)
        appendLine("首頁 · 淨資產", homeNetWorth, fallback: resolvedPalette.homeNetWorthAccent, to: &lines)
        appendLine("首頁 · 投資資產", homeInvestments, fallback: resolvedPalette.homeInvestmentsAccent, to: &lines)
        appendLine("首頁 · 現金", homeCash, fallback: resolvedPalette.homeCashAccent, to: &lines)

        if lines.count <= 4 {
            lines.append("（此模式尚無自訂覆寫，皆使用底稿預設）")
        }

        lines.append("")
        lines.append("註：台股／美股／加密若自訂，會透過既有 withMarketAssetColors 整組連動（深淺色、圓餅色盤等）。")
        return lines.joined(separator: "\n")
    }

    private func appendLine(
        _ label: String,
        _ overrideHex: String?,
        fallback: Color,
        to lines: inout [String]
    ) {
        let hex = overrideHex ?? fallback.themeHexString ?? "—"
        let tag = overrideHex == nil ? "預設" : "自訂"
        lines.append("[\(tag)] \(label)：\(hex)")
    }
}

enum ThemeCustomColorStore {
    private static let lightKey = "snapvest.themeCustomOverrides.light"
    private static let darkKey = "snapvest.themeCustomOverrides.dark"

    static func load(isDarkMode: Bool) -> ThemeCustomColorOverrides {
        let key = isDarkMode ? darkKey : lightKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ThemeCustomColorOverrides.self, from: data) else {
            return ThemeCustomColorOverrides()
        }
        return decoded
    }

    static func save(_ overrides: ThemeCustomColorOverrides, isDarkMode: Bool) {
        let key = isDarkMode ? darkKey : lightKey
        if overrides.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clearBoth() {
        UserDefaults.standard.removeObject(forKey: lightKey)
        UserDefaults.standard.removeObject(forKey: darkKey)
    }
}

// MARK: - Color ↔ hex（自訂配色用）

extension Color {
    var themeHexString: String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        let sRGB = ui.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) ?? ui.cgColor
        guard let components = sRGB.components, components.count >= 3 else { return nil }
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let alpha = components.count >= 4 ? components[3] : 1
        if alpha < 0.995 {
            return String(
                format: "#%02X%02X%02X%02X",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255)),
                Int(round(alpha * 255))
            )
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
        #else
        return nil
        #endif
    }

    func themeScaledBrightness(_ delta: CGFloat) -> Color {
        #if canImport(UIKit)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        let ui = UIColor(self)
        if ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let next = min(max(brightness + delta, 0), 1)
            return Color(UIColor(hue: hue, saturation: saturation, brightness: next, alpha: alpha))
        }
        #endif
        return self
    }

    func themePiePaletteVariants(count: Int = 6) -> [Color] {
        guard count > 0 else { return [] }
        let deltas: [CGFloat] = [0, 0.06, -0.08, -0.16, 0.12, -0.22]
        return (0..<count).map { index in
            themeScaledBrightness(deltas[index % deltas.count])
        }
    }
}
