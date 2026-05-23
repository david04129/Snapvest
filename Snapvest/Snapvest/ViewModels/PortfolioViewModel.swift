//
//  PortfolioViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var totalAssets: Decimal = 0
    @Published var totalLiabilities: Decimal = 0
    @Published var totalCash: Decimal = 0
    @Published var totalInvestments: Decimal = 0
    @Published var unrealizedGainLoss: Decimal = 0
    @Published var realizedGainLoss: Decimal = 0
    @Published var realizedGainLossTWD: Decimal = 0
    @Published var realizedGainLossUSD: Decimal = 0
    @Published var holdings: [HoldingSnapshot] = []
    @Published var liabilities: [Liability] = []
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var homeSnapshot: HomeDashboardSnapshot?
    @Published var pieChartInputs: PieChartInputs?
    
    @Published var baseCurrency: Currency = .TWD
    @Published var viewCurrency: Currency = .TWD // 顯示貨幣（可切換）
    
    // 按貨幣分組的現金餘額
    @Published var cashByCurrency: [Currency: Decimal] = [:]
    
    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private(set) var hasLoadedOnce = false
    
    init(dataService: DataServiceProtocol? = nil,
         priceService: PriceServiceProtocol? = nil) {
        let service = dataService ?? MockDataService.shared
        self.dataService = service
        self.priceService = priceService ?? PriceService(dataService: service)
    }
    
    /// 載入所有資料
    func loadData(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 並行載入所有資料
            async let accountsTask = dataService.fetchAccounts(userId: userId)
            async let liabilitiesTask = loadLiabilities(userId: userId)
            async let transactionsTask = dataService.fetchAllTransactions(userId: userId)
            
            let fetchedAccounts = try await accountsTask
            self.accounts = fetchedAccounts
            
            // 載入交易並計算持股
            let allTransactions = try await transactionsTask
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: allTransactions)
            
            // 計算已實現損益（依貨幣）
            let realizedByCurrency = HoldingCalculator.calculateRealizedGainLossByCurrency(from: allTransactions)
            self.realizedGainLossTWD = realizedByCurrency[.TWD] ?? 0
            self.realizedGainLossUSD = realizedByCurrency[.USD] ?? 0
            
            // 載入每個持股的當前價格
            var allHoldings: [HoldingSnapshot] = []
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
                
                allHoldings.append(snapshot)
            }
            
            self.holdings = allHoldings
            self.liabilities = try await liabilitiesTask
            
            // 計算總覽數據
            await calculateSummary()
            await refreshPieChartData(userId: userId)
            
            // 儲存首頁快照
            if let userId = accounts.first?.userId {
                await saveHomeDashboardSnapshot(userId: userId)
            }
            
        } catch {
            errorMessage = "載入資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
        hasLoadedOnce = true
    }

    /// 載入首頁快照（不重新計算）
    func loadHomeSnapshot(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await dataService.fetchHomeDashboardSnapshot(userId: userId)
            homeSnapshot = snapshot
            applyHomeSnapshot(snapshot)
        } catch {
            errorMessage = "載入首頁快照失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }

    /// 確保首頁快照存在（若沒有則先計算再讀取）
    func ensureHomeSnapshot(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await dataService.fetchHomeDashboardSnapshot(userId: userId)
            if snapshot == nil {
                await loadData(userId: userId)
            }
            let latestSnapshot = try await dataService.fetchHomeDashboardSnapshot(userId: userId)
            homeSnapshot = latestSnapshot
            applyHomeSnapshot(latestSnapshot)
            await refreshPieChartData(userId: userId)
        } catch {
            errorMessage = "載入首頁快照失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
        hasLoadedOnce = true
    }
    
    /// 載入圓餅圖用持股與現金明細
    func refreshPieChartData(userId: String) async {
        pieChartInputs = try? await PieChartDataLoader.load(
            userId: userId,
            dataService: dataService,
            priceService: priceService
        )
    }
    
    /// 重新載入負債（帳戶改名等操作後需刷新，避免與 debt 帳戶名稱配對失敗）
    func reloadLiabilities(userId: String) async {
        do {
            liabilities = try await loadLiabilities(userId: userId)
            await calculateSummary()
            await saveHomeDashboardSnapshot(userId: userId)
        } catch {
            // 保留現有資料
        }
    }
    
    /// 載入所有負債
    private func loadLiabilities(userId: String) async throws -> [Liability] {
        let accounts = try await dataService.fetchAccounts(userId: userId)
        var allLiabilities: [Liability] = []
        
        for account in accounts {
            let accountLiabilities = try await dataService.fetchLiabilities(accountId: account.id)
            allLiabilities.append(contentsOf: accountLiabilities)
        }
        
        return allLiabilities
    }
    
    /// 計算總覽數據
    private func calculateSummary() async {
        // TODO: 從匯率服務獲取即時匯率
        let usdToTwdRate: Decimal = 32 // 臨時固定值，之後應該從 ExchangeRate 服務獲取
        
        // 計算總投資（所有持股的市值，轉換為 TWD）
        var totalInvestmentsValue: Decimal = 0
        var totalUnrealizedGainLoss: Decimal = 0
        
        // 按帳戶分組計算持股
        var holdingsByAccount: [String: [HoldingSnapshot]] = [:]
        for holding in holdings {
            let accountId = holding.holding.accountId
            if holdingsByAccount[accountId] == nil {
                holdingsByAccount[accountId] = []
            }
            holdingsByAccount[accountId]?.append(holding)
        }
        
        // 計算每個帳戶的投資和損益（按原始貨幣），然後轉換為 TWD
        for (accountId, accountHoldings) in holdingsByAccount {
            // 找到對應的帳戶以獲取貨幣
            guard let account = accounts.first(where: { $0.id == accountId }) else { continue }
            
            var accountInvestments: Decimal = 0
            var accountGainLoss: Decimal = 0
            
            for holding in accountHoldings {
                if let marketValue = holding.marketValue {
                    accountInvestments += marketValue
                }
                if let gainLoss = holding.unrealizedGainLoss {
                    accountGainLoss += gainLoss
                }
            }
            
            // 轉換為 TWD
            if account.currency == .TWD {
                totalInvestmentsValue += accountInvestments
                totalUnrealizedGainLoss += accountGainLoss
            } else if account.currency == .USD {
                totalInvestmentsValue += accountInvestments * usdToTwdRate
                totalUnrealizedGainLoss += accountGainLoss * usdToTwdRate
            } else {
                // 其他貨幣，暫時不轉換
                totalInvestmentsValue += accountInvestments
                totalUnrealizedGainLoss += accountGainLoss
            }
        }
        
        // 計算總現金（按貨幣分組，然後轉換為 TWD）
        do {
            let allTransactions = try await dataService.fetchAllTransactions(userId: accounts.first?.userId ?? "")
            
            // 按貨幣分組計算現金
            // 傳入所有交易，CashCalculator 會自己處理轉帳/還款交易的過濾
            // 因為轉帳/還款交易記錄在轉出帳戶，但影響轉入帳戶的餘額
            // 注意：債務帳戶不應計入總資產，只計算非債務帳戶的現金
            var cashByCurrencyLocal: [Currency: Decimal] = [:]
            for account in accounts {
                // 跳過債務帳戶，因為債務是負債，不應計入總資產
                if account.accountType == .debt {
                    continue
                }
                
                let cash = CashCalculator.calculateCash(accountId: account.id, transactions: allTransactions, accounts: accounts)
                
                if let existing = cashByCurrencyLocal[account.currency] {
                    cashByCurrencyLocal[account.currency] = existing + cash
                } else {
                    cashByCurrencyLocal[account.currency] = cash
                }
            }
            
            // 保存按貨幣分組的現金（用於顯示）
            self.cashByCurrency = cashByCurrencyLocal
            
            // 轉換為 TWD
            var totalCashTWD: Decimal = 0
            for (currency, amount) in cashByCurrencyLocal {
                if currency == .TWD {
                    totalCashTWD += amount
                } else if currency == .USD {
                    totalCashTWD += amount * usdToTwdRate
                } else {
                    // 其他貨幣，暫時不轉換
                    totalCashTWD += amount
                }
            }
            
            totalCash = totalCashTWD
        } catch {
            // 如果獲取交易失敗，設為 0
            totalCash = 0
        }
        
        // 計算總負債（轉換為 TWD；已封存債務不計入）
        var totalLiabilitiesValue: Decimal = 0
        for liability in liabilities {
            if DebtAccountArchive.isDebtAccountArchived(named: liability.name, accounts: accounts) {
                continue
            }
            if liability.currency == .TWD {
                totalLiabilitiesValue += liability.remainingBalance
            } else if liability.currency == .USD {
                totalLiabilitiesValue += liability.remainingBalance * usdToTwdRate
            } else {
                // 其他貨幣，暫時不轉換
                totalLiabilitiesValue += liability.remainingBalance
            }
        }
        
        totalInvestments = totalInvestmentsValue
        totalLiabilities = totalLiabilitiesValue
        unrealizedGainLoss = totalUnrealizedGainLoss
        totalAssets = totalInvestments + totalCash
        
        // 已實現損益（顯示用，統一轉為 TWD）
        realizedGainLoss = realizedGainLossTWD + (realizedGainLossUSD * usdToTwdRate)
        
        // 更新持股的投資佔比和資產佔比
        updateHoldingRatios()
    }

    private func applyHomeSnapshot(_ snapshot: HomeDashboardSnapshot?) {
        guard let snapshot = snapshot else {
            totalAssets = 0
            totalLiabilities = 0
            totalCash = 0
            totalInvestments = 0
            unrealizedGainLoss = 0
            realizedGainLoss = 0
            realizedGainLossTWD = 0
            realizedGainLossUSD = 0
            cashByCurrency = [:]
            return
        }
        
        totalAssets = snapshot.totalAssets
        totalLiabilities = snapshot.totalLiabilities
        totalCash = snapshot.totalCash
        totalInvestments = snapshot.totalAssets - snapshot.totalCash
        unrealizedGainLoss = snapshot.totalAssets - snapshot.totalCash - snapshot.totalInvestmentsCost
        realizedGainLossTWD = snapshot.realizedGainLossTWD
        realizedGainLossUSD = snapshot.realizedGainLossUSD
        cashByCurrency = [
            .TWD: snapshot.twdCash,
            .USD: snapshot.usdCash
        ]
        realizedGainLoss = realizedGainLossTWD + (realizedGainLossUSD * 32)

        Task {
            let usdToTwdRate = (try? await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 32
            realizedGainLoss = realizedGainLossTWD + (realizedGainLossUSD * usdToTwdRate)
        }
    }

    private func saveHomeDashboardSnapshot(userId: String) async {
        let netWorth = totalAssets - totalLiabilities
        let totalInvestmentsCost = totalInvestments - unrealizedGainLoss
        let twdCash = cashByCurrency[.TWD] ?? 0
        let usdCash = cashByCurrency[.USD] ?? 0
        
        let snapshot = HomeDashboardSnapshot(
            userId: userId,
            netWorth: netWorth,
            totalLiabilities: totalLiabilities,
            totalAssets: totalAssets,
            totalInvestmentsCost: totalInvestmentsCost,
            totalCash: totalCash,
            twdCash: twdCash,
            usdCash: usdCash,
            realizedGainLossTWD: realizedGainLossTWD,
            realizedGainLossUSD: realizedGainLossUSD,
            lastUpdated: Date()
        )
        
        do {
            try await dataService.saveHomeDashboardSnapshot(snapshot)
        } catch {
            // 快照儲存失敗不影響畫面顯示
        }
    }
    
    /// 更新持股的投資佔比和資產佔比
    private func updateHoldingRatios() {
        for i in 0..<holdings.count {
            var updatedHolding = holdings[i]
            if let marketValue = updatedHolding.marketValue {
                if totalInvestments > 0 {
                    updatedHolding.investmentRatio = (marketValue / totalInvestments) * 100
                }
                if totalAssets > 0 {
                    updatedHolding.assetRatio = (marketValue / totalAssets) * 100
                }
                holdings[i] = updatedHolding
            }
        }
    }
    
    /// 切換顯示貨幣
    func toggleViewCurrency() {
        if viewCurrency == .TWD {
            viewCurrency = baseCurrency
        } else {
            viewCurrency = .TWD
        }
        // 重新計算並轉換所有金額
        Task {
            await calculateSummary()
        }
    }
    
    /// 刷新資料
    func refresh(userId: String) async {
        await loadData(userId: userId)
    }
}

