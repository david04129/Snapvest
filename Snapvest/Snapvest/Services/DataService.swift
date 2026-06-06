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
    // Retired 2026-06-06：早期雲端 User 模型，全專案無引用。
    // func fetchUser(userId: String) async throws -> User?
    // func updateUser(_ user: User) async throws
    
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

    // 手動資產（本機 private data，不同步至後端）
    func fetchManualAssets(userId: String) async throws -> [ManualAsset]
    func createManualAsset(_ asset: ManualAsset) async throws
    func updateManualAsset(_ asset: ManualAsset) async throws
    func deleteManualAsset(_ assetId: String) async throws
    func fetchManualAssetValuations(assetId: String) async throws -> [ManualAssetValuation]
    func saveManualAssetValuation(_ valuation: ManualAssetValuation) async throws
    func deleteManualAssetValuation(_ valuationId: String) async throws
    
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

    // 本機首頁走勢點
    func fetchLocalDailyTrendSnapshots(userId: String, startDate: Date?, endDate: Date?) async throws -> [LocalDailyTrendSnapshot]
    func upsertLocalDailyTrendSnapshot(_ snapshot: LocalDailyTrendSnapshot) async throws
    func fetchLastDailyTrendBackfillRunDateKey(userId: String) -> String?
    func updateLastDailyTrendBackfillRunDateKey(userId: String, dateKey: String?)
    
    // Retired 2026-06-06：雲端 portfolio 同步，全專案無引用。
    // func syncPortfolioState(_ payload: PortfolioStateSyncPayload) async throws
    // func fetchLatestPortfolioState(userId: String) async throws -> PortfolioStateSyncPayload?
    
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
    private var manualAssets: [String: [ManualAsset]] = [:] // userId: [ManualAsset]
    private var manualAssetValuations: [String: [ManualAssetValuation]] = [:] // manualAssetId: [ManualAssetValuation]
    
    // 快照儲存
    private var accountSnapshots: [String: AccountSnapshot] = [:] // accountId: AccountSnapshot
    private var assetPriceSnapshots: [String: AssetPriceSnapshot] = [:] // "assetType_symbol": AssetPriceSnapshot
    private var userHoldingsSnapshots: [String: UserHoldingsSnapshot] = [:] // userId: UserHoldingsSnapshot
    private var aggregatedHoldingSnapshots: [String: AggregatedHoldingSnapshot] = [:] // "userId_assetType_symbol": AggregatedHoldingSnapshot
    private var homeDashboardSnapshots: [String: HomeDashboardSnapshot] = [:] // userId: HomeDashboardSnapshot
    private var dailyTrendSnapshots: [String: [String: LocalDailyTrendSnapshot]] = [:] // userId: yyyy-MM-dd snapshot
    private var lastDailyTrendBackfillRunDateKeys: [String: String] = [:] // userId: yyyy-MM-dd
    // private var portfolioStates: [String: PortfolioStateSyncPayload] = [:] // Retired：legacy 雲端 portfolio
    private var priceSyncedAtByUserId: [String: Date] = [:]
    private var priceSourceUpdatedAtByUserId: [String: Date] = [:]
    private var valuationUpdatedAtByUserId: [String: Date] = [:]
    private var structureUpdatedAtByUserId: [String: Date] = [:]
    private var pendingStructurePersistWorkItem: DispatchWorkItem?
    private var realStoreBackup: RuntimeStore?
    private var isDemoModeRuntimeActive: Bool {
        realStoreBackup != nil
    }
    
    var isDemoModeActive: Bool {
        isDemoModeRuntimeActive
    }
    
    private struct RuntimeStore {
        var accounts: [String: [Account]]
        var transactions: [String: [Transaction]]
        var holdings: [String: [Holding]]
        var liabilities: [String: [Liability]]
        var manualAssets: [String: [ManualAsset]]
        var manualAssetValuations: [String: [ManualAssetValuation]]
        var accountSnapshots: [String: AccountSnapshot]
        var assetPriceSnapshots: [String: AssetPriceSnapshot]
        var userHoldingsSnapshots: [String: UserHoldingsSnapshot]
        var aggregatedHoldingSnapshots: [String: AggregatedHoldingSnapshot]
        var homeDashboardSnapshots: [String: HomeDashboardSnapshot]
        var dailyTrendSnapshots: [String: [String: LocalDailyTrendSnapshot]]
        var lastDailyTrendBackfillRunDateKeys: [String: String]
        // var portfolioStates: [String: PortfolioStateSyncPayload] // Retired
        var priceSyncedAtByUserId: [String: Date]
        var priceSourceUpdatedAtByUserId: [String: Date]
        var valuationUpdatedAtByUserId: [String: Date]
        var structureUpdatedAtByUserId: [String: Date]
    }
    
    private init() {
        restorePersistedData(for: AppUser.id)
    }
    
    func beginDemoMode(seed: DemoSeedData) {
        if realStoreBackup == nil {
            realStoreBackup = currentRuntimeStore()
        }
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        let now = Date()
        
        accounts = [seed.userId: seed.accounts]
        transactions = seed.transactionsByAccountId
        holdings = [:]
        liabilities = seed.liabilitiesByAccountId
        manualAssets = [seed.userId: seed.manualAssets]
        manualAssetValuations = seed.manualAssetValuationsByAssetId
        accountSnapshots = [:]
        assetPriceSnapshots = [:]
        userHoldingsSnapshots = [:]
        aggregatedHoldingSnapshots = [:]
        homeDashboardSnapshots = [:]
        dailyTrendSnapshots = [seed.userId: [:]]
        lastDailyTrendBackfillRunDateKeys = [:]
        // portfolioStates = [:]
        priceSyncedAtByUserId = [seed.userId: now]
        priceSourceUpdatedAtByUserId = [seed.userId: now]
        valuationUpdatedAtByUserId = [seed.userId: now]
        structureUpdatedAtByUserId = [seed.userId: now]
    }
    
    func endDemoMode() {
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        if let realStoreBackup {
            applyRuntimeStore(realStoreBackup)
        }
        realStoreBackup = nil
    }
    
    private func currentRuntimeStore() -> RuntimeStore {
        RuntimeStore(
            accounts: accounts,
            transactions: transactions,
            holdings: holdings,
            liabilities: liabilities,
            manualAssets: manualAssets,
            manualAssetValuations: manualAssetValuations,
            accountSnapshots: accountSnapshots,
            assetPriceSnapshots: assetPriceSnapshots,
            userHoldingsSnapshots: userHoldingsSnapshots,
            aggregatedHoldingSnapshots: aggregatedHoldingSnapshots,
            homeDashboardSnapshots: homeDashboardSnapshots,
            dailyTrendSnapshots: dailyTrendSnapshots,
            lastDailyTrendBackfillRunDateKeys: lastDailyTrendBackfillRunDateKeys,
            // portfolioStates: portfolioStates,
            priceSyncedAtByUserId: priceSyncedAtByUserId,
            priceSourceUpdatedAtByUserId: priceSourceUpdatedAtByUserId,
            valuationUpdatedAtByUserId: valuationUpdatedAtByUserId,
            structureUpdatedAtByUserId: structureUpdatedAtByUserId
        )
    }
    
    private func applyRuntimeStore(_ store: RuntimeStore) {
        accounts = store.accounts
        transactions = store.transactions
        holdings = store.holdings
        liabilities = store.liabilities
        manualAssets = store.manualAssets
        manualAssetValuations = store.manualAssetValuations
        accountSnapshots = store.accountSnapshots
        assetPriceSnapshots = store.assetPriceSnapshots
        userHoldingsSnapshots = store.userHoldingsSnapshots
        aggregatedHoldingSnapshots = store.aggregatedHoldingSnapshots
        homeDashboardSnapshots = store.homeDashboardSnapshots
        dailyTrendSnapshots = store.dailyTrendSnapshots
        lastDailyTrendBackfillRunDateKeys = store.lastDailyTrendBackfillRunDateKeys
        // portfolioStates = store.portfolioStates
        priceSyncedAtByUserId = store.priceSyncedAtByUserId
        priceSourceUpdatedAtByUserId = store.priceSourceUpdatedAtByUserId
        valuationUpdatedAtByUserId = store.valuationUpdatedAtByUserId
        structureUpdatedAtByUserId = store.structureUpdatedAtByUserId
    }
    
    private func restorePersistedData(for userId: String) {
        guard let saved = LocalUserDataStore.load(userId: userId) else { return }
        accounts[userId] = saved.structure.accounts
        manualAssets[userId] = saved.structure.manualAssets
        manualAssetValuations = saved.valuation.manualAssetValuationsByAssetId
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
        if let lastBackfillRun = saved.valuation.lastDailyTrendBackfillRunDateKey {
            lastDailyTrendBackfillRunDateKeys[userId] = lastBackfillRun
        }
        if let home = saved.valuation.homeDashboardSnapshot {
            recordHomeDashboardSnapshotAsTrendPoint(home, shouldPersist: true)
        }
    }
    
    private func applyValuationStore(_ store: LocalUserValuationStore, userId: String) {
        if let home = store.homeDashboardSnapshot {
            homeDashboardSnapshots[userId] = home
        }
        dailyTrendSnapshots[userId] = store.dailyTrendSnapshotsByDate
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
            manualAssets: manualAssets[userId] ?? [],
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
        let manualAssetIds = Set(manualAssets[userId, default: []].map(\.id))
        let manualValuations = manualAssetValuations.filter { manualAssetIds.contains($0.key) }
        
        return LocalUserValuationStore(
            homeDashboardSnapshot: homeDashboardSnapshots[userId],
            userHoldingsSnapshot: userHoldingsSnapshots[userId],
            accountSnapshotsByAccountId: accountSnapshotsByAccountId,
            assetPriceSnapshotsByKey: assetPrices,
            aggregatedHoldingSnapshots: aggregated,
            manualAssetValuationsByAssetId: manualValuations,
            dailyTrendSnapshotsByDate: dailyTrendSnapshots[userId] ?? [:],
            lastDailyTrendBackfillRunDateKey: lastDailyTrendBackfillRunDateKeys[userId],
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
        guard !isDemoModeRuntimeActive else { return }
        guard userId == AppUser.id else { return }
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        persistFullStore(for: userId)
    }
    
    func persistLocalStructure(for userId: String) {
        guard !isDemoModeRuntimeActive else { return }
        guard userId == AppUser.id else { return }
        pendingStructurePersistWorkItem?.cancel()
        pendingStructurePersistWorkItem = nil
        persistStructureStore(for: userId)
    }
    
    func persistLocalValuation(for userId: String) {
        guard !isDemoModeRuntimeActive else { return }
        guard userId == AppUser.id else { return }
        persistValuationStore(for: userId)
    }

    func replaceLocalStoreForRestore(_ payload: LocalUserData, userId: String) throws {
        guard userId == AppUser.id else {
            throw DataServiceError.invalidOperation("只能還原目前使用者的備份資料。")
        }

        let normalized = payload.normalizedForRestore(userId: userId)
        try LocalUserDataStore.replaceForRestore(normalized, userId: userId)
        clearRuntimeStateForRestore(userId: userId, restoredData: normalized)
        restorePersistedData(for: userId)
    }

    private func clearRuntimeStateForRestore(userId: String, restoredData: LocalUserData) {
        let existingAccountIds = Set(accounts[userId, default: []].map(\.id))
        let restoredAccountIds = Set(restoredData.structure.accounts.map(\.id))
        let affectedAccountIds = existingAccountIds.union(restoredAccountIds)

        for accountId in affectedAccountIds {
            transactions.removeValue(forKey: accountId)
            holdings.removeValue(forKey: accountId)
            liabilities.removeValue(forKey: accountId)
            accountSnapshots.removeValue(forKey: accountId)
        }

        accounts.removeValue(forKey: userId)
        manualAssets.removeValue(forKey: userId)
        manualAssetValuations.removeAll()
        userHoldingsSnapshots.removeValue(forKey: userId)
        aggregatedHoldingSnapshots = aggregatedHoldingSnapshots.filter { $0.value.userId != userId }
        homeDashboardSnapshots.removeValue(forKey: userId)
        dailyTrendSnapshots.removeValue(forKey: userId)
        lastDailyTrendBackfillRunDateKeys.removeValue(forKey: userId)
        // portfolioStates.removeValue(forKey: userId)
        priceSyncedAtByUserId.removeValue(forKey: userId)
        priceSourceUpdatedAtByUserId.removeValue(forKey: userId)
        valuationUpdatedAtByUserId.removeValue(forKey: userId)
        structureUpdatedAtByUserId.removeValue(forKey: userId)
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
        guard !isDemoModeRuntimeActive else { return }
        persistValuationStore(for: userId)
    }
    
    private func persistStructureIfActiveUser(_ userId: String, debounce: Bool = false) {
        guard !isDemoModeRuntimeActive else { return }
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
    
    // Retired 2026-06-06：早期雲端 User stub，全專案無引用。
    // func fetchUser(userId: String) async throws -> User? {
    //     User(id: userId, email: "", displayName: nil)
    // }
    //
    // func updateUser(_ user: User) async throws {
    //     // Mock 實作
    // }
    
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

    func fetchManualAssets(userId: String) async throws -> [ManualAsset] {
        manualAssets[userId] ?? []
    }

    func createManualAsset(_ asset: ManualAsset) async throws {
        let normalizedAsset = normalizedManualAsset(asset)
        if manualAssets[asset.userId] == nil {
            manualAssets[asset.userId] = []
        }
        manualAssets[asset.userId]?.append(normalizedAsset)
        persistStructureIfActiveUser(normalizedAsset.userId)
    }

    func updateManualAsset(_ asset: ManualAsset) async throws {
        let normalizedAsset = normalizedManualAsset(asset)
        guard var userAssets = manualAssets[asset.userId],
              let index = userAssets.firstIndex(where: { $0.id == asset.id }) else {
            throw DataServiceError.invalidOperation("找不到要更新的其他資產")
        }
        userAssets[index] = normalizedAsset
        manualAssets[normalizedAsset.userId] = userAssets
        persistStructureIfActiveUser(normalizedAsset.userId)
    }

    private func normalizedManualAsset(_ asset: ManualAsset) -> ManualAsset {
        guard asset.isIncludedInInvestments, !asset.isIncludedInTotalAssets else {
            return asset
        }
        var normalized = asset
        normalized.isIncludedInTotalAssets = true
        return normalized
    }

    func deleteManualAsset(_ assetId: String) async throws {
        var affectedUserId: String?
        for (userId, userAssets) in manualAssets {
            guard let index = userAssets.firstIndex(where: { $0.id == assetId }) else { continue }
            manualAssets[userId]?.remove(at: index)
            manualAssetValuations.removeValue(forKey: assetId)
            affectedUserId = userId
            break
        }
        if let affectedUserId {
            persistLocalStore(for: affectedUserId)
        }
    }

    func fetchManualAssetValuations(assetId: String) async throws -> [ManualAssetValuation] {
        manualAssetValuations[assetId, default: []].sorted { $0.valuationDate > $1.valuationDate }
    }

    func saveManualAssetValuation(_ valuation: ManualAssetValuation) async throws {
        var valuations = manualAssetValuations[valuation.manualAssetId] ?? []
        if let index = valuations.firstIndex(where: { $0.id == valuation.id }) {
            valuations[index] = valuation
        } else {
            valuations.append(valuation)
        }
        manualAssetValuations[valuation.manualAssetId] = valuations
        persistLocalValuation(for: valuation.userId)
    }

    func deleteManualAssetValuation(_ valuationId: String) async throws {
        var affectedUserId: String?
        for (assetId, valuations) in manualAssetValuations {
            guard let valuation = valuations.first(where: { $0.id == valuationId }) else { continue }
            manualAssetValuations[assetId]?.removeAll { $0.id == valuationId }
            affectedUserId = valuation.userId
            break
        }
        if let affectedUserId {
            persistLocalValuation(for: affectedUserId)
        }
    }
    
    func fetchPrice(assetType: AssetType, symbol: String, date: Date?) async throws -> Price? {
        guard let date else { return nil }
        return try await SupabasePriceService.fetchHistoricalPrice(
            assetType: assetType,
            symbol: symbol,
            date: date
        )
    }
    
    func fetchPrices(assetType: AssetType, symbol: String, startDate: Date, endDate: Date) async throws -> [Price] {
        try await SupabasePriceService.fetchHistoricalPrices(
            assetType: assetType,
            symbol: symbol,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    func fetchExchangeRate(from: Currency, to: Currency, date: Date?) async throws -> ExchangeRate? {
        if to == .TWD, from != .TWD, let cached = ExchangeRateSessionCache.twdPer(from) {
            if from == .USD, ExchangeRateSessionCache.usdToTwdUpdatedAt == nil {
                // 快取無 DB 寫入時間，改向 exchange_rates 查詢
            } else {
                let rateDate = from == .USD
                    ? (ExchangeRateSessionCache.usdToTwdUpdatedAt ?? date ?? Date())
                    : (date ?? Date())
                return ExchangeRate(
                    fromCurrency: from,
                    toCurrency: to,
                    rate: cached,
                    rateDate: rateDate
                )
            }
        }
        if let quote = await SupabaseExchangeRateService.fetchQuote(from: from, to: to) {
            if to == .TWD {
                ExchangeRateSessionCache.mergeTwdRate(currency: from, rate: quote.rate)
            }
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
        let normalized = SupabasePriceService.normalizeSymbol(assetType: assetType, symbol: symbol)
        let key = "\(assetType.rawValue)_\(normalized)"
        return assetPriceSnapshots[key]
    }
    
    func fetchAssetPriceSnapshots(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        var snapshots: [AssetPriceSnapshot] = []
        for symbolInfo in symbols {
            let normalized = SupabasePriceService.normalizeSymbol(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol
            )
            let key = "\(symbolInfo.assetType.rawValue)_\(normalized)"
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
        if !isDemoModeRuntimeActive {
            recordHomeDashboardSnapshotAsTrendPoint(snapshot, shouldPersist: false)
        }
    }

    func deleteHomeDashboardSnapshot(userId: String) async throws {
        homeDashboardSnapshots.removeValue(forKey: userId)
    }

    func fetchLocalDailyTrendSnapshots(userId: String, startDate: Date?, endDate: Date?) async throws -> [LocalDailyTrendSnapshot] {
        let calendar = Calendar.current
        let startDay = startDate.map { calendar.startOfDay(for: $0) }
        let endDay = endDate.map { calendar.startOfDay(for: $0) }

        return dailyTrendSnapshots[userId, default: [:]]
            .values
            .filter { snapshot in
                if let startDay, snapshot.date < startDay { return false }
                if let endDay, snapshot.date > endDay { return false }
                return true
            }
            .sorted { $0.date < $1.date }
    }

    func upsertLocalDailyTrendSnapshot(_ snapshot: LocalDailyTrendSnapshot) async throws {
        dailyTrendSnapshots[snapshot.userId, default: [:]][snapshot.id] = snapshot
        persistLocalValuation(for: snapshot.userId)
    }

    func fetchLastDailyTrendBackfillRunDateKey(userId: String) -> String? {
        lastDailyTrendBackfillRunDateKeys[userId]
    }

    func updateLastDailyTrendBackfillRunDateKey(userId: String, dateKey: String?) {
        if let dateKey {
            lastDailyTrendBackfillRunDateKeys[userId] = dateKey
        } else {
            lastDailyTrendBackfillRunDateKeys.removeValue(forKey: userId)
        }
        persistLocalValuation(for: userId)
    }

    private func recordHomeDashboardSnapshotAsTrendPoint(_ snapshot: HomeDashboardSnapshot, shouldPersist: Bool) {
        let trendSnapshot = LocalDailyTrendSnapshot(homeSnapshot: snapshot)
        dailyTrendSnapshots[snapshot.userId, default: [:]][trendSnapshot.id] = trendSnapshot
        if shouldPersist {
            persistLocalValuation(for: snapshot.userId)
        }
    }

    #if DEBUG
    func debugValidateSnapshotConsistency(userId: String) async -> SnapshotConsistencyReport {
        let originalStore = currentRuntimeStore()
        let currentAccountSnapshots = accountSnapshotsForUser(userId)
        let currentHomeSnapshot = homeDashboardSnapshots[userId]
        let currentUserHoldingsSnapshot = userHoldingsSnapshots[userId]
        let currentAggregatedSnapshots = aggregatedSnapshotsForUser(userId)
        var mismatches: [SnapshotConsistencyMismatch] = []

        defer {
            applyRuntimeStore(originalStore)
        }

        do {
            _ = try await SnapshotUpdater.rebuildSnapshots(
                userId: userId,
                dataService: self,
                priceService: PriceService(dataService: self)
            )

            compareAccountSnapshots(
                current: currentAccountSnapshots,
                rebuilt: accountSnapshotsForUser(userId),
                mismatches: &mismatches
            )
            compareHomeSnapshot(
                current: currentHomeSnapshot,
                rebuilt: homeDashboardSnapshots[userId],
                mismatches: &mismatches
            )
            compareUserHoldingsSnapshot(
                current: currentUserHoldingsSnapshot,
                rebuilt: userHoldingsSnapshots[userId],
                mismatches: &mismatches
            )
            compareAggregatedSnapshots(
                current: currentAggregatedSnapshots,
                rebuilt: aggregatedSnapshotsForUser(userId),
                mismatches: &mismatches
            )
        } catch {
            mismatches.append(
                SnapshotConsistencyMismatch(
                    scope: "rebuild",
                    field: "error",
                    current: "n/a",
                    rebuilt: error.localizedDescription
                )
            )
        }

        let report = SnapshotConsistencyReport(checkedAt: Date(), mismatches: mismatches)
        if report.isConsistent {
            print("[SnapshotConsistency] OK")
        } else {
            print("[SnapshotConsistency] \(mismatches.count) mismatch(es)")
            mismatches.forEach { print("[SnapshotConsistency] \($0.description)") }
        }
        return report
    }

    private func accountSnapshotsForUser(_ userId: String) -> [String: AccountSnapshot] {
        let accountIds = Set(accounts[userId, default: []].map(\.id))
        return accountSnapshots.filter { accountIds.contains($0.key) }
    }

    private func aggregatedSnapshotsForUser(_ userId: String) -> [String: AggregatedHoldingSnapshot] {
        aggregatedHoldingSnapshots.filter { $0.value.userId == userId }
    }

    private func compareAccountSnapshots(
        current: [String: AccountSnapshot],
        rebuilt: [String: AccountSnapshot],
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        let accountIds = Set(current.keys).union(rebuilt.keys).sorted()
        for accountId in accountIds {
            guard let currentSnapshot = current[accountId] else {
                appendMismatch(&mismatches, scope: "account \(accountId)", field: "snapshot", current: "missing", rebuilt: "present")
                continue
            }
            guard let rebuiltSnapshot = rebuilt[accountId] else {
                appendMismatch(&mismatches, scope: "account \(accountId)", field: "snapshot", current: "present", rebuilt: "missing")
                continue
            }

            compareDecimal(currentSnapshot.cashBalance, rebuiltSnapshot.cashBalance, scope: "account \(accountId)", field: "cashBalance", mismatches: &mismatches)
            compareOptionalDecimal(currentSnapshot.remainingBalance, rebuiltSnapshot.remainingBalance, scope: "account \(accountId)", field: "remainingBalance", mismatches: &mismatches)
            compareOptionalDecimal(currentSnapshot.totalPaidPrincipal, rebuiltSnapshot.totalPaidPrincipal, scope: "account \(accountId)", field: "totalPaidPrincipal", mismatches: &mismatches)
            compareOptionalDecimal(currentSnapshot.totalPaidInterest, rebuiltSnapshot.totalPaidInterest, scope: "account \(accountId)", field: "totalPaidInterest", mismatches: &mismatches)
            compareOptionalDecimal(currentSnapshot.totalSavedInterest, rebuiltSnapshot.totalSavedInterest, scope: "account \(accountId)", field: "totalSavedInterest", mismatches: &mismatches)
            compareHoldings(currentSnapshot.holdings ?? [], rebuiltSnapshot.holdings ?? [], accountId: accountId, mismatches: &mismatches)
        }
    }

    private func compareHoldings(
        _ current: [HoldingSnapshotItem],
        _ rebuilt: [HoldingSnapshotItem],
        accountId: String,
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        let currentByKey = Dictionary(grouping: current, by: { "\($0.assetType.rawValue)_\($0.symbol)" }).compactMapValues(\.first)
        let rebuiltByKey = Dictionary(grouping: rebuilt, by: { "\($0.assetType.rawValue)_\($0.symbol)" }).compactMapValues(\.first)
        let keys = Set(currentByKey.keys).union(rebuiltByKey.keys).sorted()

        for key in keys {
            let scope = "account \(accountId) holding \(key)"
            guard let currentHolding = currentByKey[key] else {
                appendMismatch(&mismatches, scope: scope, field: "holding", current: "missing", rebuilt: "present")
                continue
            }
            guard let rebuiltHolding = rebuiltByKey[key] else {
                appendMismatch(&mismatches, scope: scope, field: "holding", current: "present", rebuilt: "missing")
                continue
            }

            if currentHolding.currency != rebuiltHolding.currency {
                appendMismatch(&mismatches, scope: scope, field: "currency", current: currentHolding.currency.rawValue, rebuilt: rebuiltHolding.currency.rawValue)
            }
            compareDecimal(currentHolding.quantity, rebuiltHolding.quantity, scope: scope, field: "quantity", mismatches: &mismatches)
            compareDecimal(currentHolding.averageCost, rebuiltHolding.averageCost, scope: scope, field: "averageCost", mismatches: &mismatches)
        }
    }

    private func compareHomeSnapshot(
        current: HomeDashboardSnapshot?,
        rebuilt: HomeDashboardSnapshot?,
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        guard let current else {
            appendMismatch(&mismatches, scope: "home", field: "snapshot", current: "missing", rebuilt: rebuilt == nil ? "missing" : "present")
            return
        }
        guard let rebuilt else {
            appendMismatch(&mismatches, scope: "home", field: "snapshot", current: "present", rebuilt: "missing")
            return
        }

        compareDecimal(current.netWorth, rebuilt.netWorth, scope: "home", field: "netWorth", mismatches: &mismatches)
        compareDecimal(current.totalLiabilities, rebuilt.totalLiabilities, scope: "home", field: "totalLiabilities", mismatches: &mismatches)
        compareDecimal(current.totalAssets, rebuilt.totalAssets, scope: "home", field: "totalAssets", mismatches: &mismatches)
        compareDecimal(current.totalInvestments, rebuilt.totalInvestments, scope: "home", field: "totalInvestments", mismatches: &mismatches)
        compareDecimal(current.totalInvestmentsCost, rebuilt.totalInvestmentsCost, scope: "home", field: "totalInvestmentsCost", mismatches: &mismatches)
        compareDecimal(current.totalCash, rebuilt.totalCash, scope: "home", field: "totalCash", mismatches: &mismatches)
        compareDecimal(current.twdCash, rebuilt.twdCash, scope: "home", field: "twdCash", mismatches: &mismatches)
        compareDecimal(current.usdCash, rebuilt.usdCash, scope: "home", field: "usdCash", mismatches: &mismatches)
        compareDecimal(current.realizedGainLossTWD, rebuilt.realizedGainLossTWD, scope: "home", field: "realizedGainLossTWD", mismatches: &mismatches)
        compareDecimal(current.realizedGainLossUSD, rebuilt.realizedGainLossUSD, scope: "home", field: "realizedGainLossUSD", mismatches: &mismatches)
    }

    private func compareUserHoldingsSnapshot(
        current: UserHoldingsSnapshot?,
        rebuilt: UserHoldingsSnapshot?,
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        guard let current else {
            appendMismatch(&mismatches, scope: "userHoldings", field: "snapshot", current: "missing", rebuilt: rebuilt == nil ? "missing" : "present")
            return
        }
        guard let rebuilt else {
            appendMismatch(&mismatches, scope: "userHoldings", field: "snapshot", current: "present", rebuilt: "missing")
            return
        }

        let currentSymbols = current.symbols.map(symbolText).sorted()
        let rebuiltSymbols = rebuilt.symbols.map(symbolText).sorted()
        if currentSymbols != rebuiltSymbols {
            appendMismatch(
                &mismatches,
                scope: "userHoldings",
                field: "symbols",
                current: currentSymbols.joined(separator: ","),
                rebuilt: rebuiltSymbols.joined(separator: ",")
            )
        }
    }

    private func compareAggregatedSnapshots(
        current: [String: AggregatedHoldingSnapshot],
        rebuilt: [String: AggregatedHoldingSnapshot],
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        let keys = Set(current.keys).union(rebuilt.keys).sorted()
        for key in keys {
            guard let currentSnapshot = current[key] else {
                appendMismatch(&mismatches, scope: "aggregated \(key)", field: "snapshot", current: "missing", rebuilt: "present")
                continue
            }
            guard let rebuiltSnapshot = rebuilt[key] else {
                appendMismatch(&mismatches, scope: "aggregated \(key)", field: "snapshot", current: "present", rebuilt: "missing")
                continue
            }

            if currentSnapshot.currency != rebuiltSnapshot.currency {
                appendMismatch(&mismatches, scope: "aggregated \(key)", field: "currency", current: currentSnapshot.currency.rawValue, rebuilt: rebuiltSnapshot.currency.rawValue)
            }
            compareDecimal(currentSnapshot.totalQuantity, rebuiltSnapshot.totalQuantity, scope: "aggregated \(key)", field: "totalQuantity", mismatches: &mismatches)
            compareDecimal(currentSnapshot.weightedAverageCost, rebuiltSnapshot.weightedAverageCost, scope: "aggregated \(key)", field: "weightedAverageCost", mismatches: &mismatches)
            compareDecimal(currentSnapshot.totalCost, rebuiltSnapshot.totalCost, scope: "aggregated \(key)", field: "totalCost", mismatches: &mismatches)
            if currentSnapshot.sourceAccountIds.sorted() != rebuiltSnapshot.sourceAccountIds.sorted() {
                appendMismatch(
                    &mismatches,
                    scope: "aggregated \(key)",
                    field: "sourceAccountIds",
                    current: currentSnapshot.sourceAccountIds.sorted().joined(separator: ","),
                    rebuilt: rebuiltSnapshot.sourceAccountIds.sorted().joined(separator: ",")
                )
            }
        }
    }

    private func compareOptionalDecimal(
        _ current: Decimal?,
        _ rebuilt: Decimal?,
        scope: String,
        field: String,
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        switch (current, rebuilt) {
        case (.none, .none):
            return
        case (.some(let current), .some(let rebuilt)):
            compareDecimal(current, rebuilt, scope: scope, field: field, mismatches: &mismatches)
        default:
            appendMismatch(&mismatches, scope: scope, field: field, current: decimalText(current), rebuilt: decimalText(rebuilt))
        }
    }

    private func compareDecimal(
        _ current: Decimal,
        _ rebuilt: Decimal,
        scope: String,
        field: String,
        mismatches: inout [SnapshotConsistencyMismatch]
    ) {
        guard current != rebuilt else { return }
        appendMismatch(&mismatches, scope: scope, field: field, current: decimalText(current), rebuilt: decimalText(rebuilt))
    }

    private func appendMismatch(
        _ mismatches: inout [SnapshotConsistencyMismatch],
        scope: String,
        field: String,
        current: String,
        rebuilt: String
    ) {
        mismatches.append(
            SnapshotConsistencyMismatch(
                scope: scope,
                field: field,
                current: current,
                rebuilt: rebuilt
            )
        )
    }

    private func decimalText(_ value: Decimal?) -> String {
        guard let value else { return "nil" }
        return NSDecimalNumber(decimal: value).stringValue
    }

    private func symbolText(_ symbol: SymbolInfo) -> String {
        "\(symbol.assetType.rawValue)_\(symbol.symbol)"
    }
    #endif
    
    // Retired 2026-06-06：legacy 雲端 portfolio 本機 stub，全專案無引用。
    // func syncPortfolioState(_ payload: PortfolioStateSyncPayload) async throws {
    //     // Privacy: portfolio state stays local. Remote writes are replaced by anonymous tracked symbol sync.
    //     portfolioStates[payload.userId] = payload
    // }
    //
    // func fetchLatestPortfolioState(userId: String) async throws -> PortfolioStateSyncPayload? {
    //     return portfolioStates[userId]
    // }
}

