//
//  DemoModeManager.swift
//  Snapvest
//
//  一次性的本機示範模式：不寫後端、不持久化，退出或重開 App 即回到真實資料。
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()
    
    @Published private(set) var isEnabled = false
    @Published private(set) var isSwitching = false
    
    private init() {}
    
    func enterDemoMode(userId: String? = nil) async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }
        
        let resolvedUserId = userId ?? AppUser.id
        let seed = DemoSeedData.make(userId: resolvedUserId)
        MockDataService.shared.beginDemoMode(seed: seed)
        ExchangeRateSessionCache.clear()
        PieChartGroupingStore.shared.applyDemoDefaults()
        
        await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: resolvedUserId,
            dataService: MockDataService.shared,
            priceService: DemoPriceService(seed: seed),
            updatePriceMetadata: false,
            postsUpdateNotification: false
        )
        
        await DemoSeedData.reconcileDemoPresentation(
            userId: resolvedUserId,
            dataService: MockDataService.shared,
            seed: seed
        )
        
        isEnabled = true
    }

    func exitDemoMode(userId: String? = nil) async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }
        
        let resolvedUserId = userId ?? AppUser.id
        MockDataService.shared.endDemoMode()
        PieChartGroupingStore.shared.reload(for: resolvedUserId)
        isEnabled = false
    }
}

struct DemoSeedData {
    let userId: String
    let accounts: [Account]
    let transactionsByAccountId: [String: [Transaction]]
    let liabilitiesByAccountId: [String: [Liability]]
    let manualAssets: [ManualAsset]
    let manualAssetValuationsByAssetId: [String: [ManualAssetValuation]]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let trendPoints: [TrendChartPoint]
    
    static func make(userId: String) -> DemoSeedData {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        let twdCash = Account(
            id: "demo-account-twd-cash",
            userId: userId,
            name: "台幣生活戶",
            accountType: .twdDeposit,
            currency: .TWD,
            createdAt: daysAgo(360, today: today),
            updatedAt: now
        )
        let twdSecurities = Account(
            id: "demo-account-tw-securities",
            userId: userId,
            name: "台股證券戶",
            accountType: .twdSecurities,
            currency: .TWD,
            createdAt: daysAgo(330, today: today),
            updatedAt: now
        )
        let usdSecurities = Account(
            id: "demo-account-us-securities",
            userId: userId,
            name: "美股證券戶",
            accountType: .usdAccount,
            currency: .USD,
            createdAt: daysAgo(300, today: today),
            updatedAt: now
        )
        let cryptoWallet = Account(
            id: "demo-account-crypto",
            userId: userId,
            name: "加密貨幣錢包",
            accountType: .cryptoWallet,
            currency: .USD,
            createdAt: daysAgo(260, today: today),
            updatedAt: now
        )
        let installmentDebt = Account(
            id: "demo-account-car-loan",
            userId: userId,
            name: "車貸",
            accountType: .debt,
            currency: .TWD,
            createdAt: daysAgo(420, today: today),
            updatedAt: now
        )
        let otherDebt = Account(
            id: "demo-account-card-installment",
            userId: userId,
            name: "信用卡分期",
            accountType: .otherDebt,
            currency: .TWD,
            createdAt: daysAgo(160, today: today),
            updatedAt: now
        )
        
        let accounts = [twdCash, twdSecurities, usdSecurities, cryptoWallet, installmentDebt, otherDebt]
        
        let transactionsByAccountId = makeDemoTransactions(
            today: today,
            twdCash: twdCash,
            twdSecurities: twdSecurities,
            usdSecurities: usdSecurities,
            cryptoWallet: cryptoWallet,
            otherDebt: otherDebt
        )
        
        let liabilitiesByAccountId: [String: [Liability]] = [
            installmentDebt.id: [
                Liability(
                    id: "demo-liability-car-loan",
                    accountId: installmentDebt.id,
                    name: "車貸",
                    principal: decimal("370000"),
                    interestRate: decimal("2.6"),
                    monthlyPayment: decimal("12500"),
                    remainingBalance: decimal("250000"),
                    currency: .TWD,
                    startDate: daysAgo(420, today: today),
                    totalPeriods: 36,
                    paidPeriods: 10,
                    totalPaidPrincipal: decimal("120000"),
                    totalPaidInterest: decimal("8500")
                )
            ]
        ]
        
        let priceSnapshots = makeDemoPriceSnapshots(now: now)
        let (manualAssets, manualValuations) = makeDemoManualAssets(userId: userId, today: today, now: now)
        
        return DemoSeedData(
            userId: userId,
            accounts: accounts,
            transactionsByAccountId: transactionsByAccountId,
            liabilitiesByAccountId: liabilitiesByAccountId,
            manualAssets: manualAssets,
            manualAssetValuationsByAssetId: manualValuations,
            assetPriceSnapshots: priceSnapshots,
            trendPoints: makeTrendPoints(today: today)
        )
    }

