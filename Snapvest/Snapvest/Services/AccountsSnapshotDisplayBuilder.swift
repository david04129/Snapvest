//
//  AccountsSnapshotDisplayBuilder.swift
//  Snapvest
//
//  從本機估值快照 B 組出帳戶分頁顯示（不拉 Supabase、不重算交易）。
//

import Foundation

enum AccountsSnapshotDisplayBuilder {
    @MainActor
    static func build(
        accounts: [Account],
        userId: String,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal,
        liabilities: [Liability]
    ) async -> AccountsBalancesResult {
        var allTransactions: [Transaction] = []
        if let fetched = try? await dataService.fetchAllTransactions(userId: userId) {
            allTransactions = fetched
        }

        var byAccountId: [String: AccountBalanceDisplay] = [:]
        var categoryTotalsTWD: [AccountType: Decimal] = [:]
        var debtCategoryTotalBalance: Decimal = 0
        var otherDebtCategoryTotalBalance: Decimal = 0

        for account in accounts {
            if account.accountType == .debt {
                if account.isArchived { continue }
                let remaining = remainingBalance(forDebtAccount: account, in: liabilities)
                debtCategoryTotalBalance += remaining
                byAccountId[account.id] = AccountBalanceDisplay(
                    cashBalance: 0,
                    holdingsValue: 0,
                    totalAssets: 0,
                    twdEquivalent: nil,
                    remainingBalance: remaining
                )
                continue
            }

            if account.accountType == .otherDebt {
                if account.isArchived { continue }
                let remaining = OtherDebtCalculator.remainingBalance(
                    accountId: account.id,
                    transactions: allTransactions,
                    accounts: accounts
                )
                let twdRemaining = accountTotalInTWD(
                    accountTotal: remaining,
                    currency: account.currency,
                    usdToTwdRate: usdToTwdRate
                )
                otherDebtCategoryTotalBalance += twdRemaining
                byAccountId[account.id] = AccountBalanceDisplay(
                    cashBalance: 0,
                    holdingsValue: 0,
                    totalAssets: 0,
                    twdEquivalent: account.currency == .USD ? twdRemaining : nil,
                    remainingBalance: remaining
                )
                continue
            }

            let snapshot = try? await dataService.fetchAccountSnapshot(accountId: account.id)
            let cashBalance = snapshot?.cashBalance ?? 0
            let holdingsValue = await holdingsValueInAccountCurrency(
                snapshot: snapshot,
                account: account,
                dataService: dataService,
                usdToTwdRate: usdToTwdRate
            )
            let totalAssets = cashBalance + holdingsValue
            let twdEquivalent: Decimal? = account.currency == .USD ? totalAssets * usdToTwdRate : nil

            byAccountId[account.id] = AccountBalanceDisplay(
                cashBalance: cashBalance,
                holdingsValue: holdingsValue,
                totalAssets: totalAssets,
                twdEquivalent: twdEquivalent,
                remainingBalance: 0
            )

            let twdContribution = accountTotalInTWD(
                accountTotal: totalAssets,
                currency: account.currency,
                usdToTwdRate: usdToTwdRate
            )
            categoryTotalsTWD[account.accountType, default: 0] += twdContribution
        }

        return AccountsBalancesResult(
            byAccountId: byAccountId,
            categoryTotalsTWD: categoryTotalsTWD,
            debtCategoryTotalBalance: debtCategoryTotalBalance,
            otherDebtCategoryTotalBalance: otherDebtCategoryTotalBalance
        )
    }

    // MARK: - Private

    private static func holdingsValueInAccountCurrency(
        snapshot: AccountSnapshot?,
        account: Account,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async -> Decimal {
        guard let holdings = snapshot?.holdings, !holdings.isEmpty else { return 0 }

        var total: Decimal = 0
        for holding in holdings {
            let price = try? await dataService.fetchAssetPriceSnapshot(
                assetType: holding.assetType,
                symbol: holding.symbol
            )?.displayPrice
            guard let price else { continue }

            var marketValue = holding.quantity * price
            if holding.currency != account.currency {
                if holding.currency == .USD && account.currency == .TWD {
                    marketValue *= usdToTwdRate
                } else if holding.currency == .TWD && account.currency == .USD, usdToTwdRate > 0 {
                    marketValue /= usdToTwdRate
                }
            }
            total += marketValue
        }
        return total
    }

    private static func accountTotalInTWD(
        accountTotal: Decimal,
        currency: Currency,
        usdToTwdRate: Decimal
    ) -> Decimal {
        switch currency {
        case .TWD:
            return accountTotal
        case .USD:
            return accountTotal * usdToTwdRate
        default:
            return accountTotal
        }
    }

    private static func remainingBalance(forDebtAccount account: Account, in liabilities: [Liability]) -> Decimal {
        liabilities.first(where: { $0.name == account.name })?.remainingBalance ?? 0
    }
}
