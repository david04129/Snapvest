//
//  MarketStatusService.swift
//  Snapvest
//

import Foundation

struct MarketSessionStatus: Sendable, Equatable {
    let isTradingDay: Bool
    let isRegularSession: Bool
    let isIntradayActive: Bool
    let session: String
    let reason: String?
}

struct MarketStatusSnapshot: Sendable, Equatable {
    let asOf: Date?
    let tw: MarketSessionStatus
    let us: MarketSessionStatus
    let crypto: MarketSessionStatus
    let fetchedAt: Date
}

enum MarketStatusService {
    private static let cacheTTL: TimeInterval = 10 * 60
    private static var cached: MarketStatusSnapshot?
    
    static func fetchIfNeeded(force: Bool = false) async -> MarketStatusSnapshot? {
        guard SupabaseConfig.isConfigured,
              let url = URL(string: "\(SupabaseConfig.url!)/functions/v1/market-status") else {
            return nil
        }
        if !force, let cached, Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await SupabaseConfig.applyRequestAuth(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return cached
            }
            let decoded = try JSONDecoder().decode(MarketStatusResponse.self, from: data)
            let snapshot = decoded.snapshot(fetchedAt: Date())
            cached = snapshot
            return snapshot
        } catch {
            return cached
        }
    }
    
    static func invalidateCache() {
        cached = nil
    }
}

private struct MarketStatusResponse: Decodable {
    let asOf: String?
    let markets: MarketsPayload?
    
    struct MarketsPayload: Decodable {
        let tw: MarketPayload?
        let us: MarketPayload?
        let crypto: MarketPayload?
    }
    
    struct MarketPayload: Decodable {
        let isTradingDay: Bool?
        let isRegularSession: Bool?
        let isIntradayActive: Bool?
        let session: String?
        let reason: String?
    }
    
    func snapshot(fetchedAt: Date) -> MarketStatusSnapshot {
        let asOfDate = asOf.flatMap { ISO8601DateFormatter.snapvestFlexible.date(from: $0) }
        return MarketStatusSnapshot(
            asOf: asOfDate,
            tw: map(markets?.tw),
            us: map(markets?.us),
            crypto: map(markets?.crypto),
            fetchedAt: fetchedAt
        )
    }
    
    private func map(_ p: MarketPayload?) -> MarketSessionStatus {
        MarketSessionStatus(
            isTradingDay: p?.isTradingDay ?? true,
            isRegularSession: p?.isRegularSession ?? false,
            isIntradayActive: p?.isIntradayActive ?? false,
            session: p?.session ?? "closed",
            reason: p?.reason
        )
    }
}

private extension ISO8601DateFormatter {
    static let snapvestFlexible: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return f
    }()
}
