//
//  MetricTile.swift
//  Snapvest
//
//  帳戶詳情、個股詳情等共用的指標格
//

import SwiftUI

enum MetricTileProminence {
    case standard
    case featured
}

enum MetricTileFootnotePlacement {
    case below
    case trailingChip
}

struct MetricTile: View {
    let title: String
    let value: String
    var currency: Currency? = nil
    var titleCurrency: Currency? = nil
    var showsValueCurrencyChip: Bool = true
    var valueColor: Color = .primaryText
    var footnote: String? = nil
    var footnoteColor: Color = .secondaryText
    var titleLineLimit: Int = 2
    var reservesFootnoteSpace: Bool = true
    var prominence: MetricTileProminence = .standard
    var accentColor: Color? = nil
    var footnotePlacement: MetricTileFootnotePlacement = .below
    var compact: Bool = false
    var titleCurrencyCanToggle: Bool = false
    var titleCurrencyToggleAction: (() -> Void)? = nil
    
    private var isFeatured: Bool { prominence == .featured }
    
    private var valueFont: Font {
        isFeatured ? .snapAmountSecondary : .snapAmountTile
    }
    
    private var tileMinHeight: CGFloat {
        if compact {
            return isFeatured ? 78 : 74
        }
        if isFeatured, footnotePlacement == .trailingChip {
            return 78
        }
        return isFeatured ? 96 : 88
    }
    
    private var tilePadding: CGFloat {
        if compact {
            return isFeatured ? 14 : 10
        }
        if isFeatured, footnotePlacement == .trailingChip {
            return 14
        }
        return isFeatured ? 16 : 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: footnotePlacement == .trailingChip ? 7 : (isFeatured ? 10 : 8)) {
            titleRow
            
            valueRow
            
            if footnotePlacement == .below, let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(isFeatured ? .subheadline : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(footnoteColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if footnotePlacement == .below, reservesFootnoteSpace {
                Text(" ")
                    .font(.caption)
                    .opacity(0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: tileMinHeight, alignment: .leading)
        .padding(tilePadding)
        .background(Color.cardBackground)
        .cornerRadius(isFeatured ? 16 : 12)
        .overlay(alignment: .leading) {
            if isFeatured, let accentColor {
                RoundedRectangle(cornerRadius: isFeatured ? 16 : 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: isFeatured ? 16 : 12)
                .stroke(Color.separator.opacity(isFeatured ? 0.45 : 0.35), lineWidth: 1)
        )
        .shadow(color: isFeatured ? AppColors.shadowMedium : .clear, radius: isFeatured ? 6 : 0, x: 0, y: isFeatured ? 2 : 0)
    }
    
    @ViewBuilder
    private var titleRow: some View {
        if let titleCurrency {
            CurrencyToggleTitleLabel(
                title: title,
                currency: titleCurrency,
                font: .subheadline,
                weight: .medium,
                color: .secondaryText,
                chipTint: accentColor ?? .appPrimary,
                titleLineLimit: titleLineLimit,
                canToggle: titleCurrencyCanToggle,
                action: { titleCurrencyToggleAction?() }
            )
        } else {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            valueContent
                .layoutPriority(1)
            
            if footnotePlacement == .trailingChip,
               let footnote,
               !footnote.isEmpty {
                Text(footnote)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(footnoteColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(footnoteColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var valueContent: some View {
        if let currency {
            CurrencyAmountWithChip(
                text: value,
                currency: currency,
                font: valueFont,
                weight: .bold,
                color: valueColor,
                chipTint: accentColor ?? .appPrimary,
                showsChip: showsValueCurrencyChip
            )
        } else {
            Text(value)
                .font(valueFont)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
