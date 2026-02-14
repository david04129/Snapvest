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
        
        // 按時間排序交易
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        for transaction in sortedTransactions {
            // 對於轉帳/還款交易，需要檢查是轉出還是轉入
            if transaction.type == .transfer || transaction.type == .repayment {
                if transaction.accountId == accountId {
                    // 這是轉出帳戶：減少現金（使用轉出金額）
                    // 對於還款，這是還款帳戶，扣款總還款金額
                    cash -= transaction.totalAmount
                } else if transaction.targetAccountId == accountId {
                    // 這是轉入帳戶：增加現金
                    // 如果提供了帳戶列表，查找目標帳戶以確定貨幣和帳戶類型
                    var receivedAmount = transaction.totalAmount
                    
                    if !accounts.isEmpty, let targetAccount = accounts.first(where: { $0.id == accountId }) {
                        // 如果是還款交易且目標帳戶是債務帳戶，只計算本金部分（直接從 transaction.principalAmount 讀取）
                        if transaction.type == .repayment && targetAccount.accountType == .debt {
                            // 直接使用交易中存儲的本金部分
                            if let principalAmount = transaction.principalAmount {
                                receivedAmount = principalAmount
                            }
                        } else if transaction.currency != targetAccount.currency {
                            // 如果交易的貨幣與目標帳戶的貨幣不同（跨幣別轉帳/還款），需要使用匯率計算轉入金額
                            if let rate = transaction.exchangeRate, rate > 0 {
                                // 匯率是 1 USD = rate TWD
                                // 如果 transaction.currency == .TWD 且 targetAccount.currency == .USD，則轉入金額 = transaction.totalAmount / rate
                                // 如果 transaction.currency == .USD 且 targetAccount.currency == .TWD，則轉入金額 = transaction.totalAmount * rate
                                if transaction.currency == .TWD && targetAccount.currency == .USD {
                                    receivedAmount = transaction.totalAmount / rate
                                } else if transaction.currency == .USD && targetAccount.currency == .TWD {
                                    receivedAmount = transaction.totalAmount * rate
                                }
                            } else {
                                // 向後兼容：嘗試從 notes 解析匯率（僅用於舊數據）
                                if let notes = transaction.notes,
                                   let rateRange = notes.range(of: "匯率: ") {
                                    let rateString = String(notes[rateRange.upperBound...])
                                    if let rateEnd = rateString.firstIndex(of: ")") {
                                        let rateValue = String(rateString[..<rateEnd]).trimmingCharacters(in: .whitespaces)
                                        if let rate = Decimal(string: rateValue), rate > 0 {
                                            if transaction.currency == .TWD && targetAccount.currency == .USD {
                                                receivedAmount = transaction.totalAmount / rate
                                            } else if transaction.currency == .USD && targetAccount.currency == .TWD {
                                                receivedAmount = transaction.totalAmount * rate
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    cash += receivedAmount
                }
                continue
            }
            
            guard transaction.accountId == accountId else { continue }
            
            let account = accounts.first { $0.id == accountId }
            
            switch transaction.type {
            case .deposit:
                // 存入：增加現金
                cash += transaction.totalAmountWithFee
                
            case .withdraw:
                // 提取：減少現金
                cash -= transaction.totalAmountWithFee
                
            case .buy:
                // 買入：若 deductFromAccount 為 false，不扣款
                guard transaction.deductFromAccount ?? true else { continue }
                let deductAmount = amountInAccountCurrency(
                    transaction: transaction,
                    account: account
                )
                cash -= deductAmount
                
            case .sell:
                // 賣出：增加現金（含手續費），跨幣別時需換算
                let addAmount = amountInAccountCurrency(
                    transaction: transaction,
                    account: account
                )
                cash += addAmount
                
            case .dividend:
                // 股利：增加現金
                cash += transaction.totalAmount
                
            case .fee:
                // 手續費：減少現金
                cash -= transaction.fee
                
            case .liability:
                // 債務：減少現金（債務是負債）
                cash -= transaction.totalAmountWithFee
                
            case .transfer, .repayment:
                // 轉帳/還款交易已在上面處理（第22-30行）
                // 這個 case 永遠不會被執行，但需要它來滿足 switch 的完整性要求
                break
            }
        }
        
        return cash
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
            // 傳入所有交易，calculateCash 會自己處理轉帳/還款交易的過濾
            // 因為轉帳/還款交易可能記錄在轉出帳戶，但影響轉入帳戶的餘額
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
                // 轉換為基礎貨幣
                // TODO: 使用 exchangeRates 進行轉換
                // 目前先直接相加（假設匯率為 1）
                totalCash += amount
            }
        }
        
        return totalCash
    }
}

