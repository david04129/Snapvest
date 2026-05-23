//
//  DataService.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

enum DataServiceError: LocalizedError {
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidOperation(let message):
            return message
        }
    }
}

/// 資料服務協議
protocol DataServiceProtocol {
    // 使用者
    func fetchUser(userId: String) async throws -> User?
    func updateUser(_ user: User) async throws
    
    // 帳戶
    func fetchAccounts(userId: String) async throws -> [Account]
    func createAccount(_ account: Account) async throws
    func updateAccount(_ account: Account) async throws
    func deleteAccount(_ accountId: String) async throws
    func archiveDebtAccount(_ account: Account) async throws
    
    // 交易
    func fetchTransactions(accountId: String) async throws -> [Transaction]
    func fetchAllTransactions(userId: String) async throws -> [Transaction]
    func createTransaction(_ transaction: Transaction) async throws
    func updateTransaction(_ transaction: Transaction) async throws
    func deleteTransaction(_ transactionId: String) async throws
    
    // 持股
    func fetchHoldings(accountId: String) async throws -> [Holding]
    func updateHolding(_ holding: Holding) async throws
    func deleteHolding(_ holdingId: String) async throws
    
    // 負債
    func fetchLiabilities(accountId: String) async throws -> [Liability]
    func createLiability(_ liability: Liability) async throws
    func updateLiability(_ liability: Liability) async throws
    func deleteLiability(_ liabilityId: String) async throws
    
    // 價格
    func fetchPrice(assetType: AssetType, symbol: String, date: Date?) async throws -> Price?
    func fetchPrices(assetType: AssetType, symbol: String, startDate: Date, endDate: Date) async throws -> [Price]
    
    // 匯率
    func fetchExchangeRate(from: Currency, to: Currency, date: Date?) async throws -> ExchangeRate?
    
    // 快照
    func fetchSnapshots(userId: String, startDate: Date?, endDate: Date?) async throws -> [Snapshot]
    func createSnapshot(_ snapshot: Snapshot) async throws
    
    // 帳戶快照
    func fetchAccountSnapshot(accountId: String) async throws -> AccountSnapshot?
    func saveAccountSnapshot(_ snapshot: AccountSnapshot) async throws
    func deleteAccountSnapshot(accountId: String) async throws
    
    // 資產價格快照
    func fetchAssetPriceSnapshot(assetType: AssetType, symbol: String) async throws -> AssetPriceSnapshot?
    func fetchAssetPriceSnapshots(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot]
    func saveAssetPriceSnapshot(_ snapshot: AssetPriceSnapshot) async throws
    func deleteAssetPriceSnapshot(assetType: AssetType, symbol: String) async throws
    
    // 使用者持股快照
    func fetchUserHoldingsSnapshot(userId: String) async throws -> UserHoldingsSnapshot?
    func saveUserHoldingsSnapshot(_ snapshot: UserHoldingsSnapshot) async throws
    func deleteUserHoldingsSnapshot(userId: String) async throws
    
    // 跨帳戶合併持股快照
    func fetchAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws -> AggregatedHoldingSnapshot?
    func fetchAggregatedHoldingSnapshots(userId: String, assetType: AssetType?) async throws -> [AggregatedHoldingSnapshot]
    func saveAggregatedHoldingSnapshot(_ snapshot: AggregatedHoldingSnapshot) async throws
    func deleteAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws

    // 首頁快照
    func fetchHomeDashboardSnapshot(userId: String) async throws -> HomeDashboardSnapshot?
    func saveHomeDashboardSnapshot(_ snapshot: HomeDashboardSnapshot) async throws
    func deleteHomeDashboardSnapshot(userId: String) async throws
}

/// 資料服務實作（目前為 Mock，之後可替換為 Firebase/Supabase）
class MockDataService: DataServiceProtocol {
    // TODO: 實作 Firebase/Supabase 整合
    
    // 單例模式，確保資料共享
    static let shared = MockDataService()
    
    // 記憶體儲存（用於 Mock 測試）
    private var accounts: [String: [Account]] = [:] // userId: [Account]
    private var transactions: [String: [Transaction]] = [:] // accountId: [Transaction]
    private var holdings: [String: [Holding]] = [:] // accountId: [Holding]
    private var liabilities: [String: [Liability]] = [:] // accountId: [Liability]
    
