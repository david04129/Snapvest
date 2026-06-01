//
//  UsdTwdRateCaptionView.swift
//  Snapvest
//
//  USD/TWD 顯示匯率（與 Phase 5 footer 同款 caption 風格）。
//

import SwiftUI

struct UsdTwdRateCaptionView: View {
    var preferredRate: Decimal?
    var displayCurrency: Currency = .TWD
    var twdPerDisplayCurrency: Decimal = 1
    var alignment: HorizontalAlignment = .leading
    
    private var resolvedUsdToTwdRate: Decimal {
        if let preferredRate, preferredRate > 0 { return preferredRate }
        if let cached = ExchangeRateSessionCache.usdToTwd, cached > 0 { return cached }
        return 0
    }

    private var displayRate: Decimal {
        if displayCurrency == .USD { return 1 }
        guard resolvedUsdToTwdRate > 0 else { return 0 }
        if displayCurrency == .TWD { return resolvedUsdToTwdRate }
        guard twdPerDisplayCurrency > 0 else { return 0 }
        return resolvedUsdToTwdRate / twdPerDisplayCurrency
    }
    
    private var resolvedUpdatedAt: Date? {
        ExchangeRateSessionCache.usdToTwdUpdatedAt
    }
    
    var body: some View {
        if displayRate > 0 {
            HStack(spacing: 6) {
                Text("1 USD = \(displayRate.formattedExchangeRateDisplay()) \(displayCurrency.rawValue)")
                if let resolvedUpdatedAt {
                    Text("·")
                    Text("資料 \(DataFreshnessFormatter.label(for: resolvedUpdatedAt))")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }
    
    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center: return .center
        default: return .leading
        }
    }
}
