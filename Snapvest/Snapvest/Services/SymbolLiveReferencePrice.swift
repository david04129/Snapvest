//
//  SymbolLiveReferencePrice.swift
//  Snapvest
//
//  買進表單：選股後預抓參考現價（DB / fetch-or-create），成功後視為已驗證報價。
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

    /// 從 Supabase 取得有效參考現價；成功表示 DB 已有列（含 Edge 剛寫入）。
    static func prefetch(assetType: AssetType, symbol: String) async -> State {
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

        if let price = await SupabasePriceService.fetchDisplayPrice(
            assetType: assetType,
            symbol: normalized,
            coingeckoId: coingeckoId
        ), price > 0 {
            return .ready(price)
        }

        return .failed(
            SymbolPriceValidator.failureMessage(assetType: assetType, symbol: normalized)
        )
    }
}
