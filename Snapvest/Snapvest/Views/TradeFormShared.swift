//
//  TradeFormShared.swift
//  Snapvest
//
//  新增／編輯交易表單共用 UI
//

import SwiftUI

// MARK: - 精簡標題列

struct TradeFormCompactHeader: View {
    let market: TradeMarket
    let actionTitle: String
    var isEditMode: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: market.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(market.themeColor)
                .frame(width: 32, height: 32)
                .background(market.themeColor.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditMode ? "編輯\(actionTitle)" : actionTitle)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text(market.title)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - 即時金額摘要

struct TradeFormAmountSummary: View {
    let label: String
    let amountText: String
    var detailText: String? = nil
    var footnote: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
            
            Text(amountText)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
                .contentTransition(.numericText())
            
            if let detailText, !detailText.isEmpty {
                Text(detailText)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondaryBackground)
        .cornerRadius(10)
        .animation(ChartMotion.switchSpring, value: amountText)
    }
}

// MARK: - 靠左對齊的日期選擇

struct TradeFormDatePicker: View {
    @Binding var date: Date
    var maximumDate: Date = Date()
    
    var body: some View {
        HStack(spacing: 0) {
            DatePicker(
                "",
                selection: $date,
                in: ...maximumDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 更多選項區塊

struct TradeFormMoreOptionsSection<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(ChartMotion.switchSpring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("更多選項")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content
            }
        }
    }
}
