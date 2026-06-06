//
//  DailyPreviousCloseSync.swift
//  Snapvest
//
//  從 asset_price_history 對齊各股本機昨收（每日 backfill 與新加入 portfolio 時）。
//

import Foundation

enum DailyPreviousCloseSync {
    @MainActor
    @discardableResult
    static func apply(
        for symbols: [SymbolInfo],
        dataService: DataServiceProtocol,
        now: Date = Date()
    ) async -> Int {
        let unique = SupabasePriceService.deduplicatedSymbolInfos(symbols)
            .filter { $0.assetType != .cash }
        guard !unique.isEmpty else { return 0 }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: now)
        let lookbackDays = DemoHistoryFetchPolicy.previousCloseLookbackDays
        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: end) ?? end
        guard let batch = try? await SupabasePriceService.fetchBatchPrices(
            symbols: unique,
            historyStartDate: start,
            historyEndDate: end,
            includeCurrent: false
        ), !batch.dateKeys.isEmpty else {
            return 0
        }

        return await apply(
            for: unique,
            dataService: dataService,
            historyByKey: batch.historicalPricesByKeyAndDate,
            historyDateKeys: batch.dateKeys,
            now: now
        )
    }

    @MainActor
    @discardableResult
    static func apply(
        for symbols: [SymbolInfo],
        dataService: DataServiceProtocol,
        historyByKey: [String: [String: Decimal]],
        historyDateKeys: [String],
        now: Date = Date()
    ) async -> Int {
        let unique = SupabasePriceService.deduplicatedSymbolInfos(symbols)
            .filter { $0.assetType != .cash }
        guard !unique.isEmpty, !historyDateKeys.isEmpty else { return 0 }

        var updatedCount = 0
        for symbol in unique {
            let batchKey = SupabasePriceService.batchKey(assetType: symbol.assetType, symbol: symbol.symbol)
            let historyForSymbol = historyByKey[batchKey] ?? [:]
            var existing = try? await dataService.fetchAssetPriceSnapshot(
                assetType: symbol.assetType,
                symbol: symbol.symbol
            )

            if existing?.hasCurrentPrice != true {
                existing = await bootstrapCurrentFromHistoryIfNeeded(
                    symbol: symbol,
                    existing: existing,
                    exactHistoryByDate: historyForSymbol,
                    historyDateKeys: historyDateKeys,
                    dataService: dataService,
                    now: now
                )
            }

            guard let existing, existing.hasValidPrice else {
                continue
            }

            guard let resolved = DailyReferenceCloseResolver.resolvePreviousSessionClose(
                assetType: symbol.assetType,
                symbol: symbol.symbol,
                exactHistoryByDate: historyForSymbol,
                historyDateKeys: historyDateKeys,
                snapshot: existing,
                now: now
            ) else {
                continue
            }

            let anchorKey = DailyReferenceCloseResolver.effectiveAnchorDateKey(
                for: existing,
                exactHistoryByDate: historyForSymbol,
                historyDateKeys: historyDateKeys,
                now: now
            )
            let alignedCurrentCloseDate = TradingDayCalendar.date(
                fromKey: anchorKey,
                assetType: symbol.assetType
            )

            let updated = snapshotWithHistoryBackedPrevious(
                existing: existing,
                previousPrice: resolved.price,
                previousCloseDate: resolved.closeDate,
                currentCloseDate: alignedCurrentCloseDate ?? existing.currentCloseDate
            )
            try? await dataService.saveAssetPriceSnapshot(updated)
            updatedCount += 1
            #if DEBUG
            let previousKey = TradingDayCalendar.dateKey(
                for: resolved.closeDate,
                assetType: symbol.assetType
            )
            print("[DailyPreviousCloseSync] \(symbol.symbol) anchor=\(anchorKey) previous=\(resolved.price) @ \(previousKey)")
            #endif
        }
        return updatedCount
    }

    @MainActor
    private static func bootstrapCurrentFromHistoryIfNeeded(
        symbol: SymbolInfo,
        existing: AssetPriceSnapshot?,
        exactHistoryByDate: [String: Decimal],
        historyDateKeys: [String],
        dataService: DataServiceProtocol,
        now: Date
    ) async -> AssetPriceSnapshot? {
        let anchorKey = DailyReferenceCloseResolver.effectiveAnchorDateKey(
            for: existing ?? AssetPriceSnapshot(
                assetType: symbol.assetType,
                symbol: symbol.symbol,
                currency: symbol.assetType.quoteCurrency
            ),
            exactHistoryByDate: exactHistoryByDate,
            historyDateKeys: historyDateKeys,
            now: now
        )

        guard let latestKey = historyDateKeys.filter({ $0 <= anchorKey }).max(),
              let price = exactHistoryByDate[latestKey],
              price > 0,
              let closeDate = TradingDayCalendar.date(fromKey: latestKey, assetType: symbol.assetType) else {
            return existing
        }

        let bootstrapped = AssetPriceSnapshot(
            assetType: symbol.assetType,
            symbol: symbol.symbol,
            name: existing?.name,
            currency: existing?.currency ?? symbol.assetType.quoteCurrency,
            currentPrice: price,
            previousPrice: existing?.previousPrice,
            currentCloseDate: closeDate,
            currentUpdatedAt: Date(),
            previousCloseDate: existing?.previousCloseDate,
            previousUpdatedAt: existing?.previousUpdatedAt,
            currentPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource,
            previousPriceSource: existing?.previousPriceSource,
            priceKind: .close
        )
        try? await dataService.saveAssetPriceSnapshot(bootstrapped)
        #if DEBUG
        print("[DailyPreviousCloseSync] bootstrapped current from history for \(symbol.symbol) @ \(latestKey)")
        #endif
        return bootstrapped
    }

    static func snapshotWithHistoryBackedPrevious(
        existing: AssetPriceSnapshot,
        previousPrice: Decimal,
        previousCloseDate: Date,
        currentCloseDate: Date? = nil
    ) -> AssetPriceSnapshot {
        AssetPriceSnapshot(
            assetType: existing.assetType,
            symbol: existing.symbol,
            name: existing.name,
            currency: existing.currency,
            currentPrice: existing.currentPrice,
            previousPrice: previousPrice,
            currentCloseDate: currentCloseDate ?? existing.currentCloseDate,
            currentUpdatedAt: existing.currentUpdatedAt,
            previousCloseDate: TradingDayCalendar.startOfDay(previousCloseDate, assetType: existing.assetType),
            previousUpdatedAt: Date(),
            currentPriceSource: existing.currentPriceSource,
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource,
            priceKind: existing.priceKind
        )
    }
}
