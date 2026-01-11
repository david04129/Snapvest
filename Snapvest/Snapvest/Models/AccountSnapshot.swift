//
//  AccountSnapshot.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 帳戶快照 - 儲存每個帳戶的快照數據
struct AccountSnapshot: Identifiable, Codable, Equatable {
    let accountId: String         // 帳戶ID（主鍵）
    
    /// 現金相關
    var cashBalance: Decimal      // 現金餘額（帳戶貨幣）
    
    /// 持股列表（詳細資訊，不包含價格）
    var holdings: [HoldingSnapshotItem]?
    
    /// 債務相關（僅債務帳戶）
    var liabilityId: String?
    var remainingBalance: Decimal?
    var totalPaidPrincipal: Decimal?
    var totalPaidInterest: Decimal?
    var totalSavedInterest: Decimal?
    var paidPeriods: Int?
    var totalPeriods: Int?
    
    /// 時間戳記
    var lastUpdated: Date         // 快照最後更新時間
    var lastTransactionDate: Date? // 最後一筆交易日期（用於驗證快照是否完整）
    var version: Int              // 版本號（用於樂觀鎖定）
    
    var id: String {
        accountId
    }
    
    init(
        accountId: String,
        cashBalance: Decimal,
        holdings: [HoldingSnapshotItem]? = nil,
        liabilityId: String? = nil,
        remainingBalance: Decimal? = nil,
        totalPaidPrincipal: Decimal? = nil,
        totalPaidInterest: Decimal? = nil,
        totalSavedInterest: Decimal? = nil,
        paidPeriods: Int? = nil,
        totalPeriods: Int? = nil,
        lastUpdated: Date = Date(),
        lastTransactionDate: Date? = nil,
        version: Int = 0
    ) {
        self.accountId = accountId
        self.cashBalance = cashBalance
        self.holdings = holdings
        self.liabilityId = liabilityId
        self.remainingBalance = remainingBalance
        self.totalPaidPrincipal = totalPaidPrincipal
        self.totalPaidInterest = totalPaidInterest
        self.totalSavedInterest = totalSavedInterest
        self.paidPeriods = paidPeriods
        self.totalPeriods = totalPeriods
        self.lastUpdated = lastUpdated
        self.lastTransactionDate = lastTransactionDate
        self.version = version
    }
}

/// 持股快照項目（不包含價格，價格從 AssetPriceSnapshot 讀取）
struct HoldingSnapshotItem: Identifiable, Codable, Equatable {
    let id: String
    let assetType: AssetType
    let symbol: String
    var name: String?             // 股票名稱（可選，主要用於台股）
    var quantity: Decimal         // 持有數量
    var averageCost: Decimal      // 平均成本（使用 FIFO 計算）
    var currency: Currency
    var lastUpdated: Date
    
    init(
        id: String = UUID().uuidString,
        assetType: AssetType,
        symbol: String,
        name: String? = nil,
        quantity: Decimal,
        averageCost: Decimal,
        currency: Currency,
        lastUpdated: Date = Date()
    ) {
        self.id = id
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
    
    /// 顯示名稱：台股顯示 name，美股和加密貨幣顯示 symbol
    var displayName: String {
        if assetType == .stockTW, let name = name, !name.isEmpty {
            return name
        }
        return symbol
    }
}
