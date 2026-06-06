//
//  TrackedSymbolSync.swift
//  Snapvest
//
//  將指定公開 symbol（通常來自本筆 buy/sell 交易）匿名加入後端全站追蹤池。
//

import Foundation

enum TrackedSymbolSync {
    static func sync(symbols: [SymbolInfo]) async {
        guard SupabaseConfig.isConfigured else { return }

        let uniqueSymbols = unique(symbols)
        guard !uniqueSymbols.isEmpty else { return }

        for chunk in symbolChunks(uniqueSymbols, size: SupabaseTrackedSymbolService.maxBatchSymbols) {
            do {
                try await SupabaseTrackedSymbolService.trackBatch(chunk)
            } catch SupabaseTrackedSymbolError.rateLimited(let retryAfterSeconds) {
                #if DEBUG
                print("[TrackedSymbolSync] rate limited, retryAfter=\(retryAfterSeconds ?? -1)s")
                #endif
                let delaySeconds = max(retryAfterSeconds ?? 5, 1)
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
                do {
                    try await SupabaseTrackedSymbolService.trackBatch(chunk)
                } catch {
                    #if DEBUG
                    print("[TrackedSymbolSync] batch retry failed: \(error.localizedDescription)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[TrackedSymbolSync] batch failed: \(error.localizedDescription)")
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

    private static func symbolChunks(_ symbols: [SymbolInfo], size: Int) -> [[SymbolInfo]] {
        guard size > 0, !symbols.isEmpty else { return [] }
        var chunks: [[SymbolInfo]] = []
        var index = 0
        while index < symbols.count {
            let end = min(index + size, symbols.count)
            chunks.append(Array(symbols[index..<end]))
            index = end
        }
        return chunks
    }
}
