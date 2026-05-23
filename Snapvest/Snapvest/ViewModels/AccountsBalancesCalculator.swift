//
//  AccountsBalancesCalculator.swift
//  Snapvest
//
//  帳戶分頁餘額一次算完，避免類別／卡片重複拉交易與報價。
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
    /// 債務類別：各債務帳戶剩餘本金加總（正數）
    let debtCategoryTotalBalance: Decimal
}

@MainActor
enum AccountsBalancesCalculator {

    static func compute(
        accounts: [Account],
        userId: String,
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol? = nil,
        preloadedLiabilities: [Liability] = []
    ) async -> AccountsBalancesResult {
        let priceService = priceService ?? PriceService(dataService: dataService)
        let usdToTwdRate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 32

        var allTransactions: [Transaction] = []
        if let fetched = try? await dataService.fetchAllTransactions(userId: userId) {
            allTransactions = fetched
        }

        let allLiabilities: [Liability]
        if preloadedLiabilities.isEmpty {
            allLiabilities = await loadAllLiabilities(accounts: accounts, dataService: dataService)
        } else {
            allLiabilities = preloadedLiabilities
        }

        var priceCache: [String: Decimal] = [:]
        var byAccountId: [String: AccountBalanceDisplay] = [:]
        var categoryTotalsTWD: [AccountType: Decimal] = [:]
        var debtCategoryTotalBalance: Decimal = 0

        for account in accounts {
            if account.accountType == .debt {
                let remaining = remainingBalance(forDebtAccount: account, in: allLiabilities)
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

            let transactions = transactionsForAccount(
                account,
                allTransactions: allTransactions,
                allAccounts: accounts
            )
            let cashBalance = CashCalculator.calculateCash(
                accountId: account.id,
                transactions: transactions,
                accounts: accounts
            )
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)

            var holdingsValueInAccountCurrency: Decimal = 0
            for holding in calculatedHoldings {
                let cacheKey = "\(holding.assetType.rawValue)-\(holding.symbol)"
                let price: Decimal?
                if let cached = priceCache[cacheKey] {
                    price = cached
                } else {
                    let fetched = try? await priceService.fetchCurrentPrice(
                        assetType: holding.assetType,
                        symbol: holding.symbol
                    )
                    if let fetched {
                        priceCache[cacheKey] = fetched
                    }
                    price = fetched
                }

                guard let price else { continue }

                var marketValue = holding.quantity * price
                if holding.currency != account.currency {
                    if holding.currency == .USD && account.currency == .TWD {
                        marketValue = marketValue * usdToTwdRate
                    } else if holding.currency == .TWD && account.currency == .USD, usdToTwdRate > 0 {
                        marketValue = marketValue / usdToTwdRate
                    }
                }
                holdingsValueInAccountCurrency += marketValue
            }

            let totalAssets = cashBalance + holdingsValueInAccountCurrency
            let twdEquivalent: Decimal? = account.currency == .USD ? totalAssets * usdToTwdRate : nil

            byAccountId[account.id] = AccountBalanceDisplay(
                cashBalance: cashBalance,
                holdingsValue: holdingsValueInAccountCurrency,
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
            debtCategoryTotalBalance: debtCategoryTotalBalance
        )
    }

    // MARK: - Private

    private static func transactionsForAccount(
        _ account: Account,
        allTransactions: [Transaction],
        allAccounts: [Account]
    ) -> [Transaction] {
        var transactions = allTransactions.filter { $0.accountId == account.id }
        if !allTransactions.isEmpty {
            let incoming = allTransactions.filter { transaction in
                (transaction.type == .transfer || transaction.type == .repayment)
                    && transaction.targetAccountId == account.id
                    && transaction.accountId != account.id
            }
            transactions.append(contentsOf: incoming)
        }
        return transactions
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

    private static func loadAllLiabilities(
        accounts: [Account],
        dataService: DataServiceProtocol
    ) async -> [Liability] {
        var all: [Liability] = []
        for account in accounts {
            if let batch = try? await dataService.fetchLiabilities(accountId: account.id) {
                all.append(contentsOf: batch)
            }
        }
        return all
    }
}
