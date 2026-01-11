//
//  AssetsViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class AssetsViewModel: ObservableObject {
    @Published var aggregatedHoldings: [AggregatedHoldingSnapshot] = []
    @Published var assetPriceSnapshots: [AssetPriceSnapshot] = [] // 價格快照（用於計算市值和損益）
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var totalAssets: Decimal = 0
    @Published var totalInvestments: Decimal = 0
    @Published var totalCash: Decimal = 0
    
    // 匯率變數（明確區分即時匯率和購買時匯率）
    /// 即時匯率（用於市值和現金餘額轉換為台幣）
    /// TODO: 未來從 ExchangeRate 服務獲取即時匯率
    private var currentExchangeRate: Decimal {
        // 目前使用固定模擬值，未來替換為即時匯率服務
        return 32 // USD to TWD
    }
    
    /// 購買時匯率（用於成本計算）
    /// 注意：購買時匯率已存儲在 Transaction.exchangeRate 和 AggregatedHoldingSnapshot.fifoLotsByAccount 中
    /// 此處不需要額外變數，因為成本計算時直接使用快照中存儲的匯率
    
    private let dataService: DataServiceProtocol
    private let priceService: PriceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
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
            async let transactionsTask = dataService.fetchAllTransactions(userId: userId)
            
            let fetchedAccounts = try await accountsTask
            let allTransactions = try await transactionsTask
            
            // 臨時方案：從交易記錄計算 AccountSnapshot（未來可以從快照系統讀取）
            let accountSnapshots = calculateAccountSnapshotsFromTransactions(
                accounts: fetchedAccounts,
                transactions: allTransactions
            )
            
            // 載入所有持股的價格快照
            let assetPriceSnapshots = try await loadAssetPriceSnapshots(
                userId: userId,
                accounts: fetchedAccounts,
                transactions: allTransactions
            )
            
            // 計算跨帳戶合併持股快照
            let aggregated = HoldingCalculator.calculateAggregatedHoldings(
                userId: userId,
                accountSnapshots: accountSnapshots,
                accounts: fetchedAccounts,
                transactions: allTransactions,
                assetPriceSnapshots: assetPriceSnapshots
            )
            
            self.aggregatedHoldings = aggregated
            self.assetPriceSnapshots = assetPriceSnapshots
            
            // 計算總覽數據（傳入 accountSnapshots 以計算總現金）
            await calculateSummary(
                assetPriceSnapshots: assetPriceSnapshots,
                accountSnapshots: accountSnapshots,
                accounts: fetchedAccounts
            )
            
        } catch {
            errorMessage = "載入資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 臨時方案：從交易記錄計算 AccountSnapshot（未來可以從快照系統讀取）
    private func calculateAccountSnapshotsFromTransactions(
        accounts: [Account],
        transactions: [Transaction]
    ) -> [AccountSnapshot] {
        var snapshots: [AccountSnapshot] = []
        
        // 獲取所有帳戶的交易（包含轉帳/還款的轉入交易）
        // 建立一個包含所有交易的集合（避免重複）
        var allTransactionsSet: Set<String> = []
        var allTransactions: [Transaction] = transactions
        
        // 添加轉帳/還款的轉入交易（避免重複）
        for account in accounts {
            let incomingTransactions = transactions.filter { transaction in
                (transaction.type == .transfer || transaction.type == .repayment) &&
                transaction.targetAccountId == account.id &&
                transaction.accountId != account.id &&
                !allTransactionsSet.contains(transaction.id)
            }
            for transaction in incomingTransactions {
                allTransactionsSet.insert(transaction.id)
                allTransactions.append(transaction)
            }
        }
        
        // 為每個帳戶計算快照
        for account in accounts {
            // 過濾出該帳戶的交易（包含轉入交易）
            let accountTransactions = allTransactions.filter { transaction in
                transaction.accountId == account.id || 
                ((transaction.type == .transfer || transaction.type == .repayment) &&
                 transaction.targetAccountId == account.id)
            }
            
            // 計算現金餘額
            let cashBalance = CashCalculator.calculateCash(
                accountId: account.id,
                transactions: accountTransactions,
                accounts: accounts
            )
            
            // 計算持股（使用 HoldingCalculator）
            let holdings = HoldingCalculator.calculateHoldings(from: accountTransactions)
            
            // 轉換為 HoldingSnapshotItem
            let holdingItems = holdings.map { holding -> HoldingSnapshotItem in
                HoldingSnapshotItem(
                    id: holding.id,
                    assetType: holding.assetType,
                    symbol: holding.symbol,
                    name: holding.name,
                    quantity: holding.quantity,
                    averageCost: holding.averageCost,
                    currency: holding.currency,
                    lastUpdated: holding.lastUpdated
                )
            }
            
            // 找到最後一筆交易日期
            let lastTransactionDate = accountTransactions
                .max(by: { $0.transactionDate < $1.transactionDate })?
                .transactionDate
            
            let snapshot = AccountSnapshot(
                accountId: account.id,
                cashBalance: cashBalance,
                holdings: holdingItems.isEmpty ? nil : holdingItems,
                lastUpdated: Date(),
                lastTransactionDate: lastTransactionDate,
                version: 1
            )
            
            snapshots.append(snapshot)
        }
        
        return snapshots
    }
    
    /// 載入所有持股的價格快照（從 AssetPriceSnapshot 或 PriceService）
    private func loadAssetPriceSnapshots(
        userId: String,
        accounts: [Account],
        transactions: [Transaction]
    ) async throws -> [AssetPriceSnapshot] {
        // 先從所有交易中找出所有唯一的股票
        var symbolSet: Set<String> = [] // key: "assetType_symbol"
        for transaction in transactions {
            if transaction.type == .buy || transaction.type == .sell {
                let key = "\(transaction.assetType.rawValue)_\(transaction.symbol)"
                symbolSet.insert(key)
            }
        }
        
        // 轉換為 SymbolInfo
        var symbolInfos: [SymbolInfo] = []
        for key in symbolSet {
            // 嘗試所有可能的 AssetType，找到匹配的
            for assetType in AssetType.allCases {
                let prefix = assetType.rawValue + "_"
                if key.hasPrefix(prefix) {
                    let symbol = String(key.dropFirst(prefix.count))
                    symbolInfos.append(SymbolInfo(assetType: assetType, symbol: symbol))
                    break
                }
            }
        }
        
        // 嘗試從快照系統讀取價格（未來）
        // 目前暫時從 PriceService 獲取價格
        
        var priceSnapshots: [AssetPriceSnapshot] = []
        
        for symbolInfo in symbolInfos {
            // 嘗試從 DataService 讀取快照
            if let snapshot = try? await dataService.fetchAssetPriceSnapshot(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol
            ) {
                priceSnapshots.append(snapshot)
            } else {
                // 如果沒有快照，從 PriceService 獲取價格（臨時方案）
                let currentPrice = try? await priceService.fetchCurrentPrice(
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
                
                // 判斷貨幣（從帳戶推斷，或使用預設值）
                let currency: Currency = symbolInfo.assetType == .stockTW ? .TWD : .USD
                
                let snapshot = AssetPriceSnapshot(
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol,
                    name: nil, // 暫時為 nil，未來可以從後端獲取
                    currency: currency,
                    currentPrice: currentPrice,
                    previousPrice: nil,
                    currentPriceDate: Date(),
                    previousPriceDate: nil,
                    lastUpdated: Date(),
                    lastSuccessfulUpdate: currentPrice != nil ? Date() : nil
                )
                
                priceSnapshots.append(snapshot)
            }
        }
        
        return priceSnapshots
    }
    
    /// 計算總覽數據
    /// - Parameters:
    ///   - assetPriceSnapshots: 資產價格快照（用於計算市值）
    ///   - accountSnapshots: 帳戶快照（用於計算總現金）
    ///   - accounts: 帳戶列表（用於獲取帳戶貨幣類型）
    private func calculateSummary(
        assetPriceSnapshots: [AssetPriceSnapshot],
        accountSnapshots: [AccountSnapshot],
        accounts: [Account]
    ) async {
        // 建立價格快照映射
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            priceMap[key] = snapshot
        }
        
        // 建立帳戶映射（用於快速查找帳戶貨幣）
        var accountMap: [String: Account] = [:]
        for account in accounts {
            accountMap[account.id] = account
        }
        
        // ============================================
        // 使用即時匯率計算的部分（currentExchangeRate）
        // ============================================
        
        // 1. 計算總投資（所有持股的市值，使用即時匯率轉換為 TWD）
        var totalInvestmentsValue: Decimal = 0
        
        for aggregated in aggregatedHoldings {
            let key = "\(aggregated.assetType.rawValue)_\(aggregated.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            
            // 計算市值（原幣）
            let marketValue = aggregated.totalQuantity * currentPrice
            
            // 使用即時匯率轉換為 TWD
            if aggregated.currency == .TWD {
                totalInvestmentsValue += marketValue
            } else if aggregated.currency == .USD {
                totalInvestmentsValue += marketValue * currentExchangeRate
            }
        }
        
        // 2. 計算總現金（使用即時匯率轉換為 TWD）
        // 按貨幣分組計算現金，排除債務帳戶（債務是負債，不應計入總資產）
        var cashByCurrency: [Currency: Decimal] = [:]
        for snapshot in accountSnapshots {
            guard let account = accountMap[snapshot.accountId] else { continue }
            
            // 跳過債務帳戶
            if account.accountType == .debt {
                continue
            }
            
            // 累加該貨幣的現金餘額
            if let existing = cashByCurrency[account.currency] {
                cashByCurrency[account.currency] = existing + snapshot.cashBalance
            } else {
                cashByCurrency[account.currency] = snapshot.cashBalance
            }
        }
        
        // 使用即時匯率轉換為 TWD
        var totalCashTWD: Decimal = 0
        for (currency, amount) in cashByCurrency {
            if currency == .TWD {
                totalCashTWD += amount
            } else if currency == .USD {
                totalCashTWD += amount * currentExchangeRate
            } else {
                // 其他貨幣，暫時不轉換（或使用預設匯率）
                totalCashTWD += amount
            }
        }
        
        // ============================================
        // 注意：總成本計算使用購買時匯率
        // 購買時匯率已存儲在 AggregatedHoldingSnapshot.totalCost 中
        // （該值在計算時已使用 Transaction.exchangeRate，即購買時的匯率）
        // 因此這裡不需要額外處理
        // ============================================
        
        self.totalInvestments = totalInvestmentsValue
        self.totalCash = totalCashTWD
        self.totalAssets = totalInvestmentsValue + totalCashTWD
    }
}
