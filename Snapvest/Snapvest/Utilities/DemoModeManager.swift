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
            syncPortfolio: false,
            updatePriceMetadata: false
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
        NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
    }
}

struct DemoSeedData {
    let userId: String
    let accounts: [Account]
    let transactionsByAccountId: [String: [Transaction]]
    let liabilitiesByAccountId: [String: [Liability]]
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
        
        let transactionsByAccountId: [String: [Transaction]] = [
            twdCash.id: [
                deposit(accountId: twdCash.id, amount: decimal("280000"), currency: .TWD, date: daysAgo(350, today: today), note: "Demo 起始現金")
            ],
            twdSecurities.id: [
                deposit(accountId: twdSecurities.id, amount: decimal("100000"), currency: .TWD, date: daysAgo(320, today: today), note: "Demo 證券戶現金"),
                buy(accountId: twdSecurities.id, assetType: .stockTW, symbol: "2330", quantity: decimal("250"), price: decimal("760"), currency: .TWD, date: daysAgo(300, today: today), name: "台積電"),
                sell(accountId: twdSecurities.id, assetType: .stockTW, symbol: "2330", quantity: decimal("50"), price: decimal("910"), currency: .TWD, date: daysAgo(45, today: today), realizedCostPerUnit: decimal("760")),
                buy(accountId: twdSecurities.id, assetType: .stockTW, symbol: "0050", quantity: decimal("500"), price: decimal("155"), currency: .TWD, date: daysAgo(240, today: today), name: "元大台灣50"),
                buy(accountId: twdSecurities.id, assetType: .stockTW, symbol: "2317", quantity: decimal("350"), price: decimal("165"), currency: .TWD, date: daysAgo(170, today: today), name: "鴻海")
            ],
            usdSecurities.id: [
                deposit(accountId: usdSecurities.id, amount: decimal("1500"), currency: .USD, date: daysAgo(280, today: today), note: "Demo 美金現金"),
                buy(accountId: usdSecurities.id, assetType: .stockUS, symbol: "VOO", quantity: decimal("8"), price: decimal("460"), currency: .USD, date: daysAgo(260, today: today)),
                buy(accountId: usdSecurities.id, assetType: .stockUS, symbol: "AAPL", quantity: decimal("15"), price: decimal("170"), currency: .USD, date: daysAgo(220, today: today)),
                buy(accountId: usdSecurities.id, assetType: .stockUS, symbol: "NVDA", quantity: decimal("45"), price: decimal("95"), currency: .USD, date: daysAgo(190, today: today)),
                sell(accountId: usdSecurities.id, assetType: .stockUS, symbol: "NVDA", quantity: decimal("10"), price: decimal("128"), currency: .USD, date: daysAgo(35, today: today), realizedCostPerUnit: decimal("95")),
                buy(accountId: usdSecurities.id, assetType: .stockUS, symbol: "MSFT", quantity: decimal("6"), price: decimal("385"), currency: .USD, date: daysAgo(150, today: today))
            ],
            cryptoWallet.id: [
                buy(accountId: cryptoWallet.id, assetType: .crypto, symbol: "BTC", quantity: decimal("0.04"), price: decimal("68000"), currency: .USD, date: daysAgo(210, today: today)),
                buy(accountId: cryptoWallet.id, assetType: .crypto, symbol: "ETH", quantity: decimal("0.5"), price: decimal("2800"), currency: .USD, date: daysAgo(140, today: today)),
                buy(accountId: cryptoWallet.id, assetType: .crypto, symbol: "USDT", quantity: decimal("700"), price: decimal("1"), currency: .USD, date: daysAgo(90, today: today))
            ],
            otherDebt.id: [
                otherDebtInitial(accountId: otherDebt.id, amount: decimal("16000"), date: daysAgo(160, today: today))
            ]
        ]
        
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
        
        let priceSnapshots: [AssetPriceSnapshot] = []
        
        return DemoSeedData(
            userId: userId,
            accounts: accounts,
            transactionsByAccountId: transactionsByAccountId,
            liabilitiesByAccountId: liabilitiesByAccountId,
            assetPriceSnapshots: priceSnapshots,
            trendPoints: makeTrendPoints(today: today)
        )
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
                volatility = 14_000
            } else if progress < 0.58 {
                volatility = 21_000
            } else if progress < 0.78 {
                volatility = 36_000
            } else {
                volatility = 28_000
            }
            
            let shock = seededNoise(index, salt: 11)
            let clusterShock = seededNoise(index / 4, salt: 73) * 0.55
            momentum = momentum * 0.62 + (shock + clusterShock) * volatility
            let dailyNoise = momentum
            let surge = eventPulse(progress, start: 0.48, end: 0.68, amplitude: 16_500)
            let crash = eventPulse(progress, start: 0.68, end: 0.76, amplitude: -35_000)
            let rebound = eventPulse(progress, start: 0.84, end: 0.98, amplitude: 14_500)
            let correction = eventPulse(progress, start: 0.90, end: 0.94, amplitude: -15_000)
            
            value += trendDrift + dailyNoise + surge + crash + rebound + correction
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
    
    private static func deposit(accountId: String, amount: Decimal, currency: Currency, date: Date, note: String) -> Transaction {
        Transaction(accountId: accountId, type: .deposit, assetType: .cash, symbol: "CASH", quantity: amount, price: 1, currency: currency, notes: note, transactionDate: date)
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
    
    private static func buy(accountId: String, assetType: AssetType, symbol: String, quantity: Decimal, price: Decimal, currency: Currency, date: Date, name: String? = nil) -> Transaction {
        let note = name.map { "買入 \(symbol) - \($0)" } ?? "買入 \(symbol)"
        return Transaction(accountId: accountId, type: .buy, assetType: assetType, symbol: symbol, quantity: quantity, price: price, currency: currency, notes: note, transactionDate: date, deductFromAccount: false)
    }
    
    private static func sell(accountId: String, assetType: AssetType, symbol: String, quantity: Decimal, price: Decimal, currency: Currency, date: Date, realizedCostPerUnit: Decimal) -> Transaction {
        let proceeds = quantity * price
        let costBasis = quantity * realizedCostPerUnit
        let gain = proceeds - costBasis
        let pct = costBasis > 0 ? (gain / costBasis) * 100 : 0
        return Transaction(
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
    
    func fetchCurrentPrice(assetType: AssetType, symbol: String, coingeckoId: String?) async throws -> Decimal? {
        await SupabasePriceService.fetchDisplayPrice(
            assetType: assetType,
            symbol: symbol,
            coingeckoId: coingeckoId
        )
    }
    
    func fetchHistoricalPrices(assetType: AssetType, symbol: String, days: Int) async throws -> [Price] {
        []
    }
}
