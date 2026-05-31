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
        if accounts.contains(where: { $0.accountType == .otherDebt }),
           let fetched = try? await dataService.fetchAllTransactions(userId: userId) {
            allTransactions = fetched
        }

        var snapshotsByAccountId: [String: AccountSnapshot] = [:]
        var symbolInfos: [SymbolInfo] = []
        var currencies = Set(accounts.map(\.currency))
        currencies.formUnion(liabilities.map(\.currency))

        for account in accounts where !account.accountType.isLiabilityAccount {
            guard let snapshot = try? await dataService.fetchAccountSnapshot(accountId: account.id) else {
                continue
            }
            snapshotsByAccountId[account.id] = snapshot
            for holding in snapshot.holdings ?? [] {
                currencies.insert(holding.currency)
                let symbolInfo = SymbolInfo(assetType: holding.assetType, symbol: holding.symbol)
                if !symbolInfos.contains(symbolInfo) {
                    symbolInfos.append(symbolInfo)
                }
            }
        }

        let priceSnapshots = (try? await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)) ?? []
        let priceMap = Dictionary(
            uniqueKeysWithValues: priceSnapshots.map { ("\($0.assetType.rawValue)_\($0.symbol)", $0) }
        )
        let rateTable = await ExchangeRateSessionCache.loadRateTable(
            currencies: currencies,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        )

        var byAccountId: [String: AccountBalanceDisplay] = [:]
        var categoryTotalsTWD: [AccountType: Decimal] = [:]
        var debtCategoryTotalBalance: Decimal = 0
        var otherDebtCategoryTotalBalance: Decimal = 0

        for account in accounts {
            if account.accountType == .debt {
                if account.isArchived { continue }
                let remaining = remainingBalance(forDebtAccount: account, in: liabilities)
                let twdRemaining = accountTotalInTWD(
                    accountTotal: remaining,
                    currency: account.currency,
                    rateTable: rateTable
                )
                debtCategoryTotalBalance += twdRemaining
                byAccountId[account.id] = AccountBalanceDisplay(
                    cashBalance: 0,
                    holdingsValue: 0,
                    totalAssets: 0,
                    twdEquivalent: account.currency == .TWD ? nil : twdRemaining,
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
                    rateTable: rateTable
                )
                otherDebtCategoryTotalBalance += twdRemaining
                byAccountId[account.id] = AccountBalanceDisplay(
                    cashBalance: 0,
                    holdingsValue: 0,
                    totalAssets: 0,
                    twdEquivalent: account.currency == .TWD ? nil : twdRemaining,
                    remainingBalance: remaining
                )
                continue
            }

            let snapshot = snapshotsByAccountId[account.id]
            let cashBalance = snapshot?.cashBalance ?? 0
            let holdingsValue = holdingsValueInAccountCurrency(
                snapshot: snapshot,
                account: account,
                priceMap: priceMap,
                rateTable: rateTable
            )
            let totalAssets = cashBalance + holdingsValue
            let twdEquivalent = account.currency == .TWD ? nil : accountTotalInTWD(
                accountTotal: totalAssets,
                currency: account.currency,
                rateTable: rateTable
            )

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
                rateTable: rateTable
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

    @MainActor
    static func buildAccount(
        account: Account,
        accounts: [Account],
        userId: String,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal,
        liabilities: [Liability]
    ) async -> AccountBalanceDisplay {
        if account.accountType == .debt {
            let remaining = remainingBalance(forDebtAccount: account, in: liabilities)
            let twdRemaining = await accountTotalInTWD(
                accountTotal: remaining,
                currency: account.currency,
                dataService: dataService,
                usdToTwdRate: usdToTwdRate
            )
            return AccountBalanceDisplay(
                cashBalance: 0,
                holdingsValue: 0,
                totalAssets: 0,
                twdEquivalent: account.currency == .TWD ? nil : twdRemaining,
                remainingBalance: remaining
            )
        }

        if account.accountType == .otherDebt {
            let accountTransactions = (try? await dataService.fetchTransactions(accountId: account.id)) ?? []
            let remaining = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: accountTransactions,
                accounts: accounts
            )
            let twdRemaining = await accountTotalInTWD(
                accountTotal: remaining,
                currency: account.currency,
                dataService: dataService,
                usdToTwdRate: usdToTwdRate
            )
            return AccountBalanceDisplay(
                cashBalance: 0,
                holdingsValue: 0,
                totalAssets: 0,
                twdEquivalent: account.currency == .TWD ? nil : twdRemaining,
                remainingBalance: remaining
            )
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
        let twdEquivalent = account.currency == .TWD ? nil : await accountTotalInTWD(
            accountTotal: totalAssets,
            currency: account.currency,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        )

        return AccountBalanceDisplay(
            cashBalance: cashBalance,
            holdingsValue: holdingsValue,
            totalAssets: totalAssets,
            twdEquivalent: twdEquivalent,
            remainingBalance: 0
        )
    }

    // MARK: - Private

    private static func holdingsValueInAccountCurrency(
        snapshot: AccountSnapshot?,
        account: Account,
        priceMap: [String: AssetPriceSnapshot],
        rateTable: CurrencyRateTable
    ) -> Decimal {
        guard let holdings = snapshot?.holdings, !holdings.isEmpty else { return 0 }

        var total: Decimal = 0
        for holding in holdings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let price = priceMap[key]?.displayPrice else { continue }

            var marketValue = holding.quantity * price
            if holding.currency != account.currency,
               let rate = rateTable.rate(from: holding.currency, to: account.currency) {
                marketValue *= rate
            }
            total += marketValue
        }
        return total
    }

    private static func accountTotalInTWD(
        accountTotal: Decimal,
        currency: Currency,
        rateTable: CurrencyRateTable
    ) -> Decimal {
        guard currency != .TWD else { return accountTotal }
        guard let rate = rateTable.rate(from: currency, to: .TWD) else { return accountTotal }
        return accountTotal * rate
    }

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
                if let rate = await exchangeRate(
                    from: holding.currency,
                    to: account.currency,
                    dataService: dataService,
                    usdToTwdRate: usdToTwdRate
                ) {
                    marketValue *= rate
                }
            }
            total += marketValue
        }
        return total
    }

    private static func accountTotalInTWD(
        accountTotal: Decimal,
        currency: Currency,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async -> Decimal {
        guard currency != .TWD else { return accountTotal }
        guard let rate = await exchangeRate(
            from: currency,
            to: .TWD,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        ) else { return accountTotal }
        return accountTotal * rate
    }

    private static func exchangeRate(
        from source: Currency,
        to target: Currency,
        dataService: DataServiceProtocol,
        usdToTwdRate: Decimal
    ) async -> Decimal? {
        guard source != target else { return 1 }
        if source == .USD, target == .TWD, usdToTwdRate > 0 { return usdToTwdRate }
        if source == .TWD, target == .USD, usdToTwdRate > 0 { return 1 / usdToTwdRate }
        if let direct = try? await dataService.fetchExchangeRate(from: source, to: target, date: nil)?.rate,
           direct > 0 {
            return direct
        }
        let sourceToTWD: Decimal?
        if source == .TWD {
            sourceToTWD = 1
        } else if source == .USD, usdToTwdRate > 0 {
            sourceToTWD = usdToTwdRate
        } else {
            sourceToTWD = try? await dataService.fetchExchangeRate(from: source, to: .TWD, date: nil)?.rate
        }

        let targetToTWD: Decimal?
        if target == .TWD {
            targetToTWD = 1
        } else if target == .USD, usdToTwdRate > 0 {
            targetToTWD = usdToTwdRate
        } else {
            targetToTWD = try? await dataService.fetchExchangeRate(from: target, to: .TWD, date: nil)?.rate
        }

        guard let sourceToTWD,
              let targetToTWD,
              sourceToTWD > 0,
              targetToTWD > 0 else {
            return nil
        }
        return sourceToTWD / targetToTWD
    }

    private static func remainingBalance(forDebtAccount account: Account, in liabilities: [Liability]) -> Decimal {
        liabilities.first(where: { $0.name == account.name })?.remainingBalance ?? 0
    }
}
