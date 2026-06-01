//
//  PriceFreshnessLabel.swift
//  Snapvest
//

import SwiftUI

extension MarketSessionDisplay.SessionChip {
    /// 盤中：紅色；收盤：暗灰（與類股色無關）
    var chipForegroundColor: Color {
        switch self {
        case .intraday:
            return Color.lossRed
        case .close:
            return Color.secondaryText
        }
    }

    var chipBackgroundColor: Color {
        switch self {
        case .intraday:
            return Color.lossRed.opacity(0.12)
        case .close:
            return Color.secondaryText.opacity(0.14)
        }
    }
}

struct PriceSessionChip: View {
    let chip: MarketSessionDisplay.SessionChip

    var body: some View {
        Text(chip.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundColor(chip.chipForegroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chip.chipBackgroundColor)
            .clipShape(Capsule())
    }
}

struct PriceFreshnessAnnotationView: View {
    let chip: MarketSessionDisplay.SessionChip?
    let timestamp: String?

    var body: some View {
        HStack(spacing: 8) {
            if let chip {
                PriceSessionChip(chip: chip)
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
