//
//  SymbolCatalogStore.swift
//  Snapvest
//
//  本機選股 catalog：Application Support 優先，Bundle 為 bootstrap。
//

import Foundation

private struct SymbolCatalogPersistedState: Codable, Sendable {
    var versions: [String: SymbolCatalogVersion]
}

private struct SymbolCatalogDocument: Codable, Sendable {
    var epoch: Int?
    var minor: Int?
    var legacyVersion: Int?
    var updatedAt: String?
    var items: [SymbolCatalogDocumentItem]

    enum CodingKeys: String, CodingKey {
        case epoch, minor, updatedAt, items
        case legacyVersion = "version"
    }
}

private struct SymbolCatalogDocumentItem: Codable, Sendable {
    let symbol: String
    let name: String
    let coingeckoId: String?
}

enum SymbolCatalogStore {
    private static let folderName = "SymbolCatalog"
    private static let stateFileName = "catalog_state.json"

    private static var cache: [SymbolCatalogMarket: [SymbolItem]] = [:]
    private static var twNameCache: [String: String]?
    private static var cryptoNameCache: [String: String]?
    private static var cryptoCoingeckoCache: [String: String]?

    static func catalogDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    static func localVersion(for market: SymbolCatalogMarket) -> SymbolCatalogVersion {
        loadState().versions[market.rawValue] ?? bundleVersion(for: market)
    }

    static func bundleVersion(for market: SymbolCatalogMarket) -> SymbolCatalogVersion {
        guard let doc = loadBundleDocument(for: market) else { return .zero }
        return SymbolCatalogVersion(
            epoch: doc.epoch ?? 1,
            minor: doc.minor ?? doc.legacyVersion ?? 0
        )
    }

    static func items(for market: SymbolCatalogMarket) -> [SymbolItem] {
        if let cached = cache[market] {
            return cached
        }
        let loaded = loadItems(for: market)
        cache[market] = loaded
        return loaded
    }

    static func invalidateCaches() {
        cache.removeAll()
        twNameCache = nil
        cryptoNameCache = nil
        cryptoCoingeckoCache = nil
        SymbolListService.invalidateLookupCaches()
    }

    @discardableResult
    static func ensureBootstrappedFromBundleIfNeeded() -> Bool {
        var state = loadState()
        var didWrite = false
        for market in SymbolCatalogMarket.allCases {
            let cachedFile = catalogFileURL(for: market)
            if FileManager.default.fileExists(atPath: cachedFile.path) {
                if state.versions[market.rawValue] == nil {
                    state.versions[market.rawValue] = bundleVersion(for: market)
                    didWrite = true
                }
                continue
            }
            guard let doc = loadBundleDocument(for: market) else { continue }
            try? writeCatalogDocument(doc, for: market)
            state.versions[market.rawValue] = SymbolCatalogVersion(
                epoch: doc.epoch ?? 1,
                minor: doc.minor ?? doc.legacyVersion ?? 0
            )
            didWrite = true
        }
        if didWrite {
            saveState(state)
            invalidateCaches()
        }
        return didWrite
    }

    static func applyRemotePatch(
        market: SymbolCatalogMarket,
        remote: SymbolCatalogRemoteRow
    ) throws {
        var items = items(for: market)
        let removeKeys = Set(
            (remote.cumulativeRemoves ?? []).map { normalizedKey(market: market, symbol: $0.symbol) }
        )
        if !removeKeys.isEmpty {
            items.removeAll { removeKeys.contains(normalizedKey(market: market, symbol: $0.symbol)) }
        }

        var byKey: [String: SymbolItem] = Dictionary(
            uniqueKeysWithValues: items.map { (normalizedKey(market: market, symbol: $0.symbol), $0) }
        )
        for entry in remote.cumulativeAdds ?? [] {
            let key = normalizedKey(market: market, symbol: entry.symbol)
            let displaySymbol: String
            switch market {
            case .crypto:
                displaySymbol = SymbolListService.normalizedCryptoSymbol(entry.symbol)
            case .us:
                displaySymbol = entry.symbol.uppercased()
            case .tw:
                displaySymbol = entry.symbol
            }
            byKey[key] = SymbolItem(
                symbol: displaySymbol,
                name: entry.name ?? displaySymbol,
                coingeckoId: entry.coingeckoId
            )
        }

        items = Array(byKey.values).sorted {
            $0.symbol.localizedCaseInsensitiveCompare($1.symbol) == .orderedAscending
        }
        let version = SymbolCatalogVersion(epoch: remote.epoch, minor: remote.minor)
        let doc = SymbolCatalogDocument(
            epoch: version.epoch,
            minor: version.minor,
            legacyVersion: version.minor,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            items: items.map { SymbolCatalogDocumentItem(symbol: $0.symbol, name: $0.name, coingeckoId: $0.coingeckoId) }
        )
        try writeCatalogDocument(doc, for: market)
        var state = loadState()
        state.versions[market.rawValue] = version
        saveState(state)
        invalidateCaches()
    }

