//
//  SupabasePriceService.swift
//  Snapvest
//
//  從 Supabase 讀取股價（需先設定 SupabaseConfig）
//

import Foundation

/// PostgreSQL / Supabase REST 回傳的 ISO8601 時間（含微秒）
private enum SupabaseRESTTimestampParser {
    nonisolated static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTime
        ]
        withFraction.timeZone = TimeZone(identifier: "UTC")
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        withoutFraction.timeZone = TimeZone(identifier: "UTC")
        return withFraction.date(from: string) ?? withoutFraction.date(from: string)
    }
    
    /// PostgreSQL DATE（yyyy-MM-dd）
    nonisolated static func parseCloseDate(_ string: String?) -> Date? {
        guard let string, string.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(string.prefix(10)))
    }
}

/// Supabase 連線設定（請在 App 啟動時設定）
enum SupabaseConfig: Sendable {
    nonisolated(unsafe) static var url: String?
    /// REST / Edge Function 的 apikey（publishable `sb_publishable__…` 或 legacy anon JWT）
    nonisolated(unsafe) static var anonKey: String?
    /// 選填：legacy anon JWT（`eyJ…`），供 Edge Function 的 Authorization header
    nonisolated(unsafe) static var anonJwt: String?
    
    static var isConfigured: Bool {
        url != nil && !(url ?? "").isEmpty && anonKey != nil && !(anonKey ?? "").isEmpty
    }
    
    /// Edge Function 可用的 Bearer token（legacy JWT）；publishable key 不可當 JWT 使用
    static var edgeFunctionAuthorizationToken: String? {
        if let jwt = anonJwt?.trimmingCharacters(in: .whitespacesAndNewlines), jwt.hasPrefix("eyJ") {
            return jwt
        }
        if let key = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines), key.hasPrefix("eyJ") {
            return key
        }
        return nil
    }
    
    static func applyEdgeFunctionAuth(to request: inout URLRequest) {
        guard let apikey = anonKey else { return }
        request.setValue(apikey, forHTTPHeaderField: "apikey")
        if let token = edgeFunctionAuthorizationToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

/// 從 Supabase 讀取股價與更新時間
struct SupabasePriceService {
    
    private static let lastFetchedAtKey = "com.snapvest.priceLastFetchedAt"
    
    /// 取得後端價格最後更新時間
    static func fetchLastUpdatedAt() async -> Date? {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/rest/v1/price_update_metadata?id=eq.global&select=last_updated_at"),
              let key = SupabaseConfig.anonKey else { return nil }
        
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode([[String: String]].self, from: data)
            guard let last = decoded.first?["last_updated_at"] else { return nil }
            return SupabaseRESTTimestampParser.parse(last)
        } catch {
            return nil
        }
    }
    
    /// 比對是否需要拉取（後端 `price_update_metadata` 較新才拉）
    static func shouldFetchPrices(userId: String, dataService: DataServiceProtocol) async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        guard let remote = await fetchLastUpdatedAt() else { return false }
        
        let local = dataService.fetchPriceSourceUpdatedAt(userId: userId)
            ?? legacyLastFetchedAt
            ?? .distantPast
        
        return remote > local
    }
    
    /// 成功同步股價後呼叫，對齊本機 metadata（取代僅寫 UserDefaults）
    static func recordSuccessfulPriceSync(userId: String, dataService: DataServiceProtocol) async {
        let sourceUpdatedAt = await fetchLastUpdatedAt()
        dataService.updatePriceSyncMetadata(userId: userId, sourceUpdatedAt: sourceUpdatedAt)
        legacyLastFetchedAt = sourceUpdatedAt ?? Date()
    }
    
    private static var legacyLastFetchedAt: Date? {
        get { UserDefaults.standard.object(forKey: lastFetchedAtKey) as? Date }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: lastFetchedAtKey)
            }
        }
    }
    
    /// 單檔顯示價格（Supabase → fetch-or-create；不使用 Mock 100）
    static func fetchDisplayPrice(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String? = nil
    ) async -> Decimal? {
        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        let symbolInfo = SymbolInfo(assetType: assetType, symbol: normalized)
        if let snapshots = try? await fetchPrices(symbols: [symbolInfo]),
           let price = snapshots.first?.displayPrice {
            return price
        }
        if let price = try? await fetchSingle(assetType: assetType, symbol: normalized) {
            return price
        }
        if let price = try? await fetchOrCreatePrice(
            assetType: assetType,
            symbol: normalized,
            coingeckoId: coingeckoId
        ) {
            return price
        }
        return nil
    }
    /// 與 DB / Edge Function 一致的代號格式（加密、美股大寫；台股保留原樣）
    static func normalizeSymbol(assetType: AssetType, symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        switch assetType {
        case .stockUS, .crypto:
            return trimmed.uppercased()
        default:
            return trimmed
        }
    }
    
    /// 批量取得股價（並行請求）
    static func fetchPrices(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }
        
        let rows = await withTaskGroup(of: SupabasePriceRow?.self) { group in
            for s in symbols {
                group.addTask {
                    await fetchPriceRow(baseUrl: baseUrl, key: key, symbolInfo: s)
                }
            }
            var out: [SupabasePriceRow] = []
            for await row in group {
                if let r = row { out.append(r) }
            }
            return out
        }
        let results = rows.compactMap { SupabasePriceRow.toAssetPriceSnapshot($0) }
        
        #if DEBUG
        if !symbols.isEmpty, results.isEmpty {
            print("[SupabasePriceService] fetchPrices returned 0/\(symbols.count) symbols")
        }
        #endif
        
        return results
    }
    
    private static func fetchPriceRow(baseUrl: String, key: String, symbolInfo: SymbolInfo) async -> SupabasePriceRow? {
        let querySymbol = normalizeSymbol(assetType: symbolInfo.assetType, symbol: symbolInfo.symbol)
        guard let encoded = querySymbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/rest/v1/asset_price_snapshots?asset_type=eq.\(symbolInfo.assetType.rawValue)&symbol=eq.\(encoded)&select=*") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200...299).contains(http.statusCode) else {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[SupabasePriceService] HTTP \(http.statusCode) for \(symbolInfo.assetType.rawValue)/\(symbolInfo.symbol): \(body.prefix(200))")
                #endif
                return nil
            }
            let decoded = try JSONDecoder().decode([SupabasePriceRow].self, from: data)
            return decoded.first
        } catch {
            #if DEBUG
            print("[SupabasePriceService] fetch failed for \(symbolInfo.symbol): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// 單檔取得股價（REST 完整列）
    static func fetchSingle(assetType: AssetType, symbol: String) async throws -> Decimal? {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }
        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        let row = await fetchPriceRow(
            baseUrl: baseUrl,
            key: key,
            symbolInfo: SymbolInfo(assetType: assetType, symbol: normalized)
        )
        return row.flatMap { SupabasePriceRow.toAssetPriceSnapshot($0)?.displayPrice }
    }

    /// 呼叫 fetch-or-create-price（新增股票時使用）
    static func fetchOrCreatePrice(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String? = nil
    ) async throws -> Decimal? {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/fetch-or-create-price") else {
            throw SupabaseError.notConfigured
        }
        
        struct FetchOrCreateBody: Encodable {
            let assetType: String
            let symbol: String
            let coingeckoId: String?
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        SupabaseConfig.applyEdgeFunctionAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            FetchOrCreateBody(
                assetType: assetType.rawValue,
                symbol: normalizeSymbol(assetType: assetType, symbol: symbol),
                coingeckoId: coingeckoId
            )
        )
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return nil }
        guard http.statusCode == 200 else {
            #if DEBUG
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[SupabasePriceService] fetch-or-create-price HTTP \(http.statusCode) for \(symbol): \(body.prefix(300))")
            #endif
            return nil
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return parseJSONPrice(json?["price"])
    }
    
    private static func parseJSONPrice(_ value: Any?) -> Decimal? {
        if let d = value as? Double { return Decimal(d) }
        if let i = value as? Int { return Decimal(i) }
        if let n = value as? NSNumber { return Decimal(string: n.stringValue) }
        if let s = value as? String, let d = Decimal(string: s) { return d }
        return nil
    }
}

