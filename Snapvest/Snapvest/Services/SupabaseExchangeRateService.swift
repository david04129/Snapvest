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

    enum CodingKeys: String, CodingKey {
        case from_currency, to_currency, rate, updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from_currency = try container.decode(String.self, forKey: .from_currency)
        to_currency = try container.decode(String.self, forKey: .to_currency)
        if let text = try? container.decode(String.self, forKey: .rate),
           let parsed = Decimal(string: text), parsed > 0 {
            rate = parsed
        } else if let number = try? container.decode(Double.self, forKey: .rate), number > 0 {
            rate = Decimal(number)
        } else {
            rate = nil
        }
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
}

private enum ExchangeRateRESTTimestampParser {
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
}

enum SupabaseExchangeRateService {
    static func fetchRate(from: Currency, to: Currency) async -> Decimal? {
        await fetchQuote(from: from, to: to)?.rate
    }

    static func fetchQuote(from: Currency, to: Currency) async -> ExchangeRateQuote? {
        guard from != to else { return ExchangeRateQuote(rate: 1, updatedAt: nil) }
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { return nil }

        if let direct = await fetchDirectQuote(baseUrl: baseUrl, key: key, from: from, to: to) {
            return direct
        }

        if from == .USD, to == .TWD {
            return await fetchDirectQuote(baseUrl: baseUrl, key: key, from: .USD, to: .TWD)
        }
        if from == .TWD, to == .USD {
            guard let usdToTwd = await fetchDirectQuote(baseUrl: baseUrl, key: key, from: .USD, to: .TWD),
                  usdToTwd.rate > 0 else { return nil }
            return ExchangeRateQuote(rate: 1 / usdToTwd.rate, updatedAt: usdToTwd.updatedAt)
        }

        return nil
    }

    private static func fetchDirectQuote(
        baseUrl: String,
        key: String,
        from: Currency,
        to: Currency
    ) async -> ExchangeRateQuote? {
        var components = URLComponents(string: "\(baseUrl)/rest/v1/exchange_rates")!
        components.queryItems = [
            URLQueryItem(name: "from_currency", value: "eq.\(from.rawValue)"),
            URLQueryItem(name: "to_currency", value: "eq.\(to.rawValue)"),
            URLQueryItem(name: "select", value: "from_currency,to_currency,rate,updated_at"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let rows = try JSONDecoder().decode([SupabaseExchangeRateRow].self, from: data)
            guard let row = rows.first, let rate = row.rate, rate > 0 else {
                return nil
            }
            return ExchangeRateQuote(
                rate: rate,
                updatedAt: ExchangeRateRESTTimestampParser.parse(row.updated_at)
            )
        } catch {
            return nil
        }
    }
}
