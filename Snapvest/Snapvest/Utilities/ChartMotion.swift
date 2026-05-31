//
//  ChartMotion.swift
//  Snapvest
//
//  圖表切換動畫（可整檔移除以還原為即時切換）
//

import SwiftUI

enum ChartMotion {
    static let switchSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let switchQuick = Animation.easeInOut(duration: 0.22)
    /// 圓餅圖扇區切換（略長、低反彈，過渡較連貫）
    static let pieMorphSpring = Animation.spring(response: 0.48, dampingFraction: 0.86)
    /// 群組化 chip 冷卻：Chart 換資料後需完整重繪，略長較安全
    static let groupingToggleCooldown: Duration = .milliseconds(650)
    static let groupingToggleLeadIn: Duration = .milliseconds(80)
}
