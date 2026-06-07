//
//  AssetPriceSnapshotFreshnessTests.swift
//  SnapvestTests
//

import Foundation
import Testing
@testable import Snapvest

struct AssetPriceSnapshotFreshnessTests {
    private func twDate(_ key: String) -> Date {
        TradingDayCalendar.date(fromKey: key, assetType: .stockTW)!
    }

    private func snapshot(closeKey: String, now: Date) -> AssetPriceSnapshot {
        AssetPriceSnapshot(
            assetType: .stockTW,
            symbol: "2454",
            currency: .TWD,
            currentPrice: 100,
            currentCloseDate: twDate(closeKey),
            currentUpdatedAt: now
        )
    }

    @Test func closeDateFourDaysOld_isStaleOnThursday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TradingDayCalendar.timeZone(for: .stockTW)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 5
        components.hour = 14
        let now = calendar.date(from: components)!

        let stale = AssetPriceSnapshotFreshness.isStaleForLiveQuote(
            snapshot(closeKey: "2026-06-01", now: now),
            now: now
        )
        #expect(stale)
    }

    @Test func previousSessionClose_isFreshOnThursday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TradingDayCalendar.timeZone(for: .stockTW)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 5
        components.hour = 14
        let now = calendar.date(from: components)!

        let fresh = AssetPriceSnapshotFreshness.isStaleForLiveQuote(
            snapshot(closeKey: "2026-06-04", now: now),
            now: now
        )
        #expect(!fresh)
    }

    @Test func fridayClose_isFreshOnMonday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TradingDayCalendar.timeZone(for: .stockTW)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 8
        components.hour = 10
        let now = calendar.date(from: components)!

        let fresh = AssetPriceSnapshotFreshness.isStaleForLiveQuote(
            snapshot(closeKey: "2026-06-05", now: now),
            now: now
        )
        #expect(!fresh)
    }
}
