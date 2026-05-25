//
//  SymbolListService.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct SymbolItem: Identifiable, Equatable, Sendable {
    let symbol: String
    let name: String
    /// CoinGecko API 用的 id（僅加密貨幣；與 ticker 常不同，例如 USDC → usd-coin）
    let coingeckoId: String?
    var id: String { symbol }

    init(symbol: String, name: String, coingeckoId: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.coingeckoId = coingeckoId
    }
}

/// 台股簡稱查詢（可從背景執行緒呼叫，獨立於 MainActor）
private enum TWSymbolNameLookup {
    nonisolated(unsafe) private static var cache: [String: String]?

    nonisolated static func displayName(for symbol: String) -> String? {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if cache == nil {
            cache = loadFromBundle()
        }
        return cache?[trimmed]
    }

    nonisolated private static func loadFromBundle() -> [String: String] {
        let url = Bundle.main.url(forResource: "symbols_tw", withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: "symbols_tw", withExtension: "json")
        guard let url = url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsArray = json["items"] as? [[String: Any]] else {
            return [:]
        }
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(itemsArray.count)
        for item in itemsArray {
            guard let symbol = item["symbol"] as? String,
                  let name = item["name"] as? String else { continue }
            lookup[symbol] = name
        }
        return lookup
    }
}

/// 加密貨幣代號 → 顯示名稱（symbols_crypto.json；ticker 在檔內為小寫）
private enum CryptoSymbolNameLookup {
    nonisolated(unsafe) private static var cache: [String: String]?

    nonisolated static func displayName(for symbol: String) -> String? {
        let key = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if cache == nil {
            cache = loadFromBundle()
        }
        return cache?[key]
    }

    nonisolated private static func loadFromBundle() -> [String: String] {
        let url = Bundle.main.url(forResource: "symbols_crypto", withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: "symbols_crypto", withExtension: "json")
        guard let url = url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsArray = json["items"] as? [[String: Any]] else {
            return [:]
        }
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(itemsArray.count)
        for item in itemsArray {
            guard let symbol = item["symbol"] as? String,
                  let name = item["name"] as? String else { continue }
            lookup[symbol.lowercased()] = name
        }
        return lookup
    }
}

/// 從 Bundle 讀取股票/加密貨幣代號清單，並提供搜尋功能
struct SymbolListService {

    private static var cryptoCoingeckoIdBySymbol: [String: String]?

    /// 台股代號 → 簡稱（symbols_tw.json）
    static func twDisplayName(for symbol: String) -> String? {
        TWSymbolNameLookup.displayName(for: symbol)
    }

    /// 加密貨幣代號統一為大寫（BTC、ETH），與後端抓價一致
    static func normalizedCryptoSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// 清單內的加密貨幣名稱（如 Bitcoin），無則 nil
    static func cryptoListedName(for symbol: String) -> String? {
        CryptoSymbolNameLookup.displayName(for: symbol)
    }

    /// 加密貨幣 UI 顯示：僅大寫代號（BTC、ETH）
    static func cryptoDisplayName(for symbol: String, storedName: String? = nil) -> String {
        _ = storedName
        return normalizedCryptoSymbol(symbol)
    }

    /// 標題下方是否另顯示代號（台股：名稱與代號不同時才顯示；美股／加密只顯示代號，不重複）
    static func shouldShowSymbolUnderTitle(assetType: AssetType, title: String, symbol: String) -> Bool {
        guard assetType == .stockTW else { return false }
        let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbolText = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return !symbolText.isEmpty && titleText != symbolText
    }

    /// 依 ticker 查 CoinGecko id（用於抓價；與清單內 coingeckoId 一致）
    static func coingeckoId(forCryptoSymbol symbol: String) -> String? {
        if cryptoCoingeckoIdBySymbol == nil {
            let items = loadSymbols(market: .crypto)
            cryptoCoingeckoIdBySymbol = Dictionary(
                uniqueKeysWithValues: items.compactMap { item in
                    guard let cg = item.coingeckoId, !cg.isEmpty else { return nil }
                    return (item.symbol.lowercased(), cg)
                }
            )
        }
        return cryptoCoingeckoIdBySymbol?[symbol.lowercased()]
    }

    /// 載入指定市場的完整代號清單（依 symbol 排序）
    @MainActor static func loadSymbols(market: TradeMarket) -> [SymbolItem] {
        let fileName: String
        switch market {
        case .stockTW: fileName = "symbols_tw"
        case .stockUS: fileName = "symbols_us"
        case .crypto: fileName = "symbols_crypto"
        }
        return loadSymbolItems(fileName: fileName).sorted { $0.symbol < $1.symbol }
    }

    @MainActor private static func loadSymbolItems(fileName: String) -> [SymbolItem] {
        let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: fileName, withExtension: "json")
        guard let url = url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let itemsArray = json["items"] as? [[String: Any]] else {
            return []
        }
        let isCryptoList = fileName == "symbols_crypto"
        return itemsArray.compactMap { item -> SymbolItem? in
            guard let symbol = item["symbol"] as? String, let name = item["name"] as? String else { return nil }
            let coingeckoId = item["coingeckoId"] as? String
            let displaySymbol = isCryptoList ? normalizedCryptoSymbol(symbol) : symbol
            return SymbolItem(symbol: displaySymbol, name: name, coingeckoId: coingeckoId)
        }
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
