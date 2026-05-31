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
    
    private var isFeatured: Bool { prominence == .featured }
    
    private var valueFont: Font {
        isFeatured ? .snapAmountSecondary : .snapAmountTile
    }
    
    private var tileMinHeight: CGFloat {
        isFeatured ? 96 : 88
    }
    
    private var tilePadding: CGFloat {
        isFeatured ? 16 : 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isFeatured ? 10 : 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            
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
            
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(isFeatured ? .subheadline : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(footnoteColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if reservesFootnoteSpace {
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
}
