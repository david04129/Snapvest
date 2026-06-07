//
//  SymbolCatalogMarket.swift
//  Snapvest
//
//  選股 catalog OTA：台／美／加密分開版本。
//

import Foundation

enum SymbolCatalogMarket: String, CaseIterable, Codable, Sendable {
    case tw
    case us
    case crypto

    nonisolated var fileName: String { "symbols_\(rawValue)" }

    nonisolated init?(tradeMarket: TradeMarket) {
        switch tradeMarket {
        case .stockTW: self = .tw
        case .stockUS: self = .us
        case .crypto: self = .crypto
        }
    }
}

struct SymbolCatalogVersion: Equatable, Codable, Sendable {
    let epoch: Int
    let minor: Int

    nonisolated static let zero = SymbolCatalogVersion(epoch: 1, minor: 0)

    nonisolated var label: String { "\(epoch).\(minor)" }

    nonisolated func isNewer(than other: SymbolCatalogVersion) -> Bool {
        epoch > other.epoch || (epoch == other.epoch && minor > other.minor)
    }

    nonisolated func isSameEpochAndNewerMinor(than other: SymbolCatalogVersion) -> Bool {
        epoch == other.epoch && minor > other.minor
    }
}

struct SymbolCatalogPatchEntry: Codable, Sendable {
    let symbol: String
    let name: String?
    let coingeckoId: String?
}

struct SymbolCatalogRemoteRow: Decodable, Sendable {
    let market: String
    let epoch: Int
    let minor: Int
    let cumulativeAdds: [SymbolCatalogPatchEntry]?
    let cumulativeRemoves: [SymbolCatalogPatchEntry]?

    enum CodingKeys: String, CodingKey {
        case market, epoch, minor
        case cumulativeAdds = "cumulative_adds"
        case cumulativeRemoves = "cumulative_removes"
    }
}

struct SymbolCatalogManifestEntry: Decodable, Sendable {
    let epoch: Int
    let minor: Int
    let updatedAt: String?
}
