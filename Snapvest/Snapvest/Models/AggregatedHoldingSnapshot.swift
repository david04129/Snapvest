//
//  AggregatedHoldingSnapshot.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 跨帳戶合併持股快照（每個使用者每檔股票一個快照）
struct AggregatedHoldingSnapshot: Identifiable, Codable, Equatable {
    /// 唯一識別（使用 userId + assetType + symbol）
    var id: String {
        "\(userId)_\(assetType.rawValue)_\(symbol)"
    }
    
    let userId: String
    let assetType: AssetType
    let symbol: String
    
    // 基本資訊（從 AssetPriceSnapshot 同步）
    var name: String?
    var currency: Currency
    
    // 合併後的持股資訊（原幣，不依賴價格/匯率）
    var totalQuantity: Decimal       // 總數量（跨帳戶合併）
    var weightedAverageCost: Decimal // 加權平均成本（原幣）
    var totalCost: Decimal           // 總成本（原幣，totalQuantity * weightedAverageCost）
    
    // 來源帳戶資訊
    var sourceAccountIds: [String]   // 持有的帳戶ID列表
    
    // FIFO 批次快照（按帳戶分組）
    var fifoLotsByAccount: [FIFOLotsByAccountSnapshot]
    
    // 時間戳記
    var lastUpdated: Date
    var lastTransactionDate: Date?
    var version: Int
    
    init(
        userId: String,
        assetType: AssetType,
        symbol: String,
        name: String? = nil,
        currency: Currency,
        totalQuantity: Decimal,
        weightedAverageCost: Decimal,
        totalCost: Decimal,
        sourceAccountIds: [String] = [],
        fifoLotsByAccount: [FIFOLotsByAccountSnapshot] = [],
        lastUpdated: Date = Date(),
        lastTransactionDate: Date? = nil,
        version: Int = 1
    ) {
        self.userId = userId
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.totalQuantity = totalQuantity
        self.weightedAverageCost = weightedAverageCost
        self.totalCost = totalCost
        self.sourceAccountIds = sourceAccountIds
        self.fifoLotsByAccount = fifoLotsByAccount
        self.lastUpdated = lastUpdated
        self.lastTransactionDate = lastTransactionDate
        self.version = version
    }
}

/// 按帳戶分組的 FIFO 批次快照
struct FIFOLotsByAccountSnapshot: Identifiable, Codable, Equatable {
    let accountId: String
    let accountName: String
    var lots: [FIFOLotSnapshot]
    
    var id: String { accountId }
    
    init(accountId: String, accountName: String, lots: [FIFOLotSnapshot] = []) {
        self.accountId = accountId
        self.accountName = accountName
        self.lots = lots
    }
}

/// FIFO 批次快照（儲存在 AggregatedHoldingSnapshot 中）
struct FIFOLotSnapshot: Identifiable, Codable, Equatable {
    let id: String              // Transaction ID（買入交易的 ID）
    let accountId: String       // 帳戶ID
    let accountName: String     // 券商名稱（Account.name）
    let buyDate: Date          // 買入日期
    var remainingQuantity: Decimal  // 剩餘數量（FIFO 計算後）
    var costPerUnit: Decimal   // 單位成本（原幣，Transaction.totalAmountWithFee / Transaction.quantity）
    var currency: Currency     // 貨幣
    var exchangeRate: Decimal? // 買入時的匯率（跨幣交易時使用，固定值）
    
    init(
        id: String,
        accountId: String,
        accountName: String,
        buyDate: Date,
        remainingQuantity: Decimal,
        costPerUnit: Decimal,
        currency: Currency,
        exchangeRate: Decimal? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.accountName = accountName
        self.buyDate = buyDate
        self.remainingQuantity = remainingQuantity
        self.costPerUnit = costPerUnit
        self.currency = currency
        self.exchangeRate = exchangeRate
    }
    
    /// 總成本（原幣）
    var totalCost: Decimal {
        remainingQuantity * costPerUnit
    }
}
