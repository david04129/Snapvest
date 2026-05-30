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

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未設定"
        case .invalidResponse(let statusCode, let body):
            return "追蹤標的失敗（HTTP \(statusCode)）：\(body)"
        }
    }
}

private struct TrackSymbolRequest: Encodable {
    let assetType: String
    let symbol: String
}

enum SupabaseTrackedSymbolService {
    static func track(_ symbolInfo: SymbolInfo) async throws {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/track-symbol") else {
            throw SupabaseTrackedSymbolError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        SupabaseConfig.applyEdgeFunctionAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TrackSymbolRequest(
                assetType: symbolInfo.assetType.rawValue,
                symbol: symbolInfo.symbol
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseTrackedSymbolError.invalidResponse(statusCode, String(body.prefix(300)))
        }
    }
}
