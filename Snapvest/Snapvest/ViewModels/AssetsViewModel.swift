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
            let fetchedAccounts = try await dataService.fetchAccounts(userId: userId)
            let accountSnapshots = try await loadAccountSnapshots(accounts: fetchedAccounts)
            var aggregated = try await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
            let symbolInfos = await loadSymbolInfos(userId: userId, accountSnapshots: accountSnapshots, aggregatedHoldings: aggregated)
            let assetPriceSnapshots = try await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)
            
            if aggregated.isEmpty || accountSnapshots.isEmpty || assetPriceSnapshots.isEmpty {
                let bundle = try await SnapshotUpdater.rebuildSnapshots(
                    userId: userId,
                    dataService: dataService,
                    priceService: priceService
                )
                aggregated = bundle.aggregatedHoldings
                self.assetPriceSnapshots = bundle.assetPriceSnapshots
                self.aggregatedHoldings = bundle.aggregatedHoldings
                await calculateSummary(
                    assetPriceSnapshots: bundle.assetPriceSnapshots,
                    accountSnapshots: bundle.accountSnapshots,
                    accounts: fetchedAccounts
                )
            } else {
                self.assetPriceSnapshots = assetPriceSnapshots
                self.aggregatedHoldings = aggregated
                await calculateSummary(
                    assetPriceSnapshots: assetPriceSnapshots,
                    accountSnapshots: accountSnapshots,
                    accounts: fetchedAccounts
                )
            }
            
        } catch {
            errorMessage = "載入資料失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }

    private func loadAccountSnapshots(accounts: [Account]) async throws -> [AccountSnapshot] {
        var snapshots: [AccountSnapshot] = []
        for account in accounts {
            if let snapshot = try await dataService.fetchAccountSnapshot(accountId: account.id) {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    private func loadSymbolInfos(
        userId: String,
        accountSnapshots: [AccountSnapshot],
        aggregatedHoldings: [AggregatedHoldingSnapshot]
    ) async -> [SymbolInfo] {
        if let userSnapshot = try? await dataService.fetchUserHoldingsSnapshot(userId: userId) {
            if !userSnapshot.symbols.isEmpty {
                return userSnapshot.symbols
            }
        }
        
        if !aggregatedHoldings.isEmpty {
            return aggregatedHoldings.map { SymbolInfo(assetType: $0.assetType, symbol: $0.symbol) }
        }
        
        var symbolInfos: [SymbolInfo] = []
        var symbolSet: Set<String> = []
        for snapshot in accountSnapshots {
            guard let holdings = snapshot.holdings else { continue }
            for holding in holdings {
                let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
                if symbolSet.contains(key) { continue }
                symbolSet.insert(key)
                symbolInfos.append(SymbolInfo(assetType: holding.assetType, symbol: holding.symbol))
            }
        }
        return symbolInfos
    }
    
    // 計算邏輯已移至 SnapshotUpdater
    
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
