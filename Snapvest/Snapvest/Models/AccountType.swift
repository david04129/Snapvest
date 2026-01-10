//
//  AccountType.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import SwiftUI

/// 帳戶類型（明確的業務類型）
enum AccountType: String, Codable, CaseIterable {
    case twdDeposit = "twd_deposit"           // 台幣存款帳戶
    case twdSecurities = "twd_securities"     // 台幣證券戶
    case usdAccount = "usd_account"          // 美金帳戶
    case cryptoWallet = "crypto_wallet"      // 加密貨幣錢包
    case debt = "debt"                        // 債務帳戶
    
    var displayName: String {
        switch self {
        case .twdDeposit: return "台幣存款帳戶"
        case .twdSecurities: return "台幣證券戶"
        case .usdAccount: return "美金帳戶"
        case .cryptoWallet: return "加密貨幣錢包"
        case .debt: return "債務帳戶"
        }
    }
    
    var description: String {
        switch self {
        case .twdDeposit: return "用於一般台幣存提。"
        case .twdSecurities: return "用於以台幣買賣台股、美股。"
        case .usdAccount: return "用於美金存提或直接買賣海外資產。"
        case .cryptoWallet: return "用於以美金直接買賣加密貨幣。"
        case .debt: return "用於記錄房屋貸款、信用貸款等。"
        }
    }
    
    var icon: String {
        switch self {
        case .twdDeposit: return "building.columns.fill"
        case .twdSecurities: return "chart.line.uptrend.xyaxis"
        case .usdAccount: return "dollarsign.circle.fill"
        case .cryptoWallet: return "bitcoinsign.circle.fill"
        case .debt: return "creditcard.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .twdDeposit: return Color(red: 0.4, green: 0.4, blue: 0.4, opacity: 1.0)      // 深灰色
        case .twdSecurities: return Color(red: 0.0, green: 0.5, blue: 1.0, opacity: 1.0)  // 藍色
        case .usdAccount: return Color(red: 0.7, green: 0.5, blue: 0.9, opacity: 1.0)     // 淺紫色
        case .cryptoWallet: return Color(red: 1.0, green: 0.6, blue: 0.2, opacity: 1.0)   // 淺橙色
        case .debt: return Color(red: 0.9, green: 0.3, blue: 0.3, opacity: 1.0)            // 淺紅色
        }
    }
    
    /// 對應的資產類型（用於內部邏輯）
    var assetType: AssetType {
        switch self {
        case .twdDeposit: return .cash
        case .twdSecurities: return .stockTW
        case .usdAccount: return .stockUS
        case .cryptoWallet: return .crypto
        case .debt: return .cash // 債務帳戶不屬於資產類型
        }
    }
    
    /// 預設貨幣
    var defaultCurrency: Currency {
        switch self {
        case .twdDeposit, .twdSecurities: return .TWD
        case .usdAccount, .cryptoWallet: return .USD
        case .debt: return .TWD
        }
    }
}


