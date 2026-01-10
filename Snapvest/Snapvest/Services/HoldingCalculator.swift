//
//  HoldingCalculator.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 持股批次（用於 FIFO 計算）
private struct HoldingLot {
    var quantity: Decimal
    var costPerUnit: Decimal
    var transactionDate: Date
}

/// 持股計算器 - 重播交易記錄生成持股快照（使用 FIFO 方法）
class HoldingCalculator {
    
    /// 從交易記錄計算當前持股（使用 FIFO）
    static func calculateHoldings(from transactions: [Transaction]) -> [Holding] {
        // 使用批次追蹤每筆買入
        var holdingLots: [String: [HoldingLot]] = [:] // key: "assetType_symbol"
        var holdings: [String: Holding] = [:]
        
        // 按時間排序交易
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        for transaction in sortedTransactions {
            let key = "\(transaction.assetType.rawValue)_\(transaction.symbol)"
            
            switch transaction.type {
            case .buy:
                // 買入：新增一個批次
                let costPerUnit = transaction.totalAmountWithFee / transaction.quantity
                let lot = HoldingLot(
                    quantity: transaction.quantity,
                    costPerUnit: costPerUnit,
                    transactionDate: transaction.transactionDate
                )
                
                if holdingLots[key] == nil {
                    holdingLots[key] = []
                }
                holdingLots[key]?.append(lot)
                
                // 更新持股（計算總數量和加權平均成本，用於顯示）
                updateHoldingFromLots(
                    key: key,
                    lots: holdingLots[key] ?? [],
                    accountId: transaction.accountId,
                    assetType: transaction.assetType,
                    symbol: transaction.symbol,
                    currency: transaction.currency,
                    holdings: &holdings
                )
                
            case .sell:
                // 賣出：使用 FIFO，先賣出最早買入的批次
                if var lots = holdingLots[key], lots.count > 0 {
                    var remainingToSell = transaction.quantity
                    
                    while remainingToSell > 0 && !lots.isEmpty {
                        let oldestLot = lots[0]
                        
                        if oldestLot.quantity <= remainingToSell {
                            // 整個批次都賣出
                            remainingToSell -= oldestLot.quantity
                            lots.removeFirst()
                        } else {
                            // 部分賣出，更新批次數量
                            lots[0].quantity -= remainingToSell
                            remainingToSell = 0
                        }
                    }
                    
                    holdingLots[key] = lots
                    
                    // 更新持股
                    if lots.isEmpty {
                        holdings.removeValue(forKey: key)
                        holdingLots.removeValue(forKey: key)
                    } else {
                        updateHoldingFromLots(
                            key: key,
                            lots: lots,
                            accountId: transaction.accountId,
                            assetType: transaction.assetType,
                            symbol: transaction.symbol,
                            currency: transaction.currency,
                            holdings: &holdings
                        )
                    }
                }
                
            case .deposit, .withdraw, .dividend, .fee, .liability, .transfer, .repayment:
                // 這些不影響持股，只影響現金
                break
            }
        }
        
        return Array(holdings.values)
    }
    
    /// 從批次更新持股（計算加權平均成本用於顯示）
    private static func updateHoldingFromLots(
        key: String,
        lots: [HoldingLot],
        accountId: String,
        assetType: AssetType,
        symbol: String,
        currency: Currency,
        holdings: inout [String: Holding]
    ) {
        guard !lots.isEmpty else { return }
        
        // 計算總數量和總成本
        var totalQuantity: Decimal = 0
        var totalCost: Decimal = 0
        
        for lot in lots {
            totalQuantity += lot.quantity
            totalCost += lot.quantity * lot.costPerUnit
        }
        
        // 計算加權平均成本（用於顯示）
        let averageCost = totalCost / totalQuantity
        
        // 台股 symbol 到 name 的映射
        let symbolToName: [String: String] = [
            "2330": "台積電", "2317": "鴻海", "2454": "聯發科", "2308": "台達電", "2891": "中信金",
            "2882": "國泰金", "2886": "兆豐金", "1301": "台塑", "1303": "南亞", "2002": "中鋼",
            "2412": "中華電", "2382": "廣達", "2379": "瑞昱", "3008": "大立光", "2884": "玉山金"
        ]
        
        let name = (assetType == .stockTW) ? symbolToName[symbol] : nil
        
        holdings[key] = Holding(
            accountId: accountId,
            assetType: assetType,
            symbol: symbol,
            name: name,
            quantity: totalQuantity,
            averageCost: averageCost,
            currency: currency
        )
    }
    
    /// 計算已實現損益（使用 FIFO）
    static func calculateRealizedGainLoss(from transactions: [Transaction]) -> Decimal {
        var realizedGainLoss: Decimal = 0
        var holdingLots: [String: [HoldingLot]] = [:]
        
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }
        
        for transaction in sortedTransactions {
            let key = "\(transaction.assetType.rawValue)_\(transaction.symbol)"
            
            switch transaction.type {
            case .buy:
                // 買入：新增批次
                let costPerUnit = transaction.totalAmountWithFee / transaction.quantity
                let lot = HoldingLot(
                    quantity: transaction.quantity,
                    costPerUnit: costPerUnit,
                    transactionDate: transaction.transactionDate
                )
                
                if holdingLots[key] == nil {
                    holdingLots[key] = []
                }
                holdingLots[key]?.append(lot)
                
            case .sell:
                // 賣出：使用 FIFO 計算已實現損益
                if var lots = holdingLots[key], !lots.isEmpty {
                    var remainingToSell = transaction.quantity
                    let sellPricePerUnit = transaction.totalAmountWithFee / transaction.quantity
                    
                    while remainingToSell > 0 && !lots.isEmpty {
                        let oldestLot = lots[0]
                        
                        if oldestLot.quantity <= remainingToSell {
                            // 整個批次都賣出
                            let costBasis = oldestLot.quantity * oldestLot.costPerUnit
                            let proceeds = oldestLot.quantity * sellPricePerUnit
                            let gainLoss = proceeds - costBasis
                            realizedGainLoss += gainLoss
                            
                            remainingToSell -= oldestLot.quantity
                            lots.removeFirst()
                        } else {
                            // 部分賣出
                            let costBasis = remainingToSell * oldestLot.costPerUnit
                            let proceeds = remainingToSell * sellPricePerUnit
                            let gainLoss = proceeds - costBasis
                            realizedGainLoss += gainLoss
                            
                            lots[0].quantity -= remainingToSell
                            remainingToSell = 0
                        }
                    }
                    
                    holdingLots[key] = lots.isEmpty ? nil : lots
                }
                
            default:
                break
            }
        }
        
        return realizedGainLoss
    }
}

