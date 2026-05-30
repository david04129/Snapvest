//
//  CurrencyCodeChip.swift
//  Snapvest
//
//  Compact currency label used beside converted amounts.
//

import SwiftUI

struct CurrencyCodeChip: View {
    let currency: Currency
    var tint: Color = .appPrimary
    var style: Style = .subtle
    @Environment(\.colorScheme) private var colorScheme
    
    enum Style {
        case subtle
        case filled
    }
    
    var body: some View {
        Text(currency.rawValue)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityLabel(Text(currency.settingsDisplayName))
    }
    
    private var foregroundColor: Color {
        switch style {
        case .subtle:
            return colorScheme == .dark
                ? Color.white.opacity(0.82)
                : Color.primaryText.opacity(0.72)
        case .filled:
            return colorScheme == .dark
                ? Color.white.opacity(0.92)
                : Color.primaryText.opacity(0.84)
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .subtle:
            return colorScheme == .dark
                ? Color.white.opacity(0.10)
                : Color.primaryText.opacity(0.06)
        case .filled:
            return colorScheme == .dark
                ? Color.white.opacity(0.16)
                : Color.primaryText.opacity(0.10)
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .subtle:
            return colorScheme == .dark
                ? Color.white.opacity(0.18)
                : Color.primaryText.opacity(0.12)
        case .filled:
            return colorScheme == .dark
                ? Color.white.opacity(0.24)
                : Color.primaryText.opacity(0.16)
        }
    }
}

struct CurrencyIconBadge: View {
    let currency: Currency
    var tint: Color = .appPrimary
    var showsLabel: Bool = false

    var body: some View {
        HStack(spacing: showsLabel ? 8 : 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.22),
                                tint.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.42), lineWidth: 1)
                    }

                Text(currency.rawValue)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 3)
            }

            if showsLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text("帳戶幣別")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondaryText)
                    Text(currency.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primaryText)
                }
            }
        }
        .accessibilityLabel(Text("帳戶幣別 \(currency.settingsDisplayName)"))
    }
}

struct CurrencyAmountLabel: View {
    let text: String
    let currency: Currency
    var font: Font = .subheadline
    var weight: Font.Weight = .semibold
    var color: Color = .primaryText
    var chipTint: Color = .appPrimary
    var alignment: VerticalAlignment = .firstTextBaseline
    
    private var displayText: String {
        var result = text
        let symbols = [currency.symbol, "$", "NT$", "A$", "HK$", "€", "¥"]
        for symbol in symbols where !symbol.isEmpty {
            result = result.replacingOccurrences(of: symbol, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        Text(displayText)
            .font(font)
            .fontWeight(weight)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}

struct CurrencyTitleLabel: View {
    let title: String
    let currency: Currency
    var font: Font = .subheadline
    var weight: Font.Weight = .medium
    var color: Color = .secondaryText
    var chipTint: Color = .appPrimary
    var titleLineLimit: Int = 2
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(color)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            CurrencyCodeChip(currency: currency, tint: chipTint)
        }
    }
}
