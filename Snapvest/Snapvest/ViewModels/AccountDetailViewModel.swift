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
    @Published var displayCurrency: Currency = .TWD
    @Published var exchangeRate: Decimal = 32 // USD to TWD 匯率
    
    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil,
         priceService: PriceServiceProtocol? = nil) {
        let service = dataService ?? MockDataService.shared
        self.dataService = service
        self.priceService = priceService ?? PriceService(dataService: service)
    }
    
    /// 帶入帳戶列表已算好的餘額，避免詳情首幀從 0 閃爍
    func applyPrefill(_ balance: AccountBalanceDisplay) {
        cashBalance = balance.cashBalance
        holdingsValue = balance.holdingsValue
    }
    
    func loadAccountData(accountId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var transactions = try await dataService.fetchTransactions(accountId: accountId)
            let allAccounts = try await dataService.fetchAccounts(userId: AppUser.id)
            
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
            
            guard let account = allAccounts.first(where: { $0.id == accountId }) else {
                isLoading = false
                return
            }
            
            let localCashBalance = CashCalculator.calculateCash(
                accountId: accountId,
                transactions: transactions,
                accounts: allAccounts
            )
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)
            
            var localRate: Decimal = 32
            if let exchangeRateData = try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil) {
                localRate = exchangeRateData.rate
            }
            
            let localHoldings = await buildHoldingsSnapshots(
                from: calculatedHoldings,
                priceService: priceService
            )
            
            let localHoldingsValue = localHoldings.compactMap { snapshot -> Decimal? in
                guard let marketValue = snapshot.marketValue else { return nil }
                return Self.valueInAccountCurrency(
                    amount: marketValue,
                    fromCurrency: snapshot.holding.currency,
                    accountCurrency: account.currency,
                    exchangeRate: localRate
                )
            }.reduce(0, +)
            
            // 一次更新，避免現金／持股分兩幀刷新
            exchangeRate = localRate
            cashBalance = localCashBalance
            holdings = localHoldings
            holdingsValue = localHoldingsValue
            if account.currency == .TWD {
                displayCurrency = .TWD
            }
            
        } catch {
            errorMessage = "載入帳戶資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refresh(accountId: String) async {
        await loadAccountData(accountId: accountId)
    }
    
    private func buildHoldingsSnapshots(
        from holdings: [Holding],
        priceService: PriceServiceProtocol
    ) async -> [HoldingSnapshot] {
        guard !holdings.isEmpty else { return [] }
        
        return await withTaskGroup(
            of: (Int, HoldingSnapshot?).self,
            returning: [HoldingSnapshot].self
        ) { group in
            for (index, holding) in holdings.enumerated() {
                group.addTask {
                    guard let currentPrice = try? await priceService.fetchCurrentPrice(
                        assetType: holding.assetType,
                        symbol: holding.symbol
                    ) else {
                        return (index, nil)
                    }
                    let snapshot = HoldingSnapshot(
                        id: holding.id,
                        holding: holding,
                        currentPrice: currentPrice,
                        currentPriceDate: Date()
                    )
                    return (index, snapshot)
                }
            }
            
            var indexed: [(Int, HoldingSnapshot)] = []
            for await result in group {
                if let snapshot = result.1 {
                    indexed.append((result.0, snapshot))
                }
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
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
