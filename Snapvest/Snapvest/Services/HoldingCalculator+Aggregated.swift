//
//  HoldingCalculator+Aggregated.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

extension HoldingCalculator {
    /// 計算跨帳戶合併持股快照（從所有 AccountSnapshot 合併）
    /// - Parameters:
    ///   - userId: 使用者ID
    ///   - accountSnapshots: 所有帳戶的快照
    ///   - accounts: 所有帳戶資訊
    ///   - transactions: 所有交易記錄（用於計算 FIFO 批次）
    ///   - assetPriceSnapshots: 資產價格快照（用於同步 name 和 currency）
    /// - Returns: 跨帳戶合併持股快照列表
    static func calculateAggregatedHoldings(
        userId: String,
        accountSnapshots: [AccountSnapshot],
        accounts: [Account],
        transactions: [Transaction],
        assetPriceSnapshots: [AssetPriceSnapshot]
    ) -> [AggregatedHoldingSnapshot] {
        // 建立 (assetType, symbol) -> AssetPriceSnapshot 的映射
        var priceSnapshotMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            priceSnapshotMap[key] = snapshot
        }
        
        // 建立 accountId -> Account 的映射
        var accountMap: [String: Account] = [:]
        for account in accounts {
            accountMap[account.id] = account
        }
        
        // 按 (assetType, symbol) 分組合併持股
        var aggregatedMap: [String: AggregatedHoldingSnapshot] = [:] // key: "assetType_symbol"
        
        // 遍歷所有 AccountSnapshot
        for accountSnapshot in accountSnapshots {
            guard let holdings = accountSnapshot.holdings else { continue }
            // 確保帳戶存在（雖然目前沒有使用 account，但保留檢查以確保數據一致性）
            guard accountMap[accountSnapshot.accountId] != nil else { continue }
            
            // 遍歷該帳戶的所有持股
            for holdingItem in holdings {
                let key = "\(holdingItem.assetType.rawValue)_\(holdingItem.symbol)"
                
                // 獲取或建立 AggregatedHoldingSnapshot
                if var aggregated = aggregatedMap[key] {
                    // 已存在，合併計算
                    let existingTotalCost = aggregated.totalCost
                    let newTotalCost = holdingItem.totalCost
                    let totalCost = existingTotalCost + newTotalCost
                    let totalQuantity = aggregated.totalQuantity + holdingItem.quantity
                    
                    // 計算加權平均成本
                    let weightedAverageCost = totalQuantity > 0 ? (totalCost / totalQuantity) : 0
                    
                    aggregated.totalQuantity = totalQuantity
                    aggregated.weightedAverageCost = weightedAverageCost
                    aggregated.totalCost = totalCost
                    
                    // 更新來源帳戶ID列表
                    if !aggregated.sourceAccountIds.contains(accountSnapshot.accountId) {
                        aggregated.sourceAccountIds.append(accountSnapshot.accountId)
                    }
                    
                    aggregatedMap[key] = aggregated
                } else {
                    // 新建
                    let priceKey = "\(holdingItem.assetType.rawValue)_\(holdingItem.symbol)"
                    let priceSnapshot = priceSnapshotMap[priceKey]
                    
                    let aggregated = AggregatedHoldingSnapshot(
                        userId: userId,
                        assetType: holdingItem.assetType,
                        symbol: holdingItem.symbol,
                        name: priceSnapshot?.name ?? holdingItem.name,
                        currency: priceSnapshot?.currency ?? holdingItem.currency,
                        totalQuantity: holdingItem.quantity,
                        weightedAverageCost: holdingItem.averageCost,
                        totalCost: holdingItem.totalCost,
                        sourceAccountIds: [accountSnapshot.accountId],
                        fifoLotsByAccount: [],
                        lastUpdated: Date(),
                        lastTransactionDate: accountSnapshot.lastTransactionDate,
                        version: 1
                    )
                    
                    aggregatedMap[key] = aggregated
                }
            }
        }
        
