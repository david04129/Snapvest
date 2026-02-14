//
//  CategoryTotalViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class CategoryTotalViewModel: ObservableObject {
    @Published var totalAssets: Decimal = 0
    
    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil,
         priceService: PriceServiceProtocol? = nil) {
        let service = dataService ?? MockDataService.shared
        self.dataService = service
        self.priceService = priceService ?? PriceService(dataService: service)
    }
    
    func calculateCategoryTotal(
        accounts: [Account],
        portfolioViewModel: PortfolioViewModel
    ) async {
        var total: Decimal = 0
        
        // TODO: 從匯率服務獲取即時匯率
        let usdToTwdRate: Decimal = 32 // 臨時固定值
        
        // 獲取所有交易，以便正確計算轉帳/還款交易的影響
        let userId = accounts.first?.userId ?? "test-user-id"
        var allTransactions: [Transaction] = []
        do {
            allTransactions = try await dataService.fetchAllTransactions(userId: userId)
        } catch {
            // 如果獲取所有交易失敗，繼續使用單個帳戶的交易
        }
        
        for account in accounts {
            do {
                // 獲取該帳戶的交易記錄
                var transactions = try await dataService.fetchTransactions(accountId: account.id)
                
                // 如果是轉帳/還款，需要同時獲取以該帳戶為目標帳戶的交易
                if !allTransactions.isEmpty {
                    let incomingTransferTransactions = allTransactions.filter { transaction in
                        (transaction.type == .transfer || transaction.type == .repayment) &&
                        transaction.targetAccountId == account.id &&
                        transaction.accountId != account.id
                    }
                    transactions.append(contentsOf: incomingTransferTransactions)
                }
                
                // 計算現金餘額（傳入所有相關交易和帳戶信息）
                let cashBalance = CashCalculator.calculateCash(accountId: account.id, transactions: transactions, accounts: accounts)
                
                // 計算持股
                let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)
                
                // 載入當前價格並計算持股市值（換算為帳戶貨幣後再加總）
                var holdingsValueInAccountCurrency: Decimal = 0
                for holding in calculatedHoldings {
                    let currentPrice = try await priceService.fetchCurrentPrice(
                        assetType: holding.assetType,
                        symbol: holding.symbol
                    )
                    
                    if let price = currentPrice {
                        var marketValue = holding.quantity * price
                        // 跨幣別：持股市值換算為帳戶貨幣
                        if holding.currency != account.currency {
                            if holding.currency == .USD && account.currency == .TWD {
                                marketValue = marketValue * usdToTwdRate
                            } else if holding.currency == .TWD && account.currency == .USD {
                                marketValue = usdToTwdRate > 0 ? marketValue / usdToTwdRate : marketValue
                            }
                        }
                        holdingsValueInAccountCurrency += marketValue
                    }
                }
                
                // 計算帳戶總資產（已統一為帳戶貨幣）
                let accountTotal = cashBalance + holdingsValueInAccountCurrency
                
                // 轉換為 TWD 加總
                if account.currency == .TWD {
                    total += accountTotal
                } else if account.currency == .USD {
                    total += accountTotal * usdToTwdRate
                } else {
                    total += accountTotal
                }
            } catch {
                // 如果計算失敗，跳過該帳戶
                continue
            }
        }
        
        totalAssets = total
    }
}

