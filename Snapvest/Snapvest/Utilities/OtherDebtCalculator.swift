//
//  OtherDebtCalculator.swift
//  Snapvest
//
//  其他債務：由交易加減剩餘欠款（不拆本息）
//

import Foundation

enum OtherDebtCalculator {
    
    /// 從交易紀錄計算其他債務帳戶的剩餘欠款
    static func remainingBalance(
        accountId: String,
        transactions: [Transaction],
        accounts: [Account] = []
    ) -> Decimal {
        var balance: Decimal = 0
        let sorted = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        for transaction in sorted {
            guard transaction.accountId == accountId else { continue }
            
            if transaction.type == .liability {
                balance += transaction.totalAmountWithFee
            } else if transaction.type == .repayment {
                balance -= transaction.totalAmount
            }
        }
        
        return max(0, balance)
    }
    
    /// 其他債務帳戶累計已還金額
    static func totalRepaid(
        accountId: String,
        transactions: [Transaction],
        accounts: [Account] = []
    ) -> Decimal {
        transactions
            .filter { $0.accountId == accountId && $0.type == .repayment }
            .reduce(Decimal.zero) { $0 + $1.totalAmount }
    }
}