    /// 示範模式：走勢終點（約 159 萬淨資產）為基準，避免「昨天假走勢 160 萬、今天重算 126 萬」斷崖。
    static func reconcileDemoPresentation(
        userId: String,
        dataService: MockDataService,
        seed: DemoSeedData
    ) async {
        guard dataService.isDemoModeActive,
              let endpoint = seed.trendPoints.last,
              let calculated = try? await dataService.fetchHomeDashboardSnapshot(userId: userId) else {
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let now = Date()

        let trendSnap = LocalDailyTrendSnapshot(
            userId: userId,
            date: today,
            totalAssets: endpoint.totalAssets,
            netWorth: endpoint.netWorth,
            unrealizedGainLoss: endpoint.unrealizedGainLoss,
            sourceHomeSnapshotUpdatedAt: now,
            recordedAt: now
        )
        try? await dataService.upsertLocalDailyTrendSnapshot(trendSnap)

        let scale: Decimal = calculated.netWorth > 0
            ? endpoint.netWorth / calculated.netWorth
            : 1
        let scaledInvestments = calculated.totalInvestments * scale
        let scaledCash = calculated.totalCash * scale
        let investmentsCost = scaledInvestments - endpoint.unrealizedGainLoss

        let patched = HomeDashboardSnapshot(
            userId: userId,
            netWorth: endpoint.netWorth,
            totalLiabilities: calculated.totalLiabilities,
            totalAssets: endpoint.totalAssets,
            totalInvestments: scaledInvestments,
            totalInvestmentsCost: investmentsCost,
            totalCash: scaledCash,
            twdCash: calculated.twdCash * scale,
            usdCash: calculated.usdCash * scale,
            realizedGainLossTWD: calculated.realizedGainLossTWD,
            realizedGainLossUSD: calculated.realizedGainLossUSD,
            lastUpdated: now
        )
        try? await dataService.saveHomeDashboardSnapshot(patched)
    }
    
    private static func makeDemoPriceSnapshots(now: Date) -> [AssetPriceSnapshot] {
        let day = Calendar.current.startOfDay(for: now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        /// (assetType, symbol, name, currency, 今日價, 昨日價) — 全部示範用假價，製造明顯漲跌
        let specs: [(AssetType, String, String, Currency, String, String)] = [
            (.stockTW, "2330", "台積電", .TWD, "1120", "980"),
            (.stockTW, "0050", "元大台灣50", .TWD, "214", "205"),
            (.stockTW, "2317", "鴻海", .TWD, "228", "210"),
            (.stockUS, "VOO", "VOO", .USD, "645", "618"),
            (.stockUS, "AAPL", "Apple", .USD, "266", "248"),
            (.stockUS, "NVDA", "NVIDIA", .USD, "168", "138"),
            (.stockUS, "MSFT", "Microsoft", .USD, "528", "508"),
            (.crypto, "BTC", "Bitcoin", .USD, "88800", "79800"),
            (.crypto, "ETH", "Ethereum", .USD, "3880", "3580"),
            (.crypto, "USDT", "Tether", .USD, "1", "1"),
        ]
        return specs.map { assetType, symbol, name, currency, current, previous in
            AssetPriceSnapshot(
                assetType: assetType,
                symbol: symbol,
                name: name,
                currency: currency,
                currentPrice: decimal(current),
                previousPrice: decimal(previous),
                currentCloseDate: day,
                currentUpdatedAt: now,
                previousCloseDate: yesterday,
                previousUpdatedAt: now,
                currentPriceSource: "demo",
                previousPriceSource: "demo"
            )
        }
    }

    private static func makeDemoManualAssets(
        userId: String,
        today: Date,
        now: Date
    ) -> ([ManualAsset], [String: [ManualAssetValuation]]) {
        let specs: [(String, String, ManualAssetCategory, String, String, Bool)] = [
            ("demo-manual-fund", "示範私募基金", .fund, "118000", "100000", true),
            ("demo-manual-realestate", "台北市公寓分戶", .realEstate, "168000", "155000", false),
            ("demo-manual-gold", "實體黃金", .preciousMetal, "42000", "38000", false),
            ("demo-manual-bond", "公司債券", .bond, "72000", "70000", true),
            ("demo-manual-insurance", "儲蓄型保單", .insurance, "48000", "45000", false),
            ("demo-manual-collectible", "限量腕表", .collectible, "65000", "52000", false),
        ]
        var assets: [ManualAsset] = []
        var valuations: [String: [ManualAssetValuation]] = [:]
        for spec in specs {
            let purchaseDate = daysAgo(280, today: today)
            let asset = ManualAsset(
                id: spec.0,
                userId: userId,
                name: spec.1,
                category: spec.2,
                currency: .TWD,
                currentValue: decimal(spec.3),
                costBasis: decimal(spec.4),
                purchaseDate: purchaseDate,
                notes: "Demo 其他資產",
                isIncludedInTotalAssets: true,
                isIncludedInInvestments: spec.5,
                currentValueUpdatedAt: now,
                createdAt: purchaseDate,
                updatedAt: now
            )
            assets.append(asset)
            valuations[asset.id] = [
                ManualAssetValuation(
                    id: "\(asset.id)-create",
                    userId: userId,
                    manualAssetId: asset.id,
                    value: decimal(spec.4),
                    currency: .TWD,
                    valuationDate: purchaseDate,
                    notes: ManualAssetValuation.creationRecordNote,
                    createdAt: purchaseDate
                ),
                ManualAssetValuation(
                    id: "\(asset.id)-update",
                    userId: userId,
                    manualAssetId: asset.id,
                    value: decimal(spec.3),
                    currency: .TWD,
                    valuationDate: daysAgo(45, today: today),
                    notes: "Demo 更新現值",
                    createdAt: daysAgo(45, today: today)
                )
            ]
        }
        return (assets, valuations)
    }

    private static func makeDemoTransactions(
        today: Date,
        twdCash: Account,
        twdSecurities: Account,
        usdSecurities: Account,
        cryptoWallet: Account,
        otherDebt: Account
    ) -> [String: [Transaction]] {
        var tw: [Transaction] = [
            deposit(id: "demo-txn-tw-cash-1", accountId: twdSecurities.id, amount: decimal("320000"), currency: .TWD, date: daysAgo(330, today: today), note: "Demo 證券戶現金"),
            dividend(id: "demo-txn-tw-div-2330", accountId: twdSecurities.id, amount: decimal("12800"), currency: .TWD, date: daysAgo(200, today: today), note: "2330 現金股利"),
            dividend(id: "demo-txn-tw-div-0050", accountId: twdSecurities.id, amount: decimal("6200"), currency: .TWD, date: daysAgo(165, today: today), note: "0050 配息"),
            fee(id: "demo-txn-tw-fee-1", accountId: twdSecurities.id, amount: decimal("142"), currency: .TWD, date: daysAgo(300, today: today)),
            fee(id: "demo-txn-tw-fee-2", accountId: twdSecurities.id, amount: decimal("85"), currency: .TWD, date: daysAgo(48, today: today)),
        ]
        tw.append(contentsOf: demoTWTrades(accountId: twdSecurities.id, today: today))

        var us: [Transaction] = [
            deposit(id: "demo-txn-us-cash-1", accountId: usdSecurities.id, amount: decimal("4800"), currency: .USD, date: daysAgo(310, today: today), note: "Demo 美金現金"),
            dividend(id: "demo-txn-us-div-aapl", accountId: usdSecurities.id, amount: decimal("186"), currency: .USD, date: daysAgo(190, today: today), note: "AAPL 股息"),
            dividend(id: "demo-txn-us-div-voo", accountId: usdSecurities.id, amount: decimal("92"), currency: .USD, date: daysAgo(120, today: today), note: "VOO 配息"),
            fee(id: "demo-txn-us-fee-1", accountId: usdSecurities.id, amount: decimal("3.5"), currency: .USD, date: daysAgo(260, today: today)),
        ]
        us.append(contentsOf: demoUSTrades(accountId: usdSecurities.id, today: today))

        var crypto: [Transaction] = demoCryptoTrades(accountId: cryptoWallet.id, today: today)
        crypto.append(
            deposit(id: "demo-txn-crypto-cash", accountId: cryptoWallet.id, amount: decimal("2500"), currency: .USD, date: daysAgo(240, today: today), note: "Demo 加密帳戶入金")
        )

        let cashFlow: [Transaction] = [
            deposit(id: "demo-txn-cash-1", accountId: twdCash.id, amount: decimal("240000"), currency: .TWD, date: daysAgo(350, today: today), note: "Demo 薪資入帳"),
            deposit(id: "demo-txn-cash-2", accountId: twdCash.id, amount: decimal("36000"), currency: .TWD, date: daysAgo(180, today: today), note: "年終獎金"),
            withdraw(id: "demo-txn-cash-w1", accountId: twdCash.id, amount: decimal("28000"), currency: .TWD, date: daysAgo(290, today: today), note: "房租"),
            withdraw(id: "demo-txn-cash-w2", accountId: twdCash.id, amount: decimal("15000"), currency: .TWD, date: daysAgo(220, today: today), note: "保險費"),
            withdraw(id: "demo-txn-cash-w3", accountId: twdCash.id, amount: decimal("42000"), currency: .TWD, date: daysAgo(95, today: today), note: "旅遊"),
            deposit(id: "demo-txn-cash-3", accountId: twdCash.id, amount: decimal("18000"), currency: .TWD, date: daysAgo(60, today: today), note: "副業收入"),
            fee(id: "demo-txn-cash-fee", accountId: twdCash.id, amount: decimal("15"), currency: .TWD, date: daysAgo(30, today: today)),
        ]

        return [
            twdCash.id: cashFlow.filter { $0.accountId == twdCash.id },
            twdSecurities.id: tw,
            usdSecurities.id: us,
            cryptoWallet.id: crypto,
            otherDebt.id: [
                otherDebtInitial(accountId: otherDebt.id, amount: decimal("16000"), date: daysAgo(160, today: today))
            ]
        ]
    }

    /// 台股：同一標的多筆買賣（示範 FIFO／交易紀錄列表）
    private static func demoTWTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        let tsmc: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-2330-b1", 318, "buy", "90", "685", nil),
            ("demo-txn-2330-b2", 302, "buy", "70", "718", nil),
            ("demo-txn-2330-s1", 288, "sell", "25", "752", "700"),
            ("demo-txn-2330-b3", 272, "buy", "55", "735", nil),
            ("demo-txn-2330-b4", 248, "buy", "40", "798", nil),
            ("demo-txn-2330-s2", 232, "sell", "30", "842", "760"),
            ("demo-txn-2330-b5", 215, "buy", "35", "805", nil),
            ("demo-txn-2330-s3", 198, "sell", "20", "878", "805"),
            ("demo-txn-2330-b6", 178, "buy", "45", "830", nil),
            ("demo-txn-2330-b7", 155, "buy", "30", "895", nil),
            ("demo-txn-2330-s4", 138, "sell", "28", "920", "850"),
            ("demo-txn-2330-b8", 118, "buy", "25", "910", nil),
            ("demo-txn-2330-s5", 95, "sell", "22", "948", "830"),
            ("demo-txn-2330-b9", 72, "buy", "20", "935", nil),
            ("demo-txn-2330-s6", 48, "sell", "35", "962", "760"),
            ("demo-txn-2330-b10", 28, "buy", "18", "958", nil),
            ("demo-txn-2330-b11", 18, "buy", "12", "945", nil),
            ("demo-txn-2330-s7", 12, "sell", "15", "972", "900"),
            ("demo-txn-2330-b12", 5, "buy", "10", "952", nil),
        ]
        for spec in tsmc {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockTW, symbol: "2330", name: "台積電", spec: spec)
        }

