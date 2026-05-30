//
//  LocalDailyTrendBackfillService.swift
//  Snapvest
//
//  每天第一次開 App 時，將昨天與中間缺口補成日終走勢點。
//

import Foundation

enum LocalDailyTrendBackfillService {
    @discardableResult
    static func runIfNeeded(
        userId: String,
        dataService: DataServiceProtocol,
        now: Date = Date()
    ) async -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return false
        }

        let todayKey = LocalDailyTrendSnapshot.dateKey(for: today)
        guard dataService.fetchLastDailyTrendBackfillRunDateKey(userId: userId) != todayKey else {
            debugLog("skip: already ran for \(todayKey)")
            return false
        }

        let existingSnapshots = (try? await dataService.fetchLocalDailyTrendSnapshots(
            userId: userId,
            startDate: nil,
            endDate: today
        )) ?? []
        let existingDaysBeforeToday = existingSnapshots
            .map(\.date)
            .filter { $0 < today }
            .sorted()

        // 第一天使用時通常只有今天點，沒有合理的前一日帳本狀態可補。
        guard let latestExistingDayBeforeToday = existingDaysBeforeToday.last else {
            dataService.updateLastDailyTrendBackfillRunDateKey(userId: userId, dateKey: todayKey)
            debugLog("skip: first day, no prior trend point")
            return false
        }

        let targetDates = datesToBackfill(
            from: latestExistingDayBeforeToday,
            through: yesterday,
            existingDates: Set(existingDaysBeforeToday),
            calendar: calendar
        )
        guard !targetDates.isEmpty else {
            dataService.updateLastDailyTrendBackfillRunDateKey(userId: userId, dateKey: todayKey)
            debugLog("skip: no missing dates through yesterday")
            return false
        }

        let context = await BackfillContext.load(
            userId: userId,
            dataService: dataService,
            historyStartDate: historyLookbackStartDate(from: targetDates.first, calendar: calendar),
            historyEndDate: targetDates.last
        )
        var writtenCount = 0
        for date in targetDates {
            guard let snapshot = await buildSnapshot(
                userId: userId,
                date: date,
                context: context
            ) else {
                continue
            }
            try? await dataService.upsertLocalDailyTrendSnapshot(snapshot)
            writtenCount += 1
        }

        dataService.updateLastDailyTrendBackfillRunDateKey(userId: userId, dateKey: todayKey)
        debugLog("completed: targets=\(targetDates.count), wrote=\(writtenCount)")
        return writtenCount > 0
    }

    private static func datesToBackfill(
        from latestExistingDay: Date,
        through yesterday: Date,
        existingDates: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        guard latestExistingDay <= yesterday else { return [] }

        var result: [Date] = []
        var cursor = latestExistingDay
        while cursor <= yesterday {
            if cursor == yesterday || !existingDates.contains(cursor) {
                result.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func historyLookbackStartDate(from firstTargetDate: Date?, calendar: Calendar) -> Date? {
        guard let firstTargetDate else { return nil }
        return calendar.date(byAdding: .day, value: -14, to: firstTargetDate) ?? firstTargetDate
    }

    private static func buildSnapshot(
        userId: String,
        date: Date,
        context: BackfillContext
    ) async -> LocalDailyTrendSnapshot? {
        guard let homeSnapshot = context.homeSnapshot else { return nil }

        var historicalInvestmentsTWD: Decimal = 0
        var historicalUnrealizedTWD: Decimal = 0
        var hasAtLeastOneHistoricalPrice = false
        var pricedHoldingCount = 0
        for holding in context.holdings {
            guard let twdPerCurrency = twdRate(for: holding.currency, context: context) else {
                return nil
            }
            guard let priceResolution = price(for: holding, on: date, context: context) else {
                continue
            }
            hasAtLeastOneHistoricalPrice = hasAtLeastOneHistoricalPrice || priceResolution.isHistorical
            pricedHoldingCount += 1
            let price = priceResolution.price
            let marketValue = price * holding.quantity
            let cost = holding.averageCost * holding.quantity
            historicalInvestmentsTWD += marketValue * twdPerCurrency
            historicalUnrealizedTWD += (marketValue - cost) * twdPerCurrency
        }
        guard pricedHoldingCount > 0, hasAtLeastOneHistoricalPrice else { return nil }

        let stableAssetsTWD = homeSnapshot.totalAssets - context.currentHoldingsMarketValueTWD
        let totalAssets = stableAssetsTWD + historicalInvestmentsTWD
        let netWorth = totalAssets - homeSnapshot.totalLiabilities
        let stableUnrealizedTWD = (homeSnapshot.totalInvestments - homeSnapshot.totalInvestmentsCost) - context.currentHoldingsUnrealizedTWD

        return LocalDailyTrendSnapshot(
            userId: userId,
            date: date,
            totalAssets: totalAssets,
            netWorth: netWorth,
            unrealizedGainLoss: stableUnrealizedTWD + historicalUnrealizedTWD,
            sourceHomeSnapshotUpdatedAt: homeSnapshot.lastUpdated
        )
    }

    private static func price(
        for holding: HoldingSnapshotItem,
        on date: Date,
        context: BackfillContext
    ) -> HistoricalPriceResolution? {
        let dayKey = LocalDailyTrendSnapshot.dateKey(for: date)
        let batchKey = SupabasePriceService.batchKey(assetType: holding.assetType, symbol: holding.symbol)
        if let price = context.historicalPricesByKeyAndDate[batchKey]?[dayKey] {
            return HistoricalPriceResolution(price: price, isHistorical: true)
        }

        let normalized = SupabasePriceService.normalizeSymbol(assetType: holding.assetType, symbol: holding.symbol)
        let key = "\(holding.assetType.rawValue)_\(normalized)"
        guard let snapshot = context.priceSnapshotsByKey[key] else { return nil }
        let calendar = Calendar.current
        if let currentCloseDate = snapshot.currentCloseDate,
           calendar.isDate(currentCloseDate, inSameDayAs: date) {
            return snapshot.currentPrice.map {
                HistoricalPriceResolution(price: $0, isHistorical: true)
            }
        }
        if let previousCloseDate = snapshot.previousCloseDate,
           calendar.isDate(previousCloseDate, inSameDayAs: date) {
            return snapshot.previousPrice.map {
                HistoricalPriceResolution(price: $0, isHistorical: true)
            }
        }
        return snapshot.displayPrice.map {
            HistoricalPriceResolution(price: $0, isHistorical: false)
        }
    }

    private static func twdRate(
        for currency: Currency,
        context: BackfillContext
    ) -> Decimal? {
        guard currency != .TWD else { return 1 }
        return context.twdRateByCurrency[currency]
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[LocalDailyTrendBackfill] \(message)")
        #endif
    }
}

private struct HistoricalPriceResolution {
    let price: Decimal
    let isHistorical: Bool
}

private struct BackfillContext {
    let homeSnapshot: HomeDashboardSnapshot?
    let holdings: [HoldingSnapshotItem]
    let priceSnapshotsByKey: [String: AssetPriceSnapshot]
    let twdRateByCurrency: [Currency: Decimal]
    let historicalPricesByKeyAndDate: [String: [String: Decimal]]
    let currentHoldingsMarketValueTWD: Decimal
    let currentHoldingsUnrealizedTWD: Decimal

    static func load(
        userId: String,
        dataService: DataServiceProtocol,
        historyStartDate: Date?,
        historyEndDate: Date?
    ) async -> BackfillContext {
        let homeSnapshot = try? await dataService.fetchHomeDashboardSnapshot(userId: userId)
        let accounts = (try? await dataService.fetchAccounts(userId: userId)) ?? []
        var holdings: [HoldingSnapshotItem] = []

        for account in accounts where !account.accountType.isLiabilityAccount && !account.isArchived {
            guard let snapshot = try? await dataService.fetchAccountSnapshot(accountId: account.id),
                  let snapshotHoldings = snapshot.holdings else {
                continue
            }
            holdings.append(contentsOf: snapshotHoldings)
        }

        let symbols = holdings.map {
            SymbolInfo(assetType: $0.assetType, symbol: $0.symbol)
        }
        let batch = try? await SupabasePriceService.fetchBatchPrices(
            symbols: symbols,
            historyStartDate: historyStartDate,
            historyEndDate: historyEndDate,
            includeCurrent: true
        )
        let localPriceSnapshots = (try? await dataService.fetchAssetPriceSnapshots(symbols: symbols)) ?? []
        var priceSnapshotsById = Dictionary(grouping: localPriceSnapshots, by: \.id).compactMapValues(\.first)
        for snapshot in batch?.currentSnapshots ?? [] {
            priceSnapshotsById[snapshot.id] = snapshot
        }
        let priceSnapshots = Array(priceSnapshotsById.values)
        let priceSnapshotsByKey = Dictionary(grouping: priceSnapshots, by: \.id).compactMapValues(\.first)

        var twdRateByCurrency = batch?.twdRateByCurrency ?? [.TWD: 1]
        if twdRateByCurrency[.USD] == nil, let cachedUsdToTwd = ExchangeRateSessionCache.usdToTwd {
            twdRateByCurrency[.USD] = cachedUsdToTwd
        }

        var currentHoldingsMarketValueTWD: Decimal = 0
        var currentHoldingsUnrealizedTWD: Decimal = 0
        for holding in holdings {
            let normalized = SupabasePriceService.normalizeSymbol(assetType: holding.assetType, symbol: holding.symbol)
            let key = "\(holding.assetType.rawValue)_\(normalized)"
            guard let price = priceSnapshotsByKey[key]?.displayPrice,
                  let twdRate = twdRateByCurrency[holding.currency] else {
                continue
            }
            let marketValue = price * holding.quantity
            let cost = holding.averageCost * holding.quantity
            currentHoldingsMarketValueTWD += marketValue * twdRate
            currentHoldingsUnrealizedTWD += (marketValue - cost) * twdRate
        }

        return BackfillContext(
            homeSnapshot: homeSnapshot,
            holdings: holdings,
            priceSnapshotsByKey: priceSnapshotsByKey,
            twdRateByCurrency: twdRateByCurrency,
            historicalPricesByKeyAndDate: forwardFilledHistoricalPrices(
                batch: batch,
                symbols: symbols
            ),
            currentHoldingsMarketValueTWD: currentHoldingsMarketValueTWD,
            currentHoldingsUnrealizedTWD: currentHoldingsUnrealizedTWD
        )
    }

    private static func forwardFilledHistoricalPrices(
        batch: SupabasePriceBatch?,
        symbols: [SymbolInfo]
    ) -> [String: [String: Decimal]] {
        guard let batch, !batch.dateKeys.isEmpty else { return [:] }
        var result: [String: [String: Decimal]] = [:]

        for symbol in symbols {
            let key = SupabasePriceService.batchKey(assetType: symbol.assetType, symbol: symbol.symbol)
            let exactPrices = batch.historicalPricesByKeyAndDate[key] ?? [:]
            var lastKnownPrice: Decimal?
            var filledByDate: [String: Decimal] = [:]

            for dateKey in batch.dateKeys {
                if let exact = exactPrices[dateKey] {
                    lastKnownPrice = exact
                    filledByDate[dateKey] = exact
                } else if let lastKnownPrice {
                    filledByDate[dateKey] = lastKnownPrice
                }
            }

            if !filledByDate.isEmpty {
                result[key] = filledByDate
            }
        }

        return result
    }
}
