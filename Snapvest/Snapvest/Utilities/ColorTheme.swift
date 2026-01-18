//
//  ColorTheme.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

// MARK: - 集中化顏色集合
enum AppColors {
    // MARK: - 14色配色系統（從深藍到淺藍再到綠色）
    // 左側深藍區（1-4）
    static let blue1 = Color(hex: "#0D2235")  // 最深藍
    static let blue2 = Color(hex: "#132A42")  // 深藍
    static let blue3 = Color(hex: "#1B3C59")  // 中深藍
    static let blue4 = Color(hex: "#1D4C6A")  // 中藍
    
    // 中段藍綠區（5-8）
    static let blueGreen1 = Color(hex: "#1F6A8A")  // 藍綠1
    static let blueGreen2 = Color(hex: "#2A87A6")  // 藍綠2
    static let blueGreen3 = Color(hex: "#36A2C6")  // 藍綠3
    static let blueGreen4 = Color(hex: "#5FBBD5")  // 藍綠4
    
    // 右側深綠區（9-13）
    static let green1 = Color(hex: "#8AC0B3")  // 淺青綠
    static let green2 = Color(hex: "#4CA19E")  // 中青綠
    static let green3 = Color(hex: "#358077")  // 深青綠
    static let green4 = Color(hex: "#1F6E5F")  // 深綠
    static let green5 = Color(hex: "#1B4D3E")  // 最深綠
    
    // 極淺藍（用於背景）
    static let bluePale = Color(hex: "#DBEBF1")
    
    // MARK: - 圓餅圖顏色數組（14個顏色，從大到小輪流使用）
    static let pieChartColors: [Color] = [
        blue3,           // #1B3C59 - 最大市值（中深藍）
        blue4,           // #1D4C6A
        blueGreen1,      // #1F6A8A
        blueGreen2,      // #2A87A6
        blueGreen3,      // #36A2C6
        blueGreen4,      // #5FBBD5
        green1,          // #8AC0B3
        green2,          // #4CA19E
        green3,          // #358077
        green4,          // #1F6E5F
        green5,          // #1B4D3E
        blue2,           // #132A42
        blue1,           // #0D2235
        bluePale         // #DBEBF1（如果超過14個，循環使用）
    ]
    
    // MARK: - 主色調
    /// 主要交互色
    static let appPrimary = blue4  // #1D4C6A
    
    /// 次要藍色（用於輔助元素）
    static let appSecondary = blue3  // #1B3C59
    
    // MARK: - 背景顏色（不使用純白）
    /// 主背景（極淺藍，30%透明度）
    static let mainBackground = bluePale.opacity(0.3)
    
    /// 卡片背景（極淺藍，50%透明度）
    static let cardBackground = bluePale.opacity(0.5)
    
    /// 次要背景（極淺藍，40%透明度）
    static let secondaryBackground = bluePale.opacity(0.4)
    
    /// 第三級背景
    static let tertiaryBackground = bluePale.opacity(0.3)
    
    // MARK: - 語義化顏色（漲跌幅專用）
    /// 獲利/成功（正常綠色，用於漲幅）
    static let profitGreen = Color(red: 0.0, green: 0.7, blue: 0.3)  // 正常綠色
    
    /// 虧損/錯誤（亮紅色，用於跌幅）
    static let lossRed = Color(red: 1.0, green: 0.2, blue: 0.2)  // 亮紅色
    
    // MARK: - 資產類型顏色（選擇深色但明顯不同的顏色）
    /// 台股主色（深藍色）
    static let stockTWColor = blue3  // #1B3C59
    
    /// 台股深藍色（用於股票名稱和金額）
    static let stockTWDeepBlue = blue3  // #1B3C59
    
    /// 美股主色（藍綠色）
    static let stockUSColor = blueGreen2  // #2A87A6
    
    /// 美股深色（用於股票名稱和金額）
    static let stockUSDeepGreen = blueGreen1  // #1F6A8A
    
    /// 美股帳戶顏色（用於帳戶分頁）
    static let stockUSDeepPurple = blueGreen2  // #2A87A6（使用藍綠色）
    
    /// 加密貨幣主色（深綠色，較暗）
    static let cryptoColor = green3  // #358077（深青綠，較暗）
    
