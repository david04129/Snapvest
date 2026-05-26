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
    @Published var exchangeRate: Decimal = 0 // USD to TWD 匯率
    
    private(set) var hasLoadedOnce = false
    
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil,
         priceService: PriceServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
        _ = priceService
        if let cachedRate = ExchangeRateSessionCache.usdToTwd {
            exchangeRate = cachedRate
        }
    }
    
    /// 帶入帳戶列表已算好的餘額，避免詳情首幀從 0 閃爍
    func applyPrefill(_ balance: AccountBalanceDisplay) {
        cashBalance = balance.cashBalance
        holdingsValue = balance.holdingsValue
    }
    
    /// 帶入 Splash／帳戶 Tab 預建的持股明細（同步、零網路）
    func applyCachedHoldings(_ cached: [HoldingSnapshot], account: Account) {
        if let cachedRate = ExchangeRateSessionCache.usdToTwd {
            exchangeRate = cachedRate
        }
        holdings = cached
        holdingsValue = sumHoldingsValue(cached, account: account)
        if account.currency == .TWD {
            displayCurrency = .TWD
        }
    }
    
    /// 從本機估值 B 套用帳戶明細（不重算交易、不逐檔拉 Supabase）
    func loadFromPersisted(accountId: String, account: Account) async {
        errorMessage = nil
        
        if let cachedRate = ExchangeRateSessionCache.usdToTwd {
            exchangeRate = cachedRate
        }
        
        if let cached = AccountDetailPresentationStore.holdings(for: accountId), !cached.isEmpty {
            if let snapshot = try? await dataService.fetchAccountSnapshot(accountId: accountId) {
                cashBalance = snapshot.cashBalance
            }
            applyCachedHoldings(cached, account: account)
            hasLoadedOnce = true
            return
        }
        
        guard let accountSnapshot = try? await dataService.fetchAccountSnapshot(accountId: accountId) else {
            await loadAccountDataFallback(accountId: accountId)
            return
        }
        
        await applySnapshot(accountSnapshot, accountId: accountId, account: account)
        hasLoadedOnce = true
    }
    
    func refresh(accountId: String, account: Account) async {
        await loadFromPersisted(accountId: accountId, account: account)
    }
    
    /// 相容舊呼叫端（sheet／表單完成後刷新）
    func refresh(accountId: String) async {
        guard let account = try? await fetchAccount(accountId: accountId) else { return }
        await loadFromPersisted(accountId: accountId, account: account)
    }
    
    func loadAccountData(accountId: String) async {
        guard let account = try? await fetchAccount(accountId: accountId) else { return }
        await loadFromPersisted(accountId: accountId, account: account)
    }
    
    private func fetchAccount(accountId: String) async throws -> Account? {
        let accounts = try await dataService.fetchAccounts(userId: AppUser.id)
        return accounts.first(where: { $0.id == accountId })
    }
    
    // MARK: - Private
    
    private func applySnapshot(_ accountSnapshot: AccountSnapshot, accountId: String, account: Account) async {
        cashBalance = accountSnapshot.cashBalance
        let builtHoldings = await AccountDetailHoldingsBuilder.build(
            from: accountSnapshot,
            accountId: accountId,
            dataService: dataService
        )
        holdings = builtHoldings
        holdingsValue = sumHoldingsValue(builtHoldings, account: account)
        if account.currency == .TWD {
            displayCurrency = .TWD
        }
    }
    
    private func sumHoldingsValue(_ snapshots: [HoldingSnapshot], account: Account) -> Decimal {
        snapshots.reduce(into: Decimal.zero) { partial, snapshot in
            guard let marketValue = snapshot.marketValue else { return }
            partial += Self.valueInAccountCurrency(
                amount: marketValue,
                fromCurrency: snapshot.holding.currency,
                accountCurrency: account.currency,
                exchangeRate: exchangeRate
            )
        }
    }
    
    /// 本機無 accountSnapshot 時才從交易重算（fallback）
    private func loadAccountDataFallback(accountId: String) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let transactions = try await dataService.fetchTransactions(accountId: accountId)
            let allAccounts = try await dataService.fetchAccounts(userId: AppUser.id)
            
            guard let account = allAccounts.first(where: { $0.id == accountId }) else { return }
            
            cashBalance = CashCalculator.calculateCash(
                accountId: accountId,
                transactions: transactions,
                accounts: allAccounts
            )
            
            if let cachedRate = ExchangeRateSessionCache.usdToTwd {
                exchangeRate = cachedRate
            } else if let rate = try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate {
                exchangeRate = rate
            }
            
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: transactions)
            var built: [HoldingSnapshot] = []
            for holding in calculatedHoldings {
                let priceSnapshot = try? await dataService.fetchAssetPriceSnapshot(
                    assetType: holding.assetType,
                    symbol: holding.symbol
                )
                built.append(
                    HoldingSnapshot(
                        id: holding.id,
                        holding: holding,
                        currentPrice: priceSnapshot?.displayPrice,
                        currentPriceDate: priceSnapshot?.displayPriceDate
                    )
                )
            }
            holdings = built
            holdingsValue = sumHoldingsValue(built, account: account)
            
            if account.currency == .TWD {
                displayCurrency = .TWD
            }
        } catch {
            errorMessage = "載入帳戶資料失敗：\(error.localizedDescription)"
        }
        
        hasLoadedOnce = true
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
