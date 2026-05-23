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
    case debt = "debt"                        // 債務帳戶（分期貸款）
    case otherDebt = "other_debt"             // 其他債務（手動紀錄欠款）
    
    var displayName: String {
        switch self {
        case .twdDeposit: return "台幣存款帳戶"
        case .twdSecurities: return "台幣證券戶"
        case .usdAccount: return "美金帳戶"
        case .cryptoWallet: return "加密貨幣錢包"
        case .debt: return "債務帳戶"
        case .otherDebt: return "其他債務"
        }
    }
    
    var description: String {
        switch self {
        case .twdDeposit: return "用於一般台幣存提。"
        case .twdSecurities: return "用於以台幣買賣台股、美股。"
        case .usdAccount: return "用於美金存提或直接買賣海外資產。"
        case .cryptoWallet: return "用於以美金直接買賣加密貨幣。"
        case .debt: return "用於記錄房屋貸款、信用貸款等。"
        case .otherDebt: return "記錄欠朋友、信用卡帳單等，只需填欠款金額。"
        }
    }
    
    var icon: String {
        switch self {
        case .twdDeposit: return "building.columns.fill"
        case .twdSecurities: return "chart.line.uptrend.xyaxis"
        case .usdAccount: return "dollarsign.circle.fill"
        case .cryptoWallet: return "bitcoinsign.circle.fill"
        case .debt: return "creditcard.fill"
        case .otherDebt: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .twdDeposit: return Color.appPrimary
        case .twdSecurities: return Color.stockTWColor
        case .usdAccount: return Color.stockUSColor
        case .cryptoWallet: return Color.cryptoColor
        case .debt: return Color.lossRed
        case .otherDebt: return Color.lossRed.opacity(0.85)
        }
    }
    
    /// 負債類帳戶（不計入總資產）
    var isLiabilityAccount: Bool {
        self == .debt || self == .otherDebt
    }
    
    /// 對應的資產類型（用於內部邏輯）
    var assetType: AssetType {
        switch self {
        case .twdDeposit: return .cash
        case .twdSecurities: return .stockTW
        case .usdAccount: return .stockUS
        case .cryptoWallet: return .crypto
        case .debt, .otherDebt: return .cash // 負債帳戶不屬於資產類型
        }
    }
    
    /// 預設貨幣
    var defaultCurrency: Currency {
        switch self {
        case .twdDeposit, .twdSecurities: return .TWD
        case .usdAccount, .cryptoWallet: return .USD
        case .debt, .otherDebt: return .TWD
        }
    }
}


