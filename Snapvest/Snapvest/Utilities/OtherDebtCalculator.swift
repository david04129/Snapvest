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
            if transaction.accountId == accountId && transaction.type == .liability {
                balance += transaction.totalAmountWithFee
            }
            if transaction.targetAccountId == accountId
                && (transaction.type == .repayment || transaction.type == .transfer) {
                balance -= repaymentAmount(
                    transaction: transaction,
                    targetAccountId: accountId,
                    accounts: accounts
                )
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
            .filter {
                $0.targetAccountId == accountId
                    && ($0.type == .repayment || $0.type == .transfer)
            }
            .reduce(Decimal.zero) { partial, transaction in
                partial + repaymentAmount(
                    transaction: transaction,
                    targetAccountId: accountId,
                    accounts: accounts
                )
            }
    }
    
    private static func repaymentAmount(
        transaction: Transaction,
        targetAccountId: String,
        accounts: [Account]
    ) -> Decimal {
        guard let targetAccount = accounts.first(where: { $0.id == targetAccountId }) else {
            return transaction.totalAmount
        }
        
        var amount = transaction.totalAmount
        if transaction.currency != targetAccount.currency {
            if let rate = transaction.exchangeRate, rate > 0 {
                if transaction.currency == .TWD && targetAccount.currency == .USD {
                    amount = transaction.totalAmount / rate
                } else if transaction.currency == .USD && targetAccount.currency == .TWD {
                    amount = transaction.totalAmount * rate
                }
            }
        }
        return amount
    }
}
