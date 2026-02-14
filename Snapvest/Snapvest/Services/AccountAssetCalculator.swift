//
//  AccountAssetCalculator.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 帳戶資產計算器 - 計算帳戶的現金餘額和持股市值
class AccountAssetCalculator {

    /// 計算帳戶總資產（現金 + 持股市值，皆以帳戶貨幣計）
    static func calculateTotalAssets(
        account: Account,
        transactions: [Transaction],
        holdings: [HoldingSnapshot],
        accounts: [Account] = [],
        exchangeRate: Decimal? = nil
    ) -> Decimal {
        let cashBalance = CashCalculator.calculateCash(accountId: account.id, transactions: transactions, accounts: accounts.isEmpty ? [account] : accounts)
        let holdingsValue = calculateHoldingsValue(holdings: holdings, account: account, exchangeRate: exchangeRate)
        return cashBalance + holdingsValue
    }

    /// 計算帳戶現金餘額（跨幣別轉帳/買賣需傳入 accounts）
    static func calculateCashBalance(
        account: Account,
        transactions: [Transaction],
        accounts: [Account] = []
    ) -> Decimal {
        let accts = accounts.isEmpty ? [account] : accounts
        return CashCalculator.calculateCash(accountId: account.id, transactions: transactions, accounts: accts)
    }

    /// 計算帳戶持股市值（以帳戶貨幣計，跨幣別時需換算）
    static func calculateHoldingsValue(
        holdings: [HoldingSnapshot],
        account: Account? = nil,
        exchangeRate: Decimal? = nil
    ) -> Decimal {
        guard let account = account, let rate = exchangeRate, rate > 0 else {
            return holdings.compactMap { $0.marketValue }.reduce(0, +)
        }
        return holdings.compactMap { snapshot -> Decimal? in
            guard let mv = snapshot.marketValue else { return nil }
            guard snapshot.holding.currency != account.currency else { return mv }
            if snapshot.holding.currency == .USD && account.currency == .TWD {
                return mv * rate
            }
            if snapshot.holding.currency == .TWD && account.currency == .USD {
                return mv / rate
            }
            return mv
        }.reduce(0, +)
    }
}

