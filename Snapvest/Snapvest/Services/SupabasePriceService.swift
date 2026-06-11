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
    /// REST / Edge Function 的 apikey（publishable `sb_publishable__…` 或 legacy anon JWT）
    nonisolated(unsafe) static var anonKey: String?
    /// 選填：legacy anon JWT（`eyJ…`），供 Edge Function 的 Authorization header
    nonisolated(unsafe) static var anonJwt: String?
    
    nonisolated static var isConfigured: Bool {
        url != nil && !(url ?? "").isEmpty && anonKey != nil && !(anonKey ?? "").isEmpty
    }
    
    /// Edge Function 可用的 Bearer token。Publishable key 不是 JWT，不能放進 Authorization。
    nonisolated static var edgeFunctionAuthorizationToken: String? {
        if let jwt = anonJwt?.trimmingCharacters(in: .whitespacesAndNewlines), jwt.hasPrefix("eyJ") {
            return jwt
        }
        if let key = anonKey?.trimmingCharacters(in: .whitespacesAndNewlines), key.hasPrefix("eyJ") {
            return key
        }
        return nil
    }
    
    nonisolated static func applyEdgeFunctionAuth(to request: inout URLRequest) {
        guard let apikey = anonKey else { return }
        request.setValue(apikey, forHTTPHeaderField: "apikey")
        if let token = edgeFunctionAuthorizationToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Phase A：優先帶 Anonymous Auth 使用者 JWT；Demo／未登入時 fallback legacy anon JWT。
    nonisolated static func applyRequestAuth(to request: inout URLRequest) async {
        guard let apikey = anonKey else { return }
        request.setValue(apikey, forHTTPHeaderField: "apikey")
        if let userToken = await SupabaseAuthService.shared.bearerAccessToken() {
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        } else if let token = edgeFunctionAuthorizationToken {
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
    let usdToTwdUpdatedAt: Date?
}

/// fetch-or-create-price 完整報價（現價 + 可選昨收）
struct FetchOrCreateQuote: Sendable {
    let currentPrice: Decimal
    let currency: Currency
    let source: String?
    let currentCloseDate: Date?
    let previousPrice: Decimal?
    let previousCloseDate: Date?
}

/// 從 Supabase 讀取股價與更新時間
struct SupabasePriceService {
    
    private static let lastFetchedAtKey = "com.snapvest.priceLastFetchedAt"
    /// 與 `fetch-prices-batch` Edge Function `maxSymbols` 對齊
    static let maxBatchSymbols = 100
    /// 缺價補齊時並行呼叫 `fetch-or-create-price` 上限
    static let fetchOrCreateConcurrency = 5
    
    /// 取得後端價格最後更新時間
    static func fetchLastUpdatedAt() async -> Date? {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/rest/v1/price_update_metadata?id=eq.global&select=last_updated_at") else { return nil }
        
        var req = URLRequest(url: url)
        await SupabaseConfig.applyRequestAuth(to: &req)
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
    
    /// 買進表單 prefetch：DB 無列時呼叫 fetch-or-create 寫入雲端，再寫本機 AssetPriceSnapshot。
    static func prefetchAssetPriceSnapshot(
        assetType: AssetType,
        symbol: String,
        dataService: DataServiceProtocol,
        coingeckoId: String? = nil
    ) async -> AssetPriceSnapshot? {
        guard SupabaseConfig.isConfigured else { return nil }

        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        guard !normalized.isEmpty else { return nil }

        let symbolInfo = SymbolInfo(assetType: assetType, symbol: normalized)
        let existing = try? await dataService.fetchAssetPriceSnapshot(
            assetType: assetType,
            symbol: normalized
        )

        let remote = await fetchRemoteSnapshotRow(symbolInfo: symbolInfo)
        let remoteHasFreshCurrent = remote.map {
            hasPositiveCurrentPrice($0) && !AssetPriceSnapshotFreshness.isStaleForLiveQuote($0)
        } ?? false

        // 本機已有完整報價且 DB 現價仍新鮮 → 直接沿用
        if remoteHasFreshCurrent,
           let existing,
           let current = existing.currentPrice,
           current > 0,
           DailyReferenceCloseResolver.trustedSnapshotReference(from: existing) != nil,
           !AssetPriceSnapshotFreshness.isStaleForLiveQuote(existing) {
            return existing
        }

        var working: AssetPriceSnapshot?

        if !remoteHasFreshCurrent {
            guard let quote = try? await fetchOrCreateQuote(
                assetType: assetType,
                symbol: normalized,
                coingeckoId: coingeckoId
            ) else {
                #if DEBUG
                if hasPositiveCurrentPrice(remote) {
                    print("[SupabasePriceService] prefetch \(normalized): stale DB row, fetch-or-create refresh failed")
                } else {
                    print("[SupabasePriceService] prefetch \(normalized): fetch-or-create failed (DB had no current)")
                }
                #endif
                return nil
            }
            #if DEBUG
            if hasPositiveCurrentPrice(remote),
               let remote,
               AssetPriceSnapshotFreshness.isStaleForLiveQuote(remote) {
                print("[SupabasePriceService] prefetch \(normalized): refreshed stale DB closeDate=\(remote.currentCloseDate.map { TradingDayCalendar.dateKey(for: $0, assetType: assetType) } ?? "?")")
            } else {
                print("[SupabasePriceService] prefetch \(normalized): fetch-or-create wrote DB source=\(quote.source ?? "?")")
            }
            #endif
            working = PriceSnapshotMerger.mergePreservingDailyReference(
                incoming: snapshot(from: quote, assetType: assetType, symbol: normalized),
                existing: existing
            )
        } else if let remote {
            working = PriceSnapshotMerger.mergePreservingDailyReference(
                incoming: remote.strippingUntrustedRemotePrevious(),
                existing: existing
            )
        }

        guard var merged = working,
              let current = merged.currentPrice ?? merged.displayPrice,
              current > 0 else {
            return nil
        }

        if DailyReferenceCloseResolver.trustedSnapshotReference(from: merged) == nil {
            // DB 有 current 但缺昨收：再呼叫 fetch-or-create 觸發 Edge 補 history
            if remoteHasFreshCurrent {
                _ = try? await fetchOrCreateQuote(
                    assetType: assetType,
                    symbol: normalized,
                    coingeckoId: coingeckoId
                )
            }
            let anchorDate = merged.currentCloseDate ?? Date()
            if let historyRef = await fetchPreviousSessionCloseFromHistory(
                assetType: assetType,
                symbol: normalized,
                anchorDate: anchorDate
            ) {
                merged = AssetPriceSnapshot(
                    assetType: merged.assetType,
                    symbol: merged.symbol,
                    name: merged.name,
                    currency: merged.currency,
                    currentPrice: merged.currentPrice,
                    previousPrice: historyRef.price,
                    currentCloseDate: merged.currentCloseDate,
                    currentUpdatedAt: merged.currentUpdatedAt,
                    previousCloseDate: historyRef.closeDate,
                    previousUpdatedAt: Date(),
                    currentPriceSource: merged.currentPriceSource,
                    previousPriceSource: DailyReferenceCloseResolver.historyPreviousCloseSource,
                    priceKind: merged.priceKind
                )
            } else if let quote = try? await fetchOrCreateQuote(
                assetType: assetType,
                symbol: normalized,
                coingeckoId: coingeckoId
            ), quote.previousPrice != nil {
                merged = PriceSnapshotMerger.mergePreservingDailyReference(
                    incoming: snapshot(from: quote, assetType: assetType, symbol: normalized),
                    existing: merged
                )
            }
        }

        let final = PriceSnapshotMerger.mergePreservingDailyReference(
            incoming: merged,
            existing: existing
        )
        try? await dataService.saveAssetPriceSnapshot(final)
        return final
    }

    private static func hasPositiveCurrentPrice(_ snapshot: AssetPriceSnapshot?) -> Bool {
        guard let snapshot else { return false }
        guard let price = snapshot.currentPrice ?? snapshot.displayPrice else { return false }
        return price > 0
    }
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
    /// 與 DB / Edge Function 一致的代號格式（台股字母商品、美股、加密皆大寫）
    static func normalizeSymbol(assetType: AssetType, symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        switch assetType {
        case .stockTW, .stockUS, .crypto:
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
                twdRateByCurrency: [.TWD: 1],
                usdToTwdUpdatedAt: nil
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
        await SupabaseConfig.applyRequestAuth(to: &request)
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
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw SupabaseError.rateLimited(retryAfterSeconds: Self.parseRetryAfterSeconds(data: data, response: http))
        }
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
                AssetPriceSnapshot.fromRemote(
                    assetType: assetType,
                    symbol: symbol.symbol,
                    currency: currency,
                    currentPrice: currentPrice,
                    previousPrice: previousPrice,
                    currentCloseDate: SupabaseRESTTimestampParser.parseCloseDate(decoded.currentDates[key]?.stringValue),
                    currentUpdatedAt: SupabaseRESTTimestampParser.parse(decoded.currentUpdatedAt[key]?.stringValue),
                    previousCloseDate: SupabaseRESTTimestampParser.parseCloseDate(decoded.previousDates[key]?.stringValue),
                    previousUpdatedAt: nil,
                    currentPriceSource: nil,
                    previousPriceSource: decoded.previousSources[key]?.stringValue,
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
            ExchangeRateSessionCache.update(
                usdToTwd: usdToTwd,
                updatedAt: decoded.fxUpdatedAt["USD:TWD"]?.stringValue.flatMap(SupabaseRESTTimestampParser.parse)
            )
        }

        #if DEBUG
        print("[SupabasePriceService] batch response current=\(currentSnapshots.count)/\(normalizedSymbols.count), dates=\(dateKeys.count), fx=\(twdRates.keys.map(\.rawValue).sorted())")
        #endif

        return SupabasePriceBatch(
            dateKeys: dateKeys,
            dates: dates,
            historicalPricesByKeyAndDate: historyByKeyAndDate,
            currentSnapshots: currentSnapshots,
            twdRateByCurrency: twdRates,
            usdToTwdUpdatedAt: decoded.fxUpdatedAt["USD:TWD"]?.stringValue.flatMap(SupabaseRESTTimestampParser.parse)
        )
    }
    
    /// 去重後的 symbol 列表（與 batch / REST key 一致）
    static func deduplicatedSymbolInfos(_ symbols: [SymbolInfo]) -> [SymbolInfo] {
        var seen = Set<String>()
        var result: [SymbolInfo] = []
        for symbol in symbols {
            let normalized = normalizeSymbol(assetType: symbol.assetType, symbol: symbol.symbol)
            let key = batchKey(assetType: symbol.assetType, symbol: normalized)
            guard seen.insert(key).inserted else { continue }
            result.append(SymbolInfo(assetType: symbol.assetType, symbol: normalized))
        }
        return result
    }

    private static func snapshotStorageKey(assetType: AssetType, symbol: String) -> String {
        "\(assetType.rawValue)_\(normalizeSymbol(assetType: assetType, symbol: symbol))"
    }

    private static func hasPositiveDisplayPrice(_ snapshot: AssetPriceSnapshot?) -> Bool {
        guard let price = snapshot?.displayPrice else { return false }
        return price > 0
    }

    private static func symbolChunks(_ symbols: [SymbolInfo], size: Int) -> [[SymbolInfo]] {
        guard size > 0, !symbols.isEmpty else { return symbols.isEmpty ? [] : [symbols] }
        var chunks: [[SymbolInfo]] = []
        var index = 0
        while index < symbols.count {
            let end = min(index + size, symbols.count)
            chunks.append(Array(symbols[index..<end]))
            index = end
        }
        return chunks
    }

    private static func mergeBatchFX(_ batch: SupabasePriceBatch) {
        if let usdToTwd = batch.twdRateByCurrency[.USD] {
            ExchangeRateSessionCache.update(usdToTwd: usdToTwd, updatedAt: batch.usdToTwdUpdatedAt)
        }
    }

    private static func mergeSnapshots(
        into mergedByKey: inout [String: AssetPriceSnapshot],
        snapshots: [AssetPriceSnapshot]
    ) {
        for snapshot in snapshots {
            let key = snapshotStorageKey(assetType: snapshot.assetType, symbol: snapshot.symbol)
            if let existing = mergedByKey[key] {
                mergedByKey[key] = PriceSnapshotMerger.mergePreservingDailyReference(
                    incoming: snapshot,
                    existing: existing
                )
            } else {
                mergedByKey[key] = snapshot.strippingUntrustedRemotePrevious()
            }
        }
    }

    /// 批量取得目前價；依 chunk 呼叫 Edge batch，僅對仍缺價的 symbol REST fallback。
    static func fetchPrices(symbols: [SymbolInfo]) async throws -> [AssetPriceSnapshot] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url else { throw SupabaseError.notConfigured }

        let unique = deduplicatedSymbolInfos(symbols)
        guard !unique.isEmpty else { return [] }

        var mergedByKey: [String: AssetPriceSnapshot] = [:]
        var chunksNeedingREST: [[SymbolInfo]] = []

        for chunk in symbolChunks(unique, size: maxBatchSymbols) {
            do {
                let batch = try await fetchBatchPrices(symbols: chunk, includeCurrent: true)
                mergeBatchFX(batch)
                mergeSnapshots(into: &mergedByKey, snapshots: batch.currentSnapshots)
                let missingInChunk = chunk.filter { info in
                    !hasPositiveDisplayPrice(mergedByKey[snapshotStorageKey(assetType: info.assetType, symbol: info.symbol)])
                }
                if !missingInChunk.isEmpty {
                    chunksNeedingREST.append(missingInChunk)
                }
                #if DEBUG
                print("[SupabasePriceService] fetchPrices chunk batch snapshots=\(batch.currentSnapshots.count)/\(chunk.count)")
                #endif
            } catch {
                #if DEBUG
                print("[SupabasePriceService] fetchPrices chunk batch failed; will REST fallback chunk: \(error)")
                #endif
                chunksNeedingREST.append(chunk)
            }
        }

        let restTargets = deduplicatedSymbolInfos(chunksNeedingREST.flatMap { $0 })
        if !restTargets.isEmpty {
            let rows = await withTaskGroup(of: SupabasePriceRow?.self) { group in
                for symbolInfo in restTargets {
                    group.addTask {
                        await fetchPriceRow(baseUrl: baseUrl, symbolInfo: symbolInfo)
                    }
                }
                var out: [SupabasePriceRow] = []
                for await row in group {
                    if let row { out.append(row) }
                }
                return out
            }
            let restSnapshots = rows.compactMap { SupabasePriceRow.toAssetPriceSnapshot($0) }
            mergeSnapshots(into: &mergedByKey, snapshots: restSnapshots)
            #if DEBUG
            print("[SupabasePriceService] fetchPrices REST fallback snapshots=\(restSnapshots.count)/\(restTargets.count)")
            #endif
        }

        let results = unique.compactMap { info in
            mergedByKey[snapshotStorageKey(assetType: info.assetType, symbol: info.symbol)]
        }

        #if DEBUG
        if !unique.isEmpty, results.isEmpty {
            print("[SupabasePriceService] fetchPrices returned 0/\(unique.count) symbols")
        }
        #endif

        return results
    }

    /// 對仍無有效報價的標的，有限並行呼叫 `fetch-or-create-price` 並組成 snapshot。
    static func resolveMissingPrices(symbols: [SymbolInfo]) async -> [AssetPriceSnapshot] {
        let targets = deduplicatedSymbolInfos(symbols)
        guard SupabaseConfig.isConfigured, !targets.isEmpty else { return [] }

        var created: [AssetPriceSnapshot] = []
        for chunk in symbolChunks(targets, size: fetchOrCreateConcurrency) {
            await withTaskGroup(of: AssetPriceSnapshot?.self) { group in
                for symbolInfo in chunk {
                    group.addTask {
                        await createSnapshotViaFetchOrCreate(symbolInfo: symbolInfo)
                    }
                }
                for await snapshot in group {
                    if let snapshot {
                        created.append(snapshot)
                    }
                }
            }
        }
        return created
    }

    private static func createSnapshotViaFetchOrCreate(symbolInfo: SymbolInfo) async -> AssetPriceSnapshot? {
        for attempt in 0..<2 {
            switch await createSnapshotViaFetchOrCreateAttempt(symbolInfo: symbolInfo) {
            case .success(let snapshot):
                return snapshot
            case .rateLimited(let retryAfterSeconds):
                guard attempt == 0 else { return nil }
                let delaySeconds = max(retryAfterSeconds ?? 5, 1)
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            case .failed:
                return nil
            }
        }
        return nil
    }

    private enum FetchOrCreateAttemptResult {
        case success(AssetPriceSnapshot)
        case rateLimited(retryAfterSeconds: Int?)
        case failed
    }

    private static func createSnapshotViaFetchOrCreateAttempt(symbolInfo: SymbolInfo) async -> FetchOrCreateAttemptResult {
        let coingeckoId = symbolInfo.assetType == .crypto
            ? SymbolListService.coingeckoId(forCryptoSymbol: symbolInfo.symbol)
            : nil
        do {
            guard let quote = try await fetchOrCreateQuote(
                assetType: symbolInfo.assetType,
                symbol: symbolInfo.symbol,
                coingeckoId: coingeckoId
            ), quote.currentPrice > 0 else {
                return .failed
            }
            return .success(
                snapshot(
                    from: quote,
                    assetType: symbolInfo.assetType,
                    symbol: symbolInfo.symbol
                )
            )
        } catch SupabaseError.rateLimited(let retryAfterSeconds) {
            return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        } catch {
            return .failed
        }
    }
    
    private static func fetchPriceRow(baseUrl: String, symbolInfo: SymbolInfo) async -> SupabasePriceRow? {
        let querySymbol = normalizeSymbol(assetType: symbolInfo.assetType, symbol: symbolInfo.symbol)
        guard let encoded = querySymbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/rest/v1/asset_price_snapshots?asset_type=eq.\(symbolInfo.assetType.rawValue)&symbol=eq.\(encoded)&select=*") else {
            return nil
        }
        var req = URLRequest(url: url)
        await SupabaseConfig.applyRequestAuth(to: &req)
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
              let baseUrl = SupabaseConfig.url else { throw SupabaseError.notConfigured }
        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        let row = await fetchPriceRow(
            baseUrl: baseUrl,
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
              let baseUrl = SupabaseConfig.url else { throw SupabaseError.notConfigured }

        let normalized = normalizeSymbol(assetType: assetType, symbol: symbol)
        let startDay = SupabaseRESTTimestampParser.closeDateString(from: startDate)
        let endDay = SupabaseRESTTimestampParser.closeDateString(from: endDate)
        guard let encodedSymbol = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/rest/v1/asset_price_history?asset_type=eq.\(assetType.rawValue)&symbol=eq.\(encodedSymbol)&price_date=gte.\(startDay)&price_date=lte.\(endDay)&select=*&order=price_date.asc") else {
            return []
        }

        var request = URLRequest(url: url)
        await SupabaseConfig.applyRequestAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        let rows = try JSONDecoder().decode([SupabasePriceHistoryRow].self, from: data)
        return rows.compactMap { SupabasePriceHistoryRow.toPrice($0) }
    }

    private static func snapshot(
        from quote: FetchOrCreateQuote,
        assetType: AssetType,
        symbol: String
    ) -> AssetPriceSnapshot {
        let now = Date()
        let previousSource = trustedPreviousPriceSource(for: quote)
        return AssetPriceSnapshot(
            assetType: assetType,
            symbol: symbol,
            currency: quote.currency,
            currentPrice: quote.currentPrice,
            previousPrice: quote.previousPrice,
            currentCloseDate: quote.currentCloseDate ?? Calendar.current.startOfDay(for: now),
            currentUpdatedAt: now,
            previousCloseDate: quote.previousCloseDate,
            previousUpdatedAt: quote.previousPrice != nil ? now : nil,
            currentPriceSource: quote.source,
            previousPriceSource: previousSource,
            priceKind: .intraday
        )
    }

    private static func trustedPreviousPriceSource(for quote: FetchOrCreateQuote) -> String? {
        guard quote.previousPrice != nil else { return nil }
        if DailyReferenceCloseResolver.isBootstrapPreviousSource(quote.source) {
            return quote.source
        }
        // Edge DB hit 可能剛從 Yahoo / snapshot 補寫 history 昨收
        return "yahoo"
    }

    static func fetchPreviousSessionCloseFromHistory(
        assetType: AssetType,
        symbol: String,
        anchorDate: Date
    ) async -> DailyReferenceCloseResolver.ReferenceClose? {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: anchorDate)
        guard let start = calendar.date(byAdding: .day, value: -14, to: end) else { return nil }

        let prices = (try? await fetchHistoricalPrices(
            assetType: assetType,
            symbol: symbol,
            startDate: start,
            endDate: end
        )) ?? []
        guard !prices.isEmpty else { return nil }

        var exactHistoryByDate: [String: Decimal] = [:]
        var historyDateKeys: [String] = []
        for price in prices {
            let key = TradingDayCalendar.dateKey(for: price.priceDate, assetType: assetType)
            exactHistoryByDate[key] = price.price
            historyDateKeys.append(key)
        }
        historyDateKeys.sort()

        let anchorKey = TradingDayCalendar.dateKey(for: anchorDate, assetType: assetType)
        return DailyReferenceCloseResolver.resolveFromHistory(
            assetType: assetType,
            exactHistoryByDate: exactHistoryByDate,
            historyDateKeys: historyDateKeys,
            beforeAnchorKey: anchorKey
        )
    }

    static func fetchRemoteSnapshotRow(symbolInfo: SymbolInfo) async -> AssetPriceSnapshot? {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url else { return nil }
        guard let row = await fetchPriceRow(baseUrl: baseUrl, symbolInfo: symbolInfo) else { return nil }
        return SupabasePriceRow.toAssetPriceSnapshot(row)?.strippingUntrustedRemotePrevious()
    }

    /// 呼叫 fetch-or-create-price（新增股票時使用）
    static func fetchOrCreateQuote(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String? = nil
    ) async throws -> FetchOrCreateQuote? {
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
        await SupabaseConfig.applyRequestAuth(to: &req)
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
        if http.statusCode == 429 {
            throw SupabaseError.rateLimited(retryAfterSeconds: parseRetryAfterSeconds(data: data, response: http))
        }
        guard http.statusCode == 200 else {
            #if DEBUG
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[SupabasePriceService] fetch-or-create-price HTTP \(http.statusCode) for \(symbol): \(body.prefix(300))")
            #endif
            return nil
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let currentPrice = parseJSONPrice(json?["price"]), currentPrice > 0 else { return nil }

        let currencyRaw = json?["currency"] as? String
        let currency = currencyRaw.flatMap(Currency.init(rawValue:)) ?? assetType.quoteCurrency
        let source = json?["source"] as? String
        let currentCloseDate = SupabaseRESTTimestampParser.parseCloseDate(json?["currentCloseDate"] as? String)
        let previousPrice = parseJSONPrice(json?["previousPrice"])
        let previousCloseDate = SupabaseRESTTimestampParser.parseCloseDate(json?["previousCloseDate"] as? String)

        return FetchOrCreateQuote(
            currentPrice: currentPrice,
            currency: currency,
            source: source,
            currentCloseDate: currentCloseDate,
            previousPrice: previousPrice,
            previousCloseDate: previousCloseDate
        )
    }

    /// 呼叫 fetch-or-create-price（新增股票時使用）
    static func fetchOrCreatePrice(
        assetType: AssetType,
        symbol: String,
        coingeckoId: String? = nil
    ) async throws -> Decimal? {
        let quote = try await fetchOrCreateQuote(
            assetType: assetType,
            symbol: symbol,
            coingeckoId: coingeckoId
        )
        return quote?.currentPrice
    }
    
    private static func parseJSONPrice(_ value: Any?) -> Decimal? {
        if let d = value as? Double { return Decimal(d) }
        if let i = value as? Int { return Decimal(i) }
        if let n = value as? NSNumber { return Decimal(string: n.stringValue) }
        if let s = value as? String, let d = Decimal(string: s) { return d }
        return nil
    }

    private static func parseRetryAfterSeconds(data: Data, response: HTTPURLResponse) -> Int? {
        if let header = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
           let seconds = Int(header) {
            return seconds
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let seconds = json["retryAfterSeconds"] as? Int {
                return seconds
            }
            if let seconds = json["retry_after_seconds"] as? Int {
                return seconds
            }
        }
        return nil
    }
}

enum SupabaseError: LocalizedError {
    case notConfigured
    case requestFailed
    case rateLimited(retryAfterSeconds: Int?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 未設定"
        case .requestFailed:
            return "雲端請求失敗"
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds, retryAfterSeconds > 0 {
                return "雲端忙碌，請 \(retryAfterSeconds) 秒後再試"
            }
            return "雲端忙碌，請稍後再試"
        }
    }
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
        return AssetPriceSnapshot.fromRemote(
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
    let previousSources: [String: SupabaseBatchString]
    let priceKind: [String: SupabaseBatchString]
    let currentUpdatedAt: [String: SupabaseBatchString]
    let currencies: [String: String]
    let fx: [String: SupabaseBatchDecimal]
    let fxUpdatedAt: [String: SupabaseBatchString]

    enum CodingKeys: String, CodingKey {
        case dates, history, current, previous, currentDates, previousDates
        case previousSources, priceKind, currentUpdatedAt, currencies, fx, fxUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dates = try container.decodeIfPresent([String].self, forKey: .dates) ?? []
        history = try container.decodeIfPresent([String: [SupabaseBatchDecimal]].self, forKey: .history) ?? [:]
        current = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .current) ?? [:]
        previous = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .previous) ?? [:]
        currentDates = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .currentDates) ?? [:]
        previousDates = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .previousDates) ?? [:]
        previousSources = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .previousSources) ?? [:]
        priceKind = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .priceKind) ?? [:]
        currentUpdatedAt = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .currentUpdatedAt) ?? [:]
        currencies = try container.decodeIfPresent([String: String].self, forKey: .currencies) ?? [:]
        fx = try container.decodeIfPresent([String: SupabaseBatchDecimal].self, forKey: .fx) ?? [:]
        fxUpdatedAt = try container.decodeIfPresent([String: SupabaseBatchString].self, forKey: .fxUpdatedAt) ?? [:]
    }
}
