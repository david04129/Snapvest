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

    static func priceValidationKey(assetType: AssetType, symbol: String) -> String {
        let normalized = SupabasePriceService.normalizeSymbol(assetType: assetType, symbol: symbol)
        return "\(assetType.rawValue)|\(normalized)"
    }

    /// 批量驗價；回傳 validation key → 錯誤訊息（成功的不在 map 內）。
    static func validatePricesAvailable(symbols: [SymbolInfo]) async -> [String: String] {
        let unique = SupabasePriceService.deduplicatedSymbolInfos(symbols)
        guard !unique.isEmpty else { return [:] }

        if MockDataService.shared.isDemoModeActive {
            var failures: [String: String] = [:]
            for info in unique {
                if let message = await validatePriceAvailable(
                    assetType: info.assetType,
                    symbol: info.symbol,
                    transactionType: .buy
                ) {
                    failures[priceValidationKey(assetType: info.assetType, symbol: info.symbol)] = message
                }
            }
            return failures
        }

        guard SupabaseConfig.isConfigured else {
            let message = "無法連線驗證股價，請確認網路與 Supabase 設定"
            return Dictionary(
                uniqueKeysWithValues: unique.map {
                    (priceValidationKey(assetType: $0.assetType, symbol: $0.symbol), message)
                }
            )
        }

        var pricedKeys = Set<String>()
        let snapshots = (try? await SupabasePriceService.fetchPrices(symbols: unique)) ?? []
        for snapshot in snapshots {
            if let price = snapshot.displayPrice, price > 0 {
                pricedKeys.insert(priceValidationKey(assetType: snapshot.assetType, symbol: snapshot.symbol))
            }
        }

        let stillMissing = unique.filter {
            !pricedKeys.contains(priceValidationKey(assetType: $0.assetType, symbol: $0.symbol))
        }
        if !stillMissing.isEmpty {
            let created = await SupabasePriceService.resolveMissingPrices(symbols: stillMissing)
            for snapshot in created {
                if let price = snapshot.displayPrice, price > 0 {
                    pricedKeys.insert(priceValidationKey(assetType: snapshot.assetType, symbol: snapshot.symbol))
                }
            }
        }

        var failures: [String: String] = [:]
        for info in unique {
            let key = priceValidationKey(assetType: info.assetType, symbol: info.symbol)
            if pricedKeys.contains(key) { continue }
            failures[key] = failureMessage(assetType: info.assetType, symbol: info.symbol)
        }
        return failures
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

        let failures = await validatePricesAvailable(
            symbols: [SymbolInfo(assetType: assetType, symbol: normalized)]
        )
        return failures[priceValidationKey(assetType: assetType, symbol: normalized)]
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
