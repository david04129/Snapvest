//
//  SupabasePortfolioStateService.swift
//  Snapvest
//
//  將投資組合狀態 upsert 至 Supabase user_portfolio_state
//

import Foundation

enum SupabasePortfolioStateError: LocalizedError {
    case notConfigured
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase 未設定"
        case .invalidResponse: return "同步投資組合狀態失敗"
        }
    }
}

private struct SupabasePortfolioStateRow: Encodable {
    let user_id: String
    let synced_at: String
    let cash: [PortfolioCashItem]
    let holdings: [PortfolioHoldingItem]
    let liabilities: [PortfolioLiabilityItem]
}

enum SupabasePortfolioStateService {
    static func sync(_ payload: PortfolioStateSyncPayload) async throws {
        guard SupabaseConfig.isConfigured,
              let baseUrl = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(baseUrl)/rest/v1/user_portfolio_state?on_conflict=user_id") else {
            throw SupabasePortfolioStateError.notConfigured
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let row = SupabasePortfolioStateRow(
            user_id: payload.userId,
            synced_at: formatter.string(from: payload.syncedAt),
            cash: payload.cash,
            holdings: payload.holdings,
            liabilities: payload.liabilities
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(row)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabasePortfolioStateError.invalidResponse
        }
    }
}
