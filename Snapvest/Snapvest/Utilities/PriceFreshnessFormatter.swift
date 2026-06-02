//
//  PriceFreshnessFormatter.swift
//  Snapvest
//

import Foundation

enum PriceFreshnessFormatter {
    /// DB 寫入時間（`current_updated_at`）：1 小時內「N 分鐘前」，否則台北時間。
    static func dataTimestampLabel(updatedAt: Date?) -> String? {
        guard let updatedAt else { return nil }
        return DataFreshnessFormatter.label(for: updatedAt)
    }

    static func annotation(
        for snapshot: AssetPriceSnapshot,
        marketStatus: MarketStatusSnapshot?
    ) -> (chip: MarketSessionDisplay.SessionChip?, timestamp: String?) {
        guard snapshot.hasValidPrice else { return (nil, nil) }
        let chip = MarketSessionDisplay.sessionChip(
            assetType: snapshot.assetType,
            marketStatus: marketStatus
        )
        let timestamp = dataTimestampLabel(updatedAt: snapshot.currentUpdatedAt)
        return (chip, timestamp)
    }
}
