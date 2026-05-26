//
//  SymbolPriceValidator.swift
//  Snapvest
//
//  方案 A：買／賣／匯入前必須能從 Supabase 取得有效報價，否則拒絕。
//

import Foundation

enum SymbolPriceValidationError: LocalizedError {
    case unavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        }
    }
}

enum SymbolPriceValidator {
    static func needsValidation(assetType: AssetType, transactionType: TransactionType) -> Bool {
        transactionType == .buy && assetType != .cash
    }
    
    /// 驗證成功回傳 `nil`；失敗回傳使用者可讀錯誤訊息。
    static func validatePriceAvailable(
        assetType: AssetType,
        symbol: String,
        transactionType: TransactionType
    ) async -> String? {
        guard needsValidation(assetType: assetType, transactionType: transactionType) else {
            return nil
        }
        
        let normalized = SupabasePriceService.normalizeSymbol(assetType: assetType, symbol: symbol)
        guard !normalized.isEmpty else {
            return "需填 symbol"
        }
        
        if MockDataService.shared.isDemoModeActive {
            if let price = await SupabasePriceService.fetchDisplayPrice(
                assetType: assetType,
                symbol: normalized
            ), price > 0 {
                return nil
            }
            return failureMessage(assetType: assetType, symbol: normalized)
        }
        
        guard SupabaseConfig.isConfigured else {
            return "無法連線驗證股價，請確認網路與 Supabase 設定"
        }
        
        let coingeckoId = assetType == .crypto
            ? SymbolListService.coingeckoId(forCryptoSymbol: normalized)
            : nil
        
        guard let price = await SupabasePriceService.fetchDisplayPrice(
            assetType: assetType,
            symbol: normalized,
            coingeckoId: coingeckoId
        ), price > 0 else {
            return failureMessage(assetType: assetType, symbol: normalized)
        }
        
        return nil
    }
    
    static func validatePriceAvailableOrThrow(
        assetType: AssetType,
        symbol: String,
        transactionType: TransactionType
    ) async throws {
        if let message = await validatePriceAvailable(
            assetType: assetType,
            symbol: symbol,
            transactionType: transactionType
        ) {
            throw SymbolPriceValidationError.unavailable(message)
        }
    }
    
    static func failureMessage(assetType: AssetType, symbol: String) -> String {
        switch assetType {
        case .stockUS:
            return "找不到美股 \(symbol) 的股價，無法匯入（請確認代號是否正確）"
        case .stockTW:
            return "找不到台股 \(symbol) 的股價，無法匯入（請確認代號是否正確）"
        case .crypto:
            return "找不到加密貨幣 \(symbol) 的股價，無法匯入（請確認代號是否正確）"
        case .cash:
            return "無法驗證股價"
        }
    }
}