    // 快照儲存
    private var accountSnapshots: [String: AccountSnapshot] = [:] // accountId: AccountSnapshot
    private var assetPriceSnapshots: [String: AssetPriceSnapshot] = [:] // "assetType_symbol": AssetPriceSnapshot
    private var userHoldingsSnapshots: [String: UserHoldingsSnapshot] = [:] // userId: UserHoldingsSnapshot
    private var aggregatedHoldingSnapshots: [String: AggregatedHoldingSnapshot] = [:] // "userId_assetType_symbol": AggregatedHoldingSnapshot
    private var homeDashboardSnapshots: [String: HomeDashboardSnapshot] = [:] // userId: HomeDashboardSnapshot
    
    // 私有初始化，強制使用單例
    private init() {
        // 預設帳戶會在第一次 fetchAccounts 時建立
    }
    
    func fetchUser(userId: String) async throws -> User? {
        // Mock 實作
        return User(id: userId, email: "user@example.com", displayName: "測試使用者")
    }
    
    func updateUser(_ user: User) async throws {
        // Mock 實作
    }
    
    func fetchAccounts(userId: String) async throws -> [Account] {
        // 如果沒有帳戶，建立預設帳戶和測試資料
        if accounts[userId] == nil || accounts[userId]!.isEmpty {
            let twdDepositAccount = Account(userId: userId, name: "國泰銀行", accountType: .twdDeposit)
            let twdSecuritiesAccount = Account(userId: userId, name: "台股帳戶", accountType: .twdSecurities)
            let usdAccount = Account(userId: userId, name: "美股帳戶", accountType: .usdAccount)
            let cryptoWallet = Account(userId: userId, name: "加密貨幣錢包", accountType: .cryptoWallet)
            
            accounts[userId] = [
                twdDepositAccount,
                twdSecuritiesAccount,
                usdAccount,
                cryptoWallet
            ]
            
            // 創建初始債務數據（10萬貸款）
            await initializeMockLiabilities(userId: userId, repaymentAccount: twdDepositAccount)
            
            // 添加測試交易記錄
            let calendar = Calendar.current
            let today = Date()
            
            // 台幣存款帳戶：初始存入 10,000 TWD
            let deposit1 = Transaction(
                accountId: twdDepositAccount.id,
                type: .deposit,
                assetType: .cash,
                symbol: "CASH",
                quantity: 10000,
                price: 1,
                currency: .TWD,
                fee: 0,
                notes: "初始餘額",
                transactionDate: calendar.date(byAdding: .day, value: -5, to: today) ?? today
            )
            
            // 台股帳戶：初始存入 150,000 TWD（確保足夠買入所有股票）
            let deposit2 = Transaction(
                accountId: twdSecuritiesAccount.id,
                type: .deposit,
                assetType: .cash,
                symbol: "CASH",
                quantity: 150000,
                price: 1,
                currency: .TWD,
                fee: 0,
                notes: "起始資金",
                transactionDate: calendar.date(byAdding: .day, value: -20, to: today) ?? today
            )
            
            // 台股帳戶：僅兩檔，每檔多筆交易
            var twStockTransactions: [Transaction] = [deposit2]
            let twStockBuys: [(String, String, Decimal, Decimal, Int)] = [
                ("2330", "台積電", 500, 2, -19),
                ("2330", "台積電", 520, 1, -12),
                ("2317", "鴻海", 100, 5, -18),
                ("2317", "鴻海", 105, 3, -9)
            ]
            for (symbol, name, price, quantity, dayOffset) in twStockBuys {
                let buy = Transaction(
                    accountId: twdSecuritiesAccount.id,
                    type: .buy,
                    assetType: .stockTW,
                    symbol: symbol,
                    quantity: quantity,
                    price: price,
                    currency: .TWD,
                    fee: (quantity * price) * 0.001425,
                    notes: "買入\(name)",
                    transactionDate: calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
                )
                twStockTransactions.append(buy)
            }
            
            // 美股帳戶：初始存入 5,000 USD（確保足夠買入所有股票）
            let deposit3 = Transaction(
                accountId: usdAccount.id,
                type: .deposit,
                assetType: .cash,
                symbol: "CASH",
                quantity: 5000,
                price: 1,
                currency: .USD,
                fee: 0,
                notes: "初始資金",
                transactionDate: calendar.date(byAdding: .day, value: -20, to: today) ?? today
            )
            
            // 美股帳戶：僅兩檔，每檔多筆交易
            var usStockTransactions: [Transaction] = [deposit3]
            let usStockBuys: [(String, Decimal, Decimal, Int)] = [
                ("NVDA", 450, 1, -18),
                ("NVDA", 470, 1, -10),
                ("AAPL", 180, 2, -17),
                ("AAPL", 185, 1, -8)
            ]
            for (symbol, price, quantity, dayOffset) in usStockBuys {
                let buy = Transaction(
                    accountId: usdAccount.id,
                    type: .buy,
                    assetType: .stockUS,
                    symbol: symbol,
                    quantity: quantity,
                    price: price,
                    currency: .USD,
                    fee: 1,
                    notes: "買入\(symbol)",
                    transactionDate: calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
                )
                usStockTransactions.append(buy)
            }
            
            // 加密貨幣錢包：初始存入 10,000 USD（確保足夠買入所有加密貨幣）
            let deposit4 = Transaction(
                accountId: cryptoWallet.id,
                type: .deposit,
                assetType: .cash,
                symbol: "CASH",
                quantity: 10000,
                price: 1,
                currency: .USD,
                fee: 0,
                notes: "初始資金",
                transactionDate: calendar.date(byAdding: .day, value: -20, to: today) ?? today
            )
            
            // 加密貨幣錢包：僅兩檔，每檔多筆交易
            var cryptoTransactions: [Transaction] = [deposit4]
            let cryptoBuys: [(String, Decimal, Decimal, Int)] = [
                ("BTC", 52000, 0.01, -18),
                ("BTC", 54000, 0.005, -11),
                ("ETH", 3000, 0.1, -17),
                ("ETH", 3200, 0.05, -7)
            ]
            for (symbol, price, quantity, dayOffset) in cryptoBuys {
                let buy = Transaction(
                    accountId: cryptoWallet.id,
                    type: .buy,
                    assetType: .crypto,
                    symbol: symbol,
                    quantity: quantity,
                    price: price,
                    currency: .USD,
                    fee: (quantity * price) * 0.001,
                    notes: "買入\(symbol)",
                    transactionDate: calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
                )
                cryptoTransactions.append(buy)
            }
            
            // 添加交易記錄
            transactions[twdDepositAccount.id] = [deposit1]
            transactions[twdSecuritiesAccount.id] = twStockTransactions
            transactions[usdAccount.id] = usStockTransactions
            transactions[cryptoWallet.id] = cryptoTransactions
        }
        return accounts[userId] ?? []
    }
    
