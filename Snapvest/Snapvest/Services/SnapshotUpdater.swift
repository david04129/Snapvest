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
        let usdToTwdRate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
        let homeSnapshot = buildHomeDashboardSnapshot(
            userId: userId,
            accounts: accounts,
            transactions: transactions,
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            liabilities: liabilities,
            usdToTwdRate: usdToTwdRate
        )
        try await dataService.saveHomeDashboardSnapshot(homeSnapshot)
        
        return SnapshotBundle(
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            aggregatedHoldings: aggregated,
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
            
            let snapshot = AccountSnapshot(
                accountId: account.id,
                cashBalance: cashBalance,
                holdings: holdingItems.isEmpty ? nil : holdingItems,
                lastUpdated: Date(),
                lastTransactionDate: lastTransactionDate,
                version: 1
            )
            
            snapshots.append(snapshot)
        }
        
        return snapshots
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
        var snapshots: [AssetPriceSnapshot] = []
        if SupabaseConfig.isConfigured, !symbols.isEmpty {
            snapshots = (try? await SupabasePriceService.fetchPrices(symbols: symbols)) ?? []
        } else if !symbols.isEmpty {
            snapshots = try await dataService.fetchAssetPriceSnapshots(symbols: symbols)
        }
        
        var snapshotByKey: [String: AssetPriceSnapshot] = [:]
        for snapshot in snapshots {
            snapshotByKey["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }
        
        for symbolInfo in symbols {
            let key = "\(symbolInfo.assetType.rawValue)_\(symbolInfo.symbol)"
            if snapshotByKey[key] != nil { continue }
            
            let currentPrice: Decimal?
            if SupabaseConfig.isConfigured {
                currentPrice = await SupabasePriceService.fetchDisplayPrice(
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
            } else {
                currentPrice = try await priceService.fetchCurrentPrice(
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
            }
            
            guard let currentPrice else { continue }
            
            let holdingInfo = holdingsBySymbol[key]
            let rawSnapshot = AssetPriceSnapshot(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol,
                name: holdingInfo?.name,
                currency: holdingInfo?.currency ?? (symbolInfo.assetType == .stockTW ? .TWD : .USD),
                currentPrice: currentPrice,
                previousPrice: nil,
                currentPriceDate: Date(),
                previousPriceDate: nil,
                lastUpdated: Date(),
                lastSuccessfulUpdate: Date()
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

    private static func buildHomeDashboardSnapshot(
        userId: String,
        accounts: [Account],
        transactions: [Transaction],
        accountSnapshots: [AccountSnapshot],
        assetPriceSnapshots: [AssetPriceSnapshot],
        liabilities: [Liability],
        usdToTwdRate: Decimal
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
                let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
                let price = priceMap[key]?.displayPrice
                let marketValue = (price ?? 0) * holding.quantity
                let cost = holding.averageCost * holding.quantity
                totalInvestmentsTWD += amountInTWD(marketValue, currency: holding.currency, usdToTwdRate: usdToTwdRate)
                totalUnrealizedGainLossTWD += amountInTWD(
                    marketValue - cost,
                    currency: holding.currency,
                    usdToTwdRate: usdToTwdRate
                )
            }
        }
        
        var totalCashTWD: Decimal = 0
        for (currency, amount) in cashByCurrency {
            if currency == .USD {
                totalCashTWD += amount * usdToTwdRate
            } else {
                totalCashTWD += amount
            }
        }
        
        var totalLiabilitiesTWD: Decimal = 0
        totalLiabilitiesTWD = TotalDebtCalculator.totalLiabilitiesTWD(
            accounts: accounts,
            liabilities: liabilities,
            transactions: transactions,
            usdToTwdRate: usdToTwdRate
        )
        
        let realizedByCurrency = HoldingCalculator.calculateRealizedGainLossByCurrency(from: transactions)
        let realizedTWD = realizedByCurrency[.TWD] ?? 0
        let realizedUSD = realizedByCurrency[.USD] ?? 0
        
        let totalAssets = totalInvestmentsTWD + totalCashTWD
        let netWorth = totalAssets - totalLiabilitiesTWD
        let totalInvestmentsCost = totalInvestmentsTWD - totalUnrealizedGainLossTWD
        
        return HomeDashboardSnapshot(
            userId: userId,
            netWorth: netWorth,
            totalLiabilities: totalLiabilitiesTWD,
            totalAssets: totalAssets,
            totalInvestmentsCost: totalInvestmentsCost,
            totalCash: totalCashTWD,
            twdCash: cashByCurrency[.TWD] ?? 0,
            usdCash: cashByCurrency[.USD] ?? 0,
            realizedGainLossTWD: realizedTWD,
            realizedGainLossUSD: realizedUSD,
            lastUpdated: Date()
        )
    }

    /// 持股市值／損益依 `holding.currency` 換算為 TWD（與帳戶 Tab、後端 daily_portfolio_snapshot 一致）
    private static func amountInTWD(_ amount: Decimal, currency: Currency, usdToTwdRate: Decimal) -> Decimal {
        switch currency {
        case .TWD:
            return amount
        case .USD:
            return amount * usdToTwdRate
        default:
            return amount
        }
    }
}