enum SupabaseError: Error {
    case notConfigured
}

/// 支援 Postgres 回傳數字或字串格式的價格
private struct DecimalOrDouble: Decodable, Sendable {
    let decimalValue: Decimal?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            decimalValue = Decimal(i)
        } else if let d = try? container.decode(Double.self) {
            decimalValue = Decimal(d)
        } else if let s = try? container.decode(String.self), let d = Decimal(string: s) {
            decimalValue = d
        } else {
            decimalValue = nil
        }
    }
}

private struct SupabasePriceRow: Decodable, Sendable {
    let asset_type: String
    let symbol: String
    let name: String?
    let currency: String
    let current_price: DecimalOrDouble?
    let previous_price: DecimalOrDouble?
    let current_close_date: String?
    let current_updated_at: String?
    let previous_close_date: String?
    let previous_updated_at: String?
    let current_price_source: String?
    let previous_price_source: String?
    
    nonisolated static func toAssetPriceSnapshot(_ row: SupabasePriceRow) -> AssetPriceSnapshot? {
        let price = (row.current_price?.decimalValue ?? row.previous_price?.decimalValue)
        guard let _ = price, let curr = Currency(rawValue: row.currency),
              let at = AssetType(rawValue: row.asset_type) else { return nil }
        return AssetPriceSnapshot(
            assetType: at,
            symbol: row.symbol,
            name: row.name,
            currency: curr,
            currentPrice: row.current_price?.decimalValue,
            previousPrice: row.previous_price?.decimalValue,
            currentCloseDate: SupabaseRESTTimestampParser.parseCloseDate(row.current_close_date),
            currentUpdatedAt: SupabaseRESTTimestampParser.parse(row.current_updated_at),
            previousCloseDate: SupabaseRESTTimestampParser.parseCloseDate(row.previous_close_date),
            previousUpdatedAt: SupabaseRESTTimestampParser.parse(row.previous_updated_at),
            currentPriceSource: row.current_price_source,
            previousPriceSource: row.previous_price_source
        )
    }
}
