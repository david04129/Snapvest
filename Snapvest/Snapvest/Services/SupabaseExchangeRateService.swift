//
//  SupabaseExchangeRateService.swift
//  Snapvest
//
//  從 Supabase exchange_rates 讀取匯率
//

import Foundation

struct ExchangeRateQuote: Sendable {
    let rate: Decimal
    let updatedAt: Date?
}

private struct SupabaseExchangeRateRow: Decodable {
    let from_currency: String
    let to_currency: String
    let rate: Decimal?
    let updated_at: String?
    let previous_rate: Decimal?
    let previous_updated_at: String?

    enum CodingKeys: String, CodingKey {
        case from_currency, to_currency, rate, updated_at
        case previous_rate, previous_updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from_currency = try container.decode(String.self, forKey: .from_currency)
        to_currency = try container.decode(String.self, forKey: .to_currency)
        rate = Self.decodePositiveDecimal(container, forKey: .rate)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        previous_rate = Self.decodePositiveDecimal(container, forKey: .previous_rate)
        previous_updated_at = try container.decodeIfPresent(String.self, forKey: .previous_updated_at)
    }

    /// 本輪 rate 優先；無效時用 previous_rate（排程本輪抓失敗時仍可用上一輪）
    var displayRate: Decimal? {
        if let rate, rate > 0 { return rate }
        if let previous_rate, previous_rate > 0 { return previous_rate }
        return nil
    }

    var displayUpdatedAt: Date? {
        if rate != nil, (rate ?? 0) > 0 {
            return SupabaseRESTTimestampParser.parse(updated_at)
        }
        return SupabaseRESTTimestampParser.parse(previous_updated_at)
            ?? SupabaseRESTTimestampParser.parse(updated_at)
    }

    private static func decodePositiveDecimal(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Decimal? {
        if let text = try? container.decode(String.self, forKey: key),
           let parsed = Decimal(string: text), parsed > 0 {
            return parsed
        }
        if let number = try? container.decode(Double.self, forKey: key), number > 0 {
            return Decimal(number)
        }
        return nil
    }
}

enum SupabaseExchangeRateService {
    static func fetchRate(from: Currency, to: Currency) async -> Decimal? {
        await fetchQuote(from: from, to: to)?.rate
    }

    static func fetchQuote(from: Currency, to: Currency) async -> ExchangeRateQuote? {
        guard from != to else { return ExchangeRateQuote(rate: 1, updatedAt: nil) }
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url else { return nil }

        if let direct = await fetchDirectQuote(baseUrl: baseUrl, from: from, to: to) {
            return direct
        }

        // FinMind 牌告：DB 存 1 外幣 = rate TWD
        if to == .TWD, let foreignToTwd = await fetchDirectQuote(baseUrl: baseUrl, from: from, to: .TWD) {
            return foreignToTwd
        }
        if from == .TWD, let foreignToTwd = await fetchDirectQuote(baseUrl: baseUrl, from: to, to: .TWD),
           foreignToTwd.rate > 0 {
            return ExchangeRateQuote(rate: 1 / foreignToTwd.rate, updatedAt: foreignToTwd.updatedAt)
        }

        // 交叉匯率：A→B = (A→TWD) / (B→TWD)
        if let aToTwd = await fetchDirectQuote(baseUrl: baseUrl, from: from, to: .TWD),
           let bToTwd = await fetchDirectQuote(baseUrl: baseUrl, from: to, to: .TWD),
           bToTwd.rate > 0 {
            return ExchangeRateQuote(
                rate: aToTwd.rate / bToTwd.rate,
                updatedAt: maxDate(aToTwd.updatedAt, bToTwd.updatedAt)
            )
        }

        return nil
    }

    private static func maxDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case (let x?, nil): return x
        case (nil, let y?): return y
        default: return nil
        }
    }

    private static func fetchDirectQuote(
        baseUrl: String,
        from: Currency,
        to: Currency
    ) async -> ExchangeRateQuote? {
        var components = URLComponents(string: "\(baseUrl)/rest/v1/exchange_rates")!
        components.queryItems = [
            URLQueryItem(name: "from_currency", value: "eq.\(from.rawValue)"),
            URLQueryItem(name: "to_currency", value: "eq.\(to.rawValue)"),
            URLQueryItem(
                name: "select",
                value: "from_currency,to_currency,rate,updated_at,previous_rate,previous_updated_at"
            ),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        await SupabaseConfig.applyRequestAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let rows = try JSONDecoder().decode([SupabaseExchangeRateRow].self, from: data)
            guard let row = rows.first, let rate = row.displayRate, rate > 0 else {
                return nil
            }
            return ExchangeRateQuote(rate: rate, updatedAt: row.displayUpdatedAt)
        } catch {
            return nil
        }
    }
}
