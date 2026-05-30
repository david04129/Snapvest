//
//  BackfillTestDataSeeder.swift
//  Snapvest
//
//  DEBUG-only seed data for validating local daily trend backfill.
//

import Foundation

#if DEBUG
struct BackfillTestSeedResult {
    let summary: String
}

enum BackfillTestDataSeeder {
    private static let usdToTwd: Decimal = 32.15

    @MainActor
    static func run(userId: String = AppUser.id) async -> BackfillTestSeedResult {
        let seed = makeSeed(userId: userId)
        let dataService = MockDataService.shared
        dataService.beginDemoMode(seed: seed.demoSeed)
        ExchangeRateSessionCache.update(usdToTwd: usdToTwd)
        PieChartGroupingStore.shared.applyDemoDefaults()

        _ = await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: userId,
            dataService: dataService,
            priceService: DemoPriceService(seed: seed.demoSeed),
            syncPortfolio: false,
            updatePriceMetadata: false,
            postsUpdateNotification: false
        )

        let beforeBackfill = ((try? await dataService.fetchLocalDailyTrendSnapshots(
            userId: userId,
            startDate: nil,
            endDate: nil
        )) ?? []).count

        let wroteAny = await LocalDailyTrendBackfillService.runIfNeeded(
            userId: userId,
            dataService: dataService
        )

        let snapshots = (try? await dataService.fetchLocalDailyTrendSnapshots(
            userId: userId,
            startDate: nil,
            endDate: nil
        )) ?? []
        NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)

        let sortedKeys = snapshots
            .map { LocalDailyTrendSnapshot.dateKey(for: $0.date) }
            .sorted()
        let range = [sortedKeys.first, sortedKeys.last]
            .compactMap { $0 }
            .joined(separator: " ~ ")
        let expected = seed.expectedBackfillDateKeys.count
        let added = max(0, snapshots.count - beforeBackfill)
        let status = wroteAny ? "已執行補點" : "沒有補到新點"
        return BackfillTestSeedResult(
            summary: """
            \(status)
            持股：\(seed.symbolCount) 檔
            預期補點：\(expected) 天
            執行前走勢點：\(beforeBackfill)
            執行後走勢點：\(snapshots.count)
            新增走勢點：\(added)
            日期範圍：\(range)

            若新增走勢點為 0，請先確認 fetch-prices-batch 已部署，且 backend/scripts/dev_seed_backfill_test_prices.py 已成功寫入 DB。
            """
        )
    }

    private static func makeSeed(userId: String) -> BackfillTestSeed {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let oldTrendDate = calendar.date(byAdding: .day, value: -11, to: today) ?? today
        let expectedBackfillDates = (1...10).compactMap {
            calendar.date(byAdding: .day, value: -11 + $0, to: today)
        }

        let twdCash = Account(
            id: "backfill-test-twd-cash",
            userId: userId,
            name: "補點測試台幣現金",
            accountType: .twdDeposit,
            currency: .TWD,
            createdAt: oldTrendDate,
            updatedAt: now
        )
        let twdAccount = Account(
            id: "backfill-test-tw",
            userId: userId,
            name: "補點測試台股",
            accountType: .twdSecurities,
            currency: .TWD,
            createdAt: oldTrendDate,
            updatedAt: now
        )
        let usAccount = Account(
            id: "backfill-test-us",
            userId: userId,
            name: "補點測試美股",
            accountType: .usdAccount,
            currency: .USD,
            createdAt: oldTrendDate,
            updatedAt: now
        )
        let cryptoAccount = Account(
            id: "backfill-test-crypto",
            userId: userId,
            name: "補點測試加密貨幣",
            accountType: .cryptoWallet,
            currency: .USD,
            createdAt: oldTrendDate,
            updatedAt: now
        )

        let symbols = TestSymbol.all
        let buyDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        var transactionsByAccountId: [String: [Transaction]] = [
            twdCash.id: [
                Transaction(
                    accountId: twdCash.id,
                    type: .deposit,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: 100_000,
                    price: 1,
                    currency: .TWD,
                    notes: "補點測試現金",
                    transactionDate: buyDate
                )
            ],
            twdAccount.id: [],
            usAccount.id: [],
            cryptoAccount.id: []
        ]

        var assetPriceSnapshots: [AssetPriceSnapshot] = []
        for (index, symbol) in symbols.enumerated() {
            let currentPrice = testPrice(base: symbol.basePrice, symbolIndex: index, dayIndex: 9)
            let previousPrice = testPrice(base: symbol.basePrice, symbolIndex: index, dayIndex: 8)
            let quantity = testQuantity(for: symbol, index: index)
            let buyPrice = currentPrice * Decimal(string: "0.92")!
            let accountId = accountId(for: symbol.assetType, twdAccount: twdAccount, usAccount: usAccount, cryptoAccount: cryptoAccount)
            transactionsByAccountId[accountId, default: []].append(
                Transaction(
                    accountId: accountId,
                    type: .buy,
                    assetType: symbol.assetType,
                    symbol: symbol.symbol,
                    quantity: quantity,
                    price: buyPrice,
                    currency: symbol.currency,
                    notes: "補點測試買入 \(symbol.symbol)",
                    transactionDate: buyDate,
                    deductFromAccount: false
                )
            )

            assetPriceSnapshots.append(
                AssetPriceSnapshot(
                    assetType: symbol.assetType,
                    symbol: symbol.symbol,
                    name: symbol.name,
                    currency: symbol.currency,
                    currentPrice: currentPrice,
                    previousPrice: previousPrice,
                    currentCloseDate: calendar.date(byAdding: .day, value: -1, to: today),
                    currentUpdatedAt: now,
                    previousCloseDate: calendar.date(byAdding: .day, value: -2, to: today),
                    previousUpdatedAt: now,
                    currentPriceSource: "dev_seed",
                    previousPriceSource: "dev_seed"
                )
            )
        }

        let oldTrendPoint = TrendChartPoint(
            id: LocalDailyTrendSnapshot.dateKey(for: oldTrendDate),
            date: oldTrendDate,
            totalAssets: 900_000,
            netWorth: 900_000,
            unrealizedGainLoss: 0
        )

        return BackfillTestSeed(
            demoSeed: DemoSeedData(
                userId: userId,
                accounts: [twdCash, twdAccount, usAccount, cryptoAccount],
                transactionsByAccountId: transactionsByAccountId,
                liabilitiesByAccountId: [:],
                assetPriceSnapshots: assetPriceSnapshots,
                trendPoints: [oldTrendPoint]
            ),
            symbolCount: symbols.count,
            expectedBackfillDateKeys: expectedBackfillDates.map { LocalDailyTrendSnapshot.dateKey(for: $0) }
        )
    }

    private static func accountId(
        for assetType: AssetType,
        twdAccount: Account,
        usAccount: Account,
        cryptoAccount: Account
    ) -> String {
        switch assetType {
        case .stockTW:
            return twdAccount.id
        case .stockUS:
            return usAccount.id
        case .crypto:
            return cryptoAccount.id
        case .cash:
            return twdAccount.id
        }
    }

    private static func testPrice(base: Decimal, symbolIndex: Int, dayIndex: Int) -> Decimal {
        let wave = (Decimal(dayIndex % 5) - 2) * Decimal(string: "0.006")!
        let drift = (Decimal(dayIndex) - Decimal(string: "4.5")!) * Decimal(string: "0.004")!
        let bias = (Decimal(symbolIndex % 4) - Decimal(string: "1.5")!) * Decimal(string: "0.003")!
        return base * (1 + wave + drift + bias)
    }

    private static func testQuantity(for symbol: TestSymbol, index: Int) -> Decimal {
        switch symbol.assetType {
        case .stockTW:
            return Decimal(80 + index * 10)
        case .stockUS:
            return Decimal(3 + index % 5)
        case .crypto:
            switch symbol.symbol {
            case "BTC": return Decimal(string: "0.035")!
            case "ETH": return Decimal(string: "0.45")!
            case "USDT": return 500
            default: return Decimal(4 + index % 6)
            }
        case .cash:
            return 0
        }
    }
}

