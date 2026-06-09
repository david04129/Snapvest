//
//  DemoSeedData.swift
//  Snapvest
//
//  示範帳本 seed：目標 rebuild 後總資產約 340 萬、淨資產約 300 萬、
//  現金約 3 成、投資約 7 成、負債約 40 萬（依雲端即時股價略有浮動）。
//  交易成交價：Yahoo Finance 各交易日收盤價（台股以 Asia/Taipei 對齊）；
//  賣出成本依 FIFO 對應先前買入均價。
//

import Foundation

struct DemoSeedData {
    let userId: String
    let accounts: [Account]
    let transactionsByAccountId: [String: [Transaction]]
    let liabilitiesByAccountId: [String: [Liability]]
    let manualAssets: [ManualAsset]
    let manualAssetValuationsByAssetId: [String: [ManualAssetValuation]]

    static func make(userId: String) -> DemoSeedData {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)

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
        let (manualAssets, manualValuations) = makeManualAssets(userId: userId, today: today, now: now)

        return DemoSeedData(
            userId: userId,
            accounts: accounts,
            transactionsByAccountId: makeTransactions(
                today: today,
                twdCash: twdCash,
                twdSecurities: twdSecurities,
                usdSecurities: usdSecurities,
                cryptoWallet: cryptoWallet,
                otherDebt: otherDebt
            ),
            liabilitiesByAccountId: [
                installmentDebt.id: [
                    Liability(
                        id: "demo-liability-car-loan",
                        accountId: installmentDebt.id,
                        name: "車貸",
                        principal: decimal("520000"),
                        interestRate: decimal("2.4"),
                        monthlyPayment: decimal("12800"),
                        remainingBalance: decimal("320000"),
                        currency: .TWD,
                        startDate: daysAgo(420, today: today),
                        totalPeriods: 36,
                        paidPeriods: 14,
                        totalPaidPrincipal: decimal("160000"),
                        totalPaidInterest: decimal("11000")
                    )
                ]
            ],
            manualAssets: manualAssets,
            manualAssetValuationsByAssetId: manualValuations
        )
    }

    // MARK: - Manual assets（投資類 + 其他資產，含 valuation 流水）

    private static func makeManualAssets(
        userId: String,
        today: Date,
        now: Date
    ) -> ([ManualAsset], [String: [ManualAssetValuation]]) {
        let specs: [(String, String, ManualAssetCategory, String, String, Bool)] = [
            ("demo-manual-fund", "基金", .fund, "150000", "135000", true),
            ("demo-manual-bond", "公司債券", .bond, "100000", "95000", true),
            ("demo-manual-gold", "實體黃金", .preciousMetal, "55000", "48000", false),
            ("demo-manual-collectible", "限量腕表", .collectible, "65000", "58000", false),
        ]
        var assets: [ManualAsset] = []
        var valuations: [String: [ManualAssetValuation]] = [:]

        for spec in specs {
            let purchaseDate = daysAgo(300, today: today)
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
                    id: "\(asset.id)-mid",
                    userId: userId,
                    manualAssetId: asset.id,
                    value: (decimal(spec.4) + decimal(spec.3)) / 2,
                    currency: .TWD,
                    valuationDate: daysAgo(120, today: today),
                    notes: "Demo 期中調整",
                    createdAt: daysAgo(120, today: today)
                ),
                ManualAssetValuation(
                    id: "\(asset.id)-update",
                    userId: userId,
                    manualAssetId: asset.id,
                    value: decimal(spec.3),
                    currency: .TWD,
                    valuationDate: daysAgo(40, today: today),
                    notes: "Demo 更新現值",
                    createdAt: daysAgo(40, today: today)
                ),
            ]
        }
        return (assets, valuations)
    }

    // MARK: - Transactions

    private static func makeTransactions(
        today: Date,
        twdCash: Account,
        twdSecurities: Account,
        usdSecurities: Account,
        cryptoWallet: Account,
        otherDebt: Account
    ) -> [String: [Transaction]] {
        var tw: [Transaction] = [
            deposit(id: "demo-txn-tw-open", accountId: twdSecurities.id, amount: decimal("980000"), currency: .TWD, date: daysAgo(328, today: today), note: "Demo 證券戶入金"),
        ]
        tw.append(contentsOf: twStockTrades(accountId: twdSecurities.id, today: today))

        var us: [Transaction] = [
            deposit(id: "demo-txn-us-open", accountId: usdSecurities.id, amount: decimal("31500"), currency: .USD, date: daysAgo(310, today: today), note: "Demo 美金入金"),
        ]
        us.append(contentsOf: usStockTrades(accountId: usdSecurities.id, today: today))

        var crypto: [Transaction] = [
            deposit(id: "demo-txn-crypto-open", accountId: cryptoWallet.id, amount: decimal("13500"), currency: .USD, date: daysAgo(300, today: today), note: "Demo 加密帳戶入金"),
        ]
        crypto.append(contentsOf: cryptoTrades(accountId: cryptoWallet.id, today: today))

        let cashFlow: [Transaction] = [
            deposit(id: "demo-txn-cash-1", accountId: twdCash.id, amount: decimal("380000"), currency: .TWD, date: daysAgo(350, today: today), note: "Demo 薪資入帳"),
            deposit(id: "demo-txn-cash-2", accountId: twdCash.id, amount: decimal("60000"), currency: .TWD, date: daysAgo(180, today: today), note: "年終獎金"),
            deposit(id: "demo-txn-cash-3", accountId: twdCash.id, amount: decimal("28000"), currency: .TWD, date: daysAgo(70, today: today), note: "副業收入"),
            withdraw(id: "demo-txn-cash-w1", accountId: twdCash.id, amount: decimal("28000"), currency: .TWD, date: daysAgo(290, today: today), note: "房租"),
            withdraw(id: "demo-txn-cash-w2", accountId: twdCash.id, amount: decimal("18000"), currency: .TWD, date: daysAgo(220, today: today), note: "保險費"),
            withdraw(id: "demo-txn-cash-w3", accountId: twdCash.id, amount: decimal("32000"), currency: .TWD, date: daysAgo(95, today: today), note: "旅遊"),
        ]

        return [
            twdCash.id: cashFlow,
            twdSecurities.id: tw.sorted { $0.transactionDate < $1.transactionDate },
            usdSecurities.id: us.sorted { $0.transactionDate < $1.transactionDate },
            cryptoWallet.id: crypto.sorted { $0.transactionDate < $1.transactionDate },
            otherDebt.id: [
                otherDebtInitial(accountId: otherDebt.id, amount: decimal("80000"), date: daysAgo(160, today: today))
            ]
        ]
    }

    /// 台股 0050 / 006208
    private static func twStockTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockTW, symbol: "0050", name: "元大台灣50", rows: [
            .buy("demo-0050-b1", 280, "400", "52"),
            .buy("demo-0050-b2", 240, "300", "60"),
            .sell("demo-0050-s1", 210, "100", "65", cost: "52"),
            .buy("demo-0050-b3", 175, "250", "63"),
            .sell("demo-0050-s2", 140, "80", "70", cost: "52"),
            .buy("demo-0050-b4", 100, "200", "77"),
            .buy("demo-0050-b5", 55, "150", "74"),
            .sell("demo-0050-s6", 30, "60", "90", cost: "52"),
            .buy("demo-0050-b6", 12, "80", "93"),
        ])
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockTW, symbol: "006208", name: "富邦台50", rows: [
            .buy("demo-6208-b1", 270, "900", "121.4"),
            .buy("demo-6208-b2", 230, "680", "142.05"),
            .sell("demo-6208-s1", 200, "230", "148.05", cost: "121.4"),
            .buy("demo-6208-b3", 165, "815", "142.05"),
            .sell("demo-6208-s2", 130, "270", "164.1", cost: "121.4"),
            .buy("demo-6208-b4", 95, "545", "187.75"),
            .buy("demo-6208-b5", 50, "450", "187.3"),
        ])
        return trades
    }

    /// 美股 NVDA / GOOG / META / QQQ
    private static func usStockTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "NVDA", name: "NVIDIA", rows: [
            .buy("demo-nvda-b1", 285, "8", "175.64"),
            .buy("demo-nvda-b2", 250, "6", "178.43"),
            .sell("demo-nvda-s1", 220, "2", "182.16", cost: "175.64"),
            .buy("demo-nvda-b3", 185, "5", "180.26"),
            .buy("demo-nvda-b4", 140, "6", "184.86"),
            .sell("demo-nvda-s2", 100, "2", "189.82", cost: "175.64"),
            .buy("demo-nvda-b5", 60, "5", "175.75"),
            .buy("demo-nvda-b6", 20, "4", "219.44"),
        ])
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "GOOG", name: "Alphabet", rows: [
            .buy("demo-goog-b1", 275, "5", "213.53"),
            .buy("demo-goog-b2", 235, "4", "245.46"),
            .sell("demo-goog-s1", 205, "1", "279.7", cost: "213.53"),
            .buy("demo-goog-b3", 170, "4", "310.52"),
            .buy("demo-goog-b4", 120, "3", "338.53"),
            .sell("demo-goog-s2", 80, "1", "303.21", cost: "213.53"),
            .buy("demo-goog-b5", 35, "3", "342.32"),
        ])
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "META", name: "Meta", rows: [
            .buy("demo-meta-b1", 265, "3", "752.3"),
            .buy("demo-meta-b2", 225, "2", "716.92"),
            .sell("demo-meta-s1", 195, "1", "602.01", cost: "752.3"),
            .buy("demo-meta-b3", 155, "2", "663.29"),
            .buy("demo-meta-b4", 90, "2", "653.56"),
            .sell("demo-meta-s2", 50, "1", "629.86", cost: "752.3"),
            .buy("demo-meta-b5", 18, "1", "616.63"),
        ])
        appendTrades(&trades, accountId: accountId, today: today, assetType: .stockUS, symbol: "QQQ", name: "Invesco QQQ", rows: [
            .buy("demo-qqq-b1", 260, "4", "586.66"),
            .buy("demo-qqq-b2", 215, "3", "632.92"),
            .sell("demo-qqq-s1", 180, "1", "622", cost: "586.66"),
            .buy("demo-qqq-b3", 145, "3", "623.42"),
            .buy("demo-qqq-b4", 85, "2", "599.75"),
            .sell("demo-qqq-s2", 45, "1", "640.47", cost: "586.66"),
            .buy("demo-qqq-b5", 15, "2", "708.93"),
        ])
        return trades
    }

    /// 加密 BTC
    private static func cryptoTrades(accountId: String, today: Date) -> [Transaction] {
        var trades: [Transaction] = []
        appendTrades(&trades, accountId: accountId, today: today, assetType: .crypto, symbol: "BTC", name: "Bitcoin", rows: [
            .buy("demo-btc-b1", 280, "0.018", "113458.43"),
            .buy("demo-btc-b2", 240, "0.012", "122266.53"),
            .sell("demo-btc-s1", 200, "0.004", "101663.19", cost: "113458.43"),
            .buy("demo-btc-b3", 160, "0.01", "88490.02"),
            .buy("demo-btc-b4", 110, "0.008", "68793.96"),
            .sell("demo-btc-s2", 70, "0.003", "67845.21", cost: "113458.43"),
            .buy("demo-btc-b5", 35, "0.006", "78657.54"),
        ])
        return trades
    }

    private struct DemoTradeSpec {
        let id: String
        let daysAgo: Int
        let side: String
        let quantity: String
        let price: String
        let cost: String?

        static func buy(_ id: String, _ daysAgo: Int, _ quantity: String, _ price: String) -> DemoTradeSpec {
            DemoTradeSpec(id: id, daysAgo: daysAgo, side: "buy", quantity: quantity, price: price, cost: nil)
        }

        static func sell(_ id: String, _ daysAgo: Int, _ quantity: String, _ price: String, cost: String) -> DemoTradeSpec {
            DemoTradeSpec(id: id, daysAgo: daysAgo, side: "sell", quantity: quantity, price: price, cost: cost)
        }
    }

    private static func appendTrades(
        _ trades: inout [Transaction],
        accountId: String,
        today: Date,
        assetType: AssetType,
        symbol: String,
        name: String,
        rows: [DemoTradeSpec]
    ) {
        for row in rows {
            let date = daysAgo(row.daysAgo, today: today)
            let currency: Currency = assetType == .stockTW ? .TWD : .USD
            if row.side == "buy" {
                trades.append(
                    buy(
                        id: row.id,
                        accountId: accountId,
                        assetType: assetType,
                        symbol: symbol,
                        quantity: decimal(row.quantity),
                        price: decimal(row.price),
                        currency: currency,
                        date: date,
                        name: name
                    )
                )
            } else {
                trades.append(
                    sell(
                        id: row.id,
                        accountId: accountId,
                        assetType: assetType,
                        symbol: symbol,
                        quantity: decimal(row.quantity),
                        price: decimal(row.price),
                        currency: currency,
                        date: date,
                        realizedCostPerUnit: decimal(row.cost ?? row.price)
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func daysAgo(_ days: Int, today: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: today) ?? today
    }

    private static func deposit(
        id: String,
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
            notes: "Demo 信用卡分期",
            transactionDate: date
        )
    }

    private static func buy(
        id: String,
        accountId: String,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        date: Date,
        name: String
    ) -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            type: .buy,
            assetType: assetType,
            symbol: symbol,
            quantity: quantity,
            price: price,
            currency: currency,
            notes: "買入 \(symbol) - \(name)",
            transactionDate: date,
            deductFromAccount: true
        )
    }

    private static func sell(
        id: String,
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
}