    func createAccount(_ account: Account) async throws {
        // 將新帳戶加入記憶體儲存
        if accounts[account.userId] == nil {
            accounts[account.userId] = []
        }
        accounts[account.userId]?.append(account)
    }
    
    func updateAccount(_ account: Account) async throws {
        // 更新記憶體中的帳戶
        if var userAccounts = accounts[account.userId] {
            if let index = userAccounts.firstIndex(where: { $0.id == account.id }) {
                userAccounts[index] = account
                accounts[account.userId] = userAccounts
            }
        }
    }
    
    func deleteAccount(_ accountId: String) async throws {
        // 從記憶體中刪除帳戶
        for (userId, userAccounts) in accounts {
            if let index = userAccounts.firstIndex(where: { $0.id == accountId }) {
                accounts[userId]?.remove(at: index)
                // 同時刪除相關的交易和持股
                transactions.removeValue(forKey: accountId)
                holdings.removeValue(forKey: accountId)
                liabilities.removeValue(forKey: accountId)
                break
            }
        }
    }
    
    func archiveDebtAccount(_ account: Account) async throws {
        guard account.accountType == .debt else {
            throw DataServiceError.invalidOperation("僅債務帳戶可封存")
        }
        guard !account.isArchived else { return }
        
        var allLiabilities: [Liability] = []
        if let userAccounts = accounts[account.userId] {
            for repaymentAccount in userAccounts where repaymentAccount.accountType != .debt {
                allLiabilities.append(contentsOf: liabilities[repaymentAccount.id] ?? [])
            }
        }
        let matchedLiability = DebtAccountArchive.liability(forDebtAccount: account, in: allLiabilities)
        let (allowed, reason) = DebtAccountArchive.canArchive(debtAccount: account, liability: matchedLiability)
        guard allowed else {
            throw DataServiceError.invalidOperation(reason ?? "無法封存此帳戶")
        }
        
        var updated = account
        updated.isArchived = true
        updated.archivedAt = Date()
        updated.updatedAt = Date()
        try await updateAccount(updated)
    }
    
