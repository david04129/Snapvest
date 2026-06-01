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
        if let parsed = withFraction.date(from: string) ?? withoutFraction.date(from: string) {
            return parsed
        }

        let taipeiLocal = DateFormatter()
        taipeiLocal.locale = Locale(identifier: "en_US_POSIX")
        taipeiLocal.timeZone = TimeZone(identifier: "Asia/Taipei")
        taipeiLocal.dateFormat = string.contains("T") ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd HH:mm:ss"
        return taipeiLocal.date(from: String(string.prefix(19)))
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

    nonisolated static func closeDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
    
    /// Edge Function 可用的 Bearer token。Publishable key 不是 JWT，不能放進 Authorization。
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

struct SupabasePriceBatch {
    let dateKeys: [String]
    let dates: [Date]
    let historicalPricesByKeyAndDate: [String: [String: Decimal]]
    let currentSnapshots: [AssetPriceSnapshot]
    let twdRateByCurrency: [Currency: Decimal]
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

    static func batchKey(assetType: AssetType, symbol: String) -> String {
        "\(assetType.rawValue):\(normalizeSymbol(assetType: assetType, symbol: symbol))"
    }

    static func fetchBatchPrices(
        symbols: [SymbolInfo],
        historyStartDate: Date? = nil,
        historyEndDate: Date? = nil,
        includeCurrent: Bool = true
    ) async throws -> SupabasePriceBatch {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/fetch-prices-batch") else {
            throw SupabaseError.notConfigured
        }

        struct BatchSymbol: Encodable {
            let assetType: String
            let symbol: String
        }

        struct BatchHistory: Encodable {
            let startDate: String
            let endDate: String
        }

        struct BatchBody: Encodable {
            let symbols: [BatchSymbol]
            let history: BatchHistory?
            let includeCurrent: Bool
        }

        var seenKeys = Set<String>()
        let normalizedSymbols = symbols.compactMap { info -> BatchSymbol? in
            let normalized = normalizeSymbol(assetType: info.assetType, symbol: info.symbol)
            let key = "\(info.assetType.rawValue):\(normalized)"
            guard !seenKeys.contains(key) else { return nil }
            seenKeys.insert(key)
            return BatchSymbol(assetType: info.assetType.rawValue, symbol: normalized)
        }
        guard !normalizedSymbols.isEmpty else {
            return SupabasePriceBatch(
                dateKeys: [],
                dates: [],
                historicalPricesByKeyAndDate: [:],
                currentSnapshots: [],
                twdRateByCurrency: [.TWD: 1]
            )
        }

        let history: BatchHistory?
        if let historyStartDate, let historyEndDate {
            history = BatchHistory(
                startDate: SupabaseRESTTimestampParser.closeDateString(from: historyStartDate),
                endDate: SupabaseRESTTimestampParser.closeDateString(from: historyEndDate)
            )
        } else {
            history = nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        SupabaseConfig.applyEdgeFunctionAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            BatchBody(
                symbols: normalizedSymbols,
                history: history,
                includeCurrent: includeCurrent
            )
        )

        #if DEBUG
        let historyDescription = history.map { "\($0.startDate)...\($0.endDate)" } ?? "none"
        print("[SupabasePriceService] batch request symbols=\(normalizedSymbols.count), includeCurrent=\(includeCurrent), history=\(historyDescription)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            #if DEBUG
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[SupabasePriceService] batch request failed HTTP \(statusCode): \(body.prefix(300))")
            #endif
            throw SupabaseError.requestFailed
        }

        let decoded = try JSONDecoder().decode(SupabasePriceBatchResponse.self, from: data)
        let dateKeys = decoded.dates
        let dates = dateKeys.compactMap { SupabaseRESTTimestampParser.parseCloseDate($0) }

        var historyByKeyAndDate: [String: [String: Decimal]] = [:]
        for (key, values) in decoded.history {
            var byDate: [String: Decimal] = [:]
            for (index, value) in values.enumerated() where index < dateKeys.count {
                if let price = value.decimalValue {
                    byDate[dateKeys[index]] = price
                }
            }
            historyByKeyAndDate[key] = byDate
        }

        var currentSnapshots: [AssetPriceSnapshot] = []
        for symbol in normalizedSymbols {
            let key = "\(symbol.assetType):\(symbol.symbol)"
            guard let assetType = AssetType(rawValue: symbol.assetType) else { continue }
            let currency = decoded.currencies[key].flatMap(Currency.init(rawValue:))
                ?? assetType.quoteCurrency
            let currentPrice = decoded.current[key]?.decimalValue
            let previousPrice = decoded.previous[key]?.decimalValue
            guard currentPrice != nil || previousPrice != nil else { continue }
            currentSnapshots.append(
                AssetPriceSnapshot(
                    assetType: assetType,
                    symbol: symbol.symbol,
                    currency: currency,
                    currentPrice: currentPrice,
                    previousPrice: previousPrice,
                    currentCloseDate: SupabaseRESTTimestampParser.parseCloseDate(decoded.currentDates[key]?.stringValue),
                    currentUpdatedAt: SupabaseRESTTimestampParser.parse(decoded.currentUpdatedAt[key]?.stringValue),
                    previousCloseDate: SupabaseRESTTimestampParser.parseCloseDate(decoded.previousDates[key]?.stringValue),
                    priceKind: decoded.priceKind[key]?.stringValue.flatMap(AssetPriceKind.init(rawValue:))
                )
            )
        }