        let fifty: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-0050-b1", 265, "buy", "400", "148", nil),
            ("demo-txn-0050-b2", 228, "buy", "250", "156", nil),
            ("demo-txn-0050-s1", 205, "sell", "120", "162", "152"),
            ("demo-txn-0050-b3", 180, "buy", "180", "168", nil),
            ("demo-txn-0050-s2", 155, "sell", "90", "175", "168"),
            ("demo-txn-0050-b4", 125, "buy", "150", "172", nil),
            ("demo-txn-0050-s3", 88, "sell", "80", "181", "170"),
            ("demo-txn-0050-b5", 55, "buy", "100", "178", nil),
        ]
        for spec in fifty {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockTW, symbol: "0050", name: "元大台灣50", spec: spec)
        }

        let hon: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-2317-b1", 290, "buy", "200", "158", nil),
            ("demo-txn-2317-b2", 250, "buy", "150", "168", nil),
            ("demo-txn-2317-s1", 225, "sell", "60", "175", "162"),
            ("demo-txn-2317-b3", 200, "buy", "120", "162", nil),
            ("demo-txn-2317-s2", 175, "sell", "80", "182", "165"),
            ("demo-txn-2317-b4", 145, "buy", "100", "170", nil),
            ("demo-txn-2317-b5", 110, "buy", "80", "185", nil),
            ("demo-txn-2317-s3", 82, "sell", "50", "192", "175"),
            ("demo-txn-2317-b6", 52, "buy", "70", "188", nil),
        ]
        for spec in hon {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockTW, symbol: "2317", name: "鴻海", spec: spec)
        }

        return trades.sorted { $0.transactionDate < $1.transactionDate }
    }

    private static func demoUSTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        let nvda: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-nvda-b1", 305, "buy", "12", "88", nil),
            ("demo-txn-nvda-b2", 285, "buy", "15", "102", nil),
            ("demo-txn-nvda-s1", 268, "sell", "6", "115", "95"),
            ("demo-txn-nvda-b3", 250, "buy", "10", "108", nil),
            ("demo-txn-nvda-b4", 228, "buy", "8", "118", nil),
            ("demo-txn-nvda-s2", 210, "sell", "5", "132", "110"),
            ("demo-txn-nvda-b5", 192, "buy", "12", "125", nil),
            ("demo-txn-nvda-s3", 175, "sell", "8", "142", "125"),
            ("demo-txn-nvda-b6", 158, "buy", "10", "135", nil),
            ("demo-txn-nvda-s4", 140, "sell", "6", "148", "130"),
            ("demo-txn-nvda-b7", 120, "buy", "14", "138", nil),
            ("demo-txn-nvda-s5", 98, "sell", "7", "155", "120"),
            ("demo-txn-nvda-b8", 75, "buy", "9", "148", nil),
            ("demo-txn-nvda-s6", 42, "sell", "10", "152", "95"),
            ("demo-txn-nvda-b9", 22, "buy", "8", "146", nil),
            ("demo-txn-nvda-b10", 15, "buy", "6", "151", nil),
            ("demo-txn-nvda-s7", 8, "sell", "4", "144", "138"),
            ("demo-txn-nvda-b11", 3, "buy", "5", "140", nil),
        ]
        for spec in nvda {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "NVDA", name: "NVIDIA", spec: spec)
        }

        let aapl: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-aapl-b1", 298, "buy", "10", "165", nil),
            ("demo-txn-aapl-b2", 270, "buy", "8", "178", nil),
            ("demo-txn-aapl-s1", 252, "sell", "4", "188", "172"),
            ("demo-txn-aapl-b3", 230, "buy", "6", "182", nil),
            ("demo-txn-aapl-s2", 208, "sell", "3", "195", "180"),
            ("demo-txn-aapl-b4", 185, "buy", "7", "190", nil),
            ("demo-txn-aapl-b5", 160, "buy", "5", "205", nil),
            ("demo-txn-aapl-s3", 135, "sell", "4", "212", "198"),
            ("demo-txn-aapl-b6", 108, "buy", "6", "208", nil),
            ("demo-txn-aapl-s4", 78, "sell", "5", "222", "205"),
            ("demo-txn-aapl-b7", 45, "buy", "4", "218", nil),
        ]
        for spec in aapl {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "AAPL", name: "Apple", spec: spec)
        }

        let voo: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-voo-b1", 280, "buy", "5", "445", nil),
            ("demo-txn-voo-b2", 240, "buy", "4", "468", nil),
            ("demo-txn-voo-s1", 210, "sell", "2", "492", "456"),
            ("demo-txn-voo-b3", 175, "buy", "3", "505", nil),
            ("demo-txn-voo-b4", 120, "buy", "2", "528", nil),
        ]
        for spec in voo {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "VOO", name: "VOO", spec: spec)
        }

        let msft: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-msft-b1", 265, "buy", "4", "365", nil),
            ("demo-txn-msft-s1", 235, "sell", "1", "398", "370"),
            ("demo-txn-msft-b2", 200, "buy", "3", "388", nil),
            ("demo-txn-msft-b3", 165, "buy", "2", "412", nil),
            ("demo-txn-msft-s2", 125, "sell", "2", "435", "400"),
            ("demo-txn-msft-b4", 88, "buy", "2", "428", nil),
        ]
        for spec in msft {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "MSFT", name: "Microsoft", spec: spec)
        }

        return trades.sorted { $0.transactionDate < $1.transactionDate }
    }

    private static func demoCryptoTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        let btc: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-btc-b1", 300, "buy", "0.03", "62000", nil),
            ("demo-txn-btc-b2", 265, "buy", "0.02", "68500", nil),
            ("demo-txn-btc-s1", 240, "sell", "0.01", "72000", "65000"),
            ("demo-txn-btc-b3", 210, "buy", "0.015", "70000", nil),
            ("demo-txn-btc-s2", 180, "sell", "0.008", "78000", "70000"),
            ("demo-txn-btc-b4", 150, "buy", "0.012", "75000", nil),
            ("demo-txn-btc-b5", 115, "buy", "0.01", "82000", nil),
            ("demo-txn-btc-s3", 85, "sell", "0.006", "91000", "78000"),
            ("demo-txn-btc-b6", 55, "buy", "0.008", "88000", nil),
            ("demo-txn-btc-s4", 40, "sell", "0.004", "76000", "82000"),
            ("demo-txn-btc-b7", 25, "buy", "0.006", "81000", nil),
        ]
        for spec in btc {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .crypto, symbol: "BTC", name: "Bitcoin", spec: spec)
        }

        let eth: [(String, Int, String, String, String, String?)] = [
            ("demo-txn-eth-b1", 275, "buy", "0.4", "2650", nil),
            ("demo-txn-eth-s1", 248, "sell", "0.15", "2920", "2700"),
            ("demo-txn-eth-b2", 220, "buy", "0.25", "2850", nil),
            ("demo-txn-eth-b3", 185, "buy", "0.2", "3100", nil),
            ("demo-txn-eth-s2", 155, "sell", "0.12", "3350", "3000"),
            ("demo-txn-eth-b4", 120, "buy", "0.18", "3200", nil),
            ("demo-txn-eth-b5", 75, "buy", "0.15", "3480", nil),
        ]
        for spec in eth {
            appendTrade(&trades, accountId: accountId, today: today, assetType: .crypto, symbol: "ETH", name: "Ethereum", spec: spec)
        }

        trades.append(
            buy(id: "demo-txn-usdt-b1", accountId: accountId, assetType: .crypto, symbol: "USDT", quantity: decimal("1200"), price: decimal("1"), currency: .USD, date: daysAgo(200, today: today))
        )
        trades.append(
            buy(id: "demo-txn-usdt-b2", accountId: accountId, assetType: .crypto, symbol: "USDT", quantity: decimal("800"), price: decimal("1"), currency: .USD, date: daysAgo(95, today: today))
        )

        return trades.sorted { $0.transactionDate < $1.transactionDate }
    }

    private static func appendTrade(
        _ trades: inout [Transaction],
        accountId: String,
        today: Date,
        assetType: AssetType,
        symbol: String,
        name: String?,
        spec: (String, Int, String, String, String, String?)
    ) {
        let (id, days, side, qty, price, cost) = spec
        let date = daysAgo(days, today: today)
        if side == "buy" {
            trades.append(
                buy(id: id, accountId: accountId, assetType: assetType, symbol: symbol, quantity: decimal(qty), price: decimal(price), currency: assetType == .stockTW ? .TWD : .USD, date: date, name: name)
            )
        } else {
            trades.append(
                sell(id: id, accountId: accountId, assetType: assetType, symbol: symbol, quantity: decimal(qty), price: decimal(price), currency: assetType == .stockTW ? .TWD : .USD, date: date, realizedCostPerUnit: decimal(cost ?? price))
            )
        }
    }

    private static func makeTrendPoints(today: Date) -> [TrendChartPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        
        var rawNetWorths: [Double] = []
        var value = 760_000.0
        var momentum = 0.0
        
        for index in 0..<365 {
            let progress = Double(index) / 364.0
            let trendDrift = 1_050.0 + progress * 760.0
            let volatility: Double
            if progress < 0.30 {
                volatility = 18_000
            } else if progress < 0.58 {
                volatility = 28_000
            } else if progress < 0.78 {
                volatility = 44_000
            } else {
                volatility = 34_000
            }
            
            let shock = seededNoise(index, salt: 11)
            let clusterShock = seededNoise(index / 4, salt: 73) * 0.55
            momentum = momentum * 0.62 + (shock + clusterShock) * volatility
            let dailyNoise = momentum
            let surge = eventPulse(progress, start: 0.42, end: 0.55, amplitude: 22_000)
            let dip = eventPulse(progress, start: 0.55, end: 0.62, amplitude: -28_000)
            let crash = eventPulse(progress, start: 0.66, end: 0.74, amplitude: -42_000)
            let rebound = eventPulse(progress, start: 0.82, end: 0.96, amplitude: 20_000)
            let correction = eventPulse(progress, start: 0.88, end: 0.92, amplitude: -18_000)
            let lateRipple = seededNoise(index, salt: 909) * 12_000
            
            value += trendDrift + dailyNoise + surge + dip + crash + rebound + correction + lateRipple
            rawNetWorths.append(max(520_000, value))
        }
        
        let targetStart = 760_000.0
        let targetEnd = 1_590_000.0
        let rawStart = rawNetWorths.first ?? targetStart
        let rawEnd = rawNetWorths.last ?? targetEnd
        let scale = (targetEnd - targetStart) / max(1, rawEnd - rawStart)
        
        return rawNetWorths.enumerated().compactMap { index, rawValue in
            guard let date = calendar.date(byAdding: .day, value: index - 364, to: today) else { return nil }
            let progress = Double(index) / 364.0
            let netWorth = targetStart + (rawValue - rawStart) * scale
            let liabilities = 330_000 - progress * 64_000
            let totalAssets = netWorth + liabilities
            let unrealized = -12_000 + (netWorth - targetStart) * 0.22 + seededNoise(index, salt: 701) * 24_000
            
            return TrendChartPoint(
                id: formatter.string(from: date),
                date: date,
                totalAssets: Decimal(Int(totalAssets.rounded())),
                netWorth: Decimal(Int(netWorth.rounded())),
                unrealizedGainLoss: Decimal(Int(unrealized.rounded()))
            )
        }
    }
    
    private static func seededNoise(_ index: Int, salt: UInt64) -> Double {
        let primary = seededUnit(index, salt: salt) * 2 - 1
        let secondary = seededUnit(index, salt: salt &+ 10_007) * 2 - 1
        return primary * 0.72 + secondary * 0.28
    }
    
    private static func seededUnit(_ index: Int, salt: UInt64) -> Double {
        var value = UInt64(bitPattern: Int64(index + 1))
        value = value &* 0x9E3779B185EBCA87 &+ salt
        value ^= value >> 30
        value = value &* 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value = value &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value & 0xFFFF_FFFF) / Double(UInt32.max)
    }
    
    private static func eventPulse(_ progress: Double, start: Double, end: Double, amplitude: Double) -> Double {
        guard progress >= start, progress <= end else { return 0 }
        let local = (progress - start) / (end - start)
        return amplitude * sin(local * .pi)
    }
    
    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
    
    private static func daysAgo(_ days: Int, today: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: today) ?? today
    }
    
    private static func deposit(
        id: String = UUID().uuidString,
        accountId: String,
        amount: Decimal,
        currency: Currency,
        date: Date,
        note: String
    ) -> Transaction {
        Transaction(id: id, accountId: accountId, type: .deposit, assetType: .cash, symbol: "CASH", quantity: amount, price: 1, currency: currency, notes: note, transactionDate: date)
    }
    
    private static func otherDebtInitial(accountId: String, amount: Decimal, date: Date) -> Transaction {
        Transaction(
            accountId: accountId,
            type: .liability,
            assetType: .cash,
            symbol: "DEBT",
            quantity: 1,
            price: amount,
            currency: .TWD,
            notes: "Demo 初始其他貸款",
            transactionDate: date
        )
    }
    
    private static func buy(
        id: String = UUID().uuidString,
        accountId: String,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        date: Date,
        name: String? = nil
    ) -> Transaction {
        let note = name.map { "買入 \(symbol) - \($0)" } ?? "買入 \(symbol)"
        return Transaction(id: id, accountId: accountId, type: .buy, assetType: assetType, symbol: symbol, quantity: quantity, price: price, currency: currency, notes: note, transactionDate: date, deductFromAccount: true)
    }

    private static func dividend(
        id: String,
        accountId: String,
        amount: Decimal,
        currency: Currency,
        date: Date,
        note: String
    ) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            type: .dividend,
            assetType: .cash,
            symbol: "CASH",
            quantity: amount,
            price: 1,
            currency: currency,
            notes: note,
            transactionDate: date
        )
    }

    private static func withdraw(
        id: String,
        accountId: String,
        amount: Decimal,
        currency: Currency,
        date: Date,
        note: String
    ) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            type: .withdraw,
            assetType: .cash,
            symbol: "CASH",
            quantity: amount,
            price: 1,
            currency: currency,
            notes: note,
            transactionDate: date
        )
    }

    private static func fee(
        id: String,
        accountId: String,
        amount: Decimal,
        currency: Currency,
        date: Date
    ) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            type: .fee,
            assetType: .cash,
            symbol: "CASH",
            quantity: 1,
            price: amount,
            currency: currency,
            notes: "手續費",
            transactionDate: date
        )
    }
    
    private static func sell(
        id: String = UUID().uuidString,
        accountId: String,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        date: Date,
        realizedCostPerUnit: Decimal
    ) -> Transaction {
        let proceeds = quantity * price
        let costBasis = quantity * realizedCostPerUnit
        let gain = proceeds - costBasis
        let pct = costBasis > 0 ? (gain / costBasis) * 100 : 0
        return Transaction(
            id: id,
            accountId: accountId,
            type: .sell,
            assetType: assetType,
            symbol: symbol,
            quantity: quantity,
            price: price,
            currency: currency,
            notes: "賣出 \(symbol)",
            transactionDate: date,
            realizedGainLoss: gain,
            realizedGainLossPercent: pct,
            realizedCostBasis: costBasis,
            realizedCostPerUnit: realizedCostPerUnit
        )
    }
    
}

struct DemoPriceService: PriceServiceProtocol {
    let seed: DemoSeedData
    private let priceByKey: [String: Decimal]

    init(seed: DemoSeedData) {
        self.seed = seed
        priceByKey = Dictionary(
            uniqueKeysWithValues: seed.assetPriceSnapshots.map { snapshot in
                (snapshot.id, snapshot.currentPrice ?? 0)
            }
        )
    }

    func fetchCurrentPrice(assetType: AssetType, symbol: String, coingeckoId: String?) async throws -> Decimal? {
        let key = "\(assetType.rawValue)_\(symbol)"
        guard let price = priceByKey[key], price > 0 else { return nil }
        return price
    }

    func fetchHistoricalPrices(assetType: AssetType, symbol: String, days: Int) async throws -> [Price] {
        []
    }
}