    func fetchTransactions(accountId: String) async throws -> [Transaction] {
        return transactions[accountId] ?? []
    }
    
    func fetchAllTransactions(userId: String) async throws -> [Transaction] {
        // 獲取該使用者的所有帳戶的交易
        let userAccounts = accounts[userId] ?? []
        var allTransactions: [Transaction] = []
        for account in userAccounts {
            allTransactions.append(contentsOf: transactions[account.id] ?? [])
        }
        return allTransactions
    }
    
    func createTransaction(_ transaction: Transaction) async throws {
        if transactions[transaction.accountId] == nil {
            transactions[transaction.accountId] = []
        }
        transactions[transaction.accountId]?.append(transaction)
    }
    
    func updateTransaction(_ transaction: Transaction) async throws {
        if var accountTransactions = transactions[transaction.accountId] {
            if let index = accountTransactions.firstIndex(where: { $0.id == transaction.id }) {
                accountTransactions[index] = transaction
                transactions[transaction.accountId] = accountTransactions
            }
        }
    }
    
    func deleteTransaction(_ transactionId: String) async throws {
        for (accountId, accountTransactions) in transactions {
            if let index = accountTransactions.firstIndex(where: { $0.id == transactionId }) {
                transactions[accountId]?.remove(at: index)
                break
            }
        }
    }
    
    func fetchHoldings(accountId: String) async throws -> [Holding] {
        return holdings[accountId] ?? []
    }
    
    func updateHolding(_ holding: Holding) async throws {
        if holdings[holding.accountId] == nil {
            holdings[holding.accountId] = []
        }
        if var accountHoldings = holdings[holding.accountId] {
            if let index = accountHoldings.firstIndex(where: { $0.id == holding.id }) {
                accountHoldings[index] = holding
            } else {
                accountHoldings.append(holding)
            }
            holdings[holding.accountId] = accountHoldings
        } else {
            holdings[holding.accountId] = [holding]
        }
    }
    
    func deleteHolding(_ holdingId: String) async throws {
        for (accountId, accountHoldings) in holdings {
            if let index = accountHoldings.firstIndex(where: { $0.id == holdingId }) {
                holdings[accountId]?.remove(at: index)
                break
            }
        }
    }
    
    func fetchLiabilities(accountId: String) async throws -> [Liability] {
        return liabilities[accountId] ?? []
    }
    
    private func initializeMockLiabilities(userId: String, repaymentAccount: Account) async {
        let calendar = Calendar.current
        let today = Date()
        
        // 10萬貸款，分12期，年利率2.3%
        let principal: Decimal = 100000
        let interestRate: Decimal = 2.3
        let periods = 12
        let monthlyRate = interestRate / 100 / 12
        let principalNS = NSDecimalNumber(decimal: principal)
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        let power = onePlusRate.raising(toPower: periods)
        let numerator = principalNS.multiplying(by: monthlyRateNS).multiplying(by: power)
        let denominator = power.subtracting(NSDecimalNumber.one)
        let monthlyPayment = numerator.dividing(by: denominator).decimalValue
        
        var dateComponents = calendar.dateComponents([.year, .month], from: today)
        dateComponents.day = 1
        let startDate = calendar.date(from: dateComponents) ?? today
        
        // 創建債務帳戶
        let debtAccount = Account(userId: userId, name: "10萬貸款", accountType: .debt)
        
        // 將債務帳戶加入帳戶列表
        if accounts[userId] == nil {
            accounts[userId] = []
        }
        accounts[userId]?.append(debtAccount)
        
        // 創建債務記錄
        let liability = Liability(
            accountId: repaymentAccount.id,
            name: "10萬貸款",
            principal: principal,
            interestRate: interestRate,
            monthlyPayment: monthlyPayment,
            remainingBalance: principal,
            currency: .TWD,
            startDate: startDate,
            totalPeriods: periods,
            paidPeriods: 0
        )
        
        try? await createLiability(liability)
        
        // 創建債務帳戶的初始交易記錄（.liability 類型）
        let liabilityTransaction = Transaction(
            accountId: debtAccount.id,
            type: .liability,
            assetType: .cash,
            symbol: "CASH",
            quantity: principal,
            price: 1,
            currency: .TWD,
            fee: 0,
            notes: "新增債務：10萬貸款",
            transactionDate: startDate
        )
        
        // 將交易記錄加入債務帳戶
        if transactions[debtAccount.id] == nil {
            transactions[debtAccount.id] = []
        }
        transactions[debtAccount.id]?.append(liabilityTransaction)
    }
    
