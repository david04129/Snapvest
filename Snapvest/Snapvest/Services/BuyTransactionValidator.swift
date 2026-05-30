//
//  BuyTransactionValidator.swift
//  Snapvest
//
//  Created on 2026
//

import Foundation

/// 買入交易（新建／編輯）共用驗證
enum BuyTransactionValidator {
    
    static func resolvedExchangeRate(account: Account, assetType: AssetType, exchangeRate: Decimal?) -> Decimal? {
        guard requiresExchangeRate(account: account, assetType: assetType) else { return nil }
        return exchangeRate
    }

    static func requiresExchangeRate(account: Account, assetType: AssetType) -> Bool {
        transactionCurrency(for: assetType) != account.currency
    }

    static func transactionCurrency(for assetType: AssetType) -> Currency {
        switch assetType {
        case .stockTW, .cash:
            return .TWD
        case .stockUS, .crypto:
            return .USD
        }
    }
    
    static func validate(
        account: Account,
        assetType: AssetType,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        fee: Decimal,
        exchangeRate: Decimal?,
        deductFromAccount: Bool,
        accountTransactions: [Transaction],
        allAccounts: [Account],
        existingTransaction: Transaction?
    ) -> String? {
        if requiresExchangeRate(account: account, assetType: assetType) {
            guard let rate = exchangeRate, rate > 0 else {
                return "請填寫 \(transactionCurrency(for: assetType).rawValue) 對 \(account.currency.rawValue) 匯率"
            }
        }
        
        guard deductFromAccount else { return nil }
        
        let rateForDeduct = resolvedExchangeRate(
            account: account,
            assetType: assetType,
            exchangeRate: exchangeRate
        )
        let deductAmount = CashCalculator.proposedBuyDeductAmount(
            quantity: quantity,
            price: price,
            fee: fee,
            currency: currency,
            account: account,
            exchangeRate: rateForDeduct
        )
        let available = CashCalculator.availableCashForBuy(
            accountId: account.id,
            account: account,
            transactions: accountTransactions,
            accounts: allAccounts,
            existingTransaction: existingTransaction
        )
        
        if deductAmount > available {
            return "現金餘額不足。可用餘額：\(available.formatted(currency: account.currency))，本筆需扣款：\(deductAmount.formatted(currency: account.currency))"
        }
        
        return nil
    }
}
