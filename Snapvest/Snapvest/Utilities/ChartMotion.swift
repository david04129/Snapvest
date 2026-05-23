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
}