    func createLiability(_ liability: Liability) async throws {
        if liabilities[liability.accountId] == nil {
            liabilities[liability.accountId] = []
        }
        liabilities[liability.accountId]?.append(liability)
    }
    
    func updateLiability(_ liability: Liability) async throws {
        if var accountLiabilities = liabilities[liability.accountId] {
            if let index = accountLiabilities.firstIndex(where: { $0.id == liability.id }) {
                accountLiabilities[index] = liability
                liabilities[liability.accountId] = accountLiabilities
            }
        }
    }
    
    func deleteLiability(_ liabilityId: String) async throws {
        for (accountId, accountLiabilities) in liabilities {
            if let index = accountLiabilities.firstIndex(where: { $0.id == liabilityId }) {
                liabilities[accountId]?.remove(at: index)
                break
            }
        }
    }
    
    func fetchPrice(assetType: AssetType, symbol: String, date: Date?) async throws -> Price? {
        // Mock 實作 - 返回模擬價格
        let mockPrices: [String: Decimal] = [
            // 台股
            "2330": 820, "2317": 60, "2454": 850, "2308": 260, "2891": 26,
            "2882": 52, "2886": 32, "1301": 95, "1303": 65, "2002": 27,
            "2412": 125, "2382": 190, "2379": 370, "3008": 2100, "2884": 30,
            // 美股
            "AAPL": 120, "MSFT": 360, "GOOGL": 145, "AMZN": 155, "TSLA": 255,
            "META": 310, "NVDA": 700, "JPM": 155, "V": 255, "JNJ": 165,
            "WMT": 155, "MA": 410, "PG": 155, "UNH": 510, "HD": 360,
            // 加密貨幣
            "BTC": 65000, "ETH": 2000, "BNB": 310, "SOL": 105, "ADA": 0.55,
            "XRP": 0.65, "DOGE": 0.085, "DOT": 7.5, "MATIC": 0.95, "AVAX": 36,
            "LINK": 16, "UNI": 6.5, "ATOM": 10.5, "ALGO": 0.22, "VET": 0.035
        ]
        
        let price = mockPrices[symbol] ?? 100
        
        // 根據資產類型決定貨幣
        let currency: Currency
        switch assetType {
        case .stockTW:
            currency = .TWD
        case .stockUS, .crypto:
            currency = .USD
        case .cash:
            currency = .TWD // 預設
        }
        
        return Price(
            assetType: assetType,
            symbol: symbol,
            price: price,
            currency: currency,
            priceDate: date ?? Date()
        )
    }
    
    func fetchPrices(assetType: AssetType, symbol: String, startDate: Date, endDate: Date) async throws -> [Price] {
        // Mock 實作
        return []
    }
    
    func fetchExchangeRate(from: Currency, to: Currency, date: Date?) async throws -> ExchangeRate? {
        // Mock 實作 - 返回假匯率
        let rate: Decimal
        if from == .USD && to == .TWD {
            rate = 32 // 1 USD = 32 TWD
        } else if from == .TWD && to == .USD {
            rate = 0.03125 // 1 TWD = 0.03125 USD (1/32)
        } else {
            rate = 1.0 // 相同貨幣或其他情況
        }
        return ExchangeRate(
            fromCurrency: from,
            toCurrency: to,
            rate: rate,
            rateDate: date ?? Date()
        )
    }
    
