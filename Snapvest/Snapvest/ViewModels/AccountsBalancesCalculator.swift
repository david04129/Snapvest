//
//  AccountsBalancesCalculator.swift
//  Snapvest
//
//  帳戶卡片餘額顯示模型（計算邏輯見 AccountsSnapshotDisplayBuilder）。
//

import Foundation

struct AccountBalanceDisplay: Equatable {
    let cashBalance: Decimal
    let holdingsValue: Decimal
    let totalAssets: Decimal
    let twdEquivalent: Decimal?
    let remainingBalance: Decimal
}

struct AccountsBalancesResult: Equatable {
    let byAccountId: [String: AccountBalanceDisplay]
    let categoryTotalsTWD: [AccountType: Decimal]
    /// 債務類別：各債務帳戶剩餘本金加總（正數，僅分期債務）
    let debtCategoryTotalBalance: Decimal
    /// 其他債務類別加總（正數）
    let otherDebtCategoryTotalBalance: Decimal
}
