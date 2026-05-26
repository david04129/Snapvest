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
    
    let assetType: AssetType
    let symbol: String
    
    var name: String?
    var currency: Currency
    
    var currentPrice: Decimal?
    var previousPrice: Decimal?
    
    /// 此 current_price 對應的收盤所屬日（僅日期）
    var currentCloseDate: Date?
    /// 本列 current_price 寫入時間
    var currentUpdatedAt: Date?
    var previousCloseDate: Date?
    var previousUpdatedAt: Date?
    
    var currentPriceSource: String?
    var previousPriceSource: String?
    
    nonisolated init(
        assetType: AssetType,
        symbol: String,
        name: String? = nil,
        currency: Currency,
        currentPrice: Decimal? = nil,
        previousPrice: Decimal? = nil,
        currentCloseDate: Date? = nil,
        currentUpdatedAt: Date? = nil,
        previousCloseDate: Date? = nil,
        previousUpdatedAt: Date? = nil,
        currentPriceSource: String? = nil,
        previousPriceSource: String? = nil
    ) {
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.currentCloseDate = currentCloseDate
        self.currentUpdatedAt = currentUpdatedAt
        self.previousCloseDate = previousCloseDate
        self.previousUpdatedAt = previousUpdatedAt
        self.currentPriceSource = currentPriceSource
        self.previousPriceSource = previousPriceSource
    }
    
    enum CodingKeys: String, CodingKey {
        case assetType, symbol, name, currency
        case currentPrice, previousPrice
        case currentCloseDate, currentUpdatedAt
        case previousCloseDate, previousUpdatedAt
        case currentPriceSource, previousPriceSource
        case legacyCurrentPriceDate = "currentPriceDate"
        case legacyPreviousPriceDate = "previousPriceDate"
        case legacyLastUpdated = "lastUpdated"
        case legacyLastSuccessfulUpdate = "lastSuccessfulUpdate"
        case legacyPriceSource = "priceSource"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assetType = try c.decode(AssetType.self, forKey: .assetType)
        symbol = try c.decode(String.self, forKey: .symbol)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        currency = try c.decode(Currency.self, forKey: .currency)
        currentPrice = try c.decodeIfPresent(Decimal.self, forKey: .currentPrice)
        previousPrice = try c.decodeIfPresent(Decimal.self, forKey: .previousPrice)
        currentCloseDate = try c.decodeIfPresent(Date.self, forKey: .currentCloseDate)
            ?? c.decodeIfPresent(Date.self, forKey: .legacyCurrentPriceDate)
        currentUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .currentUpdatedAt)
            ?? c.decodeIfPresent(Date.self, forKey: .legacyLastSuccessfulUpdate)
            ?? c.decodeIfPresent(Date.self, forKey: .legacyLastUpdated)
        previousCloseDate = try c.decodeIfPresent(Date.self, forKey: .previousCloseDate)
            ?? c.decodeIfPresent(Date.self, forKey: .legacyPreviousPriceDate)
        previousUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .previousUpdatedAt)
        currentPriceSource = try c.decodeIfPresent(String.self, forKey: .currentPriceSource)
            ?? c.decodeIfPresent(String.self, forKey: .legacyPriceSource)
        previousPriceSource = try c.decodeIfPresent(String.self, forKey: .previousPriceSource)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(assetType, forKey: .assetType)
        try c.encode(symbol, forKey: .symbol)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(currentPrice, forKey: .currentPrice)
        try c.encodeIfPresent(previousPrice, forKey: .previousPrice)
        try c.encodeIfPresent(currentCloseDate, forKey: .currentCloseDate)
        try c.encodeIfPresent(currentUpdatedAt, forKey: .currentUpdatedAt)
        try c.encodeIfPresent(previousCloseDate, forKey: .previousCloseDate)
        try c.encodeIfPresent(previousUpdatedAt, forKey: .previousUpdatedAt)
        try c.encodeIfPresent(currentPriceSource, forKey: .currentPriceSource)
        try c.encodeIfPresent(previousPriceSource, forKey: .previousPriceSource)
    }
    
    var displayPrice: Decimal? {
        currentPrice ?? previousPrice
    }
    
    var displayCloseDate: Date? {
        currentCloseDate ?? previousCloseDate
    }
    
    var displayPriceDate: Date? {
        displayCloseDate
    }
    
    /// 顯示用現價來源
    var displayPriceSource: String? {
        currentPriceSource ?? previousPriceSource
    }
    
    var hasValidPrice: Bool {
        currentPrice != nil || previousPrice != nil
    }
    
    var hasCurrentPrice: Bool {
        currentPrice != nil
    }
}

/// 用於批量請求的符號資訊
struct SymbolInfo: Codable, Equatable, Hashable {
    let assetType: AssetType
    let symbol: String
}
