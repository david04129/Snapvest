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
            
            // 取得所有帳戶（一次取得，後續共用）
            let allAccounts = try await dataService.fetchAccounts(userId: "test-user-id")
            
            // 對於轉帳/還款交易，需要同時獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
            if let account = allAccounts.first(where: { $0.id == accountId }) {
                do {
                    let allTransactions = try await dataService.fetchAllTransactions(userId: account.userId)
                    let incomingTransferTransactions = allTransactions.filter { transaction in
                        (transaction.type == .transfer || transaction.type == .repayment) &&
                        transaction.targetAccountId == accountId &&
                        transaction.accountId != accountId
                    }
                    transactions.append(contentsOf: incomingTransferTransactions)
                } catch {
                    // 如果獲取所有交易失敗，繼續使用該帳戶自己的交易
                }
            }
            
            // 計算現金餘額（傳入所有相關交易和帳戶信息，跨幣別買賣會依 exchangeRate 換算）
            cashBalance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccounts)
            
            // 取得帳戶以取得貨幣（用於持股市值換算與顯示）
            guard let account = allAccounts.first(where: { $0.id == accountId }) else {
                isLoading = false
                return
            }
            
            // 台幣帳戶以 TWD 顯示（default 為 USD 會導致錯誤）
            if account.currency == .TWD {
                displayCurrency = .TWD
            }
            
            // 計算持股
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)
            
            // 載入匯率（先載入，持股市值換算需要）
            var rate: Decimal = 32
            if let exchangeRateData = try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil) {
                rate = exchangeRateData.rate
            }
            exchangeRate = rate
            
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
            
            // 計算持股市值（換算為帳戶貨幣：台幣證券戶持有美股時，USD 市值 × 匯率 = TWD）
            holdingsValue = holdings.compactMap { snapshot -> Decimal? in
                guard let marketValue = snapshot.marketValue else { return nil }
                return Self.valueInAccountCurrency(
                    amount: marketValue,
                    fromCurrency: snapshot.holding.currency,
                    accountCurrency: account.currency,
                    exchangeRate: rate
                )
            }.reduce(0, +)
            
        } catch {
            errorMessage = "載入帳戶資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refresh(accountId: String) async {
        await loadAccountData(accountId: accountId)
    }
    
    /// 將金額換算為帳戶貨幣（1 USD = exchangeRate TWD）
    private static func valueInAccountCurrency(
        amount: Decimal,
        fromCurrency: Currency,
        accountCurrency: Currency,
        exchangeRate: Decimal
    ) -> Decimal {
        guard fromCurrency != accountCurrency, exchangeRate > 0 else { return amount }
        if fromCurrency == .USD && accountCurrency == .TWD {
            return amount * exchangeRate
        }
        if fromCurrency == .TWD && accountCurrency == .USD {
            return amount / exchangeRate
        }
        return amount
    }
}

