//
//  TradeFormShared.swift
//  Snapvest
//
//  新增／編輯交易表單共用 UI
//

import SwiftUI

// MARK: - 版面常數（買入／賣出／NewTradeFlow 內嵌表單一致）

enum TradeFormLayout {
    static let scrollSpacing: CGFloat = 10
    static let bottomBarSpacing: CGFloat = 8
    static let rowPadding: CGFloat = 12
    static let rowHeaderSpacing: CGFloat = 6
    static let fieldMinHeight: CGFloat = 40
    static let fieldInnerHPadding: CGFloat = 10
    static let fieldInnerVPadding: CGFloat = 8
    static let fieldCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardDividerInset: CGFloat = 14
    static let submitButtonVPadding: CGFloat = 14
    static let accountPickerSpacing: CGFloat = 6
    static let accountPickerHPadding: CGFloat = 12
    static let accountPickerVPadding: CGFloat = 10
}

// MARK: - 表單列與輸入容器

struct TradeFormRow<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var showsIcon: Bool = true
    var helpAction: (() -> Void)?
    var helpAccessibilityLabel: String = "說明"
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TradeFormLayout.rowHeaderSpacing) {
            HStack(spacing: 6) {
                if showsIcon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                if let helpAction {
                    Button(action: helpAction) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color.opacity(0.9))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(helpAccessibilityLabel)
                }
            }

            TradeFormInputContainer {
                content
            }
        }
        .padding(TradeFormLayout.rowPadding)
    }
}

struct TradeFormInputContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TradeFormLayout.fieldInnerHPadding)
            .padding(.vertical, TradeFormLayout.fieldInnerVPadding)
            .frame(minHeight: TradeFormLayout.fieldMinHeight, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: TradeFormLayout.fieldCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TradeFormLayout.fieldCornerRadius, style: .continuous)
                    .stroke(Color.separator.opacity(0.32), lineWidth: 1)
            }
    }
}

struct TradeFormCardDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, TradeFormLayout.cardDividerInset)
    }
}

struct TradeFormInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.top, 2)
    }
}

struct TradeFormReferencePriceCard: View {
    let title: String
    let priceText: String
    var tint: Color = .appPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
            Text(priceText)
                .font(.snapReferencePrice)
                .foregroundColor(.primaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1))
        .cornerRadius(TradeFormLayout.fieldCornerRadius)
        .padding(.top, 4)
    }
}

extension View {
    func tradeFormDecimalFieldStyle() -> some View {
        font(.system(size: 16, weight: .semibold))
            .monospacedDigit()
            .snapFormFieldTapTarget()
    }
}

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
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundColor(.primaryText.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.primaryText.opacity(0.06))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primaryText.opacity(0.12), lineWidth: 1)
            }
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
                .tradeFormDecimalFieldStyle()
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
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditMode ? "編輯\(actionTitle)" : actionTitle)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text(market.title)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Spacer(minLength: 0)

            Text(market.title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(market.themeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(market.themeColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

// MARK: - 即時金額摘要

struct TradeFormAmountSummary: View {
    let label: String
    let amountText: String
    var detailText: String? = nil
    var footnote: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)

            Text(amountText)
                .font(.headline.weight(.bold))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: TradeFormLayout.fieldCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TradeFormLayout.fieldCornerRadius, style: .continuous)
                .stroke(Color.separator.opacity(0.32), lineWidth: 1)
        }
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
                .padding(.horizontal, TradeFormLayout.cardDividerInset)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content
            }
        }
    }
}
