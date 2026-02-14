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
        // 1. 若 Supabase 已設定，優先從 Supabase 讀取（使用與資產畫面相同的批量 API）
        if SupabaseConfig.isConfigured {
            let symbolInfo = SymbolInfo(assetType: assetType, symbol: symbol)
            if let snapshots = try? await SupabasePriceService.fetchPrices(symbols: [symbolInfo]),
               let snapshot = snapshots.first {
                return snapshot.displayPrice
            }
        }
        
        // 2. 後備：DataService（Mock 或本地快取）
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