    func fetchSnapshots(userId: String, startDate: Date?, endDate: Date?) async throws -> [Snapshot] {
        // Mock 實作
        return []
    }
    
    func createSnapshot(_ snapshot: Snapshot) async throws {
        // Mock 實作
    }
    
    // MARK: - 帳戶快照
    
    func fetchAccountSnapshot(accountId: String) async throws -> AccountSnapshot? {
        return accountSnapshots[accountId]
    }
    
    func saveAccountSnapshot(_ snapshot: AccountSnapshot) async throws {
        accountSnapshots[snapshot.accountId] = snapshot
    }
    
    func deleteAccountSnapshot(accountId: String) async throws {
        accountSnapshots.removeValue(forKey: accountId)
    }
    
    // MARK: - 資產價格快照
    
    func fetchAssetPriceSnapshot(assetType: AssetType, symbol: String) async throws -> AssetPriceSnapshot? {
        let key = "\(assetType.rawValue)_\(symbol)"
        return assetPriceSnapshots[key]
    }
    
    func fetchAssetPriceSnapshots(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        var snapshots: [AssetPriceSnapshot] = []
        for symbolInfo in symbols {
            let key = "\(symbolInfo.assetType.rawValue)_\(symbolInfo.symbol)"
            if let snapshot = assetPriceSnapshots[key] {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }
    
    func saveAssetPriceSnapshot(_ snapshot: AssetPriceSnapshot) async throws {
        let key = snapshot.id
        assetPriceSnapshots[key] = snapshot
    }
    
    func deleteAssetPriceSnapshot(assetType: AssetType, symbol: String) async throws {
        let key = "\(assetType.rawValue)_\(symbol)"
        assetPriceSnapshots.removeValue(forKey: key)
    }
    
    // MARK: - 使用者持股快照
    
    func fetchUserHoldingsSnapshot(userId: String) async throws -> UserHoldingsSnapshot? {
        return userHoldingsSnapshots[userId]
    }
    
    func saveUserHoldingsSnapshot(_ snapshot: UserHoldingsSnapshot) async throws {
        userHoldingsSnapshots[snapshot.userId] = snapshot
    }
    
    func deleteUserHoldingsSnapshot(userId: String) async throws {
        userHoldingsSnapshots.removeValue(forKey: userId)
    }
    
    // MARK: - 跨帳戶合併持股快照
    
    func fetchAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws -> AggregatedHoldingSnapshot? {
        let key = "\(userId)_\(assetType.rawValue)_\(symbol)"
        return aggregatedHoldingSnapshots[key]
    }
    
    func fetchAggregatedHoldingSnapshots(userId: String, assetType: AssetType?) async throws -> [AggregatedHoldingSnapshot] {
        if let assetType = assetType {
            // 過濾特定資產類型
            return aggregatedHoldingSnapshots.values.filter { snapshot in
                snapshot.userId == userId && snapshot.assetType == assetType
            }
        } else {
            // 返回所有資產類型
            return aggregatedHoldingSnapshots.values.filter { snapshot in
                snapshot.userId == userId
            }
        }
    }
    
    func saveAggregatedHoldingSnapshot(_ snapshot: AggregatedHoldingSnapshot) async throws {
        let key = snapshot.id
        aggregatedHoldingSnapshots[key] = snapshot
    }
    
    func deleteAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws {
        let key = "\(userId)_\(assetType.rawValue)_\(symbol)"
        aggregatedHoldingSnapshots.removeValue(forKey: key)
    }

    func fetchHomeDashboardSnapshot(userId: String) async throws -> HomeDashboardSnapshot? {
        return homeDashboardSnapshots[userId]
    }

    func saveHomeDashboardSnapshot(_ snapshot: HomeDashboardSnapshot) async throws {
        homeDashboardSnapshots[snapshot.userId] = snapshot
    }

    func deleteHomeDashboardSnapshot(userId: String) async throws {
        homeDashboardSnapshots.removeValue(forKey: userId)
    }
}

