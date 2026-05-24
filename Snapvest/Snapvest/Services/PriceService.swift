//
//  PriceService.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 價格服務協議
protocol PriceServiceProtocol {
    func fetchCurrentPrice(assetType: AssetType, symbol: String, coingeckoId: String?) async throws -> Decimal?
    func fetchHistoricalPrices(assetType: AssetType, symbol: String, days: Int) async throws -> [Price]
}

extension PriceServiceProtocol {
    func fetchCurrentPrice(assetType: AssetType, symbol: String) async throws -> Decimal? {
        try await fetchCurrentPrice(assetType: assetType, symbol: symbol, coingeckoId: nil)
    }
}

/// 價格服務實作
class PriceService: PriceServiceProtocol {
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    func fetchCurrentPrice(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String?
    ) async throws -> Decimal? {
        if SupabaseConfig.isConfigured {
            return await SupabasePriceService.fetchDisplayPrice(
                assetType: assetType,
                symbol: symbol,
                coingeckoId: coingeckoId
            )
        }
        
        // 離線且未設定 Supabase 時無本地股價
        if let cachedPrice = try await dataService.fetchPrice(assetType: assetType, symbol: symbol, date: nil) {
            return cachedPrice.price
        }
        
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

