//
//  SellTransactionValidator.swift
//  Snapvest
//
//  賣出交易（新建／編輯）共用驗證
//

import Foundation

enum SellTransactionValidator {
    static func resolvedExchangeRate(account: Account, assetType: AssetType, exchangeRate: Decimal?) -> Decimal? {
        guard assetType == .stockUS, account.accountType == .twdSecurities else { return nil }
        return exchangeRate
    }

    static func requiresExchangeRate(account: Account, assetType: AssetType) -> Bool {
        assetType == .stockUS && account.accountType == .twdSecurities
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
                return "複委托賣出美股請填寫美金對台匯率"
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
