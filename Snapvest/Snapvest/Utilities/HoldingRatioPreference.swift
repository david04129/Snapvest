//
//  HoldingRatioPreference.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 持股佔比顯示類型
enum HoldingRatioType: String, Codable, CaseIterable {
    case totalAssets = "totalAssets"           // 總資產佔比
    case totalInvestments = "totalInvestments" // 總投資佔比
    
    var displayName: String {
        switch self {
        case .totalAssets:
            return "總資產佔比"
        case .totalInvestments:
            return "總投資佔比"
        }
    }
}

/// 持股佔比顯示偏好管理（使用 UserDefaults 儲存）
struct HoldingRatioPreference {
    private static let key = "holdingRatioPreference"
    
    /// 獲取佔比顯示偏好
    /// - Returns: 佔比類型（預設為 totalAssets）
    static func get() -> HoldingRatioType {
        if let rawValue = UserDefaults.standard.string(forKey: key),
           let type = HoldingRatioType(rawValue: rawValue) {
            return type
        }
        return .totalAssets  // 預設為總資產佔比
    }
    
    /// 設定佔比顯示偏好
    /// - Parameter type: 佔比類型
    static func set(_ type: HoldingRatioType) {
        UserDefaults.standard.set(type.rawValue, forKey: key)
    }
}
