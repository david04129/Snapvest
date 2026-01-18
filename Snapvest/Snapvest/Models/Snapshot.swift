//
//  Snapshot.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct Snapshot: Identifiable, Codable {
    let id: String
    let userId: String
    var snapshotDate: Date
    var totalAssets: Decimal
    var totalLiabilities: Decimal
    var totalCash: Decimal
    var totalInvestments: Decimal
    var unrealizedGainLoss: Decimal
    var realizedGainLoss: Decimal
    var baseCurrency: Currency
    var snapshotData: SnapshotData?
    var createdAt: Date
    
    init(id: String = UUID().uuidString,
         userId: String,
         snapshotDate: Date = Date(),
         totalAssets: Decimal = 0,
         totalLiabilities: Decimal = 0,
         totalCash: Decimal = 0,
         totalInvestments: Decimal = 0,
         unrealizedGainLoss: Decimal = 0,
         realizedGainLoss: Decimal = 0,
         baseCurrency: Currency = .TWD,
         snapshotData: SnapshotData? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.snapshotDate = snapshotDate
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
        self.totalCash = totalCash
        self.totalInvestments = totalInvestments
        self.unrealizedGainLoss = unrealizedGainLoss
        self.realizedGainLoss = realizedGainLoss
        self.baseCurrency = baseCurrency
        self.snapshotData = snapshotData
        self.createdAt = createdAt
    }
    
    /// 淨資產
    var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
    
    /// 負債比例
    var liabilityRatio: Decimal {
        guard totalAssets > 0 else { return 0 }
        return (totalLiabilities / totalAssets) * 100
    }
    
    /// 現金比例
    var cashRatio: Decimal {
        guard totalAssets > 0 else { return 0 }
        return (totalCash / totalAssets) * 100
    }
    
    /// 投資比例
    var investmentRatio: Decimal {
        guard totalAssets > 0 else { return 0 }
        return (totalInvestments / totalAssets) * 100
    }
}

// MARK: - 首頁快照
struct HomeDashboardSnapshot: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let netWorth: Decimal
    let totalLiabilities: Decimal
    let totalAssets: Decimal
    let totalInvestmentsCost: Decimal
    let totalCash: Decimal
    let twdCash: Decimal
    let usdCash: Decimal
    let realizedGainLossTWD: Decimal
    let realizedGainLossUSD: Decimal
    let lastUpdated: Date
    
    init(
        userId: String,
        netWorth: Decimal,
        totalLiabilities: Decimal,
        totalAssets: Decimal,
        totalInvestmentsCost: Decimal,
        totalCash: Decimal,
        twdCash: Decimal,
        usdCash: Decimal,
        realizedGainLossTWD: Decimal,
        realizedGainLossUSD: Decimal,
        lastUpdated: Date = Date()
    ) {
        self.userId = userId
        self.id = userId
        self.netWorth = netWorth
        self.totalLiabilities = totalLiabilities
        self.totalAssets = totalAssets
        self.totalInvestmentsCost = totalInvestmentsCost
        self.totalCash = totalCash
        self.twdCash = twdCash
        self.usdCash = usdCash
        self.realizedGainLossTWD = realizedGainLossTWD
        self.realizedGainLossUSD = realizedGainLossUSD
        self.lastUpdated = lastUpdated
    }
}

/// 快照詳細資料
struct SnapshotData: Codable {
    var accounts: [String: AccountSnapshot]?
    var holdings: [HoldingSnapshotData]?
    
    struct AccountSnapshot: Codable {
        var cash: Decimal
        var holdings: [String: Decimal] // symbol: marketValue
    }
    
    /// 持股快照資料（用於序列化）
    struct HoldingSnapshotData: Codable {
        let id: String
        let accountId: String
        let assetType: AssetType
        let symbol: String
        let quantity: Decimal
        let averageCost: Decimal
        let currency: Currency
        let currentPrice: Decimal?
        let investmentRatio: Decimal?
        let assetRatio: Decimal?
    }
}

