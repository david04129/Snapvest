//
//  MetricTile.swift
//  Snapvest
//
//  帳戶詳情、個股詳情等共用的指標格
//

import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    var valueColor: Color = .primaryText
    var footnote: String? = nil
    var footnoteColor: Color = .secondaryText
    var titleLineLimit: Int = 2
    var reservesFootnoteSpace: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(value)
                .font(.snapAmountTile)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(footnoteColor)
                    .lineLimit(1)
            } else if reservesFootnoteSpace {
                Text(" ")
                    .font(.caption)
                    .opacity(0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.separator.opacity(0.35), lineWidth: 1)
        )
    }
}
