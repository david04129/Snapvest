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
    
    // 投資組合狀態（同步至後端）
    func syncPortfolioState(_ payload: PortfolioStateSyncPayload) async throws
    func fetchLatestPortfolioState(userId: String) async throws -> PortfolioStateSyncPayload?
    
    /// 將本機帳戶／交易／快照寫入 JSON（MockDataService 實作；其他實作可為空操作）
    func persistLocalStore(for userId: String)
    /// 僅寫入結構快照 A（帳戶／交易／負債）
    func persistLocalStructure(for userId: String)
    /// 僅寫入估值快照 B（股價／市值／首頁）
    func persistLocalValuation(for userId: String)
    
    /// 本機對齊過的 `price_update_metadata.last_updated_at`
    func fetchPriceSourceUpdatedAt(userId: String) -> Date?
    /// 本機成功同步股價的時間
    func fetchPriceSyncedAt(userId: String) -> Date?
    /// 估值快照 B 最後寫入時間
    func fetchValuationUpdatedAt(userId: String) -> Date?
    /// 結構快照 A 最後寫入時間
    func fetchStructureUpdatedAt(userId: String) -> Date?
    /// 成功同步股價後更新本機 metadata
    func updatePriceSyncMetadata(userId: String, sourceUpdatedAt: Date?)
}

/// 本機記憶體資料服務（帳戶／交易；股價／匯率走 Supabase）
class MockDataService: DataServiceProtocol {
    // 單例模式，確保資料共享
    static let shared = MockDataService()
    
    // 記憶體儲存
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
    private var portfolioStates: [String: PortfolioStateSyncPayload] = [:] // userId: latest state
    private var priceSyncedAtByUserId: [String: Date] = [:]
    private var priceSourceUpdatedAtByUserId: [String: Date] = [:]
    private var valuationUpdatedAtByUserId: [String: Date] = [:]
    private var structureUpdatedAtByUserId: [String: Date] = [:]
    private var pendingStructurePersistWorkItem: DispatchWorkItem?
    
    private init() {
        restorePersistedData(for: AppUser.id)
    }
    
    private func restorePersistedData(for userId: String) {
        guard let saved = LocalUserDataStore.load(userId: userId) else { return }
        accounts[userId] = saved.structure.accounts
        let accountIds = Set(saved.structure.accounts.map(\.id))
        for accountId in accountIds {
            if let accountTransactions = saved.structure.transactionsByAccountId[accountId] {
                transactions[accountId] = accountTransactions
            }
            if let accountLiabilities = saved.structure.liabilitiesByAccountId[accountId] {
                liabilities[accountId] = accountLiabilities
            }
        }
        applyValuationStore(saved.valuation, userId: userId)
        priceSyncedAtByUserId[userId] = saved.valuation.priceSyncedAt
        priceSourceUpdatedAtByUserId[userId] = saved.valuation.priceSourceUpdatedAt
        valuationUpdatedAtByUserId[userId] = saved.valuation.updatedAt
        structureUpdatedAtByUserId[userId] = saved.structure.updatedAt
    }
    
    private func applyValuationStore(_ store: LocalUserValuationStore, userId: String) {
        if let home = store.homeDashboardSnapshot {
            homeDashboardSnapshots[userId] = home
        }
        if let userHoldings = store.userHoldingsSnapshot {
            userHoldingsSnapshots[userId] = userHoldings
        }
        for (accountId, snapshot) in store.accountSnapshotsByAccountId {
            accountSnapshots[accountId] = snapshot
        }
        for (key, snapshot) in store.assetPriceSnapshotsByKey {
            assetPriceSnapshots[key] = snapshot
        }
        for snapshot in store.aggregatedHoldingSnapshots {
            aggregatedHoldingSnapshots[snapshot.id] = snapshot
        }
    }
    
