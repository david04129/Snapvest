//
//  Holding.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct Holding: Identifiable, Codable {
    let id: String
    let accountId: String
    var assetType: AssetType
    var symbol: String
    var name: String? // 股票名稱（主要用於台股）
    var quantity: Decimal
    var averageCost: Decimal
    var currency: Currency
    var lastUpdated: Date
    
    init(id: String = UUID().uuidString,
         accountId: String,
         assetType: AssetType,
         symbol: String,
         name: String? = nil,
         quantity: Decimal,
         averageCost: Decimal,
         currency: Currency,
         lastUpdated: Date = Date()) {
        self.id = id
        self.accountId = accountId
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.quantity = quantity
        self.averageCost = averageCost
        self.currency = currency
        self.lastUpdated = lastUpdated
    }
    
    /// 總成本
    var totalCost: Decimal {
        quantity * averageCost
    }
    
    /// 顯示名稱：台股顯示名稱；加密顯示清單名稱或大寫代號；美股顯示代號
    var displayName: String {
        switch assetType {
        case .stockTW:
            if let name = name, !name.isEmpty { return name }
            return symbol
        case .crypto:
            return SymbolListService.cryptoDisplayName(for: symbol, storedName: name)
        case .stockUS:
            return symbol.uppercased()
        default:
            return symbol
        }
    }
}

/// 持股快照（包含當前價格）
struct HoldingSnapshot: Identifiable {
    let id: String
    let holding: Holding
    var currentPrice: Decimal?
    var currentPriceDate: Date?
    var investmentRatio: Decimal?      // 投資佔比（相對於總投資）
    var assetRatio: Decimal?           // 資產佔比（相對於總資產）
    
    /// 當前市值
    var marketValue: Decimal? {
        guard let price = currentPrice else { return nil }
        return holding.quantity * price
    }
    
    /// 未實現損益
    var unrealizedGainLoss: Decimal? {
        guard let marketValue = marketValue else { return nil }
        return marketValue - holding.totalCost
    }
    
    /// 未實現損益百分比
    var unrealizedGainLossPercent: Decimal? {
        guard let gainLoss = unrealizedGainLoss,
              holding.totalCost > 0 else { return nil }
        return (gainLoss / holding.totalCost) * 100
    }
    
    /// 顯示名稱：直接使用 holding 的 displayName
    var displayName: String {
        holding.displayName
    }
}