        var twdRates: [Currency: Decimal] = [.TWD: 1]
        for (pair, value) in decoded.fx {
            let parts = pair.split(separator: ":")
            guard parts.count == 2,
                  String(parts[1]) == "TWD",
                  let currency = Currency(rawValue: String(parts[0])),
                  let rate = value.decimalValue,
                  rate > 0 else {
                continue
            }
            twdRates[currency] = rate
        }
        if let usdToTwd = twdRates[.USD] {
            ExchangeRateSessionCache.update(usdToTwd: usdToTwd)
        }

        #if DEBUG
        print("[SupabasePriceService] batch response current=\(currentSnapshots.count)/\(normalizedSymbols.count), dates=\(dateKeys.count), fx=\(twdRates.keys.map(\.rawValue).sorted())")
        #endif

        return SupabasePriceBatch(
            dateKeys: dateKeys,
            dates: dates,
            historicalPricesByKeyAndDate: historyByKeyAndDate,
            currentSnapshots: currentSnapshots,
            twdRateByCurrency: twdRates
        )
    }
    
    /// 批量取得目前價；優先走 Edge Function 單筆請求，失敗時保留舊 REST fallback。
    static func fetchPrices(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }

        do {
            let batch = try await fetchBatchPrices(symbols: symbols, includeCurrent: true)
            if !batch.currentSnapshots.isEmpty {
                #if DEBUG
                print("[SupabasePriceService] fetchPrices using batch snapshots=\(batch.currentSnapshots.count)/\(symbols.count)")
                #endif
                return batch.currentSnapshots
            }
            #if DEBUG
            print("[SupabasePriceService] fetchPrices batch returned no snapshots; falling back to per-symbol REST")
            #endif
        } catch {
            #if DEBUG
            print("[SupabasePriceService] fetchPrices batch failed; falling back to per-symbol REST: \(error)")
            #endif
        }
        
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

    static func fetchHistoricalPrice(assetType: AssetType, symbol: String, date: Date) async throws -> Price? {
        let prices = try await fetchHistoricalPrices(assetType: assetType, symbol: symbol, startDate: date, endDate: date)
        return prices.first
    }

    static func fetchHistoricalPrices(assetType: AssetType, symbol: String, startDate: Date, endDate: Date) async throws -> [Price] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { throw SupabaseError.notConfigured }

        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        let startDay = SupabaseRESTTimestampParser.closeDateString(from: startDate)
        let endDay = SupabaseRESTTimestampParser.closeDateString(from: endDate)
        guard let encodedSymbol = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/rest/v1/asset_price_history?asset_type=eq.\(assetType.rawValue)&symbol=eq.\(encodedSymbol)&price_date=gte.\(startDay)&price_date=lte.\(endDay)&select=*&order=price_date.asc") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        let rows = try JSONDecoder().decode([SupabasePriceHistoryRow].self, from: data)
        return rows.compactMap { SupabasePriceHistoryRow.toPrice($0) }
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
    case requestFailed
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
    let price_kind: String?
    
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
            previousPriceSource: row.previous_price_source,
            priceKind: row.price_kind.flatMap(AssetPriceKind.init(rawValue:))
        )
    }
}

private struct SupabasePriceHistoryRow: Decodable, Sendable {
    let asset_type: String
    let symbol: String
    let price_date: String
    let close_price: DecimalOrDouble
    let currency: String
    let source: String?
    let updated_at: String?

    nonisolated static func toPrice(_ row: SupabasePriceHistoryRow) -> Price? {
        guard let assetType = AssetType(rawValue: row.asset_type),
              let currency = Currency(rawValue: row.currency),
              let closePrice = row.close_price.decimalValue else {
            return nil
        }

        return Price(
            assetType: assetType,
            symbol: row.symbol,
            price: closePrice,
            currency: currency,
            priceDate: SupabaseRESTTimestampParser.parseCloseDate(row.price_date) ?? Date(),
            source: row.source,
            createdAt: SupabaseRESTTimestampParser.parse(row.updated_at) ?? Date()
        )
    }
}

private struct SupabaseBatchDecimal: Decodable, Sendable {
    let decimalValue: Decimal?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            decimalValue = nil
        } else if let i = try? container.decode(Int.self) {
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

private struct SupabaseBatchString: Decodable, Sendable {
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            stringValue = nil
        } else {
            stringValue = try? container.decode(String.self)
        }
    }
}

private struct SupabasePriceBatchResponse: Decodable, Sendable {
    let dates: [String]
    let history: [String: [SupabaseBatchDecimal]]
    let current: [String: SupabaseBatchDecimal]
    let previous: [String: SupabaseBatchDecimal]
    let currentDates: [String: SupabaseBatchString]
    let previousDates: [String: SupabaseBatchString]
    let priceKind: [String: SupabaseBatchString]
    let currentUpdatedAt: [String: SupabaseBatchString]
    let currencies: [String: String]
    let fx: [String: SupabaseBatchDecimal]

    enum CodingKeys: String, CodingKey {
        case dates, history, current, previous, currentDates, previousDates
        case priceKind, currentUpdatedAt, currencies, fx
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dates = try container.decodeIfPresent([String].self, forKey: .dates) ?? []
        history = try container.decodeIfPresent([String: [SupabaseBatchDecimal]].self, forKey: .history) ?? [:]
        current = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .current) ?? [:]
        previous = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .previous) ?? [:]
        currentDates = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .currentDates) ?? [:]
        previousDates = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .previousDates) ?? [:]
        priceKind = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .priceKind) ?? [:]
        currentUpdatedAt = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .currentUpdatedAt) ?? [:]
        currencies = try container.decodeIfPresent([String: String].self, forKey: .currencies) ?? [:]
        fx = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .fx) ?? [:]
    }
}
