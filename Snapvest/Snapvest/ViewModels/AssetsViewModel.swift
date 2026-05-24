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
    @Published private(set) var hasLoadedOnce = false
    @Published var errorMessage: String?
    
    @Published var totalAssets: Decimal = 0
    @Published var totalInvestments: Decimal = 0
    @Published var totalCash: Decimal = 0
    
    /// 總資產圓餅圖：各類市值（台幣）
    @Published var allocationTwdCash: Decimal = 0
    @Published var allocationUsdCashTWD: Decimal = 0
    @Published var allocationStockTW: Decimal = 0
    @Published var allocationStockUS: Decimal = 0
    @Published var allocationCrypto: Decimal = 0
    
    @Published private(set) var usdToTwdRate: Decimal = 0
    
    /// 即時匯率（用於市值和現金餘額轉換為台幣）
    var displayUsdToTwdRate: Decimal { usdToTwdRate }
    
    /// 購買時匯率（用於成本計算）
    /// 注意：購買時匯率已存儲在 Transaction.exchangeRate 和 AggregatedHoldingSnapshot.fifoLotsByAccount 中
    /// 此處不需要額外變數，因為成本計算時直接使用快照中存儲的匯率
    
    private let dataService: DataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }
    
    /// 從本機估值 B 灌入資產分頁（Splash／快照更新；不拉 Supabase）
    func applyFromPersisted(userId: String, usdToTwdRate: Decimal) async {
        errorMessage = nil
        self.usdToTwdRate = usdToTwdRate

        do {
            let fetchedAccounts = try await dataService.fetchAccounts(userId: userId)
            let accountSnapshots = try await loadAccountSnapshots(accounts: fetchedAccounts)
            let aggregated = try await dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
            let symbolInfos = await loadSymbolInfos(
                userId: userId,
                accountSnapshots: accountSnapshots,
                aggregatedHoldings: aggregated
            )
            let assetPriceSnapshots = try await dataService.fetchAssetPriceSnapshots(symbols: symbolInfos)

            self.aggregatedHoldings = aggregated
            self.assetPriceSnapshots = assetPriceSnapshots
            await calculateSummary(
                assetPriceSnapshots: assetPriceSnapshots,
                accountSnapshots: accountSnapshots,
                accounts: fetchedAccounts
            )
        } catch {
            errorMessage = "載入資料失敗：\(error.localizedDescription)"
        }

        isLoading = false
        hasLoadedOnce = true
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
                totalInvestmentsValue += marketValue * usdToTwdRate
            }
        }
        
        // 2. 計算總現金（使用即時匯率轉換為 TWD）
        // 按貨幣分組計算現金，排除債務帳戶（債務是負債，不應計入總資產）
        var cashByCurrency: [Currency: Decimal] = [:]
        for snapshot in accountSnapshots {
            guard let account = accountMap[snapshot.accountId] else { continue }
            
            if account.accountType.isLiabilityAccount {
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
                totalCashTWD += amount * usdToTwdRate
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
        
        allocationTwdCash = cashByCurrency[.TWD] ?? 0
        let usdCash = cashByCurrency[.USD] ?? 0
        allocationUsdCashTWD = usdCash * usdToTwdRate
        
        var tw: Decimal = 0
        var us: Decimal = 0
        var crypto: Decimal = 0
        for aggregated in aggregatedHoldings {
            let key = "\(aggregated.assetType.rawValue)_\(aggregated.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            let marketValue = aggregated.totalQuantity * currentPrice
            let marketValueTWD: Decimal
            if aggregated.currency == .TWD {
                marketValueTWD = marketValue
            } else if aggregated.currency == .USD {
                marketValueTWD = marketValue * usdToTwdRate
            } else {
                continue
            }
            switch aggregated.assetType {
            case .stockTW: tw += marketValueTWD
            case .stockUS: us += marketValueTWD
            case .crypto: crypto += marketValueTWD
            case .cash: break
            }
        }
        allocationStockTW = tw
        allocationStockUS = us
        allocationCrypto = crypto
    }
}
