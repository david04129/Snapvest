//
//  SymbolListService.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct SymbolItem: Identifiable, Equatable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

/// 從 Bundle 讀取股票/加密貨幣代號清單，並提供搜尋功能
struct SymbolListService {

    /// 載入指定市場的完整代號清單（依 symbol 排序）
    @MainActor static func loadSymbols(market: TradeMarket) -> [SymbolItem] {
        let fileName: String
        switch market {
        case .stockTW: fileName = "symbols_tw"
        case .stockUS: fileName = "symbols_us"
        case .crypto: fileName = "symbols_crypto"
        }
        let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: fileName, withExtension: "json")
        guard let url = url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsArray = json["items"] as? [[String: Any]] else {
            return []
        }
        return itemsArray.compactMap { item -> SymbolItem? in
            guard let symbol = item["symbol"] as? String, let name = item["name"] as? String else { return nil }
            return SymbolItem(symbol: symbol, name: name)
        }.sorted { $0.symbol < $1.symbol }
    }
    
    /// 搜尋代號或名稱（不區分大小寫）：代號匹配優先，名稱匹配次之
    @MainActor static func search(market: TradeMarket, query: String) -> [SymbolItem] {
        filter(items: loadSymbols(market: market), query: query)
    }
    
    /// 從已載入的清單進行搜尋（避免重複讀取 JSON，用於 UI 即時過濾）
    /// - Parameters:
    ///   - items: 完整清單
    ///   - query: 搜尋關鍵字
    ///   - limit: 最多回傳筆數（nil 表示不限制）
    nonisolated static func filter(items: [SymbolItem], query: String, limit: Int? = nil) -> [SymbolItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return items
        }
        let lower = query.lowercased()
        var symbolExact: [SymbolItem] = []
        var symbolPrefix: [SymbolItem] = []
        var symbolContains: [SymbolItem] = []
        var nameOnly: [SymbolItem] = []

        for item in items {
            let sym = item.symbol.lowercased()
            let nam = item.name.lowercased()
            let symbolMatch = sym.contains(lower)
            let nameMatch = !symbolMatch && nam.contains(lower)

            if symbolMatch {
                if sym == lower {
                    symbolExact.append(item)
                } else if sym.hasPrefix(lower) {
                    symbolPrefix.append(item)
                } else {
                    symbolContains.append(item)
                }
            } else if nameMatch {
                nameOnly.append(item)
            }
        }

        let combined = symbolExact + symbolPrefix + symbolContains + nameOnly
        return limit != nil ? Array(combined.prefix(limit!)) : combined
    }
}

