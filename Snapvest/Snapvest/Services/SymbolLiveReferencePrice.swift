//
//  SymbolLiveReferencePrice.swift
//  Snapvest
//
//  買進表單：選股後預抓參考現價（snapshots + history 昨收 / fetch-or-create），寫入本機快照。
//

import Foundation

enum SymbolLiveReferencePrice {
    enum State: Equatable {
        case idle
        case loading
        case ready(Decimal)
        case failed(String)
    }

    static func normalizedSymbol(assetType: AssetType, symbol: String) -> String {
        SupabasePriceService.normalizeSymbol(assetType: assetType, symbol: symbol)
    }

    /// 從 Supabase 取得有效參考現價並寫入本機 AssetPriceSnapshot；成功表示可 skip 買入驗價。
    @MainActor
    static func prefetch(
        assetType: AssetType,
        symbol: String,
        dataService: DataServiceProtocol
    ) async -> State {
        let normalized = normalizedSymbol(assetType: assetType, symbol: symbol)
        guard !normalized.isEmpty else {
            return .failed("請選擇股票代號")
        }
        guard SupabaseConfig.isConfigured else {
            return .failed("無法連線驗證股價，請確認網路與 Supabase 設定")
        }

        let coingeckoId = assetType == .crypto
            ? SymbolListService.coingeckoId(forCryptoSymbol: normalized)
            : nil

        if let snapshot = await SupabasePriceService.prefetchAssetPriceSnapshot(
            assetType: assetType,
            symbol: normalized,
            dataService: dataService,
            coingeckoId: coingeckoId
        ),
           let price = snapshot.displayPrice,
           price > 0 {
            return .ready(price)
        }

        return .failed(
            SymbolPriceValidator.failureMessage(assetType: assetType, symbol: normalized)
        )
    }
}