    private func buildStructureStore(for userId: String) -> LocalUserStructureStore {
        let userAccounts = accounts[userId] ?? []
        let accountIds = Set(userAccounts.map(\.id))
        var transactionsByAccountId: [String: [Transaction]] = [:]
        var liabilitiesByAccountId: [String: [Liability]] = [:]
        for accountId in accountIds {
            if let accountTransactions = transactions[accountId], !accountTransactions.isEmpty {
                transactionsByAccountId[accountId] = accountTransactions
            }
            if let accountLiabilities = liabilities[accountId], !accountLiabilities.isEmpty {
                liabilitiesByAccountId[accountId] = accountLiabilities
            }
        }
        return LocalUserStructureStore(
            accounts: userAccounts,
            transactionsByAccountId: transactionsByAccountId,
            liabilitiesByAccountId: liabilitiesByAccountId,
            updatedAt: Date()
        )
    }
    
    private func buildValuationStore(for userId: String) -> LocalUserValuationStore {
        let userAccounts = accounts[userId] ?? []
        let accountIds = Set(userAccounts.map(\.id))
        var accountSnapshotsByAccountId: [String: AccountSnapshot] = [:]
        for accountId in accountIds {
            if let snapshot = accountSnapshots[accountId] {
                accountSnapshotsByAccountId[accountId] = snapshot
            }
        }
        
        let aggregated = aggregatedHoldingSnapshots.values.filter { $0.userId == userId }
        var priceKeys = Set<String>()
        for snapshot in aggregated {
            priceKeys.insert("\(snapshot.assetType.rawValue)_\(snapshot.symbol)")
        }
        for snapshot in accountSnapshotsByAccountId.values {
            guard let holdings = snapshot.holdings else { continue }
            for holding in holdings {
                priceKeys.insert("\(holding.assetType.rawValue)_\(holding.symbol)")
            }
        }
        var assetPrices: [String: AssetPriceSnapshot] = [:]
        for key in priceKeys {
            if let snapshot = assetPriceSnapshots[key] {
                assetPrices[key] = snapshot
            }
        }
        
        return LocalUserValuationStore(
            homeDashboardSnapshot: homeDashboardSnapshots[userId],
            userHoldingsSnapshot: userHoldingsSnapshots[userId],
            accountSnapshotsByAccountId: accountSnapshotsByAccountId,
            assetPriceSnapshotsByKey: assetPrices,
            aggregatedHoldingSnapshots: aggregated,
            priceSyncedAt: priceSyncedAtByUserId[userId],
            priceSourceUpdatedAt: priceSourceUpdatedAtByUserId[userId],
            updatedAt: Date()
        )
    }
    
    private func persistStructureStore(for userId: String) {
        let store = buildStructureStore(for: userId)
        structureUpdatedAtByUserId[userId] = store.updatedAt
        LocalUserDataStore.saveStructure(store, userId: userId)
    }
    
    private func persistValuationStore(for userId: String) {
        let store = buildValuationStore(for: userId)
        valuationUpdatedAtByUserId[userId] = store.updatedAt
        LocalUserDataStore.saveValuation(store, userId: userId)
    }
    
    private func persistFullStore(for userId: String) {
        let structure = buildStructureStore(for: userId)
        let valuation = buildValuationStore(for: userId)
        structureUpdatedAtByUserId[userId] = structure.updatedAt
        valuationUpdatedAtByUserId[userId] = valuation.updatedAt
        let payload = LocalUserData(
            userId: userId,
            structure: structure,
            valuation: valuation
        )
        LocalUserDataStore.save(payload)
    }
    
    func persistLocalStore(for userId: String) {
        guard userId == AppUser.id else { return }
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        persistFullStore(for: userId)
    }
    
    func persistLocalStructure(for userId: String) {
        guard userId == AppUser.id else { return }
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        persistStructureStore(for: userId)
    }
    
    func persistLocalValuation(for userId: String) {
        guard userId == AppUser.id else { return }
        persistValuationStore(for: userId)
    }
    
