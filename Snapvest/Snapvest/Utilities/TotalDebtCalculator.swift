//
//  TotalDebtCalculator.swift
//  Snapvest
//
//  總負債 = 分期債務（Liability）+ 其他債務（otherDebt 交易餘額）
//

import Foundation

enum TotalDebtCalculator {
    
    static func convertToTWD(_ amount: Decimal, currency: Currency, usdToTwdRate: Decimal) -> Decimal {
        switch currency {
        case .TWD:
            return amount
        case .USD:
            return amount * usdToTwdRate
        default:
            return amount
        }
    }
    
    /// 總負債（TWD），已排除已封存帳戶
    static func totalLiabilitiesTWD(
        accounts: [Account],
        liabilities: [Liability],
        transactions: [Transaction],
        usdToTwdRate: Decimal
    ) -> Decimal {
        var total: Decimal = 0
        
        for liability in liabilities {
            if DebtAccountArchive.isDebtAccountArchived(named: liability.name, accounts: accounts) {
                continue
            }
            total += convertToTWD(
                liability.remainingBalance,
                currency: liability.currency,
                usdToTwdRate: usdToTwdRate
            )
        }
        
        for account in accounts where account.accountType == .otherDebt && !account.isArchived {
            let remaining = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: transactions,
                accounts: accounts
            )
            total += convertToTWD(
                remaining,
                currency: account.currency,
                usdToTwdRate: usdToTwdRate
            )
        }
        
        return total
    }
    
    /// 其他債務類別加總（TWD，未封存）
    static func otherDebtCategoryTotalTWD(
        accounts: [Account],
        transactions: [Transaction],
        usdToTwdRate: Decimal
    ) -> Decimal {
        accounts
            .filter { $0.accountType == .otherDebt && !$0.isArchived }
            .reduce(Decimal.zero) { partial, account in
                let remaining = OtherDebtCalculator.remainingBalance(
                    accountId: account.id,
                    transactions: transactions,
                    accounts: accounts
                )
                return partial + convertToTWD(
                    remaining,
                    currency: account.currency,
                    usdToTwdRate: usdToTwdRate
                )
            }
    }
}
