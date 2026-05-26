//
//  AssetType.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 資產類型
enum AssetType: String, Codable, CaseIterable {
    case stockTW = "stock_tw"      // 台股
    case stockUS = "stock_us"       // 美股
    case crypto = "crypto"          // 加密貨幣
    case cash = "cash"              // 現金
    
    var displayName: String {
        switch self {
        case .stockTW: return "台股"
        case .stockUS: return "美股"
        case .crypto: return "加密貨幣"
        case .cash: return "現金"
        }
    }
}

/// 貨幣類型
enum Currency: String, Codable, CaseIterable {
    case TWD = "TWD"
    case USD = "USD"
    case EUR = "EUR"
    case JPY = "JPY"
    case CNY = "CNY"
    case HKD = "HKD"
    case AUD = "AUD"
    
    var symbol: String {
        switch self {
        case .TWD: return "NT$"
        case .USD: return "$"
        case .EUR: return "€"
        case .JPY: return "¥"
        case .CNY: return "¥"
        case .HKD: return "HK$"
        case .AUD: return "A$"
        }
    }
    
    var displayName: String {
        switch self {
        case .TWD: return "新台幣"
        case .USD: return "美元"
        case .EUR: return "歐元"
        case .JPY: return "日圓"
        case .CNY: return "人民幣"
        case .HKD: return "港幣"
        case .AUD: return "澳幣"
        }
    }
}