        // 計算每個 AggregatedHoldingSnapshot 的 FIFO 批次
        for (key, var aggregated) in aggregatedMap {
            // 計算 FIFO 批次（按帳戶分組）
            aggregated.fifoLotsByAccount = calculateFIFOLotsByAccount(
                symbol: aggregated.symbol,
                assetType: aggregated.assetType,
                transactions: transactions,
                accounts: accounts,
                sourceAccountIds: aggregated.sourceAccountIds
            )
            
            aggregatedMap[key] = aggregated
        }
        
        return Array(aggregatedMap.values)
    }
    
    /// 計算單一股票的跨帳戶合併快照
    /// - Parameters:
    ///   - userId: 使用者ID
    ///   - assetType: 資產類型
    ///   - symbol: 股票代號
    ///   - accountSnapshots: 所有帳戶的快照
    ///   - accounts: 所有帳戶資訊
    ///   - transactions: 所有交易記錄（用於計算 FIFO 批次）
    ///   - assetPriceSnapshot: 資產價格快照（用於同步 name 和 currency）
    /// - Returns: 跨帳戶合併持股快照（如果該股票沒有持股，返回 nil）
    static func calculateAggregatedHolding(
        userId: String,
        assetType: AssetType,
        symbol: String,
        accountSnapshots: [AccountSnapshot],
        accounts: [Account],
        transactions: [Transaction],
        assetPriceSnapshot: AssetPriceSnapshot?
    ) -> AggregatedHoldingSnapshot? {
        // 建立 accountId -> Account 的映射
        var accountMap: [String: Account] = [:]
        for account in accounts {
            accountMap[account.id] = account
        }
        
        var totalQuantity: Decimal = 0
        var totalCost: Decimal = 0
        var sourceAccountIds: [String] = []
        var lastTransactionDate: Date?
        
        // 遍歷所有 AccountSnapshot，合併該股票的持股
        for accountSnapshot in accountSnapshots {
            guard let holdings = accountSnapshot.holdings else { continue }
            
            // 找到該股票的持股
            if let holdingItem = holdings.first(where: { $0.assetType == assetType && $0.symbol == symbol }) {
                totalQuantity += holdingItem.quantity
                totalCost += holdingItem.totalCost
                
                if !sourceAccountIds.contains(accountSnapshot.accountId) {
                    sourceAccountIds.append(accountSnapshot.accountId)
                }
                
                // 更新最後交易日期
                if let transactionDate = accountSnapshot.lastTransactionDate {
                    if let lastDate = lastTransactionDate {
                        lastTransactionDate = transactionDate > lastDate ? transactionDate : lastDate
                    } else {
                        lastTransactionDate = transactionDate
                    }
                }
            }
        }
        
        // 如果沒有持股，返回 nil
        guard totalQuantity > 0 else { return nil }
        
        // 計算加權平均成本
        let weightedAverageCost = totalCost / totalQuantity
        
        // 計算 FIFO 批次（按帳戶分組）
        let fifoLotsByAccount = calculateFIFOLotsByAccount(
            symbol: symbol,
            assetType: assetType,
            transactions: transactions,
            accounts: accounts,
            sourceAccountIds: sourceAccountIds
        )
        
        return AggregatedHoldingSnapshot(
            userId: userId,
            assetType: assetType,
            symbol: symbol,
            name: assetPriceSnapshot?.name,
            currency: assetPriceSnapshot?.currency ?? .TWD, // 預設 TWD，實際上應該從持股推斷
            totalQuantity: totalQuantity,
            weightedAverageCost: weightedAverageCost,
            totalCost: totalCost,
            sourceAccountIds: sourceAccountIds,
            fifoLotsByAccount: fifoLotsByAccount,
            lastUpdated: Date(),
            lastTransactionDate: lastTransactionDate,
            version: 1
        )
    }
    
    /// 計算 FIFO 批次（按帳戶分組）
    /// - Parameters:
    ///   - symbol: 股票代號
    ///   - assetType: 資產類型
    ///   - transactions: 所有交易記錄
    ///   - accounts: 所有帳戶資訊
    ///   - sourceAccountIds: 持有的帳戶ID列表
    /// - Returns: 按帳戶分組的 FIFO 批次快照
    private static func calculateFIFOLotsByAccount(
        symbol: String,
        assetType: AssetType,
        transactions: [Transaction],
        accounts: [Account],
        sourceAccountIds: [String]
    ) -> [FIFOLotsByAccountSnapshot] {
        // 建立 accountId -> Account 的映射
        var accountMap: [String: Account] = [:]
        for account in accounts {
            accountMap[account.id] = account
        }
        
        // 按帳戶分組計算 FIFO 批次
        var result: [FIFOLotsByAccountSnapshot] = []
        
        for accountId in sourceAccountIds {
            guard let account = accountMap[accountId] else { continue }
            
            // 過濾出該帳戶、該股票的所有買入/賣出交易
            let accountTransactions = transactions.filter { transaction in
                transaction.accountId == accountId &&
                transaction.assetType == assetType &&
                transaction.symbol == symbol &&
                (transaction.type == .buy || transaction.type == .sell)
            }
            
            // 計算該帳戶的 FIFO 批次
            let lots = calculateFIFOLotsForAccount(
                transactions: accountTransactions,
                accountName: account.name
            )
            
            if !lots.isEmpty {
                result.append(FIFOLotsByAccountSnapshot(
                    accountId: accountId,
                    accountName: account.name,
                    lots: lots
                ))
            }
        }
        
        return result
    }
    
    /// 計算單一帳戶的 FIFO 批次（從交易記錄）
    /// - Parameters:
    ///   - transactions: 該帳戶的交易記錄（已過濾為該股票）
    ///   - accountName: 帳戶名稱（用於建立 FIFOLotSnapshot）
    /// - Returns: FIFO 批次快照列表
    private static func calculateFIFOLotsForAccount(
        transactions: [Transaction],
        accountName: String
    ) -> [FIFOLotSnapshot] {
        // 由於 HoldingLot 是 private，我們需要重新實作 FIFO 邏輯
        // 使用 Transaction ID 作為 key 來追蹤每個買入交易的批次
        
        // 按時間排序交易
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        // 追蹤每個買入交易的批次資訊
        struct BuyLotInfo {
            var transaction: Transaction
            var remainingQuantity: Decimal
            var costPerUnit: Decimal
        }
        
        var buyLots: [BuyLotInfo] = [] // 按時間排序的買入批次列表
        
        // 重播交易記錄計算 FIFO
        for transaction in sortedTransactions {
            switch transaction.type {
            case .buy:
                // 買入：新增一個批次
                let costPerUnit = transaction.totalAmountWithFee / transaction.quantity
                let lot = BuyLotInfo(
                    transaction: transaction,
                    remainingQuantity: transaction.quantity,
                    costPerUnit: costPerUnit
                )
                buyLots.append(lot)
                // 保持按時間排序
                buyLots.sort { $0.transaction.transactionDate < $1.transaction.transactionDate }
                
            case .sell:
                // 賣出：使用 FIFO，先賣出最早買入的批次
                var remainingToSell = transaction.quantity
                
                var index = 0
                while remainingToSell > 0 && index < buyLots.count {
                    if buyLots[index].remainingQuantity <= remainingToSell {
                        // 整個批次都賣出
                        remainingToSell -= buyLots[index].remainingQuantity
                        buyLots.remove(at: index)
                        // 不移動 index，因為移除了當前元素
                    } else {
                        // 部分賣出，更新批次數量
                        buyLots[index].remainingQuantity -= remainingToSell
                        remainingToSell = 0
                        index += 1
                    }
                }
                
            default:
                break
            }
        }
        
        // 將 BuyLotInfo 轉換為 FIFOLotSnapshot
        var fifoLots: [FIFOLotSnapshot] = []
        
        for lot in buyLots {
            let fifoLot = FIFOLotSnapshot(
                id: lot.transaction.id,
                accountId: lot.transaction.accountId,
                accountName: accountName,
                buyDate: lot.transaction.transactionDate,
                remainingQuantity: lot.remainingQuantity,
                costPerUnit: lot.costPerUnit,
                currency: lot.transaction.currency,
                exchangeRate: lot.transaction.exchangeRate
            )
            
            fifoLots.append(fifoLot)
        }
        
        // 按買入日期排序（應該已經排序了，但確保）
        fifoLots.sort { $0.buyDate < $1.buyDate }
        
        return fifoLots
    }
}
