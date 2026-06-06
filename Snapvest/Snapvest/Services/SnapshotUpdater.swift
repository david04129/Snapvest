//
//  SnapshotUpdater.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct SnapshotBundle {
    let accountSnapshots: [AccountSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let aggregatedHoldings: [AggregatedHoldingSnapshot]
    let userHoldingsSnapshot: UserHoldingsSnapshot
}

enum SnapshotUpdater {
    static func rebuildSnapshots(
        userId: String,
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol
    ) async throws -> SnapshotBundle {
        let accounts = try await dataService.fetchAccounts(userId: userId)
        let transactions = try await dataService.fetchAllTransactions(userId: userId)
        
        let accountSnapshots = calculateAccountSnapshotsFromTransactions(
            accounts: accounts,
            transactions: transactions
        )
        
        for snapshot in accountSnapshots {
            try await dataService.saveAccountSnapshot(snapshot)
        }
        
        let symbolInfos = buildSymbolInfos(from: accountSnapshots)
        let userHoldingsSnapshot = UserHoldingsSnapshot(
            userId: userId,
            symbols: symbolInfos,
            lastUpdated: Date()
        )
        try await dataService.saveUserHoldingsSnapshot(userHoldingsSnapshot)
        
        let assetPriceSnapshots = try await loadOrFetchAssetPriceSnapshots(
            symbols: symbolInfos,
            dataService: dataService,
            priceService: priceService,
            holdingsBySymbol: holdingsBySymbol(from: accountSnapshots)
        )
        
        for snapshot in assetPriceSnapshots {
            try await dataService.saveAssetPriceSnapshot(snapshot)
        }
        
        let aggregated = HoldingCalculator.calculateAggregatedHoldings(
            userId: userId,
            accountSnapshots: accountSnapshots,
            accounts: accounts,
            transactions: transactions,
            assetPriceSnapshots: assetPriceSnapshots
        )
        
        let existingAggregated = try await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
        let newAggregatedKeys = Set(aggregated.map { "\($0.assetType.rawValue)_\($0.symbol)" })
        for snapshot in existingAggregated {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            if !newAggregatedKeys.contains(key) {
                try await dataService.deleteAggregatedHoldingSnapshot(
                    userId: userId,
                    assetType: snapshot.assetType,
                    symbol: snapshot.symbol
                )
            }
        }
        
        for snapshot in aggregated {
            try await dataService.saveAggregatedHoldingSnapshot(snapshot)
        }

        let liabilities = try await loadLiabilities(userId: userId, dataService: dataService, accounts: accounts)
        let manualAssets = try await dataService.fetchManualAssets(userId: userId)
        let usdToTwdRate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
        let twdRateTable = await loadTwdRateTable(
            accounts: accounts,
            accountSnapshots: accountSnapshots,
            liabilities: liabilities,
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            dataService: dataService
        )
        let homeSnapshot = await resolveHomeDashboardSnapshot(
            userId: userId,
            accounts: accounts,
            transactions: transactions,
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            symbolInfos: symbolInfos,
            liabilities: liabilities,
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable,
            dataService: dataService
        )
        try await dataService.saveHomeDashboardSnapshot(homeSnapshot)
        
        return SnapshotBundle(
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            aggregatedHoldings: aggregated,
            userHoldingsSnapshot: userHoldingsSnapshot
        )
    }