private struct BackfillTestSeed {
    let demoSeed: DemoSeedData
    let symbolCount: Int
    let expectedBackfillDateKeys: [String]
}

private struct TestSymbol {
    let assetType: AssetType
    let symbol: String
    let currency: Currency
    let basePrice: Decimal
    let name: String?

    static let all: [TestSymbol] = [
        .init(assetType: .stockTW, symbol: "990001", currency: .TWD, basePrice: 935, name: "測試台股一"),
        .init(assetType: .stockTW, symbol: "990002", currency: .TWD, basePrice: 182, name: "測試台股二"),
        .init(assetType: .stockTW, symbol: "990003", currency: .TWD, basePrice: 1260, name: "測試台股三"),
        .init(assetType: .stockTW, symbol: "990004", currency: .TWD, basePrice: Decimal(string: "54.2")!, name: "測試台股四"),
        .init(assetType: .stockTW, symbol: "990005", currency: .TWD, basePrice: Decimal(string: "88.6")!, name: "測試台股五"),
        .init(assetType: .stockTW, symbol: "990006", currency: .TWD, basePrice: Decimal(string: "182.4")!, name: "測試台股六"),
        .init(assetType: .stockTW, symbol: "990007", currency: .TWD, basePrice: Decimal(string: "22.8")!, name: "測試台股七"),
        .init(assetType: .stockUS, symbol: "ZZTST1", currency: .USD, basePrice: Decimal(string: "195.5")!, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST2", currency: .USD, basePrice: 430, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST3", currency: .USD, basePrice: 126, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST4", currency: .USD, basePrice: 340, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST5", currency: .USD, basePrice: 505, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST6", currency: .USD, basePrice: 184, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST7", currency: .USD, basePrice: 176, name: nil),
        .init(assetType: .stockUS, symbol: "ZZTST8", currency: .USD, basePrice: 585, name: nil),
        .init(assetType: .crypto, symbol: "TSTBTC", currency: .USD, basePrice: 104_000, name: nil),
        .init(assetType: .crypto, symbol: "TSTETH", currency: .USD, basePrice: 3_850, name: nil),
        .init(assetType: .crypto, symbol: "TSTSOL", currency: .USD, basePrice: 166, name: nil),
        .init(assetType: .crypto, symbol: "TSTXRP", currency: .USD, basePrice: Decimal(string: "2.22")!, name: nil),
        .init(assetType: .crypto, symbol: "TSTUSD", currency: .USD, basePrice: 1, name: nil)
    ]
}

#endif
