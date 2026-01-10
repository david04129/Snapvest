//
//  AccountAssetCalculator.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 帳戶資產計算器 - 計算帳戶的現金餘額和持股市值
class AccountAssetCalculator {
    
    /// 計算帳戶總資產（現金 + 持股市值）
    static func calculateTotalAssets(
        account: Account,
        transactions: [Transaction],
        holdings: [HoldingSnapshot],
        exchangeRate: Decimal? = nil
    ) -> Decimal {
        let cashBalance = CashCalculator.calculateCash(accountId: account.id, transactions: transactions)
        let holdingsValue = holdings.compactMap { $0.marketValue }.reduce(0, +)
        
        // 如果帳戶貨幣不是 TWD 且有匯率，轉換為 TWD
        if account.currency != .TWD, let rate = exchangeRate {
            return (cashBalance + holdingsValue) * rate
        }
        
        return cashBalance + holdingsValue
    }
    
    /// 計算帳戶現金餘額
    static func calculateCashBalance(
        account: Account,
        transactions: [Transaction]
    ) -> Decimal {
        return CashCalculator.calculateCash(accountId: account.id, transactions: transactions)
    }
    
    /// 計算帳戶持股市值
    static func calculateHoldingsValue(
        holdings: [HoldingSnapshot]
    ) -> Decimal {
        return holdings.compactMap { $0.marketValue }.reduce(0, +)
    }
}

