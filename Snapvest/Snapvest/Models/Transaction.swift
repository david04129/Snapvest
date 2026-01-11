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
    case transfer = "transfer"       // 轉帳
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
        case .transfer: return "轉帳"
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
    var targetAccountId: String?  // 轉帳/還款目標帳戶ID
    
    // 交易金額（儲存欄位，在交易當下計算並儲存）
    var totalAmount: Decimal      // 交易總金額（不含手續費）
    var totalAmountWithFee: Decimal  // 交易總金額（含手續費）
    
    // 匯率（跨幣別交易時使用，格式：USD to TWD，1 USD = exchangeRate TWD）
    var exchangeRate: Decimal?    // 交易當下的匯率（跨幣別買賣股票、轉帳、還款時使用）
    
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
         targetAccountId: String? = nil,
         exchangeRate: Decimal? = nil,
         beforeRepaymentBalance: Decimal? = nil,
         beforeRepaymentInterest: Decimal? = nil,
         beforeRepaymentPaidPeriods: Int? = nil,
         beforeRepaymentTotalPeriods: Int? = nil,
         principalAmount: Decimal? = nil,
         interestAmount: Decimal? = nil,
         savedInterest: Decimal? = nil) {
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
        self.targetAccountId = targetAccountId
        self.exchangeRate = exchangeRate
        
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
        case .transfer, .repayment:
            // 轉帳/還款：從轉出帳戶角度看是減少，從轉入帳戶角度看是增加
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

