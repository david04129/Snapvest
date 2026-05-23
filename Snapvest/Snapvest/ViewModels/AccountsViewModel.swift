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
}

