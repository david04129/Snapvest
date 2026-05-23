//
//  AccentBarCard.swift
//  Snapvest
//
//  左色條卡片（方向 A，與帳戶／交易列同款）
//

import SwiftUI

struct AccentBarCard<Content: View>: View {
    var title: String? = nil
    let accentColor: Color
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(cornerRadius)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

#Preview {
    AccentBarCard(title: "淨資產", accentColor: .appPrimary) {
        Text("NT$1,000,000")
            .font(.snapAmountHero)
            .foregroundColor(.primaryText)
    }
    .padding()
}
