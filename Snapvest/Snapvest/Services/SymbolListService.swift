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

    nonisolated init(symbol: String, name: String, coingeckoId: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.coingeckoId = coingeckoId
    }
}

private enum SymbolCatalogFileLookup {
    nonisolated(unsafe) private static var twNameCache: [String: String]?
    nonisolated(unsafe) private static var cryptoNameCache: [String: String]?
    nonisolated(unsafe) private static var cryptoCoingeckoCache: [String: String]?

    nonisolated static func invalidateCaches() {
        twNameCache = nil
        cryptoNameCache = nil
        cryptoCoingeckoCache = nil
    }

    nonisolated static func twDisplayName(for symbol: String) -> String? {
        let key = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if twNameCache == nil {
            twNameCache = loadLookup(fileName: "symbols_tw", keyTransform: { $0 })
        }
        return twNameCache?[key]
    }

    nonisolated static func cryptoListedName(for symbol: String) -> String? {
        let key = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if cryptoNameCache == nil {
            cryptoNameCache = loadLookup(fileName: "symbols_crypto", keyTransform: { $0.lowercased() })
        }
        return cryptoNameCache?[key]
    }

    nonisolated static func coingeckoId(forCryptoSymbol symbol: String) -> String? {
        let key = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if cryptoCoingeckoCache == nil {
            cryptoCoingeckoCache = loadLookup(
                fileName: "symbols_crypto",
                valueField: "coingeckoId",
                keyTransform: { $0.lowercased() }
            )
        }
        return cryptoCoingeckoCache?[key]
    }

    nonisolated private static func loadLookup(
        fileName: String,
        valueField: String = "name",
        keyTransform: (String) -> String
    ) -> [String: String] {
        guard let items = loadItemsArray(fileName: fileName) else { return [:] }
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(items.count)
        for item in items {
            guard let symbol = item["symbol"] as? String,
                  let value = item[valueField] as? String,
                  !value.isEmpty else { continue }
            lookup[keyTransform(symbol)] = value
        }
        return lookup
    }

    nonisolated private static func loadItemsArray(fileName: String) -> [[String: Any]]? {
        let localURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SymbolCatalog", isDirectory: true)
            .appendingPathComponent("\(fileName).json")

        let url = localURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: fileName, withExtension: "json")

        guard let url,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return nil
        }
        return items
    }
}

/// 從本機 catalog（Application Support 或 Bundle）讀取股票/加密貨幣代號清單。
struct SymbolListService {

    /// 台股代號 → 簡稱
    nonisolated static func twDisplayName(for symbol: String) -> String? {
        SymbolCatalogFileLookup.twDisplayName(for: symbol)
    }

    /// 加密貨幣代號統一為大寫（BTC、ETH），與後端抓價一致
    nonisolated static func normalizedCryptoSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// 清單內的加密貨幣名稱（如 Bitcoin），無則 nil
    nonisolated static func cryptoListedName(for symbol: String) -> String? {
        SymbolCatalogFileLookup.cryptoListedName(for: symbol)
    }

    /// 加密貨幣 UI 顯示：僅大寫代號（BTC、ETH）
    nonisolated static func cryptoDisplayName(for symbol: String, storedName: String? = nil) -> String {
        _ = storedName
        return normalizedCryptoSymbol(symbol)
    }

    nonisolated static func displayName(
        assetType: AssetType,
        symbol: String,
        storedName: String? = nil
    ) -> String {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = storedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usableName = trimmedName.flatMap { name -> String? in
            guard !name.isEmpty, name != trimmedSymbol else { return nil }
            return name
        }
        switch assetType {
        case .stockTW:
            return twDisplayName(for: trimmedSymbol)
                ?? usableName
                ?? trimmedSymbol
        case .crypto:
            return cryptoDisplayName(for: trimmedSymbol, storedName: trimmedName)
        case .stockUS:
            return trimmedSymbol.uppercased()
        case .cash:
            return usableName ?? trimmedSymbol
        }
    }

    /// 標題下方是否另顯示代號（台股：名稱與代號不同時才顯示；美股／加密只顯示代號，不重複）
    static func shouldShowSymbolUnderTitle(assetType: AssetType, title: String, symbol: String) -> Bool {
        guard assetType == .stockTW else { return false }
        let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbolText = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return !symbolText.isEmpty && titleText != symbolText
    }

    /// 依 ticker 查 CoinGecko id（用於抓價；與清單內 coingeckoId 一致）
    nonisolated static func coingeckoId(forCryptoSymbol symbol: String) -> String? {
        SymbolCatalogFileLookup.coingeckoId(forCryptoSymbol: symbol)
    }

    nonisolated static func invalidateLookupCaches() {
        SymbolCatalogFileLookup.invalidateCaches()
    }

    /// 載入指定市場的完整代號清單（依 symbol 排序）
    @MainActor static func loadSymbols(market: TradeMarket) -> [SymbolItem] {
        guard let catalogMarket = SymbolCatalogMarket(tradeMarket: market) else { return [] }
        return SymbolCatalogStore.items(for: catalogMarket)
    }

    /// 搜尋代號或名稱（不區分大小寫）：代號匹配優先，名稱匹配次之
    @MainActor static func search(market: TradeMarket, query: String) -> [SymbolItem] {
        filter(items: loadSymbols(market: market), query: query)
    }

    /// 從已載入的清單進行搜尋（避免重複讀取 JSON，用於 UI 即時過濾）
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
