//
//  AccountType.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import SwiftUI

/// 新增帳戶／列表用的大分類
enum AccountCategory: String, CaseIterable, Identifiable {
    case deposit = "存款帳戶"
    case investment = "投資帳戶"
    case liability = "債務帳戶"
    
    var id: String { rawValue }
    
    var accountTypes: [AccountType] {
        switch self {
        case .deposit: return [.twdDeposit]
        case .investment: return [.twdSecurities, .usdAccount, .cryptoWallet]
        case .liability: return [.debt, .otherDebt]
        }
    }
}

/// 帳戶類型（明確的業務類型）
enum AccountType: String, Codable, CaseIterable {
    case twdDeposit = "twd_deposit"           // 台幣存款戶
    case twdSecurities = "twd_securities"     // 台幣證券戶（複委托）
    case usdAccount = "usd_account"          // 美金證券戶
    case cryptoWallet = "crypto_wallet"      // 加密貨幣戶
    case debt = "debt"                        // 分期貸款戶
    case otherDebt = "other_debt"             // 其他負債戶
    
    var category: AccountCategory {
        switch self {
        case .twdDeposit: return .deposit
        case .twdSecurities, .usdAccount, .cryptoWallet: return .investment
        case .debt, .otherDebt: return .liability
        }
    }
    
    var displayName: String {
        switch self {
        case .twdDeposit: return "台幣存款戶"
        case .twdSecurities: return "台幣證券戶（複委托）"
        case .usdAccount: return "美金證券戶"
        case .cryptoWallet: return "加密貨幣戶"
        case .debt: return "分期貸款戶"
        case .otherDebt: return "其他負債戶"
        }
    }
    
    var description: String {
        switch self {
        case .twdDeposit: return "台幣現金存提，不記錄股票持倉。"
        case .twdSecurities: return "以台幣交割，買賣台股及券商內海外標的。"
        case .usdAccount: return "美金現金與海外標的（美股等）買賣。"
        case .cryptoWallet: return "以美金計價的加密資產買賣與持倉。"
        case .debt: return "房貸、信貸等：本金、期數、利率與每月還款。"
        case .otherDebt: return "欠朋友、卡費等：只記欠款金額與備註。"
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
    
    /// 是否支援 CSV 匯入交易（證券戶與加密貨幣戶）
    var supportsTransactionImport: Bool {
        self == .twdSecurities || self == .usdAccount || self == .cryptoWallet
    }
    
    /// 是否可從帳戶詳情新增買賣交易
    var supportsStockTrading: Bool {
        switch self {
        case .twdSecurities, .usdAccount, .cryptoWallet: return true
        default: return false
        }
    }
}


