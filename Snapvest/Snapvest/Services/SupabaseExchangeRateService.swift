//
//  SupabaseExchangeRateService.swift
//  Snapvest
//
//  從 Supabase exchange_rates 讀取匯率
//

import Foundation

private struct SupabaseExchangeRateRow: Decodable {
    let from_currency: String
    let to_currency: String
    let rate: Decimal?

    enum CodingKeys: String, CodingKey {
        case from_currency, to_currency, rate
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
    }
}

enum SupabaseExchangeRateService {
    static func fetchRate(from: Currency, to: Currency) async -> Decimal? {
        guard from != to else { return 1 }
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else { return nil }

        if let direct = await fetchDirectRate(baseUrl: baseUrl, key: key, from: from, to: to) {
            return direct
        }

        // 常見路徑：USD → TWD 透過 exchange_rates 表
        if from == .USD, to == .TWD {
            return await fetchDirectRate(baseUrl: baseUrl, key: key, from: .USD, to: .TWD)
        }
        if from == .TWD, to == .USD {
            guard let usdToTwd = await fetchDirectRate(baseUrl: baseUrl, key: key, from: .USD, to: .TWD),
                  usdToTwd > 0 else { return nil }
            return 1 / usdToTwd
        }

        return nil
    }

    private static func fetchDirectRate(
        baseUrl: String,
        key: String,
        from: Currency,
        to: Currency
    ) async -> Decimal? {
        var components = URLComponents(string: "\(baseUrl)/rest/v1/exchange_rates")!
        components.queryItems = [
            URLQueryItem(name: "from_currency", value: "eq.\(from.rawValue)"),
            URLQueryItem(name: "to_currency", value: "eq.\(to.rawValue)"),
            URLQueryItem(name: "select", value: "from_currency,to_currency,rate"),
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
            guard let rate = rows.first?.rate, rate > 0 else {
                return nil
            }
            return rate
        } catch {
            return nil
        }
    }
}
