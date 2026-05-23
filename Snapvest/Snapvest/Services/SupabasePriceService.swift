//
//  SupabasePriceService.swift
//  Snapvest
//
//  從 Supabase 讀取股價（需先設定 SupabaseConfig）
//

import Foundation

/// Supabase 連線設定（請在 App 啟動時設定）
enum SupabaseConfig: Sendable {
    nonisolated(unsafe) static var url: String?
    nonisolated(unsafe) static var anonKey: String?
    
    static var isConfigured: Bool {
        url != nil && !(url ?? "").isEmpty && anonKey != nil && !(anonKey ?? "").isEmpty
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
            guard let last = decoded.first?["last_updated_at"],
                  let date = ISO8601DateFormatter().date(from: last) else { return nil }
            return date
        } catch {
            return nil
        }
    }
    
    /// 比對是否需要拉取（後端較新才拉）
    static func shouldFetchPrices() async -> Bool {
        let local = UserDefaults.standard.object(forKey: lastFetchedAtKey) as? Date ?? .distantPast
        guard let remote = await fetchLastUpdatedAt() else { return false }
        return remote > local
    }
    
    /// 批量取得股價（並行請求）
    static func fetchPrices(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }
        
        let rows = await withTaskGroup(of: SupabasePriceRow?.self) { group in
            for s in symbols {
                group.addTask {
                    guard let encoded = s.symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                          let url = URL(string: "\(baseUrl)/rest/v1/asset_price_snapshots?asset_type=eq.\(s.assetType.rawValue)&symbol=eq.\(encoded)&select=*") else { return nil }
                    var req = URLRequest(url: url)
                    req.setValue(key, forHTTPHeaderField: "apikey")
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    guard let (data, _) = try? await URLSession.shared.data(for: req),
                          let decoded = try? JSONDecoder().decode([SupabasePriceRow].self, from: data),
                          let row = decoded.first else { return nil }
                    return row
                }
            }
            var out: [SupabasePriceRow] = []
            for await row in group {
                if let r = row { out.append(r) }
            }
            return out
        }
        let results = rows.compactMap { SupabasePriceRow.toAssetPriceSnapshot($0) }
        
        UserDefaults.standard.set(Date(), forKey: lastFetchedAtKey)
        return results
    }
    
    /// 單檔取得股價
    static func fetchSingle(assetType: AssetType, symbol: String) async throws -> Decimal? {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(SupabaseConfig.url!)/rest/v1/asset_price_snapshots?asset_type=eq.\(assetType.rawValue)&symbol=eq.\(encoded)&select=current_price,previous_price"),
              let key = SupabaseConfig.anonKey else { return nil }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: req)
        let rows = try JSONDecoder().decode([SupabasePriceRow].self, from: data)
        let price = rows.first?.current_price?.decimalValue ?? rows.first?.previous_price?.decimalValue
        return price
    }

    /// 呼叫 fetch-or-create-price（新增股票時使用）
    static func fetchOrCreatePrice(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String? = nil
    ) async throws -> Decimal? {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/fetch-or-create-price"),
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["assetType": assetType.rawValue, "symbol": symbol])
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let price = json?["price"] as? Double else { return nil }
        return Decimal(price)
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
        if let d = try? container.decode(Double.self) {
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
    let current_price_date: String?
    let previous_price_date: String?
    let last_updated: String
    let last_successful_update: String?
    
    nonisolated static func toAssetPriceSnapshot(_ row: SupabasePriceRow) -> AssetPriceSnapshot? {
        let price = (row.current_price?.decimalValue ?? row.previous_price?.decimalValue)
        guard let _ = price, let curr = Currency(rawValue: row.currency),
              let at = AssetType(rawValue: row.asset_type) else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime]
        fmt.timeZone = TimeZone(identifier: "UTC")
        return AssetPriceSnapshot(
            assetType: at,
            symbol: row.symbol,
            name: row.name,
            currency: curr,
            currentPrice: row.current_price?.decimalValue,
            previousPrice: row.previous_price?.decimalValue,
            currentPriceDate: row.current_price_date.flatMap { fmt.date(from: $0) },
            previousPriceDate: row.previous_price_date.flatMap { fmt.date(from: $0) },
            lastUpdated: fmt.date(from: row.last_updated) ?? Date(),
            lastSuccessfulUpdate: row.last_successful_update.flatMap { fmt.date(from: $0) }
        )
    }
}
