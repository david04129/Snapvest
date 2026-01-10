//
//  AccountDetailViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class AccountDetailViewModel: ObservableObject {
    @Published var cashBalance: Decimal = 0
    @Published var holdings: [HoldingSnapshot] = []
    @Published var holdingsValue: Decimal = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var displayCurrency: Currency = .USD // 顯示貨幣（用於美股和加密貨幣）
    @Published var exchangeRate: Decimal = 32 // USD to TWD 匯率
    
    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil,
         priceService: PriceServiceProtocol? = nil) {
        let service = dataService ?? MockDataService.shared
        self.dataService = service
        self.priceService = priceService ?? PriceService(dataService: service)
    }
    
    func loadAccountData(accountId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 載入該帳戶的交易記錄
            var transactions = try await dataService.fetchTransactions(accountId: accountId)
            
            // 對於轉帳/還款交易，需要同時獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
            // 這樣轉入帳戶的餘額才能正確計算
            do {
                // 嘗試獲取所有帳戶，找到包含該 accountId 的帳戶
                // 由於 mock data 使用 "test-user-id"，先嘗試這個
                let allAccounts = try await dataService.fetchAccounts(userId: "test-user-id")
                if let account = allAccounts.first(where: { $0.id == accountId }) {
                    // 獲取該用戶的所有交易
                    let allTransactions = try await dataService.fetchAllTransactions(userId: account.userId)
                    // 找到以該帳戶為目標帳戶的轉帳/還款交易
                    let incomingTransferTransactions = allTransactions.filter { transaction in
                        (transaction.type == .transfer || transaction.type == .repayment) &&
                        transaction.targetAccountId == accountId &&
                        transaction.accountId != accountId
                    }
                    transactions.append(contentsOf: incomingTransferTransactions)
                }
            } catch {
                // 如果獲取所有交易失敗，繼續使用該帳戶自己的交易
            }
            
            // 計算現金餘額（傳入所有相關交易和帳戶信息）
            let allAccounts = try await dataService.fetchAccounts(userId: "test-user-id")
            cashBalance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccounts)
            
            // 計算持股
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)
            
            // 載入當前價格並建立快照
            var holdingsSnapshots: [HoldingSnapshot] = []
            for holding in calculatedHoldings {
                let currentPrice = try await priceService.fetchCurrentPrice(
                    assetType: holding.assetType,
                    symbol: holding.symbol
                )
                
                let snapshot = HoldingSnapshot(
                    id: holding.id,
                    holding: holding,
                    currentPrice: currentPrice,
                    currentPriceDate: Date()
                )
                
                holdingsSnapshots.append(snapshot)
            }
            
            holdings = holdingsSnapshots
            
            // 計算持股市值
            holdingsValue = holdings.compactMap { $0.marketValue }.reduce(0, +)
            
            // 載入匯率
            if let exchangeRateData = try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil) {
                exchangeRate = exchangeRateData.rate
            }
            
        } catch {
            errorMessage = "載入帳戶資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refresh(accountId: String) async {
        await loadAccountData(accountId: accountId)
    }
}