    /// 加密貨幣深色（用於股票名稱和金額）
    static let cryptoDeepBrown = green4  // #1F6E5F（深綠）
    
    // MARK: - 文字顏色層次
    /// 主要文字（最深藍）
    static let primaryText = blue1  // #0D2235
    
    /// 次要文字（深藍）
    static let secondaryText = blue2  // #132A42
    
    /// 第三級文字（中深藍，70%透明度）
    static let tertiaryText = blue3.opacity(0.7)  // #1B3C59 70%
    
    // MARK: - 分隔線和邊框
    /// 分隔線（極淺藍，60%透明度）
    static let separator = bluePale.opacity(0.6)
    
    /// 邊框（極淺藍，50%透明度）
    static let borderLight = bluePale.opacity(0.5)
    
    // MARK: - 交互/狀態與陰影
    static let disabledBackground = bluePale.opacity(0.7)
    static let disabledForeground = secondaryText.opacity(0.6)
    static let overlayDark = Color.black.opacity(0.85)
    
    static let shadowLow = Color.black.opacity(0.02)
    static let shadowMedium = Color.black.opacity(0.04)
    static let shadowSoft = Color.black.opacity(0.05)
    static let shadowCard = Color.black.opacity(0.08)
    static let shadowHigh = Color.black.opacity(0.1)
    
    static let strokeSubtle = primaryText.opacity(0.1)
    static let strokeMuted = primaryText.opacity(0.2)
    
    static let noticeForeground = appPrimary
    static let noticeBackground = appPrimary.opacity(0.1)
    
    static let actionEditBackground = appPrimary
    static let actionDestructiveBackground = lossRed
    static let actionForeground = Color.white
    
    static let chipBackground = appPrimary.opacity(0.1)
    static let placeholderFill = bluePale.opacity(0.5)
}

/// iOS 風格的顏色主題（為舊有呼叫提供相容入口）
extension Color {
    // MARK: - Hex 顏色初始化
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static var blue1: Color { AppColors.blue1 }
    static var blue2: Color { AppColors.blue2 }
    static var blue3: Color { AppColors.blue3 }
    static var blue4: Color { AppColors.blue4 }
    static var blueGreen1: Color { AppColors.blueGreen1 }
    static var blueGreen2: Color { AppColors.blueGreen2 }
    static var blueGreen3: Color { AppColors.blueGreen3 }
    static var blueGreen4: Color { AppColors.blueGreen4 }
    static var green1: Color { AppColors.green1 }
    static var green2: Color { AppColors.green2 }
    static var green3: Color { AppColors.green3 }
    static var green4: Color { AppColors.green4 }
    static var green5: Color { AppColors.green5 }
    static var bluePale: Color { AppColors.bluePale }
    
    static var pieChartColors: [Color] { AppColors.pieChartColors }
    
    static var appPrimary: Color { AppColors.appPrimary }
    static var appSecondary: Color { AppColors.appSecondary }
    
    static var mainBackground: Color { AppColors.mainBackground }
    static var cardBackground: Color { AppColors.cardBackground }
    static var secondaryBackground: Color { AppColors.secondaryBackground }
    static var tertiaryBackground: Color { AppColors.tertiaryBackground }
    
    static var profitGreen: Color { AppColors.profitGreen }
    static var lossRed: Color { AppColors.lossRed }
    
    static var stockTWColor: Color { AppColors.stockTWColor }
    static var stockTWDeepBlue: Color { AppColors.stockTWDeepBlue }
    static var stockUSColor: Color { AppColors.stockUSColor }
    static var stockUSDeepGreen: Color { AppColors.stockUSDeepGreen }
    static var stockUSDeepPurple: Color { AppColors.stockUSDeepPurple }
    static var cryptoColor: Color { AppColors.cryptoColor }
    static var cryptoDeepBrown: Color { AppColors.cryptoDeepBrown }
    
    static var primaryText: Color { AppColors.primaryText }
    static var secondaryText: Color { AppColors.secondaryText }
    static var tertiaryText: Color { AppColors.tertiaryText }
    
    static var separator: Color { AppColors.separator }
    static var borderLight: Color { AppColors.borderLight }
}

