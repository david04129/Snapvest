//
//  SymbolCatalogSyncService.swift
//  Snapvest
//
//  冷啟背景：比對 DB symbol catalog 版本，冪等套用累積 patch。
//

import Foundation

enum SymbolCatalogSyncService {
    @MainActor
    @discardableResult
    static func syncIfNeeded() async -> Int {
        guard SupabaseConfig.isConfigured, let baseUrl = SupabaseConfig.url else { return 0 }
        _ = SymbolCatalogStore.ensureBootstrappedFromBundleIfNeeded()

        guard let rows = await fetchRemoteRows(baseUrl: baseUrl), !rows.isEmpty else { return 0 }

        var updatedMarkets = 0
        for row in rows {
            guard let market = SymbolCatalogMarket(rawValue: row.market) else { continue }
            let local = SymbolCatalogStore.localVersion(for: market)
            let remote = SymbolCatalogVersion(epoch: row.epoch, minor: row.minor)

            guard remote.epoch == local.epoch, remote.isNewer(than: local) else {
                #if DEBUG
                if remote.epoch > local.epoch {
                    print("[SymbolCatalogSync] \(market.rawValue) 需 App 大版（local \(local.label) remote \(remote.label)）")
                }
                #endif
                continue
            }

            do {
                try SymbolCatalogStore.applyRemotePatch(market: market, remote: row)
                updatedMarkets += 1
                #if DEBUG
                print("[SymbolCatalogSync] \(market.rawValue) \(local.label) → \(remote.label)")
                #endif
            } catch {
                #if DEBUG
                print("[SymbolCatalogSync] \(market.rawValue) patch 失敗: \(error)")
                #endif
            }
        }
        return updatedMarkets
    }

    private static func fetchRemoteRows(baseUrl: String) async -> [SymbolCatalogRemoteRow]? {
        guard var components = URLComponents(string: "\(baseUrl)/rest/v1/symbol_catalog_markets") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "market,epoch,minor,cumulative_adds,cumulative_removes")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await SupabaseConfig.applyRequestAuth(to: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode([SymbolCatalogRemoteRow].self, from: data)
        } catch {
            #if DEBUG
            print("[SymbolCatalogSync] fetch failed: \(error)")
            #endif
            return nil
        }
    }
}
