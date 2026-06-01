//
//  AssetPriceKind.swift
//  Snapvest
//

import Foundation

/// 對應 Supabase `asset_price_snapshots.price_kind`
enum AssetPriceKind: String, Codable, Sendable {
    case intraday
    case close
}
