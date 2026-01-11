//
//  CardView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

/// iOS 風格的卡片組件
struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var backgroundColor: Color? = nil
    var borderColor: Color? = nil
    
    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding(padding)
        .background(backgroundColor ?? Color.cardBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            Group {
                if let borderColor = borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 5,
            x: 0,
            y: 2
        )
    }
}

/// 帶標題的卡片
struct TitledCardView<Content: View>: View {
    let title: String
    let content: Content
    var titleFont: Font = .headline
    var backgroundColor: Color? = nil
    var borderColor: Color? = nil
    
    init(
        title: String,
        titleFont: Font = .headline,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleFont = titleFont
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        CardView(backgroundColor: backgroundColor, borderColor: borderColor) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(.primaryText)
                
                content
            }
        }
    }
}

/// 統計卡片（用於顯示數字和標籤）
struct StatCardView: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color = .primaryText
    var icon: String? = nil
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CardView {
            Text("基本卡片")
        }
        
        TitledCardView(title: "標題卡片") {
            Text("內容")
        }
        
        StatCardView(
            title: "總資產",
            value: "NT$1,000,000",
            subtitle: "較上月 +5%",
            valueColor: .appPrimary
        )
    }
    .padding()
}

