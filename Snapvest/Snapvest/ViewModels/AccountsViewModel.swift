//
//  AccountsViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class AccountsViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var balancesByAccountId: [String: AccountBalanceDisplay] = [:]
    @Published var categoryTotalsTWD: [AccountType: Decimal] = [:]
    @Published var debtCategoryTotalBalance: Decimal = 0
    @Published var otherDebtCategoryTotalBalance: Decimal = 0
    @Published var balancesLoading = false
    @Published var balancesLoadedOnce = false
    @Published private(set) var isSaving = false
    
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }
    
    func loadAccounts(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            accounts = try await dataService.fetchAccounts(userId: userId)
        } catch {
            errorMessage = "載入帳戶失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }

    /// Splash／快照更新後：從本機 B 套用帳戶餘額（不重算交易、不拉 Supabase）
    func applyFromPersisted(
        userId: String,
        usdToTwdRate: Decimal? = nil,
        liabilities: [Liability] = []
    ) async {
        let rate: Decimal
        if let usdToTwdRate {
            rate = usdToTwdRate
        } else {
            rate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
        }

        await loadAccounts(userId: userId)

        let result = await AccountsSnapshotDisplayBuilder.build(
            accounts: accounts,
            userId: userId,
            dataService: dataService,
            usdToTwdRate: rate,
            liabilities: liabilities
        )
        balancesByAccountId = result.byAccountId
        categoryTotalsTWD = result.categoryTotalsTWD
        debtCategoryTotalBalance = result.debtCategoryTotalBalance
        otherDebtCategoryTotalBalance = result.otherDebtCategoryTotalBalance
        balancesLoading = false
        balancesLoadedOnce = true
    }

    /// 一次算出所有帳戶卡片與類別總額（`applyFromPersisted` 的別名；仍使用中）
    func refreshBalances(userId: String, preloadedLiabilities: [Liability] = []) async {
        await applyFromPersisted(userId: userId, liabilities: preloadedLiabilities)
    }

    func applyChangedAccountsFromPersisted(
        userId: String,
        affectedAccountIds: Set<String>,
        usdToTwdRate: Decimal,
        liabilities: [Liability] = []
    ) async {
        if accounts.isEmpty {
            await loadAccounts(userId: userId)
        }

        for account in accounts where affectedAccountIds.contains(account.id) {
            guard !account.isArchived else {
                balancesByAccountId.removeValue(forKey: account.id)
                continue
            }
            let balance = await AccountsSnapshotDisplayBuilder.buildAccount(
                account: account,
                accounts: accounts,
                userId: userId,
                dataService: dataService,
                usdToTwdRate: usdToTwdRate,
                liabilities: liabilities
            )
            balancesByAccountId[account.id] = balance
        }

        recalculateCategoryTotalsFromCachedBalances()
        balancesLoading = false
        balancesLoadedOnce = true
    }
    
    func createAccountRecord(_ account: Account) async throws {
        try await dataService.createAccount(account)
        await loadAccounts(userId: account.userId)
    }

    func persistTransaction(_ transaction: Transaction) async throws {
        try await dataService.createTransaction(transaction)
    }

    func persistLiability(_ liability: Liability) async throws {
        try await dataService.createLiability(liability)
    }

    /// 寫入帳戶／交易／負債後重建快照；`structureOnly` 僅重算結構、不拉雲端股價。
    func runAccountSave(
        userId: String,
        structureOnly: Bool = false,
        affectedAccountId: String? = nil,
        _ work: () async throws -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await work()
            if structureOnly, let affectedAccountId {
                try await AccountSnapshotRefresh.afterCashAccountChange(
                    userId: userId,
                    affectedAccountId: affectedAccountId,
                    dataService: dataService
                )
            } else {
                await SnapshotRefreshCoordinator.rebuildAndNotify(
                    userId: userId,
                    dataService: dataService
                )
            }
            return true
        } catch {
            errorMessage = "建立帳戶失敗：\(error.localizedDescription)"
            return false
        }
    }

    func createAccount(_ account: Account, structureOnly: Bool = false) async {
        _ = await runAccountSave(
            userId: account.userId,
            structureOnly: structureOnly,
            affectedAccountId: structureOnly ? account.id : nil
        ) {
            try await createAccountRecord(account)
        }
    }

    private func recalculateCategoryTotalsFromCachedBalances() {
        var totals: [AccountType: Decimal] = [:]
        var debtTotal: Decimal = 0
        var otherDebtTotal: Decimal = 0

        for account in accounts where !account.isArchived {
            guard let balance = balancesByAccountId[account.id] else { continue }
            switch account.accountType {
            case .debt:
                debtTotal += balance.twdEquivalent ?? balance.remainingBalance
            case .otherDebt:
                otherDebtTotal += balance.twdEquivalent ?? balance.remainingBalance
            default:
                totals[account.accountType, default: 0] += balance.twdEquivalent ?? balance.totalAssets
            }
        }

        categoryTotalsTWD = totals
        debtCategoryTotalBalance = debtTotal
        otherDebtCategoryTotalBalance = otherDebtTotal
    }
    
    /// 永久刪除帳戶與其交易、持股快照、負債資料；成功回傳 nil。
    func deleteAccount(_ account: Account) async -> String? {
        let accountId = account.id
        do {
            if account.accountType == .debt {
                let batch = try await dataService.fetchLiabilities(accountId: accountId)
                for liability in batch {
                    try await dataService.deleteLiability(liability.id)
                }
            }

            try await dataService.deleteAccount(accountId)
            accounts.removeAll { $0.id == accountId }
            balancesByAccountId.removeValue(forKey: accountId)
            recalculateCategoryTotalsFromCachedBalances()
            return nil
        } catch {
            let message = "刪除帳戶失敗：\(error.localizedDescription)"
            errorMessage = message
            return message
        }
    }

    private func loadAllLiabilities(userId: String) async throws -> [Liability] {
        let userAccounts = try await dataService.fetchAccounts(userId: userId)
        var all: [Liability] = []
        for item in userAccounts where item.accountType == .debt {
            let batch = try await dataService.fetchLiabilities(accountId: item.id)
            all.append(contentsOf: batch)
        }
        return all
    }
    
    func archiveDebtAccount(_ account: Account) async -> String? {
        do {
            try await dataService.archiveDebtAccount(account)
            await loadAccounts(userId: account.userId)
            try await AccountSnapshotRefresh.afterAccountRemovedOrArchived(
                userId: account.userId,
                dataService: dataService
            )
            await refreshBalances(userId: account.userId)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    
    func renameAccount(accountId: String, userId: String, to newName: String) async -> String? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "請輸入帳戶名稱" }
        
        if accounts.isEmpty {
            await loadAccounts(userId: userId)
        }
        
        guard var account = accounts.first(where: { $0.id == accountId }) else {
            return "找不到帳戶"
        }
        guard trimmed != account.name else { return nil }
        
        let isDuplicate = accounts.contains {
            $0.id != accountId && $0.accountType == account.accountType && $0.name == trimmed
        }
        if isDuplicate {
            return "此類別已有相同名稱的帳戶"
        }
        
        do {
            if account.accountType == .debt {
                if let liability = try await findLiability(matchingDebtAccount: account) {
                    var updatedLiability = liability
                    updatedLiability.name = trimmed
                    updatedLiability.updatedAt = Date()
                    try await dataService.updateLiability(updatedLiability)
                }
            }
            
            account.name = trimmed
            account.updatedAt = Date()
            try await dataService.updateAccount(account)
            
            await loadAccounts(userId: userId)
            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
            await refreshBalances(userId: userId)
            return nil
        } catch {
            return "重新命名失敗：\(error.localizedDescription)"
        }
    }
    
    func archiveOtherDebtAccount(_ account: Account) async -> String? {
        guard account.accountType == .otherDebt else {
            return "僅其他債務帳戶可封存"
        }
        guard !account.isArchived else {
            return "此帳戶已封存"
        }
        
        do {
            let transactions = try await dataService.fetchAllTransactions(userId: account.userId)
            let accounts = try await dataService.fetchAccounts(userId: account.userId)
            let remaining = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: transactions,
                accounts: accounts
            )
            guard remaining <= DebtAccountArchive.balanceTolerance else {
                return "欠款須歸零後才能封存"
            }
            
            var updated = account
            updated.isArchived = true
            updated.archivedAt = Date()
            updated.updatedAt = Date()
            try await dataService.updateAccount(updated)
            
            await loadAccounts(userId: account.userId)
            try await AccountSnapshotRefresh.afterAccountRemovedOrArchived(
                userId: account.userId,
                dataService: dataService
            )
            await refreshBalances(userId: account.userId)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    
    private func findLiability(matchingDebtAccount account: Account) async throws -> Liability? {
        let batch = try await dataService.fetchLiabilities(accountId: account.id)
        return batch.first(where: { $0.name == account.name }) ?? batch.first
    }
}

