//
//  ColorTheme.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

/// iOS 風格的顏色主題
extension Color {
    // MARK: - 主色調（iOS 風格）
    /// 主要藍色（基於 iOS 系統藍色，但可自訂）
    static let appPrimary = Color(red: 0.0, green: 0.48, blue: 1.0) // iOS Blue
    
    /// 次要藍色（用於輔助元素）
    static let appSecondary = Color(red: 0.0, green: 0.4, blue: 0.9)
    
    // MARK: - 語義化顏色（iOS 標準）
    /// 獲利/成功（綠色）
    static let profitGreen = Color.green
    
    /// 虧損/錯誤（紅色）
    static let lossRed = Color.red
    
    /// 警告（橙色）
    static let warningOrange = Color.orange
    
    // MARK: - 背景顏色（自動適應 Dark Mode）
    /// 卡片背景
    static let cardBackground = Color(.systemBackground)
    
    /// 次要背景
    static let secondaryBackground = Color(.secondarySystemBackground)
    
    /// 第三級背景
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    
    // MARK: - 文字顏色（自動適應 Dark Mode）
    /// 主要文字
    static let primaryText = Color(.label)
    
    /// 次要文字
    static let secondaryText = Color(.secondaryLabel)
    
    /// 第三級文字
    static let tertiaryText = Color(.tertiaryLabel)
    
    // MARK: - 分隔線
    static let separator = Color(.separator)
}