    func fetchPriceSourceUpdatedAt(userId: String) -> Date? {
        priceSourceUpdatedAtByUserId[userId]
    }
    
    func fetchPriceSyncedAt(userId: String) -> Date? {
        priceSyncedAtByUserId[userId]
    }
    
    func fetchValuationUpdatedAt(userId: String) -> Date? {
        valuationUpdatedAtByUserId[userId]
    }
    
    func fetchStructureUpdatedAt(userId: String) -> Date? {
        structureUpdatedAtByUserId[userId]
    }
    
    func updatePriceSyncMetadata(userId: String, sourceUpdatedAt: Date?) {
        priceSyncedAtByUserId[userId] = Date()
        if let sourceUpdatedAt {
            priceSourceUpdatedAtByUserId[userId] = sourceUpdatedAt
        }
        persistValuationStore(for: userId)
    }
    
    private func persistStructureIfActiveUser(_ userId: String, debounce: Bool = false) {
        guard userId == AppUser.id else { return }
        if debounce {
            scheduleStructurePersist(userId: userId)
        } else {
            pendingStructurePersistWorkItem?.cancel()
            pendingStructurePersistWorkItem = nil
            persistStructureStore(for: userId)
        }
    }
    
    private func scheduleStructurePersist(userId: String) {
        pendingStructurePersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistStructureStore(for: userId)
        }
        pendingStructurePersistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    private func persistAfterStructureMutation(userId: String?, debounce: Bool = false) {
        if let userId {
            persistStructureIfActiveUser(userId, debounce: debounce)
            return
        }
        persistStructureIfActiveUser(AppUser.id, debounce: debounce)
    }
    
    private func userIdForAccountId(_ accountId: String) -> String? {
        for (userId, userAccounts) in accounts where userAccounts.contains(where: { $0.id == accountId }) {
            return userId
        }
        return nil
    }
    
    func fetchUser(userId: String) async throws -> User? {
        User(id: userId, email: "", displayName: nil)
    }
    
    func updateUser(_ user: User) async throws {
        // Mock 實作
    }
    
    func fetchAccounts(userId: String) async throws -> [Account] {
        if accounts[userId] == nil {
            accounts[userId] = []
        }
        return accounts[userId] ?? []
    }
    
    func createAccount(_ account: Account) async throws {
        // 將新帳戶加入記憶體儲存
        if accounts[account.userId] == nil {
            accounts[account.userId] = []
        }
        accounts[account.userId]?.append(account)
        persistStructureIfActiveUser(account.userId)
    }
    
    func updateAccount(_ account: Account) async throws {
        // 更新記憶體中的帳戶
        if var userAccounts = accounts[account.userId] {
            if let index = userAccounts.firstIndex(where: { $0.id == account.id }) {
                userAccounts[index] = account
                accounts[account.userId] = userAccounts
                persistStructureIfActiveUser(account.userId)
            }
        }
    }
    
    func deleteAccount(_ accountId: String) async throws {
        // 從記憶體中刪除帳戶
        var affectedUserId: String?
        for (userId, userAccounts) in accounts {
            if let index = userAccounts.firstIndex(where: { $0.id == accountId }) {
                affectedUserId = userId
                accounts[userId]?.remove(at: index)
                // 同時刪除相關的交易和持股
                transactions.removeValue(forKey: accountId)
                holdings.removeValue(forKey: accountId)
                liabilities.removeValue(forKey: accountId)
                accountSnapshots.removeValue(forKey: accountId)
                break
            }
        }
        persistAfterStructureMutation(userId: affectedUserId)
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
        persistAfterStructureMutation(userId: userIdForAccountId(transaction.accountId), debounce: true)
    }
    
