//
//  ChartLongPressInteraction.swift
//  Snapvest
//
//  首頁 ScrollView 內圖表：按住一段時間後才進入 scrub／選 slice。
//

import UIKit

enum ChartLongPressInteraction {
    /// 按住多久（秒）後才進入圖表控制
    static let minimumDuration: TimeInterval = 0.45
    /// 長按完成前允許的最大位移（pt）；超過則視為捲動
    static let maximumMovement: CGFloat = 8

    static func playReadyFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
