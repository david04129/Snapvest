//
//  CashCalculator.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 現金計算器 - 從交易記錄計算現金餘額
class CashCalculator {
    
    /// 從交易記錄計算帳戶的現金餘額
    static func calculateCash(accountId: String, transactions: [Transaction], accounts: [Account] = []) -> Decimal {
        var cash: Decimal = 0
        
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        for transaction in sortedTransactions {
            guard transaction.accountId == accountId else { continue }
            
            // 還款只記在債務帳戶，不影響現金餘額
            if transaction.type == .repayment { continue }
            
            let account = accounts.first { $0.id == accountId }
            
            switch transaction.type {
            case .deposit:
                cash += transaction.totalAmountWithFee
                
            case .withdraw:
                cash -= transaction.totalAmountWithFee
                
            case .buy:
                guard transaction.deductFromAccount == true else { continue }
                let deductAmount = amountInAccountCurrency(
                    transaction: transaction,
                    account: account
                )
                cash -= deductAmount
                
            case .sell:
                let addAmount = amountInAccountCurrency(
                    transaction: transaction,
                    account: account
                )
                cash += addAmount
                
            case .dividend:
                cash += transaction.totalAmount
                
            case .fee:
                cash -= transaction.fee
                
            case .liability:
                cash -= transaction.totalAmountWithFee
                
            case .repayment:
                break
            }
        }
        
        return cash
    }
    
    /// 買入交易在帳戶貨幣下的扣款金額（僅當 deductFromAccount == true 時有意義）
    static func buyDeductAmountInAccountCurrency(transaction: Transaction, account: Account) -> Decimal {
        guard transaction.type == .buy, transaction.deductFromAccount == true else { return 0 }
        return amountInAccountCurrency(transaction: transaction, account: account)
    }
    
    /// 預估買入扣款金額（帳戶貨幣）
    static func proposedBuyDeductAmount(
        quantity: Decimal,
        price: Decimal,
        fee: Decimal,
        currency: Currency,
        account: Account,
        exchangeRate: Decimal?
    ) -> Decimal {
        let amountInTradeCurrency = quantity * price + fee
        if currency == account.currency {
            return amountInTradeCurrency
        }
        guard currency == .USD, account.currency == .TWD,
              let rate = exchangeRate, rate > 0 else {
            return amountInTradeCurrency
        }
        return amountInTradeCurrency * rate
    }
    
    /// 編輯買入時可用於扣款的現金（若原交易在同帳戶且曾扣款，會加回該筆舊扣款）
    static func availableCashForBuy(
        accountId: String,
        account: Account,
        transactions: [Transaction],
        accounts: [Account],
        existingTransaction: Transaction?
    ) -> Decimal {
        var available = calculateCash(accountId: accountId, transactions: transactions, accounts: accounts)
        if let existing = existingTransaction,
           existing.accountId == accountId,
           existing.type == .buy {
            available += buyDeductAmountInAccountCurrency(transaction: existing, account: account)
        }
        return available
    }
    
    /// 將買賣交易金額換算為帳戶貨幣（供交易紀錄餘額計算使用，與 calculateCash 邏輯一致）
    static func buySellAmountInAccountCurrency(transaction: Transaction, accountCurrency: Currency) -> Decimal {
        let amount = transaction.totalAmountWithFee
        guard transaction.currency != accountCurrency,
              let rate = transaction.exchangeRate, rate > 0 else {
            return amount
        }
        if transaction.currency == .USD && accountCurrency == .TWD {
            return amount * rate
        }
        if transaction.currency == .TWD && accountCurrency == .USD {
            return amount / rate
        }
        return amount
    }
    
    /// 將交易金額換算為帳戶貨幣（用於買入扣款、賣出入帳等跨幣別情境）
    private static func amountInAccountCurrency(
        transaction: Transaction,
        account: Account?
    ) -> Decimal {
        let amount = transaction.totalAmountWithFee
        guard let account = account else { return amount }
        guard transaction.currency != account.currency,
              let rate = transaction.exchangeRate, rate > 0 else {
            return amount
        }
        if transaction.currency == .USD && account.currency == .TWD {
            return amount * rate
        }
        if transaction.currency == .TWD && account.currency == .USD {
            return amount / rate
        }
        return amount
    }
    
    /// 計算所有帳戶的總現金（按貨幣分組）
    static func calculateTotalCashByCurrency(
        accounts: [Account],
        allTransactions: [Transaction]
    ) -> [Currency: Decimal] {
        var cashByCurrency: [Currency: Decimal] = [:]
        
        for account in accounts {
            let cash = calculateCash(accountId: account.id, transactions: allTransactions, accounts: accounts)
            
            if let existing = cashByCurrency[account.currency] {
                cashByCurrency[account.currency] = existing + cash
            } else {
                cashByCurrency[account.currency] = cash
            }
        }
        
        return cashByCurrency
    }
    
    /// 計算總現金（轉換為基礎貨幣）
    static func calculateTotalCash(
        accounts: [Account],
        allTransactions: [Transaction],
        baseCurrency: Currency,
        exchangeRates: [Currency: [Currency: Decimal]] = [:]
    ) -> Decimal {
        let cashByCurrency = calculateTotalCashByCurrency(
            accounts: accounts,
            allTransactions: allTransactions
        )
        
        var totalCash: Decimal = 0
        
        for (currency, amount) in cashByCurrency {
            if currency == baseCurrency {
                totalCash += amount
            } else {
                totalCash += amount
            }
        }
        
        return totalCash
    }
}
