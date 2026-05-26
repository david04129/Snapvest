//
//  HomeShareMessageBuilder.swift
//  Snapvest
//
//  系統分享時附帶的文字（圖片另附）
//

import Foundation

enum HomeShareMessageBuilder {
    /// App Store 或 TestFlight 下載連結；上架後填入
    static var appDownloadURL: URL? = nil

    static func shareText(config: HomeShareRenderConfig) -> String {
        var lines: [String] = []
        lines.append("快來下載 Snapvest")
        lines.append("台股、美股、加密貨幣與資產配置都能一起記錄，走勢、持股占比與損益一目瞭然。")

        let included = HomeShareChartKind.allCases.filter {
            config.selectedKinds.contains($0) && config.isAvailable($0)
        }
        if !included.isEmpty {
            lines.append("")
            lines.append("這張分享圖包含\(chartKindsPhrase(included))，可以快速查看投資組合狀況。")
        }

        if config.hideAmounts {
            lines.append("圖中金額已隱藏，可先查看配置與走勢。")
        }

        lines.append("")
        if let url = appDownloadURL {
            lines.append("下載 Snapvest：")
            lines.append(url.absoluteString)
        } else {
            lines.append("到 App Store 搜尋「Snapvest」即可下載。")
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated static func chartKindsPhrase(_ kinds: [HomeShareChartKind]) -> String {
        let phrases = kinds.map(featureName)
        switch phrases.count {
        case 1:
            return "（\(phrases[0])）"
        case 2:
            return "（\(phrases[0])與\(phrases[1])）"
        default:
            return "（\(phrases.dropLast().joined(separator: "、"))與\(phrases.last!)）"
        }
    }

    private nonisolated static func featureName(_ kind: HomeShareChartKind) -> String {
        switch kind {
        case .trend: return "資產走勢"
        case .pie: return "持股占比"
        case .performance: return "損益績效"
        }
    }
}
