//
//  HoldingDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct HoldingDetailView: View {
    let aggregatedHolding: AggregatedHoldingSnapshot
    let assetPriceSnapshot: AssetPriceSnapshot?
    let totalAssets: Decimal
    let totalInvestments: Decimal
    
    @Environment(\.dismiss) private var dismiss
    @State private var usdToTwdRate: Decimal = 32
    @State private var activeTradeSheet: HoldingTradeSheet?
    @State private var metricAmountDisplay: MetricAmountDisplay
    
    enum MetricAmountDisplay {
        case twd
        case original
    }
    
    init(
        aggregatedHolding: AggregatedHoldingSnapshot,
        assetPriceSnapshot: AssetPriceSnapshot?,
        totalAssets: Decimal,
        totalInvestments: Decimal
    ) {
        self.aggregatedHolding = aggregatedHolding
        self.assetPriceSnapshot = assetPriceSnapshot
        self.totalAssets = totalAssets
        self.totalInvestments = totalInvestments
        _metricAmountDisplay = State(
            initialValue: Self.defaultAmountDisplay(for: aggregatedHolding.assetType)
        )
    }
    
    /// 美股、加密貨幣預設原幣（美金）；台股等預設台幣
    private static func defaultAmountDisplay(for assetType: AssetType) -> MetricAmountDisplay {
        switch assetType {
        case .stockUS, .crypto:
            return .original
        default:
            return .twd
        }
    }
    
    private enum HoldingTradeSheet: Identifiable {
        case buy
        case sell
        
        var id: String {
            switch self {
            case .buy: return "buy"
            case .sell: return "sell"
            }
        }
    }
    
    /// 市值（原幣）
    var marketValueInOriginalCurrency: Decimal {
        guard let price = currentPrice else { return 0 }
        return aggregatedHolding.totalQuantity * price
    }

    // 計算市值（台幣）
    var marketValue: Decimal {
        let mv = marketValueInOriginalCurrency
        if aggregatedHolding.currency == .TWD {
            return mv
        } else if aggregatedHolding.currency == .USD {
            return mv * usdToTwdRate
        }
        return mv
    }
    
    // 計算總成本（台幣）
    var totalCostTWD: Decimal {
        if aggregatedHolding.currency == .TWD {
            return aggregatedHolding.totalCost
        } else if aggregatedHolding.currency == .USD {
            return aggregatedHolding.totalCost * usdToTwdRate
        }
        return 0
    }
    
    // 計算未實現損益（台幣）
    var unrealizedGainLoss: Decimal {
        marketValue - totalCostTWD
    }
    
    // 計算未實現損益（原幣）
    var unrealizedGainLossOriginal: Decimal {
        marketValueInOriginalCurrency - aggregatedHolding.totalCost
    }
    
    // 計算未實現損益百分比
    var unrealizedGainLossPercent: Decimal {
        guard totalCostTWD > 0 else { return 0 }
        return (unrealizedGainLoss / totalCostTWD) * 100
    }
    
    var unrealizedGainLossPercentOriginal: Decimal {
        guard aggregatedHolding.totalCost > 0 else { return 0 }
        return (unrealizedGainLossOriginal / aggregatedHolding.totalCost) * 100
    }
    
    var totalAssetsRatio: Decimal {
        totalAssets > 0 ? (marketValue / totalAssets) * 100 : 0
    }
    
    var totalInvestmentsRatio: Decimal {
        totalInvestments > 0 ? (marketValue / totalInvestments) * 100 : 0
    }
    
    var averageCostTWD: Decimal {
        if aggregatedHolding.currency == .TWD {
            return aggregatedHolding.weightedAverageCost
        } else if aggregatedHolding.currency == .USD {
            return aggregatedHolding.weightedAverageCost * usdToTwdRate
        }
        return aggregatedHolding.weightedAverageCost
    }
    
    // 顯示名稱
    var displayName: String {
        if aggregatedHolding.assetType == .stockTW,
           let name = aggregatedHolding.name,
           !name.isEmpty {
            return name
        }
        return aggregatedHolding.symbol
    }
    
    // 當前價格（原幣）
    var currentPrice: Decimal? {
        assetPriceSnapshot?.displayPrice
    }
    
    var displayedPriceCurrency: Currency {
        switch metricAmountDisplay {
        case .twd: return .TWD
        case .original: return aggregatedHolding.currency
        }
    }
    
    var displayedCurrentPrice: Decimal? {
        guard let price = currentPrice else { return nil }
        switch metricAmountDisplay {
        case .original:
            return price
        case .twd:
            if aggregatedHolding.currency == .TWD { return price }
            if aggregatedHolding.currency == .USD { return price * usdToTwdRate }
            return price
        }
    }
    
    private var displayedDailyPriceChange: (amount: Decimal, percent: Decimal)? {
        guard let daily = dailyPriceChange else { return nil }
        switch metricAmountDisplay {
        case .original:
            return daily
        case .twd:
            if aggregatedHolding.currency == .TWD { return daily }
            if aggregatedHolding.currency == .USD {
                return (daily.amount * usdToTwdRate, daily.percent)
            }
            return daily
        }
    }
    
    private var canToggleCurrency: Bool {
        aggregatedHolding.currency != .TWD
    }
    
    private var holdingsCurrencyDisplayBinding: Binding<AssetsCurrencyDisplay> {
        Binding(
            get: { metricAmountDisplay == .twd ? .twd : .original },
            set: { newValue in
                withAnimation(ChartMotion.switchSpring) {
                    metricAmountDisplay = newValue == .twd ? .twd : .original
                }
            }
        )
    }
    
    private var displayedMarketValueText: String {
        switch metricAmountDisplay {
        case .twd:
            return marketValue.formatted(currency: .TWD, fractionDigits: 0)
        case .original:
            return marketValueInOriginalCurrency.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedTotalCostText: String {
        switch metricAmountDisplay {
        case .twd:
            return totalCostTWD.formatted(currency: .TWD, fractionDigits: 0)
        case .original:
            return aggregatedHolding.totalCost.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedAverageCostText: String {
        switch metricAmountDisplay {
        case .twd:
            return averageCostTWD.formatted(currency: .TWD, fractionDigits: 2)
        case .original:
            return aggregatedHolding.weightedAverageCost.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedUnrealizedAmountText: String {
        switch metricAmountDisplay {
        case .twd:
            return unrealizedGainLoss.formatted(currency: .TWD, fractionDigits: 0)
        case .original:
            return unrealizedGainLossOriginal.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedUnrealizedPercentText: String {
        let pct: Decimal
        switch metricAmountDisplay {
        case .twd:
            pct = unrealizedGainLossPercent
        case .original:
            pct = unrealizedGainLossPercentOriginal
        }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(pct.formatted(fractionDigits: 2))%"
    }
    
    private var displayedUnrealizedColor: Color {
        let amount: Decimal
        switch metricAmountDisplay {
        case .twd:
            amount = unrealizedGainLoss
        case .original:
            amount = unrealizedGainLossOriginal
        }
        return Color.marketColor(for: amount)
    }
    
    var holdingColor: Color {
        HoldingColorPreferences.getColor(for: aggregatedHolding.symbol, assetType: aggregatedHolding.assetType)
    }
    
    private var assetAccentColor: Color {
        switch aggregatedHolding.assetType {
        case .stockTW: return .stockTWDeepAmber
        case .stockUS: return .stockUSDeep
        case .crypto: return .cryptoDeep
        default: return .appPrimary
        }
    }
    
    /// 單日漲跌（currentPrice 相對 previousPrice）
    private var dailyPriceChange: (amount: Decimal, percent: Decimal)? {
        guard let snapshot = assetPriceSnapshot,
              let current = snapshot.currentPrice,
              let previous = snapshot.previousPrice,
              previous > 0 else { return nil }
        let change = current - previous
        return (change, (change / previous) * 100)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if canToggleCurrency {
                    HStack {
                        Spacer(minLength: 0)
                        AccountsCurrencyControlsBar(currencyDisplay: holdingsCurrencyDisplayBinding)
                    }
                }
                
                heroSummaryCard
                secondaryMetricsSection
                
                if !aggregatedHolding.fifoLotsByAccount.isEmpty {
                    fifoLotsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.mainBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionButtons
        }
        .task {
            usdToTwdRate = (try? await MockDataService.shared.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 32
        }
        .sheet(item: $activeTradeSheet) { sheet in
            holdingTradeSheetContent(for: sheet)
        }
    }
    
// MARK: - 方向 A：英雄摘要卡
    private var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    Text(aggregatedHolding.symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Text(aggregatedHolding.assetType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(assetAccentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(assetAccentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let price = displayedCurrentPrice {
                    Text(price.formatted(currency: displayedPriceCurrency, fractionDigits: 2))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primaryText)
                } else {
                    Text("--")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.secondaryText)
                }
                
                if let daily = displayedDailyPriceChange {
                    dailyChangeBadge(
                        amount: daily.amount,
                        percent: daily.percent,
                        currency: displayedPriceCurrency
                    )
                }
                
                Spacer(minLength: 0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("持有數量")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(aggregatedHolding.totalQuantity.formatted(fractionDigits: 4))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(assetAccentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private func dailyChangeBadge(amount: Decimal, percent: Decimal, currency: Currency) -> some View {
        let up = amount >= 0
        let color: Color = up ? .marketUp : .marketDown
        return HStack(spacing: 4) {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .font(.caption2.weight(.bold))
            Text("\(amount.formatted(currency: currency, fractionDigits: 2, showSymbol: false)) (\(percent.formatted(fractionDigits: 2))%)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
    
    // MARK: - 次要指標
    private var secondaryMetricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            HoldingMetricTile(
                title: "市值",
                value: displayedMarketValueText
            )
            HoldingMetricTile(
                title: "未實現損益",
                value: displayedUnrealizedAmountText,
                valueColor: displayedUnrealizedColor,
                footnote: displayedUnrealizedPercentText
            )
            HoldingMetricTile(
                title: "總成本",
                value: displayedTotalCostText
            )
            HoldingMetricTile(
                title: "平均成本",
                value: displayedAverageCostText
            )
            HoldingMetricTile(
                title: "總資產佔比",
                value: "\(totalAssetsRatio.formatted(fractionDigits: 1))%",
                valueColor: holdingColor
            )
            HoldingMetricTile(
                title: "投資組合佔比",
                value: "\(totalInvestmentsRatio.formatted(fractionDigits: 1))%",
                valueColor: holdingColor
            )
        }
    }

    // MARK: - 各次買入（表格式）
    private var fifoLotsSection: some View {
        HoldingFIFOLotsTableSection(
            fifoLotsByAccount: aggregatedHolding.fifoLotsByAccount,
            currency: aggregatedHolding.currency,
            currentPrice: currentPrice,
            amountDisplay: metricAmountDisplay,
            usdToTwdRate: usdToTwdRate
        )
    }
    
    // MARK: - 底部操作按鈕
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            // 買入按鈕
            Button(action: {
                activeTradeSheet = .buy
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("買入")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.profitGreen)
                .cornerRadius(12)
            }
            
            // 賣出按鈕
            Button(action: {
                activeTradeSheet = .sell
            }) {
                HStack {
                    Image(systemName: "minus.circle.fill")
                    Text("賣出")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.separator.opacity(0.3)),
            alignment: .top
        )
    }
    private var preferredTradeAccountId: String? {
        aggregatedHolding.fifoLotsByAccount.first?.accountId
            ?? aggregatedHolding.sourceAccountIds.first
    }
    
    private var buyPrefill: BuyTradePrefill {
        BuyTradePrefill(
            symbol: aggregatedHolding.symbol,
            symbolName: aggregatedHolding.name,
            preferredAccountId: preferredTradeAccountId,
            lockSymbol: true
        )
    }
    
    private var sellPrefill: SellTradePrefill {
        SellTradePrefill(
            symbol: aggregatedHolding.symbol,
            preferredAccountId: preferredTradeAccountId,
            lockSymbol: true
        )
    }
    
    @ViewBuilder
    private func holdingTradeSheetContent(for sheet: HoldingTradeSheet) -> some View {
        if let market = TradeMarket(assetType: aggregatedHolding.assetType) {
            NavigationStack {
                Group {
                    switch sheet {
                    case .buy:
                        BuyTradeFormView(market: market, prefill: buyPrefill) {
                            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
                        }
                    case .sell:
                        SellTradeFormView(market: market, prefill: sellPrefill) { _ in
                            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
                        }
                    }
                }
                .navigationTitle(sheet == .buy ? "買入\(aggregatedHolding.symbol)" : "賣出\(aggregatedHolding.symbol)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { activeTradeSheet = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appPrimary)
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}

// MARK: - 各次買入表（僅 FIFO 區塊 UI）
private struct FIFOLotTableRow: Identifiable {
    let id: String
    let brokerName: String
    let lot: FIFOLotSnapshot
}

struct HoldingFIFOLotsTableSection: View {
    let fifoLotsByAccount: [FIFOLotsByAccountSnapshot]
    let currency: Currency
    let currentPrice: Decimal?
    var amountDisplay: HoldingDetailView.MetricAmountDisplay = .original
    var usdToTwdRate: Decimal = 32
    
    private var showsBrokerColumn: Bool {
        fifoLotsByAccount.count > 1
    }
    
    private var tableRows: [FIFOLotTableRow] {
        fifoLotsByAccount.flatMap { group in
            group.lots
                .sorted { $0.buyDate > $1.buyDate }
                .map { lot in
                    FIFOLotTableRow(
                        id: lot.id,
                        brokerName: group.accountName,
                        lot: lot
                    )
                }
        }
        .sorted { $0.lot.buyDate > $1.lot.buyDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("各次買入")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text("賣出時依買入先後扣庫存")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            if tableRows.isEmpty {
                Text("尚無買入明細")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(Color.secondaryBackground)
                    .cornerRadius(10)
            } else {
                VStack(spacing: 0) {
                    tableHeaderRow
                    Divider()
                    ForEach(Array(tableRows.enumerated()), id: \.element.id) { index, row in
                        FIFOLotTableDataRow(
                            row: row,
                            currency: currency,
                            currentPrice: currentPrice,
                            amountDisplay: amountDisplay,
                            usdToTwdRate: usdToTwdRate,
                            showsBroker: showsBrokerColumn,
                            isAlternate: index.isMultiple(of: 2)
                        )
                        if index < tableRows.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.secondaryBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.separator.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    private var tableHeaderRow: some View {
        HStack(spacing: 6) {
            if showsBrokerColumn {
                headerCell("券商", alignment: .leading)
                    .frame(minWidth: 52, maxWidth: 72, alignment: .leading)
            }
            headerCell("買入日", alignment: .leading)
                .frame(width: 54, alignment: .leading)
            headerCell("數量", alignment: .trailing)
                .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
            headerCell("均價", alignment: .trailing)
                .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
            headerCell("損益", alignment: .trailing)
                .frame(minWidth: 72, maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.tertiaryBackground.opacity(0.6))
    }
    
    private func headerCell(_ title: String, alignment: HorizontalAlignment) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.primaryText.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct FIFOLotTableDataRow: View {
    let row: FIFOLotTableRow
    let currency: Currency
    let currentPrice: Decimal?
    let amountDisplay: HoldingDetailView.MetricAmountDisplay
    let usdToTwdRate: Decimal
    let showsBroker: Bool
    let isAlternate: Bool
    
    private var useTWDDisplay: Bool {
        amountDisplay == .twd && currency != .TWD
    }
    
    private var displayCurrency: Currency {
        useTWDDisplay ? .TWD : currency
    }
    
    private var displayPrice: Decimal? {
        guard let price = currentPrice else { return nil }
        if useTWDDisplay, currency == .USD {
            return price * usdToTwdRate
        }
        return price
    }
    
    private var displayCostPerUnit: Decimal {
        if useTWDDisplay, currency == .USD {
            return row.lot.costPerUnit * usdToTwdRate
        }
        return row.lot.costPerUnit
    }
    
    private var marketValue: Decimal {
        guard let price = displayPrice else { return 0 }
        return row.lot.remainingQuantity * price
    }
    
    private var totalCost: Decimal {
        row.lot.remainingQuantity * displayCostPerUnit
    }
    
    private var unrealizedGainLoss: Decimal {
        marketValue - totalCost
    }
    
    private var unrealizedGainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    private var plColor: Color {
        Color.marketColor(for: unrealizedGainLoss)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if showsBroker {
                dataCell(row.brokerName, alignment: .leading, weight: .regular)
                    .frame(minWidth: 52, maxWidth: 72, alignment: .leading)
                    .lineLimit(2)
            }
            dataCell(formatBuyDate(row.lot.buyDate), alignment: .leading, weight: .medium)
                .frame(width: 54, alignment: .leading)
            dataCell(formatLotQuantity(row.lot.remainingQuantity), alignment: .trailing, weight: .semibold)
                .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
            dataCell(
                displayCostPerUnit.formatted(
                    currency: displayCurrency,
                    fractionDigits: 2,
                    showSymbol: displayCurrency != .TWD
                ),
                alignment: .trailing,
                weight: .regular
            )
            .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
            profitLossCell
                .frame(minWidth: 72, maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isAlternate ? Color.cardBackground.opacity(0.35) : Color.clear)
    }
    
    private var profitLossCell: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(unrealizedGainLoss.formatted(
                currency: displayCurrency,
                fractionDigits: 0,
                showSymbol: displayCurrency != .TWD
            ))
                .font(.caption)
                .fontWeight(.semibold)
            Text("\(unrealizedGainLossPercent.formatted(fractionDigits: 2))%")
                .font(.caption2)
        }
        .foregroundColor(plColor)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private func dataCell(_ text: String, alignment: HorizontalAlignment, weight: Font.Weight) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(weight)
            .foregroundColor(.primaryText)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }
    
    private func formatBuyDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    private func formatLotQuantity(_ quantity: Decimal) -> String {
        let number = NSDecimalNumber(decimal: quantity)
        let double = number.doubleValue
        if abs(double - double.rounded()) < 0.000_000_1 {
            return quantity.formatted(fractionDigits: 0)
        }
        return quantity.formatted(fractionDigits: 4)
    }
}


// MARK: - 次要指標格
private struct HoldingMetricTile: View {
    let title: String
    let value: String
    var valueColor: Color = .primaryText
    var footnote: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
                    .lineLimit(1)
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

#Preview {
    NavigationStack {
        HoldingDetailView(
            aggregatedHolding: AggregatedHoldingSnapshot(
                userId: "test-user",
                assetType: .stockTW,
                symbol: "2330",
                name: "台積電",
                currency: .TWD,
                totalQuantity: 10,
                weightedAverageCost: 500,
                totalCost: 5000,
                sourceAccountIds: ["account1", "account2"],
                fifoLotsByAccount: [
                    FIFOLotsByAccountSnapshot(
                        accountId: "account1",
                        accountName: "台新證券",
                        lots: [
                            FIFOLotSnapshot(
                                id: "lot1",
                                accountId: "account1",
                                accountName: "台新證券",
                                buyDate: Date(),
                                remainingQuantity: 5,
                                costPerUnit: 480,
                                currency: .TWD
                            )
                        ]
                    )
                ]
            ),
            assetPriceSnapshot: AssetPriceSnapshot(
                assetType: .stockTW,
                symbol: "2330",
                name: "台積電",
                currency: .TWD,
                currentPrice: 550
            ),
            totalAssets: 100000,
            totalInvestments: 80000
        )
    }
}
