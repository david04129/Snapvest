//
//  SupabaseDailySnapshotService.swift
//  Snapvest
//
//  從 Supabase user_daily_snapshots 讀取走勢圖資料
//

import Foundation

enum SupabaseDailySnapshotError: LocalizedError {
    case notConfigured
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未設定"
        case .invalidResponse: return "讀取每日快照失敗"
        }
    }
}

private struct SupabaseDailySnapshotRow: Decodable {
    let user_id: String
    let snapshot_date: String
    let total_assets: Decimal?
    let total_liabilities: Decimal?
    let net_worth: Decimal?
    let unrealized_gain_loss: Decimal?

    enum CodingKeys: String, CodingKey {
        case user_id, snapshot_date, total_assets, total_liabilities, net_worth, unrealized_gain_loss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(String.self, forKey: .user_id)
        snapshot_date = try container.decode(String.self, forKey: .snapshot_date)
        total_assets = Self.decodeDecimal(from: container, forKey: .total_assets)
        total_liabilities = Self.decodeDecimal(from: container, forKey: .total_liabilities)
        net_worth = Self.decodeDecimal(from: container, forKey: .net_worth)
        unrealized_gain_loss = Self.decodeDecimal(from: container, forKey: .unrealized_gain_loss)
    }

    private static func decodeDecimal(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Decimal? {
        if let text = try? container.decode(String.self, forKey: key),
           let parsed = Decimal(string: text) {
            return parsed
        }
        if let number = try? container.decode(Double.self, forKey: key) {
            return Decimal(number)
        }
        return nil
    }
}

enum SupabaseDailySnapshotService {
    static func fetchTrendPoints(
        userId: String,
        startDate: Date?,
        endDate: Date?
    ) async throws -> [TrendChartPoint] {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey else {
            throw SupabaseDailySnapshotError.notConfigured
        }
        
        var components = URLComponents(string: "\(baseUrl)/rest/v1/user_daily_snapshots")!
        var queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "user_id,snapshot_date,total_assets,net_worth,unrealized_gain_loss"),
            URLQueryItem(name: "order", value: "snapshot_date.asc"),
        ]
        
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"
        
        if let startDate {
            queryItems.append(URLQueryItem(name: "snapshot_date", value: "gte.\(dayFormatter.string(from: startDate))"))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SupabaseDailySnapshotError.notConfigured
        }
        
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseDailySnapshotError.invalidResponse
        }
        
        let rows = try JSONDecoder().decode([SupabaseDailySnapshotRow].self, from: data)
        let calendar = Calendar.current
        
        return rows.compactMap { row in
            guard let date = dayFormatter.date(from: row.snapshot_date) else { return nil }
            let normalizedDate = calendar.startOfDay(for: date)
            if let endDate, normalizedDate > calendar.startOfDay(for: endDate) {
                return nil
            }
            return TrendChartPoint(
                id: row.snapshot_date,
                date: normalizedDate,
                totalAssets: row.total_assets ?? 0,
                netWorth: row.net_worth ?? 0,
                unrealizedGainLoss: row.unrealized_gain_loss ?? 0
            )
        }
    }
}
