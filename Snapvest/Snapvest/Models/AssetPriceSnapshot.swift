//
//  AssetPriceSnapshot.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 統一價格快照 - 儲存所有使用者需要的股票價格（所有帳戶共享）
struct AssetPriceSnapshot: Identifiable, Codable, Equatable {
    /// 唯一識別（使用 assetType + symbol 作為 ID）
    var id: String {
        "\(assetType.rawValue)_\(symbol)"
    }
    
    let assetType: AssetType      // 資產類型（台股、美股、加密貨幣）
    let symbol: String            // 股票代號（唯一識別碼，API 使用）
    
    /// 股票資訊
    var name: String?             // 股票名稱（顯示用，可選，後續維護）
    var currency: Currency        // 貨幣
    
    /// 價格數據
    var currentPrice: Decimal?    // 當前價格（最新一次成功獲取的價格）
    var previousPrice: Decimal?   // 上一次價格（容錯備份）
    
    /// 價格日期
    var currentPriceDate: Date?   // 當前價格的日期（後端提供，例如昨天收盤價的日期）
    var previousPriceDate: Date?  // 上一次價格的日期
    
    /// 時間戳記
    var lastUpdated: Date         // 快照最後更新時間（無論成功或失敗）
    var lastSuccessfulUpdate: Date? // 最後一次成功獲取價格的時間
    
    nonisolated init(
        assetType: AssetType,
        symbol: String,
        name: String? = nil,
        currency: Currency,
        currentPrice: Decimal? = nil,
        previousPrice: Decimal? = nil,
        currentPriceDate: Date? = nil,
        previousPriceDate: Date? = nil,
        lastUpdated: Date = Date(),
        lastSuccessfulUpdate: Date? = nil
    ) {
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.currentPriceDate = currentPriceDate
        self.previousPriceDate = previousPriceDate
        self.lastUpdated = lastUpdated
        self.lastSuccessfulUpdate = lastSuccessfulUpdate
    }
    
    /// 獲取顯示用的價格（優先使用 currentPrice，如果為 nil 則使用 previousPrice）
    var displayPrice: Decimal? {
        currentPrice ?? previousPrice
    }
    
    /// 獲取顯示用的價格日期（優先使用 currentPriceDate，如果為 nil 則使用 previousPriceDate）
    var displayPriceDate: Date? {
        currentPriceDate ?? previousPriceDate
    }
    
    /// 判斷價格是否有效（至少有一個價格）
    var hasValidPrice: Bool {
        currentPrice != nil || previousPrice != nil
    }
    
    /// 判斷當前價格是否有效
    var hasCurrentPrice: Bool {
        currentPrice != nil
    }
}

/// 用於批量請求的符號資訊
struct SymbolInfo: Codable, Equatable, Hashable {
    let assetType: AssetType
    let symbol: String
}
