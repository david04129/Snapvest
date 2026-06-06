//
//  DailyReferenceCloseResolverTests.swift
//  SnapvestTests
//

import Foundation
import Testing
@testable import Snapvest

struct DailyReferenceCloseResolverTests {
    private func usDate(_ key: String) -> Date {
        TradingDayCalendar.date(fromKey: key, assetType: .stockUS)!
    }

    @Test func effectivePreviousClose_usesHistoryBeforeCurrentCloseDate_notWrongSnapshotPrevious() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "TSLA",
            currency: .USD,
            currentPrice: 391,
            previousPrice: 401,
            currentCloseDate: usDate("2026-05-29"),
            previousCloseDate: usDate("2026-05-29"),
            previousPriceSource: "finnhub"
        )
        let history: [String: Decimal] = [
            "2026-05-28": 418,
            "2026-05-29": 391
        ]
        let keys = ["2026-05-28", "2026-05-29"]

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: keys
        )

        #expect(reference?.price == 418)
    }

    @Test func dailyChange_matchesOfficialDailyPercent() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "TSLA",
            currency: .USD,
            currentPrice: 391,
            previousPrice: 401,
            currentCloseDate: usDate("2026-05-29"),
            previousCloseDate: usDate("2026-05-29"),
            previousPriceSource: "finnhub"
        )
        let history: [String: Decimal] = [
            "2026-05-28": 418,
            "2026-05-29": 391
        ]

        let change = DailyReferenceCloseResolver.dailyChange(
            snapshot: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: ["2026-05-28", "2026-05-29"]
        )

        #expect(change?.amount == -27)
        let percent = NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue
        #expect(abs(percent - (-6.4593301435)) < 0.01)
    }

    @Test func googDailyChange_usesJune4NotStaleLocalJune3() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "GOOG",
            currency: .USD,
            currentPrice: 365.76,
            previousPrice: 355.68,
            currentCloseDate: usDate("2026-06-05"),
            previousCloseDate: usDate("2026-06-03"),
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource
        )
        let history: [String: Decimal] = [
            "2026-06-01": 372.58,
            "2026-06-02": 358.39,
            "2026-06-03": 355.68,
            "2026-06-04": 369.27,
            "2026-06-05": 365.76
        ]
        let keys = ["2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04", "2026-06-05"]

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: keys
        )
        #expect(reference?.price == 369.27)

        let change = DailyReferenceCloseResolver.dailyChange(
            snapshot: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: keys
        )
        #expect(change?.amount == -3.51)
        let percent = NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue
        #expect(abs(percent - (-0.950524)) < 0.01)
    }

    @Test func staleCurrentCloseDate_upgradesAnchorFromMatchingHistory() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "GOOG",
            currency: .USD,
            currentPrice: 365.76,
            previousPrice: 355.68,
            currentCloseDate: usDate("2026-06-04"),
            previousCloseDate: usDate("2026-06-03"),
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource
        )
        let history: [String: Decimal] = [
            "2026-06-03": 355.68,
            "2026-06-04": 369.27,
            "2026-06-05": 365.76
        ]
        let keys = ["2026-06-03", "2026-06-04", "2026-06-05"]

        let anchor = DailyReferenceCloseResolver.effectiveAnchorDateKey(
            for: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: keys
        )
        #expect(anchor == "2026-06-05")

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: history,
            historyDateKeys: keys
        )
        #expect(reference?.price == 369.27)
    }

    @Test func trustedHistoryBackedSnapshotPrevious_usedWhenHistoryUnavailable() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "AAPL",
            currency: .USD,
            currentPrice: 200,
            previousPrice: 195,
            currentCloseDate: usDate("2026-05-29"),
            previousCloseDate: usDate("2026-05-28"),
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource
        )

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: [:],
            historyDateKeys: []
        )

        #expect(reference?.price == 195)
    }

    @Test func staleTrustedPrevious_isIgnoredWhenHistoryHasIntermediateSession() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "GOOG",
            currency: .USD,
            currentPrice: 365.76,
            previousPrice: 355.68,
            currentCloseDate: usDate("2026-06-05"),
            previousCloseDate: usDate("2026-06-03"),
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource
        )

        let isStale = DailyReferenceCloseResolver.isTrustedPreviousStale(
            snapshot: snapshot,
            anchorKey: "2026-06-05",
            historyDateKeys: ["2026-06-03", "2026-06-04", "2026-06-05"]
        )
        #expect(isStale)

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: [
                "2026-06-03": 355.68,
                "2026-06-04": 369.27,
                "2026-06-05": 365.76
            ],
            historyDateKeys: ["2026-06-03", "2026-06-04", "2026-06-05"]
        )
        #expect(reference?.price == 369.27)
    }

    @Test func bootstrapPreviousFromFetchOrCreate_isUsedWhenNoHistory() {
        let snapshot = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "NEW",
            currency: .USD,
            currentPrice: 110,
            previousPrice: 100,
            currentCloseDate: usDate("2026-05-29"),
            previousCloseDate: usDate("2026-05-28"),
            previousPriceSource: "yahoo"
        )

        let reference = DailyReferenceCloseResolver.effectivePreviousClose(
            snapshot: snapshot,
            exactHistoryByDate: [:],
            historyDateKeys: []
        )

        #expect(reference?.price == 100)
    }
}

struct PriceSnapshotMergerTests {
    @Test func merge_preservesHistoryBackedPreviousWhenUpdatingCurrent() {
        let existing = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "TSLA",
            currency: .USD,
            currentPrice: 391,
            previousPrice: 418,
            currentCloseDate: TradingDayCalendar.date(fromKey: "2026-05-29", assetType: .stockUS),
            previousCloseDate: TradingDayCalendar.date(fromKey: "2026-05-28", assetType: .stockUS),
            previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource
        )
        let incoming = AssetPriceSnapshot(
            assetType: .stockUS,
            symbol: "TSLA",
            currency: .USD,
            currentPrice: 395,
            previousPrice: 401,
            currentCloseDate: TradingDayCalendar.date(fromKey: "2026-05-30", assetType: .stockUS),
            previousCloseDate: TradingDayCalendar.date(fromKey: "2026-05-29", assetType: .stockUS),
            previousPriceSource: "finnhub"
        )

        let merged = PriceSnapshotMerger.merge(incoming: incoming, existing: existing)

        #expect(merged.currentPrice == 395)
        #expect(merged.previousPrice == 418)
        #expect(merged.previousPriceSource == DailyReferenceCloseResolver.historyPreviousCloseSource)
    }
}
