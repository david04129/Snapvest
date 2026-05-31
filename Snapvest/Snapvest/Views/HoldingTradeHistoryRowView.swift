//
//  HoldingTradeHistoryRowView.swift
//  Snapvest
//
//  個股詳情「交易紀錄」專用列（與帳戶／紀錄分頁列分開）。
//

import SwiftUI

struct HoldingTradeHistoryRowView: View {
    let transaction: Transaction
    let aggregatedHolding: AggregatedHoldingSnapshot
    let currentPrice: Decimal?
    let onRowTap: () -> Void
    let onDelete: ((Transaction) -> Void)?

    private var display: TransactionDisplayFormatter {
        TransactionDisplayFormatter(transaction: transaction)
    }

    private var accentColor: Color {
        display.typeAccentColor
    }

    private var tradeAmount: Decimal {
        transaction.quantity * transaction.price
    }

    private var tradeAmountText: String {
        tradeAmount.formattedTradeAmount(currency: display.tradePriceCurrency)
    }

    private var quantityAtPriceText: String {
        guard let line = display.tradeDetailLine else { return "" }
        return line
    }

    var body: some View {
        Button(action: onRowTap) {
            cardContent {
                VStack(alignment: .leading, spacing: 6) {
                    primaryLine
                    secondaryLine
                    if let note = display.userNotePreview {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button {
                    onDelete(transaction)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("刪除")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(width: 70, height: 70)
                    .background(AppColors.actionDestructiveBackground)
                }
                .tint(AppColors.actionDestructiveBackground)
            }
        }
    }

    @ViewBuilder
    private func cardContent<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }

    private var primaryLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(actionLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)

            Text(transaction.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primaryText)
                .lineLimit(1)

            Text(quantityAtPriceText)
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            Text(tradeAmountText)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var secondaryLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(performanceLabel)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)

            Text(performanceValueString)
                .font(.caption.weight(.semibold))
                .foregroundColor(performanceColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }

    private var actionLabel: String {
        transaction.type == .buy ? "買入" : "賣出"
    }

    private var performanceLabel: String {
        transaction.type == .buy ? "目前損益" : "已實現損益"
    }

    private var performanceValueString: String {
        switch transaction.type {
        case .buy:
            return buyUnrealizedPerformance?.text ?? "已出清"
        case .sell:
            return sellRealizedPerformance?.text ?? "—"
        default:
            return "—"
        }
    }

    private var performanceColor: Color {
        switch transaction.type {
        case .buy:
            if let buyPerformance = buyUnrealizedPerformance {
                return Color.marketColor(for: buyPerformance.amount)
            }
            return .secondaryText
        case .sell:
            if let sellPerformance = sellRealizedPerformance {
                return Color.marketColor(for: sellPerformance.amount)
            }
            return .secondaryText
        default:
            return .secondaryText
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: transaction.transactionDate)
    }

    // MARK: - 買入：FIFO 剩餘批次未實現損益

    private struct PerformanceLine {
        let amount: Decimal
        let text: String
    }

    private var buyUnrealizedPerformance: PerformanceLine? {
        guard transaction.type == .buy else { return nil }
        guard let lot = fifoLot(for: transaction), lot.remainingQuantity > 0 else {
            return nil
        }
        guard let price = currentPrice, price > 0 else { return nil }

        let cost = lot.remainingQuantity * lot.costPerUnit
        let marketValue = lot.remainingQuantity * price
        let pl = marketValue - cost
        guard cost > 0 else { return nil }

        let pct = (pl / cost) * 100
        let sign = pl >= 0 ? "+" : ""
        let amountText = pl.formattedTradeAmount(currency: display.tradePriceCurrency)
        let pctText = pct.formattedPercentValue(maxFractionDigits: 1)
        return PerformanceLine(
            amount: pl,
            text: "\(sign)\(amountText) (\(sign)\(pctText)%)"
        )
    }

    private func fifoLot(for transaction: Transaction) -> FIFOLotSnapshot? {
        aggregatedHolding.fifoLotsByAccount
            .first(where: { $0.accountId == transaction.accountId })?
            .lots
            .first(where: { $0.id == transaction.id })
    }

    // MARK: - 賣出：儲存欄位已實現損益

    private var sellRealizedPerformance: PerformanceLine? {
        guard transaction.type == .sell,
              let pl = transaction.realizedGainLoss else {
            return nil
        }
        let sign = pl >= 0 ? "+" : ""
        var text = "\(sign)\(display.realizedGainLossText ?? pl.formattedTradeAmount(currency: display.tradePriceCurrency))"
        if let pct = display.realizedGainLossPercentText {
            text += " \(pct)"
        }
        return PerformanceLine(amount: pl, text: text)
    }
}
