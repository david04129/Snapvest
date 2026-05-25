//
//  Transaction.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 交易類型
enum TransactionType: String, Codable, CaseIterable {
    case buy = "buy"                // 買入
    case sell = "sell"              // 賣出
    case deposit = "deposit"        // 存入
    case withdraw = "withdraw"      // 提取
    case dividend = "dividend"      // 股利
    case fee = "fee"                // 手續費
    case liability = "liability"    // 債務
    case repayment = "repayment"    // 還款
    
    var displayName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        case .deposit: return "存入"
        case .withdraw: return "提取"
        case .dividend: return "股利"
        case .fee: return "手續費"
        case .liability: return "債務"
        case .repayment: return "還款"
        }
    }
}

struct Transaction: Identifiable, Codable, Equatable {
    let id: String
    var accountId: String
    var type: TransactionType
    var assetType: AssetType
    var symbol: String
    var quantity: Decimal
    var price: Decimal
    var currency: Currency
    var fee: Decimal
    var notes: String?
    var transactionDate: Date
    var createdAt: Date
    var updatedAt: Date
    
    // 交易金額（儲存欄位，在交易當下計算並儲存）
    var totalAmount: Decimal      // 交易總金額（不含手續費）
    var totalAmountWithFee: Decimal  // 交易總金額（含手續費）
    
    // 匯率（跨幣別交易時使用，格式：USD to TWD，1 USD = exchangeRate TWD）
    var exchangeRate: Decimal?    // 交易當下的匯率（跨幣別買賣股票時使用）
    
    // 買入時是否從帳戶扣款（true = 扣款，nil 或 false = 不扣款，用於外部資金買入等情境）
    var deductFromAccount: Bool?
    
    // 已實現損益（僅用於賣出交易）
    var realizedGainLoss: Decimal?
    var realizedGainLossPercent: Decimal?
    var realizedCostBasis: Decimal?
    var realizedCostPerUnit: Decimal?
    
    // 還款前狀態（僅用於 .repayment 類型，用於刪除時恢復）
    var beforeRepaymentBalance: Decimal?  // 還款前的剩餘本金
    var beforeRepaymentInterest: Decimal?  // 還款前的剩餘利息
    var beforeRepaymentPaidPeriods: Int?  // 還款前的已還期數
    var beforeRepaymentTotalPeriods: Int?  // 還款前的總期數
    // 還款金額組成（僅用於 .repayment 類型）
    var principalAmount: Decimal?  // 本金部分
    var interestAmount: Decimal?   // 利息部分
    var savedInterest: Decimal?    // 節省利息（僅用於提前還款類型）
    
    init(id: String = UUID().uuidString,
         accountId: String,
         type: TransactionType,
         assetType: AssetType,
         symbol: String,
         quantity: Decimal,
         price: Decimal,
         currency: Currency,
         fee: Decimal = 0,
         notes: String? = nil,
         transactionDate: Date = Date(),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         exchangeRate: Decimal? = nil,
         deductFromAccount: Bool? = false,
         beforeRepaymentBalance: Decimal? = nil,
         beforeRepaymentInterest: Decimal? = nil,
         beforeRepaymentPaidPeriods: Int? = nil,
         beforeRepaymentTotalPeriods: Int? = nil,
         principalAmount: Decimal? = nil,
         interestAmount: Decimal? = nil,
         savedInterest: Decimal? = nil,
         realizedGainLoss: Decimal? = nil,
         realizedGainLossPercent: Decimal? = nil,
         realizedCostBasis: Decimal? = nil,
         realizedCostPerUnit: Decimal? = nil) {
        self.id = id
        self.accountId = accountId
        self.type = type
        self.assetType = assetType
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.currency = currency
        self.fee = fee
        self.notes = notes
        self.transactionDate = transactionDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exchangeRate = exchangeRate
        self.deductFromAccount = deductFromAccount
        self.realizedGainLoss = realizedGainLoss
        self.realizedGainLossPercent = realizedGainLossPercent
        self.realizedCostBasis = realizedCostBasis
        self.realizedCostPerUnit = realizedCostPerUnit
        
        // 計算並儲存交易金額
        let calculatedTotalAmount = quantity * price
        self.totalAmount = calculatedTotalAmount
        
        // 根據交易類型計算含手續費的總金額
        switch type {
        case .buy, .deposit:
            self.totalAmountWithFee = calculatedTotalAmount + fee
        case .sell, .withdraw:
            self.totalAmountWithFee = calculatedTotalAmount - fee
        case .dividend:
            self.totalAmountWithFee = calculatedTotalAmount
        case .fee:
            self.totalAmountWithFee = fee
        case .liability:
            self.totalAmountWithFee = calculatedTotalAmount
        case .repayment:
            self.totalAmountWithFee = calculatedTotalAmount
        }
        
        self.beforeRepaymentBalance = beforeRepaymentBalance
        self.beforeRepaymentInterest = beforeRepaymentInterest
        self.beforeRepaymentPaidPeriods = beforeRepaymentPaidPeriods
        self.beforeRepaymentTotalPeriods = beforeRepaymentTotalPeriods
        self.principalAmount = principalAmount
        self.interestAmount = interestAmount
        self.savedInterest = savedInterest
    }
}

extension Transaction {
    /// 從買入備註解析股票名稱（格式：買入 SYMBOL - 名稱）
    var buySymbolNameFromNotes: String? {
        guard type == .buy, let notes else { return nil }
        let prefix = "買入 \(symbol) - "
        guard notes.hasPrefix(prefix) else { return nil }
        let name = String(notes.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
    
    /// 刪除確認對話框摘要
    var deleteConfirmationMessage: String {
        let dateText: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_TW")
            f.dateFormat = "yyyy/M/d"
            return f.string(from: transactionDate)
        }()
        switch type {
        case .buy:
            return "確定刪除「買入 \(symbol)」？（\(dateText)）此操作無法復原。"
        case .sell:
            return "確定刪除「賣出 \(symbol)」？（\(dateText)）此操作無法復原。"
        case .deposit:
            return "確定刪除這筆收入？（\(dateText)）此操作無法復原。"
        case .withdraw:
            return "確定刪除這筆支出？（\(dateText)）此操作無法復原。"
        case .repayment:
            return "確定刪除這筆還款？（\(dateText)）此操作無法復原。"
        default:
            return "確定刪除這筆紀錄？（\(dateText)）此操作無法復原。"
        }
    }
}

