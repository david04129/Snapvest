//
//  PriceFreshnessLabel.swift
//  Snapvest
//

import SwiftUI

struct PriceSessionChip: View {
    let chip: MarketSessionDisplay.SessionChip
    var tint: Color = .appPrimary

    var body: some View {
        Text(chip.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PriceFreshnessAnnotationView: View {
    let chip: MarketSessionDisplay.SessionChip?
    let timestamp: String?
    var chipTint: Color = .appPrimary

    var body: some View {
        HStack(spacing: 8) {
            if let chip {
                PriceSessionChip(chip: chip, tint: chipTint)
            }
            if let timestamp, !timestamp.isEmpty {
                Text(timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 舊版純文字（保留給尚未改為 Chip 的呼叫點）
struct PriceFreshnessLabel: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
    }
}