    static func updateSnapshotsIncrementally(
        userId: String,
        affectedAccountIds: Set<String>,
        affectedSymbols: [SymbolInfo],
        realizedGainLossDeltaByCurrency: [Currency: Decimal] = [:],
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol
    ) async throws -> SnapshotBundle {
        let accounts = try await dataService.fetchAccounts(userId: userId)
        guard let existingHomeSnapshot = try await dataService.fetchHomeDashboardSnapshot(userId: userId) else {
            return try await rebuildSnapshots(
                userId: userId,
                dataService: dataService,
                priceService: priceService
            )
        }

        var snapshotsByAccountId: [String: AccountSnapshot] = [:]
        for account in accounts {
            if affectedAccountIds.contains(account.id) {
                let accountTransactions = try await dataService.fetchTransactions(accountId: account.id)
                let snapshot = calculateAccountSnapshot(
                    account: account,
                    accountTransactions: accountTransactions,
                    accounts: accounts
                )
                try await dataService.saveAccountSnapshot(snapshot)
                snapshotsByAccountId[account.id] = snapshot
            } else if let snapshot = try await dataService.fetchAccountSnapshot(accountId: account.id) {
                snapshotsByAccountId[account.id] = snapshot
            } else {
                // Missing persisted snapshots means the cache is incomplete; fall back to the safe path.
                return try await rebuildSnapshots(
                    userId: userId,
                    dataService: dataService,
                    priceService: priceService
                )
            }
        }

        let accountSnapshots = accounts.compactMap { snapshotsByAccountId[$0.id] }
        let symbolInfos = buildSymbolInfos(from: accountSnapshots)
        let userHoldingsSnapshot = UserHoldingsSnapshot(
            userId: userId,
            symbols: symbolInfos,
            lastUpdated: Date()
        )
        try await dataService.saveUserHoldingsSnapshot(userHoldingsSnapshot)

        let holdingsMap = holdingsBySymbol(from: accountSnapshots)
        let updatedPriceSnapshots = try await loadOrFetchAssetPriceSnapshots(
            symbols: affectedSymbols,
            dataService: dataService,
            priceService: priceService,
            holdingsBySymbol: holdingsMap
        )
        for snapshot in updatedPriceSnapshots {
            try await dataService.saveAssetPriceSnapshot(snapshot)
        }

        let assetPriceSnapshots = try await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            priceMap["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }

        var aggregatedHoldings: [AggregatedHoldingSnapshot] = []
        for symbolInfo in affectedSymbols {
            let accountIdsWithSymbol = Set(
                accountSnapshots.compactMap { snapshot -> String? in
                    guard snapshot.holdings?.contains(where: {
                        $0.assetType == symbolInfo.assetType && $0.symbol == symbolInfo.symbol
                    }) == true else {
                        return nil
                    }
                    return snapshot.accountId
                }
            )
            var transactions: [Transaction] = []
            for accountId in accountIdsWithSymbol {
                let accountTransactions = try await dataService.fetchTransactions(accountId: accountId)
                transactions.append(contentsOf: accountTransactions.filter {
                    $0.assetType == symbolInfo.assetType && $0.symbol == symbolInfo.symbol
                })
            }

            if let aggregated = HoldingCalculator.calculateAggregatedHolding(
                userId: userId,
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol,
                accountSnapshots: accountSnapshots,
                accounts: accounts,
                transactions: transactions,
                assetPriceSnapshot: priceMap["\(symbolInfo.assetType.rawValue)_\(symbolInfo.symbol)"]
            ) {
                try await dataService.saveAggregatedHoldingSnapshot(aggregated)
                aggregatedHoldings.append(aggregated)
            } else {
                try await dataService.deleteAggregatedHoldingSnapshot(
                    userId: userId,
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
            }
        }

        let liabilities = try await loadLiabilities(userId: userId, dataService: dataService, accounts: accounts)
        let manualAssets = try await dataService.fetchManualAssets(userId: userId)
        let usdToTwdRate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
        let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
        let realizedByCurrency = HoldingCalculator.calculateRealizedGainLossByCurrency(from: allTransactions)
        let twdRateTable = await loadTwdRateTable(
            accounts: accounts,
            accountSnapshots: accountSnapshots,
            liabilities: liabilities,
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            dataService: dataService
        )
        let homeSnapshot = buildHomeDashboardSnapshotFromExistingTotals(
            userId: userId,
            accounts: accounts,
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            existingHomeSnapshot: existingHomeSnapshot,
            manualAssets: manualAssets,
            realizedGainLossByCurrency: realizedByCurrency,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable
        )
        try await dataService.saveHomeDashboardSnapshot(homeSnapshot)

        return SnapshotBundle(
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            aggregatedHoldings: aggregatedHoldings,
            userHoldingsSnapshot: userHoldingsSnapshot
        )
    }
    
    private static func calculateAccountSnapshotsFromTransactions(
        accounts: [Account],
        transactions: [Transaction]
    ) -> [AccountSnapshot] {
        var snapshots: [AccountSnapshot] = []
        
        for account in accounts {
            let accountTransactions = transactions.filter { transaction in
                transaction.accountId == account.id
            }
            
            snapshots.append(
                calculateAccountSnapshot(
                    account: account,
                    accountTransactions: accountTransactions,
                    accounts: accounts
                )
            )
        }
        
        return snapshots
    }

    private static func calculateAccountSnapshot(
        account: Account,
        accountTransactions: [Transaction],
        accounts: [Account]
    ) -> AccountSnapshot {
        let cashBalance = CashCalculator.calculateCash(
            accountId: account.id,
            transactions: accountTransactions,
            accounts: accounts
        )

        let holdings = HoldingCalculator.calculateHoldings(from: accountTransactions)
        let holdingItems = holdings.map { holding -> HoldingSnapshotItem in
            HoldingSnapshotItem(
                id: holding.id,
                assetType: holding.assetType,
                symbol: holding.symbol,
                name: holding.name,
                quantity: holding.quantity,
                averageCost: holding.averageCost,
                currency: holding.currency,
                lastUpdated: holding.lastUpdated
            )
        }

        let lastTransactionDate = accountTransactions
            .max(by: { $0.transactionDate < $1.transactionDate })?
            .transactionDate

        return AccountSnapshot(
            accountId: account.id,
            cashBalance: cashBalance,
            holdings: holdingItems.isEmpty ? nil : holdingItems,
            lastUpdated: Date(),
            lastTransactionDate: lastTransactionDate,
            version: 1
        )
    }
    
    private static func buildSymbolInfos(from accountSnapshots: [AccountSnapshot]) -> [SymbolInfo] {
        var symbolSet: Set<String> = []
        var symbolInfos: [SymbolInfo] = []
        
        for snapshot in accountSnapshots {
            guard let holdings = snapshot.holdings else { continue }
            for holding in holdings {
                let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
                if symbolSet.contains(key) { continue }
                symbolSet.insert(key)
                symbolInfos.append(SymbolInfo(assetType: holding.assetType, symbol: holding.symbol))
            }
        }
        
        return symbolInfos
    }
    
    private static func holdingsBySymbol(from accountSnapshots: [AccountSnapshot]) -> [String: HoldingSnapshotItem] {
        var map: [String: HoldingSnapshotItem] = [:]
        for snapshot in accountSnapshots {
            guard let holdings = snapshot.holdings else { continue }
            for holding in holdings {
                let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
                map[key] = holding
            }
        }
        return map
    }
    
    private static func loadOrFetchAssetPriceSnapshots(
        symbols: [SymbolInfo],
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol,
        holdingsBySymbol: [String: HoldingSnapshotItem]
    ) async throws -> [AssetPriceSnapshot] {
        var snapshotByKey: [String: AssetPriceSnapshot] = [:]
        for symbolInfo in symbols {
            let key = "\(symbolInfo.assetType.rawValue)_\(symbolInfo.symbol)"
            if let existing = try? await dataService.fetchAssetPriceSnapshot(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol
            ) {
                snapshotByKey[key] = existing
            }
        }

        var snapshots: [AssetPriceSnapshot] = []
        if SupabaseConfig.isConfigured, !symbols.isEmpty {
            snapshots = (try? await SupabasePriceService.fetchPrices(symbols: symbols)) ?? []
        } else if !symbols.isEmpty {
            snapshots = (try? await dataService.fetchAssetPriceSnapshots(symbols: symbols)) ?? []
        }

        for snapshot in snapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            let existing = snapshotByKey[key]
            snapshotByKey[key] = PriceSnapshotMerger.mergePreservingDailyReference(
                incoming: snapshot,
                existing: existing
            )
        }

        if SupabaseConfig.isConfigured {
            let missingAfterBatch = symbols.filter { info in
                let key = "\(info.assetType.rawValue)_\(info.symbol)"
                guard let snapshot = snapshotByKey[key],
                      let price = snapshot.displayPrice,
                      price > 0 else {
                    return true
                }
                return false
            }
            if !missingAfterBatch.isEmpty {
                let filled = await SupabasePriceService.resolveMissingPrices(symbols: missingAfterBatch)
                for snapshot in filled {
                    let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
                    let existing = snapshotByKey[key]
                    var enriched = snapshot
                    if enriched.name == nil, let holdingInfo = holdingsBySymbol[key] {
                        enriched.name = SymbolListService.displayName(
                            assetType: snapshot.assetType,
                            symbol: snapshot.symbol,
                            storedName: holdingInfo.name
                        )
                    }
                    snapshotByKey[key] = PriceSnapshotMerger.mergePreservingDailyReference(
                        incoming: enriched,
                        existing: existing
                    )
                }
            }
        }
        
        for symbolInfo in symbols {
            let key = "\(symbolInfo.assetType.rawValue)_\(symbolInfo.symbol)"
            if let snapshot = snapshotByKey[key],
               let price = snapshot.displayPrice,
               price > 0 {
                continue
            }
            
            let currentPrice: Decimal?
            if SupabaseConfig.isConfigured {
                continue
            } else {
                currentPrice = try await priceService.fetchCurrentPrice(
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
            }
            
            guard let currentPrice else { continue }
            
            let holdingInfo = holdingsBySymbol[key]
            let displayName = SymbolListService.displayName(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol,
                storedName: holdingInfo?.name
            )
            let now = Date()
            let rawSnapshot = AssetPriceSnapshot(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol,
                name: displayName,
                currency: holdingInfo?.currency ?? (symbolInfo.assetType == .stockTW ? .TWD : .USD),
                currentPrice: currentPrice,
                previousPrice: nil,
                currentCloseDate: Calendar.current.startOfDay(for: now),
                currentUpdatedAt: now
            )
            let existing = try? await dataService.fetchAssetPriceSnapshot(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol
            )
            snapshotByKey[key] = PriceSnapshotMerger.merge(incoming: rawSnapshot, existing: existing)
        }
        
        let ordered = symbols.compactMap { info in
            snapshotByKey["\(info.assetType.rawValue)_\(info.symbol)"]
        }
        return await PriceSnapshotMerger.mergeIncoming(ordered, dataService: dataService)
    }

    private static func loadLiabilities(
        userId: String,
        dataService: DataServiceProtocol,
        accounts: [Account]
    ) async throws -> [Liability] {
        var allLiabilities: [Liability] = []
        for account in accounts {
            let liabilities = try await dataService.fetchLiabilities(accountId: account.id)
            allLiabilities.append(contentsOf: liabilities)
        }
        return allLiabilities
    }

    private static func loadTwdRateTable(
        accounts: [Account],
        accountSnapshots: [AccountSnapshot],
        liabilities: [Liability],
        manualAssets: [ManualAsset],
        usdToTwdRate: Decimal,
        dataService: DataServiceProtocol
    ) async -> CurrencyRateTable {
        var currencies = Set(accounts.map(\.currency))
        currencies.formUnion(liabilities.map(\.currency))
        currencies.formUnion(manualAssets.map(\.currency))
        for snapshot in accountSnapshots {
            snapshot.holdings?.forEach { currencies.insert($0.currency) }
        }
        return await ExchangeRateSessionCache.loadRateTable(
            currencies: currencies,
            dataService: dataService,
            usdToTwdRate: usdToTwdRate
        )
    }

    private static func buildHomeDashboardSnapshot(
        userId: String,
        accounts: [Account],
        transactions: [Transaction],
        accountSnapshots: [AccountSnapshot],
        assetPriceSnapshots: [AssetPriceSnapshot],
        liabilities: [Liability],
        manualAssets: [ManualAsset],
        usdToTwdRate: Decimal,
        twdRateTable: CurrencyRateTable
    ) -> HomeDashboardSnapshot {
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            priceMap["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }
        
        var totalInvestmentsTWD: Decimal = 0
        var totalUnrealizedGainLossTWD: Decimal = 0
        var cashByCurrency: [Currency: Decimal] = [:]
        
        for account in accounts where !account.accountType.isLiabilityAccount {
            guard let snapshot = accountSnapshots.first(where: { $0.accountId == account.id }) else { continue }
            cashByCurrency[account.currency, default: 0] += snapshot.cashBalance
            
            guard let holdings = snapshot.holdings else { continue }
            
            for holding in holdings {
                guard let priceSnapshot = priceSnapshot(for: holding, in: priceMap),
                      let price = priceSnapshot.displayPrice,
                      price > 0 else {
                    continue
                }
                let marketValue = price * holding.quantity
                let cost = holding.averageCost * holding.quantity
                totalInvestmentsTWD += amountInTWD(marketValue, currency: holding.currency, usdToTwdRate: usdToTwdRate, twdRateTable: twdRateTable)
                totalUnrealizedGainLossTWD += amountInTWD(
                    marketValue - cost,
                    currency: holding.currency,
                    usdToTwdRate: usdToTwdRate,
                    twdRateTable: twdRateTable
                )
            }
        }
        
        var totalCashTWD: Decimal = 0
        for (currency, amount) in cashByCurrency {
            totalCashTWD += amountInTWD(amount, currency: currency, usdToTwdRate: usdToTwdRate, twdRateTable: twdRateTable)
        }
        
        var totalLiabilitiesTWD: Decimal = 0
        totalLiabilitiesTWD = TotalDebtCalculator.totalLiabilitiesTWD(
            accounts: accounts,
            liabilities: liabilities,
            transactions: transactions,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable
        )
        
        let realizedByCurrency = HoldingCalculator.calculateRealizedGainLossByCurrency(from: transactions)
        let realizedTWD = realizedByCurrency[.TWD] ?? 0
        let realizedUSD = realizedByCurrency[.USD] ?? 0
        
        let manualTotals = manualAssetTotals(
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable
        )
        totalInvestmentsTWD += manualTotals.investmentsTWD
        totalUnrealizedGainLossTWD += manualTotals.investmentGainLossTWD

        let totalAssets = totalInvestmentsTWD + totalCashTWD + manualTotals.nonInvestmentAssetsTWD
        let netWorth = totalAssets - totalLiabilitiesTWD
        let totalInvestmentsCost = totalInvestmentsTWD - totalUnrealizedGainLossTWD
        
        return HomeDashboardSnapshot(
            userId: userId,
            netWorth: netWorth,
            totalLiabilities: totalLiabilitiesTWD,
            totalAssets: totalAssets,
            totalInvestments: totalInvestmentsTWD,
            totalInvestmentsCost: totalInvestmentsCost,
            totalCash: totalCashTWD,
            twdCash: cashByCurrency[.TWD] ?? 0,
            usdCash: cashByCurrency[.USD] ?? 0,
            realizedGainLossTWD: realizedTWD,
            realizedGainLossUSD: realizedUSD,
            lastUpdated: Date()
        )
    }

    private static func buildHomeDashboardSnapshotFromExistingTotals(
        userId: String,
        accounts: [Account],
        accountSnapshots: [AccountSnapshot],
        assetPriceSnapshots: [AssetPriceSnapshot],
        existingHomeSnapshot: HomeDashboardSnapshot,
        manualAssets: [ManualAsset],
        realizedGainLossByCurrency: [Currency: Decimal],
        usdToTwdRate: Decimal,
        twdRateTable: CurrencyRateTable
    ) -> HomeDashboardSnapshot {
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            priceMap["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }

        var totalInvestmentsTWD: Decimal = 0
        var totalUnrealizedGainLossTWD: Decimal = 0
        var cashByCurrency: [Currency: Decimal] = [:]

        for account in accounts where !account.accountType.isLiabilityAccount {
            guard let snapshot = accountSnapshots.first(where: { $0.accountId == account.id }) else { continue }
            cashByCurrency[account.currency, default: 0] += snapshot.cashBalance

            guard let holdings = snapshot.holdings else { continue }
            for holding in holdings {
                guard let priceSnapshot = priceSnapshot(for: holding, in: priceMap),
                      let price = priceSnapshot.displayPrice,
                      price > 0 else {
                    continue
                }
                let marketValue = price * holding.quantity
                let cost = holding.averageCost * holding.quantity
                totalInvestmentsTWD += amountInTWD(
                    marketValue,
                    currency: holding.currency,
                    usdToTwdRate: usdToTwdRate,
                    twdRateTable: twdRateTable
                )
                totalUnrealizedGainLossTWD += amountInTWD(
                    marketValue - cost,
                    currency: holding.currency,
                    usdToTwdRate: usdToTwdRate,
                    twdRateTable: twdRateTable
                )
            }
        }

        var totalCashTWD: Decimal = 0
        for (currency, amount) in cashByCurrency {
            totalCashTWD += amountInTWD(
                amount,
                currency: currency,
                usdToTwdRate: usdToTwdRate,
                twdRateTable: twdRateTable
            )
        }

        let manualTotals = manualAssetTotals(
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable
        )
        totalInvestmentsTWD += manualTotals.investmentsTWD
        totalUnrealizedGainLossTWD += manualTotals.investmentGainLossTWD

        let totalAssets = totalInvestmentsTWD + totalCashTWD + manualTotals.nonInvestmentAssetsTWD
        let netWorth = totalAssets - existingHomeSnapshot.totalLiabilities
        let totalInvestmentsCost = totalInvestmentsTWD - totalUnrealizedGainLossTWD

        return HomeDashboardSnapshot(
            userId: userId,
            netWorth: netWorth,
            totalLiabilities: existingHomeSnapshot.totalLiabilities,
            totalAssets: totalAssets,
            totalInvestments: totalInvestmentsTWD,
            totalInvestmentsCost: totalInvestmentsCost,
            totalCash: totalCashTWD,
            twdCash: cashByCurrency[.TWD] ?? 0,
            usdCash: cashByCurrency[.USD] ?? 0,
            realizedGainLossTWD: realizedGainLossByCurrency[.TWD] ?? 0,
            realizedGainLossUSD: realizedGainLossByCurrency[.USD] ?? 0,
            lastUpdated: Date()
        )
    }

    private static func manualAssetTotals(
        manualAssets: [ManualAsset],
        usdToTwdRate: Decimal,
        twdRateTable: CurrencyRateTable
    ) -> (assetsTWD: Decimal, investmentsTWD: Decimal, nonInvestmentAssetsTWD: Decimal, investmentGainLossTWD: Decimal) {
        var assetsTWD: Decimal = 0
        var investmentsTWD: Decimal = 0
        var investmentGainLossTWD: Decimal = 0

        for asset in manualAssets where asset.isIncludedInTotalAssets {
            let valueTWD = amountInTWD(
                asset.currentValue,
                currency: asset.currency,
                usdToTwdRate: usdToTwdRate,
                twdRateTable: twdRateTable
            )
            assetsTWD += valueTWD

            guard asset.isIncludedInInvestments else { continue }
            investmentsTWD += valueTWD
            if let costBasis = asset.costBasis {
                let costTWD = amountInTWD(
                    costBasis,
                    currency: asset.currency,
                    usdToTwdRate: usdToTwdRate,
                    twdRateTable: twdRateTable
                )
                investmentGainLossTWD += valueTWD - costTWD
            }
        }

        return (
            assetsTWD: assetsTWD,
            investmentsTWD: investmentsTWD,
            nonInvestmentAssetsTWD: assetsTWD - investmentsTWD,
            investmentGainLossTWD: investmentGainLossTWD
        )
    }

    private static func resolveHomeDashboardSnapshot(
        userId: String,
        accounts: [Account],
        transactions: [Transaction],
        accountSnapshots: [AccountSnapshot],
        assetPriceSnapshots: [AssetPriceSnapshot],
        symbolInfos: [SymbolInfo],
        liabilities: [Liability],
        manualAssets: [ManualAsset],
        usdToTwdRate: Decimal,
        twdRateTable: CurrencyRateTable,
        dataService: DataServiceProtocol
    ) async -> HomeDashboardSnapshot {
        let built = buildHomeDashboardSnapshot(
            userId: userId,
            accounts: accounts,
            transactions: transactions,
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            liabilities: liabilities,
            manualAssets: manualAssets,
            usdToTwdRate: usdToTwdRate,
            twdRateTable: twdRateTable
        )
        guard built.totalInvestments <= 0,
              hasPositiveQuantityHoldings(in: accountSnapshots) else {
            return built
        }

        let localPrices = (try? await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)) ?? []
        if !localPrices.isEmpty {
            let retry = buildHomeDashboardSnapshot(
                userId: userId,
                accounts: accounts,
                transactions: transactions,
                accountSnapshots: accountSnapshots,
                assetPriceSnapshots: localPrices,
                liabilities: liabilities,
                manualAssets: manualAssets,
                usdToTwdRate: usdToTwdRate,
                twdRateTable: twdRateTable
            )
            if retry.totalInvestments > 0 {
                return retry
            }
        }

        if let existing = try? await dataService.fetchHomeDashboardSnapshot(userId: userId),
           existing.totalInvestments > 0 {
            return existing
        }
        return built
    }

    private static func hasPositiveQuantityHoldings(in accountSnapshots: [AccountSnapshot]) -> Bool {
        accountSnapshots.contains { snapshot in
            snapshot.holdings?.contains(where: { $0.quantity > 0 }) == true
        }
    }

    private static func priceSnapshot(
        for holding: HoldingSnapshotItem,
        in priceMap: [String: AssetPriceSnapshot]
    ) -> AssetPriceSnapshot? {
        let rawKey = "\(holding.assetType.rawValue)_\(holding.symbol)"
        if let snapshot = priceMap[rawKey] {
            return snapshot
        }
        let normalized = SupabasePriceService.normalizeSymbol(
            assetType: holding.assetType,
            symbol: holding.symbol
        )
        return priceMap["\(holding.assetType.rawValue)_\(normalized)"]
    }

    /// 持股市值／損益依 `holding.currency` 換算為 TWD（與帳戶 Tab、後端 daily_portfolio_snapshot 一致）
    private static func amountInTWD(
        _ amount: Decimal,
        currency: Currency,
        usdToTwdRate: Decimal,
        twdRateTable: CurrencyRateTable
    ) -> Decimal {
        switch currency {
        case .TWD:
            return amount
        case .USD:
            guard usdToTwdRate > 0 else {
                guard let rate = twdRateTable.rate(from: currency, to: .TWD) else { return amount }
                return amount * rate
            }
            return amount * usdToTwdRate
        default:
            guard let rate = twdRateTable.rate(from: currency, to: .TWD) else { return amount }
            return amount * rate
        }
    }
}
