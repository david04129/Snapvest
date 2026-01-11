//
//  PriceService.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 價格服務協議
protocol PriceServiceProtocol {
    func fetchCurrentPrice(assetType: AssetType, symbol: String) async throws -> Decimal?
    func fetchHistoricalPrices(assetType: AssetType, symbol: String, days: Int) async throws -> [Price]
}

/// 價格服務實作
class PriceService: PriceServiceProtocol {
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    func fetchCurrentPrice(assetType: AssetType, symbol: String) async throws -> Decimal? {
        // 1. 先查資料庫快取（MockDataService 會返回所有模擬價格）
        if let cachedPrice = try await dataService.fetchPrice(assetType: assetType, symbol: symbol, date: nil) {
            return cachedPrice.price
        }
        
        // 2. 如果沒有快取，調用 API
        // TODO: 實作 API 調用
        // 這裡需要後端服務支援
        
        return nil
    }
    
    func fetchHistoricalPrices(assetType: AssetType, symbol: String, days: Int) async throws -> [Price] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        return try await dataService.fetchPrices(
            assetType: assetType,
            symbol: symbol,
            startDate: startDate,
            endDate: endDate
        )
    }
}

