//
//  TradeFormShared.swift
//  Snapvest
//
//  新增／編輯交易表單共用 UI
//

import SwiftUI

// MARK: - 單價輸入（幣別標示）

enum TradeFormUnitPriceLabels {
    static func rowTitle(market: TradeMarket, isSell: Bool) -> String {
        let verb = isSell ? "賣價" : "買價"
        switch market {
        case .stockTW:
            return "每股\(verb)（台幣）"
        case .stockUS:
            return "每股\(verb)（美金）"
        case .crypto:
            return "每單位\(verb)（美金）"
        }
    }
}

enum TradeFormMoneyLabels {
    static func balanceRowTitle(currency: Currency) -> String {
        switch currency {
        case .TWD:
            return "新餘額（台幣）"
        case .USD:
            return "新餘額（美金）"
        default:
            return "新餘額（\(currency.rawValue)）"
        }
    }
}

struct TradeFormCurrencyBadge: View {
    let currency: Currency
    
    private var code: String {
        switch currency {
        case .TWD: return "TWD"
        case .USD: return "USD"
        default: return currency.rawValue
        }
    }
    
    var body: some View {
        Text(code)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.tertiaryBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.separator.opacity(0.45), lineWidth: 1)
            )
    }
}

struct TradeFormUnitPriceInput: View {
    @Binding var priceText: String
    let currency: Currency
    
    var body: some View {
        HStack(spacing: 8) {
            TradeFormCurrencyBadge(currency: currency)
            TextField("0", text: $priceText)
                .keyboardType(.decimalPad)
                .snapFormFieldTapTarget()
        }
        .snapFormFieldTapTarget()
    }
}

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
        SnapTappableDateField(
            date: $date,
            sheetTitle: "交易日期",
            maximumDate: maximumDate,
            showsLeadingIcon: false
        )
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
