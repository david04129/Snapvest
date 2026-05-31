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
    case deposit = "現金帳戶"
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
    case debt = "debt"                        // 分期貸款
    case otherDebt = "other_debt"             // 其他負債
    
    var category: AccountCategory {
        switch self {
        case .twdDeposit: return .deposit
        case .twdSecurities, .usdAccount, .cryptoWallet: return .investment
        case .debt, .otherDebt: return .liability
        }
    }
    
    var displayName: String {
        switch self {
        case .twdDeposit: return "現金帳戶"
        case .twdSecurities: return "台股證券"
        case .usdAccount: return "美股證券"
        case .cryptoWallet: return "加密貨幣錢包"
        case .debt: return "分期貸款"
        case .otherDebt: return "其他負債"
        }
    }
    
    var description: String {
        switch self {
        case .twdDeposit: return "可選幣別的現金存提與日常資金。"
        case .twdSecurities: return "買賣台股、台股 ETF 與台股債券 ETF，可依帳戶選擇常用幣別。"
        case .usdAccount: return "買賣美股與美股 ETF，可依帳戶選擇常用幣別。"
        case .cryptoWallet: return "追蹤加密貨幣持倉，可依錢包選擇常用幣別。"
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
    
    var selectableCurrencies: [Currency] {
        switch self {
        case .twdDeposit:
            return Currency.baseCurrencyOptions
        case .twdSecurities, .usdAccount, .cryptoWallet:
            return [.USD, .TWD, .AUD, .JPY, .EUR, .HKD, .CNY]
        case .debt, .otherDebt:
            return Currency.baseCurrencyOptions
        }
    }

    var allowsCurrencySelection: Bool {
        selectableCurrencies.count > 1
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

    /// 詳情頁內嵌交易紀錄（取代 toolbar 另開完整列表）
    var showsInlineTransactionHistory: Bool {
        switch self {
        case .twdDeposit, .twdSecurities, .usdAccount, .cryptoWallet, .debt, .otherDebt:
            return true
        }
    }

    /// 投資帳戶詳情：顯示持股市值與持股明細
    var showsInvestmentHoldingsOnDetail: Bool {
        switch self {
        case .twdSecurities, .usdAccount, .cryptoWallet:
            return true
        default:
            return false
        }
    }
}


