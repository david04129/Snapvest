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
    let usdToTwdRate: Decimal
    let accountCurrency: Currency
    let onRowTap: () -> Void
    let onDelete: ((Transaction) -> Void)?

    private var display: TransactionDisplayFormatter {
        TransactionDisplayFormatter(transaction: transaction)
    }

    private var accentColor: Color {
        display.typeAccentColor
    }

    private var amountDisplayCurrency: Currency {
        display.displayAmount(accountCurrency: accountCurrency, usdToTwdRate: usdToTwdRate).currency
    }

    private var tradeAmountText: String {
        let displayed = display.displayAmount(accountCurrency: accountCurrency, usdToTwdRate: usdToTwdRate)
        return formattedCompactAmount(displayed.amount, currency: displayed.currency)
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

            CurrencyAmountWithChip(
                text: tradeAmountText,
                currency: amountDisplayCurrency,
                font: .system(size: 17, weight: .bold),
                weight: .bold,
                color: .primaryText,
                chipTint: accentColor,
                spacing: 5,
                minimumScaleFactor: 0.75
            )
            .monospacedDigit()
            .lineLimit(1)
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

        let cost = costAmountInDisplayCurrency(for: lot)
        let marketValueInPriceCurrency = lot.remainingQuantity * price
        guard let marketValue = convertedAmount(
            marketValueInPriceCurrency,
            from: display.tradePriceCurrency,
            to: amountDisplayCurrency,
            rate: usdToTwdRate > 0 ? usdToTwdRate : transaction.exchangeRate
        ) else { return nil }
        let pl = marketValue - cost
        guard cost > 0 else { return nil }

        let pct = (pl / cost) * 100
        let sign = pl >= 0 ? "+" : ""
        let amountText = formattedCompactAmount(abs(pl), currency: amountDisplayCurrency)
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
        let displayed = display.displayRealizedGainLoss(
            accountCurrency: accountCurrency,
            usdToTwdRate: usdToTwdRate
        )
        let displayedPL = displayed?.amount ?? pl
        let displayedCurrency = displayed?.currency ?? amountDisplayCurrency
        let sign = pl >= 0 ? "+" : ""
        var text = "\(sign)\(formattedCompactAmount(abs(displayedPL), currency: displayedCurrency))"
        if let pct = display.realizedGainLossPercentText {
            text += " \(pct)"
        }
        return PerformanceLine(amount: displayedPL, text: text)
    }

    private func costAmountInDisplayCurrency(for lot: FIFOLotSnapshot) -> Decimal {
        let proportionalFee = transaction.quantity > 0
            ? transaction.fee * (lot.remainingQuantity / transaction.quantity)
            : Decimal.zero
        let costInPriceCurrency = (lot.remainingQuantity * transaction.price) + proportionalFee
        return convertedAmount(
            costInPriceCurrency,
            from: display.tradePriceCurrency,
            to: amountDisplayCurrency,
            rate: transaction.exchangeRate ?? usdToTwdRate
        ) ?? (lot.remainingQuantity * lot.costPerUnit)
    }

    private func convertedAmount(
        _ amount: Decimal,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        rate: Decimal?
    ) -> Decimal? {
        if sourceCurrency == targetCurrency { return amount }
        guard let rate, rate > 0 else { return nil }
        if sourceCurrency == .USD, targetCurrency == .TWD {
            return amount * rate
        }
        if sourceCurrency == .TWD, targetCurrency == .USD {
            return amount / rate
        }
        return nil
    }

    private func formattedCompactAmount(_ amount: Decimal, currency: Currency) -> String {
        amount.formatted(currency: currency, fractionDigits: 1, showSymbol: false)
    }
}
