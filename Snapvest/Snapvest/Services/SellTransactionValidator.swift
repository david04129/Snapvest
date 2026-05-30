//
//  SellTransactionValidator.swift
//  Snapvest
//
//  賣出交易（新建／編輯）共用驗證
//

import Foundation

enum SellTransactionValidator {
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
        symbol: String,
        quantity: Decimal,
        exchangeRate: Decimal?,
        maxSellQuantity: Decimal
    ) -> String? {
        if requiresExchangeRate(account: account, assetType: assetType) {
            guard let rate = exchangeRate, rate > 0 else {
                return "請填寫 \(transactionCurrency(for: assetType).rawValue) 對 \(account.currency.rawValue) 匯率"
            }
        }

        if quantity > maxSellQuantity {
            let digits = assetType == .crypto ? 8 : 4
            let maxLabel = maxSellQuantity.formattedQuantityInput(maxFractionDigits: digits)
            return "數量不可超過可賣數量（\(maxLabel)）"
        }

        return nil
    }
}
