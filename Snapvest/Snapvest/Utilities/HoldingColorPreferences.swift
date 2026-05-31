//
//  HoldingColorPreferences.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

/// 持股顏色偏好管理（使用 UserDefaults 儲存）
struct HoldingColorPreferences {
    private static let key = "holdingColorPreferences"
    
    /// 獲取持股顏色
    /// - Parameters:
    ///   - symbol: 股票代號
    ///   - assetType: 資產類型
    /// - Returns: 顏色（如果沒有設定，返回預設顏色）
    static func getColor(for symbol: String, assetType: AssetType) -> Color {
        let keyString = "\(assetType.rawValue)_\(symbol)"
        
        // 從 UserDefaults 讀取
        if let colorData = UserDefaults.standard.data(forKey: keyString),
           let colorDict = try? JSONDecoder().decode([String: Double].self, from: colorData),
           let red = colorDict["red"],
           let green = colorDict["green"],
           let blue = colorDict["blue"] {
            return Color(red: red, green: green, blue: blue)
        }
        
        // 如果沒有設定，返回預設顏色（依 assetType）
        return getDefaultColor(for: assetType)
    }
    
    /// 設定持股顏色
    /// - Parameters:
    ///   - color: 顏色
    ///   - symbol: 股票代號
    ///   - assetType: 資產類型
    static func setColor(_ color: Color, for symbol: String, assetType: AssetType) {
        let keyString = "\(assetType.rawValue)_\(symbol)"
        
        // 將 Color 轉換為 RGB 值（使用 UIColor）
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorDict: [String: Double] = [
            "red": Double(red),
            "green": Double(green),
            "blue": Double(blue)
        ]
        
        if let colorData = try? JSONEncoder().encode(colorDict) {
            UserDefaults.standard.set(colorData, forKey: keyString)
        }
        #endif
    }
    
    /// 預設色（依 assetType，見 ThemePalette）
    private static func getDefaultColor(for assetType: AssetType) -> Color {
        switch assetType {
        case .stockTW: return Color.stockTWColor
        case .stockUS: return Color.stockUSColor
        case .crypto: return Color.cryptoColor
        case .cash: return Color.appPrimary
        }
    }
    
    /// 移除持股顏色偏好
    /// - Parameters:
    ///   - symbol: 股票代號
    ///   - assetType: 資產類型
    static func removeColor(for symbol: String, assetType: AssetType) {
        let keyString = "\(assetType.rawValue)_\(symbol)"
        UserDefaults.standard.removeObject(forKey: keyString)
    }

    /// 還原預設風格時一併清除所有持股自訂色
    static func clearAll() {
        let prefixes = [
            AssetType.stockTW.rawValue + "_",
            AssetType.stockUS.rawValue + "_",
            AssetType.crypto.rawValue + "_"
        ]
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            guard prefixes.contains(where: { key.hasPrefix($0) }) else { continue }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
