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
    @Published var balancesLoading = false
    @Published var balancesLoadedOnce = false
    
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

    /// 一次算出所有帳戶卡片與類別總額（單次交易／報價／負債查詢）
    func refreshBalances(userId: String, preloadedLiabilities: [Liability] = []) async {
        if !balancesLoadedOnce { balancesLoading = true }
        defer {
            balancesLoading = false
            balancesLoadedOnce = true
        }

        let result = await AccountsBalancesCalculator.compute(
            accounts: accounts,
            userId: userId,
            dataService: dataService,
            preloadedLiabilities: preloadedLiabilities
        )
        balancesByAccountId = result.byAccountId
        categoryTotalsTWD = result.categoryTotalsTWD
        debtCategoryTotalBalance = result.debtCategoryTotalBalance
    }
    
    func createAccount(_ account: Account) async {
        do {
            try await dataService.createAccount(account)
            await loadAccounts(userId: account.userId)
        } catch {
            errorMessage = "建立帳戶失敗：\(error.localizedDescription)"
        }
    }
    
    func deleteAccount(_ accountId: String) async {
        do {
            try await dataService.deleteAccount(accountId)
            accounts.removeAll { $0.id == accountId }
        } catch {
            errorMessage = "刪除帳戶失敗：\(error.localizedDescription)"
        }
    }
    
    func archiveDebtAccount(_ account: Account) async -> String? {
        do {
            try await dataService.archiveDebtAccount(account)
            await loadAccounts(userId: account.userId)
            let priceService = PriceService(dataService: dataService)
            _ = try? await SnapshotUpdater.rebuildSnapshots(
                userId: account.userId,
                dataService: dataService,
                priceService: priceService
            )
            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
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
    
    private func findLiability(matchingDebtAccount account: Account) async throws -> Liability? {
        for repaymentAccount in accounts where repaymentAccount.accountType != .debt {
            let batch = try await dataService.fetchLiabilities(accountId: repaymentAccount.id)
            if let liability = batch.first(where: { $0.name == account.name }) {
                return liability
            }
        }
        return nil
    }
}

