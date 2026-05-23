//
//  PortfolioStateSyncPayload.swift
//  Snapvest
//
//  同步至後端的投資組合狀態（現金、持股、負債），供每日淨資產/總資產計算
//

import Foundation

struct PortfolioStateSyncPayload: Codable, Equatable {
    let userId: String
    let syncedAt: Date
    let cash: [PortfolioCashItem]
    let holdings: [PortfolioHoldingItem]
    let liabilities: [PortfolioLiabilityItem]
}

struct PortfolioCashItem: Codable, Equatable {
    let accountId: String
    let currency: String
    let amount: String
}

struct PortfolioHoldingItem: Codable, Equatable {
    let assetType: String
    let symbol: String
    let quantity: String
    let currency: String
    /// 加權平均成本（原幣），供後端算未實現損益
    let averageCost: String?
}

struct PortfolioLiabilityItem: Codable, Equatable {
    /// installment | other_debt
    let kind: String
    let accountId: String
    let liabilityId: String?
    let currency: String
    let amount: String
}

enum PortfolioStateSyncBuilder {
    static func build(
        userId: String,
        accounts: [Account],
        accountSnapshots: [AccountSnapshot],
        aggregatedHoldings: [AggregatedHoldingSnapshot],
        liabilities: [Liability],
        transactions: [Transaction]
    ) -> PortfolioStateSyncPayload {
        let snapshotByAccount = Dictionary(uniqueKeysWithValues: accountSnapshots.map { ($0.accountId, $0) })
        
        var cashItems: [PortfolioCashItem] = []
        for account in accounts where !account.accountType.isLiabilityAccount {
            let balance = snapshotByAccount[account.id]?.cashBalance ?? 0
            cashItems.append(
                PortfolioCashItem(
                    accountId: account.id,
                    currency: account.currency.rawValue,
                    amount: decimalString(balance)
                )
            )
        }
        
        let holdingItems = aggregatedHoldings
            .filter { $0.totalQuantity > 0 }
            .sorted { lhs, rhs in
                if lhs.assetType.rawValue != rhs.assetType.rawValue {
                    return lhs.assetType.rawValue < rhs.assetType.rawValue
                }
                return lhs.symbol < rhs.symbol
            }
            .map { holding in
                PortfolioHoldingItem(
                    assetType: holding.assetType.rawValue,
                    symbol: holding.symbol,
                    quantity: decimalString(holding.totalQuantity),
                    currency: holding.currency.rawValue,
                    averageCost: decimalString(holding.weightedAverageCost)
                )
            }
        
        var liabilityItems: [PortfolioLiabilityItem] = []
        for liability in liabilities where liability.remainingBalance > 0 {
            liabilityItems.append(
                PortfolioLiabilityItem(
                    kind: "installment",
                    accountId: liability.accountId,
                    liabilityId: liability.id,
                    currency: liability.currency.rawValue,
                    amount: decimalString(liability.remainingBalance)
                )
            )
        }
        
        for account in accounts where account.accountType == .otherDebt && !account.isArchived {
            let balance = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: transactions,
                accounts: accounts
            )
            guard balance > 0 else { continue }
            liabilityItems.append(
                PortfolioLiabilityItem(
                    kind: "other_debt",
                    accountId: account.id,
                    liabilityId: nil,
                    currency: account.currency.rawValue,
                    amount: decimalString(balance)
                )
            )
        }
        
        return PortfolioStateSyncPayload(
            userId: userId,
            syncedAt: Date(),
            cash: cashItems,
            holdings: holdingItems,
            liabilities: liabilityItems
        )
    }
    
    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