    func updateTransaction(_ transaction: Transaction) async throws {
        var sourceAccountId: String?
        for (accountId, accountTransactions) in transactions {
            if accountTransactions.contains(where: { $0.id == transaction.id }) {
                sourceAccountId = accountId
                break
            }
        }
        
        guard let sourceAccountId else {
            throw DataServiceError.invalidOperation("找不到要更新的交易")
        }
        
        if sourceAccountId == transaction.accountId {
            guard var accountTransactions = transactions[transaction.accountId] else {
                throw DataServiceError.invalidOperation("找不到交易所屬帳戶")
            }
            guard let index = accountTransactions.firstIndex(where: { $0.id == transaction.id }) else {
                throw DataServiceError.invalidOperation("找不到要更新的交易")
            }
            accountTransactions[index] = transaction
            transactions[transaction.accountId] = accountTransactions
        } else {
            transactions[sourceAccountId]?.removeAll { $0.id == transaction.id }
            if transactions[transaction.accountId] == nil {
                transactions[transaction.accountId] = []
            }
            transactions[transaction.accountId]?.append(transaction)
        }
        
        persistAfterStructureMutation(userId: userIdForAccountId(transaction.accountId), debounce: true)
    }
    
    func deleteTransaction(_ transactionId: String) async throws {
        for (accountId, accountTransactions) in transactions {
            if let index = accountTransactions.firstIndex(where: { $0.id == transactionId }) {
                transactions[accountId]?.remove(at: index)
                persistAfterStructureMutation(userId: userIdForAccountId(accountId))
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
    
    func createLiability(_ liability: Liability) async throws {
        if liabilities[liability.accountId] == nil {
            liabilities[liability.accountId] = []
        }
        liabilities[liability.accountId]?.append(liability)
        persistAfterStructureMutation(userId: userIdForAccountId(liability.accountId), debounce: true)
    }
    
    func updateLiability(_ liability: Liability) async throws {
        if var accountLiabilities = liabilities[liability.accountId] {
            if let index = accountLiabilities.firstIndex(where: { $0.id == liability.id }) {
                accountLiabilities[index] = liability
                liabilities[liability.accountId] = accountLiabilities
                persistAfterStructureMutation(userId: userIdForAccountId(liability.accountId), debounce: true)
            }
        }
    }
    
    func deleteLiability(_ liabilityId: String) async throws {
        for (accountId, accountLiabilities) in liabilities {
            if let index = accountLiabilities.firstIndex(where: { $0.id == liabilityId }) {
                liabilities[accountId]?.remove(at: index)
                persistAfterStructureMutation(userId: userIdForAccountId(accountId))
                break
            }
        }
    }
    
    func fetchPrice(assetType: AssetType, symbol: String, date: Date?) async throws -> Price? {
        nil
    }
    
    func fetchPrices(assetType: AssetType, symbol: String, startDate: Date, endDate: Date) async throws -> [Price] {
        // Mock 實作
        return []
    }
    
    func fetchExchangeRate(from: Currency, to: Currency, date: Date?) async throws -> ExchangeRate? {
        if from == .USD, to == .TWD, let cached = ExchangeRateSessionCache.usdToTwd {
            return ExchangeRate(
                fromCurrency: from,
                toCurrency: to,
                rate: cached,
                rateDate: ExchangeRateSessionCache.usdToTwdUpdatedAt ?? date ?? Date()
            )
        }
        if let quote = await SupabaseExchangeRateService.fetchQuote(from: from, to: to) {
            if from == .USD, to == .TWD {
                ExchangeRateSessionCache.update(usdToTwd: quote.rate, updatedAt: quote.updatedAt)
            }
            return ExchangeRate(
                fromCurrency: from,
                toCurrency: to,
                rate: quote.rate,
                rateDate: quote.updatedAt ?? date ?? Date()
            )
        }
        return nil
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
    
    func syncPortfolioState(_ payload: PortfolioStateSyncPayload) async throws {
        portfolioStates[payload.userId] = payload
        if SupabaseConfig.isConfigured {
            try await SupabasePortfolioStateService.sync(payload)
        }
    }
    
    func fetchLatestPortfolioState(userId: String) async throws -> PortfolioStateSyncPayload? {
        return portfolioStates[userId]
    }
}

