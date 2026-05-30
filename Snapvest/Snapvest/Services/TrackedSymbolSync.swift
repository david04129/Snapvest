//
//  TrackedSymbolSync.swift
//  Snapvest
//
//  將目前持有的公開 symbol 匿名加入後端全站追蹤池。
//

import Foundation

enum TrackedSymbolSync {
    static func sync(symbols: [SymbolInfo]) async {
        guard SupabaseConfig.isConfigured else { return }

        let uniqueSymbols = unique(symbols)
        for symbol in uniqueSymbols {
            do {
                try await SupabaseTrackedSymbolService.track(symbol)
            } catch {
                #if DEBUG
                print("[TrackedSymbolSync] failed \(symbol.assetType.rawValue)/\(symbol.symbol): \(error.localizedDescription)")
                #endif
            }
        }
    }

    private static func unique(_ symbols: [SymbolInfo]) -> [SymbolInfo] {
        var seen = Set<String>()
        var result: [SymbolInfo] = []
        for symbol in symbols {
            let normalized = SupabasePriceService.normalizeSymbol(
                assetType: symbol.assetType,
                symbol: symbol.symbol
            )
            let key = "\(symbol.assetType.rawValue)_\(normalized)"
            guard seen.insert(key).inserted else { continue }
            result.append(SymbolInfo(assetType: symbol.assetType, symbol: normalized))
        }
        return result
    }
}
