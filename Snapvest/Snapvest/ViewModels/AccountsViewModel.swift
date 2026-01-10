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

