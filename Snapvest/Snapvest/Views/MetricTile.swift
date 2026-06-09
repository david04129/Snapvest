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
    var valueColor: Color = .primaryText
    var footnote: String? = nil
    var footnoteColor: Color = .secondaryText
    var titleLineLimit: Int = 2
    var reservesFootnoteSpace: Bool = true
    var prominence: MetricTileProminence = .standard
    var accentColor: Color? = nil
    var footnotePlacement: MetricTileFootnotePlacement = .below
    
    private var isFeatured: Bool { prominence == .featured }
    
    private var valueFont: Font {
        isFeatured ? .snapAmountSecondary : .snapAmountTile
    }
    
    private var tileMinHeight: CGFloat {
        if isFeatured, footnotePlacement == .trailingChip {
            return 78
        }
        return isFeatured ? 96 : 88
    }
    
    private var tilePadding: CGFloat {
        if isFeatured, footnotePlacement == .trailingChip {
            return 14
        }
        return isFeatured ? 16 : 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: footnotePlacement == .trailingChip ? 7 : (isFeatured ? 10 : 8)) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            
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
                chipTint: accentColor ?? .appPrimary
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