    private static func loadItems(for market: SymbolCatalogMarket) -> [SymbolItem] {
        if let doc = loadCachedDocument(for: market) ?? loadBundleDocument(for: market) {
            return doc.items.map {
                SymbolItem(symbol: $0.symbol, name: $0.name, coingeckoId: $0.coingeckoId)
            }
        }
        return []
    }

    private static func loadCachedDocument(for market: SymbolCatalogMarket) -> SymbolCatalogDocument? {
        let url = catalogFileURL(for: market)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SymbolCatalogDocument.self, from: data)
    }

    private static func loadBundleDocument(for market: SymbolCatalogMarket) -> SymbolCatalogDocument? {
        let url = Bundle.main.url(forResource: market.fileName, withExtension: "json", subdirectory: "Symbols")
            ?? Bundle.main.url(forResource: market.fileName, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SymbolCatalogDocument.self, from: data)
    }

    private static func catalogFileURL(for market: SymbolCatalogMarket) -> URL {
        catalogDirectory().appendingPathComponent("\(market.fileName).json")
    }

    private static func writeCatalogDocument(_ document: SymbolCatalogDocument, for market: SymbolCatalogMarket) throws {
        let dir = catalogDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        try data.write(to: catalogFileURL(for: market), options: .atomic)
    }

    private static func loadState() -> SymbolCatalogPersistedState {
        let url = catalogDirectory().appendingPathComponent(stateFileName)
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SymbolCatalogPersistedState.self, from: data) else {
            return SymbolCatalogPersistedState(versions: [:])
        }
        return state
    }

    private static func saveState(_ state: SymbolCatalogPersistedState) {
        let dir = catalogDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(stateFileName)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func normalizedKey(market: SymbolCatalogMarket, symbol: String) -> String {
        switch market {
        case .crypto: return symbol.lowercased()
        case .us: return symbol.uppercased()
        case .tw: return symbol
        }
    }

    static func twDisplayName(for symbol: String) -> String? {
        if twNameCache == nil {
            twNameCache = Dictionary(uniqueKeysWithValues: items(for: .tw).map { ($0.symbol, $0.name) })
        }
        return twNameCache?[symbol.trimmingCharacters(in: .whitespaces)]
    }

    static func cryptoListedName(for symbol: String) -> String? {
        let key = symbol.lowercased()
        if cryptoNameCache == nil {
            cryptoNameCache = Dictionary(
                uniqueKeysWithValues: items(for: .crypto).map { ($0.symbol.lowercased(), $0.name) }
            )
        }
        return cryptoNameCache?[key]
    }

    static func coingeckoId(forCryptoSymbol symbol: String) -> String? {
        let key = symbol.lowercased()
        if cryptoCoingeckoCache == nil {
            cryptoCoingeckoCache = Dictionary(
                uniqueKeysWithValues: items(for: .crypto).compactMap { item in
                    guard let cg = item.coingeckoId, !cg.isEmpty else { return nil }
                    return (item.symbol.lowercased(), cg)
                }
            )
        }
        return cryptoCoingeckoCache?[key]
    }
}
