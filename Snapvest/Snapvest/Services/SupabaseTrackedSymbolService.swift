//
//  SupabaseTrackedSymbolService.swift
//  Snapvest
//
//  匿名加入全站 tracked_symbols 大池子，不提交 user_id、數量、成本或帳戶資訊。
//

import Foundation

enum SupabaseTrackedSymbolError: LocalizedError {
    case notConfigured
    case invalidResponse(Int, String)
    case rateLimited(retryAfterSeconds: Int?)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未設定"
        case .invalidResponse(let statusCode, let body):
            return "追蹤標的失敗（HTTP \(statusCode)）：\(body)"
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds, retryAfterSeconds > 0 {
                return "追蹤標的忙碌，請 \(retryAfterSeconds) 秒後再試"
            }
            return "追蹤標的忙碌，請稍後再試"
        }
    }
}

private struct TrackSymbolRequest: Encodable {
    let assetType: String
    let symbol: String
}

private struct TrackSymbolsBatchBody: Encodable {
    let symbols: [TrackSymbolRequest]
}

enum SupabaseTrackedSymbolService {
    static let maxBatchSymbols = 100

    static func track(_ symbolInfo: SymbolInfo) async throws {
        try await trackBatch([symbolInfo])
    }

    static func trackBatch(_ symbols: [SymbolInfo]) async throws {
        guard SupabaseConfig.isConfigured,
              !symbols.isEmpty,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/track-symbols-batch") else {
            throw SupabaseTrackedSymbolError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        await SupabaseConfig.applyRequestAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TrackSymbolsBatchBody(
                symbols: symbols.map {
                    TrackSymbolRequest(assetType: $0.assetType.rawValue, symbol: $0.symbol)
                }
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseTrackedSymbolError.invalidResponse(-1, "")
        }
        if http.statusCode == 429 {
            throw SupabaseTrackedSymbolError.rateLimited(
                retryAfterSeconds: SupabaseHTTPRetryAfter.parse(data: data, response: http)
            )
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseTrackedSymbolError.invalidResponse(http.statusCode, String(body.prefix(300)))
        }
    }
}

enum SupabaseHTTPRetryAfter {
    static func parse(data: Data, response: HTTPURLResponse) -> Int? {
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
