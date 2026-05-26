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
    @State private var usdToTwdRate: Decimal = ExchangeRateSessionCache.usdToTwd ?? 32
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
        switch aggregatedHolding.assetType {
        case .stockTW:
            if let name = aggregatedHolding.name, !name.isEmpty {
                return name
            }
            return aggregatedHolding.symbol
        case .stockUS:
            return aggregatedHolding.symbol.uppercased()
        case .crypto:
            return SymbolListService.normalizedCryptoSymbol(aggregatedHolding.symbol)
        case .cash:
            return aggregatedHolding.symbol
        }
    }

    private var showsSymbolSubtitle: Bool {
        SymbolListService.shouldShowSymbolUnderTitle(
            assetType: aggregatedHolding.assetType,
            title: displayName,
            symbol: aggregatedHolding.symbol
        )
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
    
    /// 美股／加密：原幣單價 × 即時匯率後以台幣顯示（僅格式化，不影響計算）
    private var showsForeignUnitPriceInTWD: Bool {
        metricAmountDisplay == .twd && aggregatedHolding.currency != .TWD
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
            return averageCostTWD.formattedDisplayUnitPrice(
                currency: .TWD,
                convertedFromForeignToTWD: showsForeignUnitPriceInTWD
            )
        case .original:
            return aggregatedHolding.weightedAverageCost.formattedTradePrice(currency: aggregatedHolding.currency)
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
        .enableNavigationSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                SnapToolbarIconButton(icon: .back, action: { dismiss() })
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionButtons
        }
        .task {
            if let cached = ExchangeRateSessionCache.usdToTwd, cached > 0 {
                usdToTwdRate = cached
            } else if usdToTwdRate <= 0 {
                usdToTwdRate = (try? await MockDataService.shared.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 32
            }
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
                    if showsSymbolSubtitle {
                        Text(aggregatedHolding.symbol)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
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
            
            heroCurrentPriceBlock
            
            Divider()
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("持有數量")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(heroQuantityDisplayText)
                    .font(.snapAmountTile)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let breakdown = accountQuantityBreakdownText {
                    Text(breakdown)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .padding(.top, 2)
                }
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
    
    /// 現價：左側短色條 + 大字（不用整條橫向底色框）
    private var heroCurrentPriceBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(assetAccentColor)
                .frame(width: 4)
                .frame(minHeight: 48)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("每股現價")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Group {
                        if let price = displayedCurrentPrice {
                            Text(price.formattedDisplayUnitPrice(
                                currency: displayedPriceCurrency,
                                convertedFromForeignToTWD: showsForeignUnitPriceInTWD
                            ))
                                .foregroundColor(.primaryText)
                        } else {
                            Text("--")
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .font(.snapStockPriceHero)
                    .monospacedDigit()
                    
                    if let daily = displayedDailyPriceChange {
                        dailyChangeBadge(
                            amount: daily.amount,
                            percent: daily.percent,
                            currency: displayedPriceCurrency,
                            convertedFromForeignToTWD: showsForeignUnitPriceInTWD
                        )
                    }
                    
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func dailyChangeBadge(
        amount: Decimal,
        percent: Decimal,
        currency: Currency,
        convertedFromForeignToTWD: Bool = false
    ) -> some View {
        let up = amount >= 0
        let color: Color = up ? .marketUp : .marketDown
        let amountDigits = convertedFromForeignToTWD ? 1 : 2
        return HStack(spacing: 4) {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .font(.caption2.weight(.bold))
            Text("\(amount.formatted(currency: currency, fractionDigits: amountDigits, showSymbol: false)) (\(percent.formatted(fractionDigits: 2))%)")
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
        VStack(spacing: 10) {
            MetricTile(
                title: "市值",
                value: displayedMarketValueText,
                prominence: .featured,
                accentColor: assetAccentColor
            )
            MetricTile(
                title: "未實現損益",
                value: displayedUnrealizedAmountText,
                valueColor: displayedUnrealizedColor,
                footnote: displayedUnrealizedPercentText,
                footnoteColor: displayedUnrealizedColor,
                prominence: .featured,
                accentColor: displayedUnrealizedColor
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MetricTile(
                    title: "總成本",
                    value: displayedTotalCostText
                )
                MetricTile(
                    title: "平均成本",
                    value: displayedAverageCostText
                )
                MetricTile(
                    title: "總資產佔比",
                    value: "\(totalAssetsRatio.formatted(fractionDigits: 1))%",
                    valueColor: holdingColor
                )
                MetricTile(
                    title: "投資組合佔比",
                    value: "\(totalInvestmentsRatio.formatted(fractionDigits: 1))%",
                    valueColor: holdingColor
                )
            }
        }
    }

    // MARK: - 買入批次（表格式）
    private var fifoLotsSection: some View {
        HoldingFIFOLotsTableSection(
            fifoLotsByAccount: aggregatedHolding.fifoLotsByAccount,
            assetType: aggregatedHolding.assetType,
            currency: aggregatedHolding.currency,
            currentPrice: currentPrice,
            amountDisplay: metricAmountDisplay,
            usdToTwdRate: usdToTwdRate
        )
    }
    
    private var heroQuantityDisplayText: String {
        formatShareQuantity(
            aggregatedHolding.totalQuantity,
            assetType: aggregatedHolding.assetType,
            includeShareSuffix: true
        )
    }

    /// 多帳戶持有時，在總股數下方顯示各帳戶分布
    private var accountQuantityBreakdownText: String? {
        let groups = aggregatedHolding.fifoLotsByAccount.compactMap { group -> (String, Decimal)? in
            let quantity = group.lots.reduce(Decimal.zero) { $0 + $1.remainingQuantity }
            guard quantity > 0 else { return nil }
            return (group.accountName, quantity)
        }
        guard groups.count > 1 else { return nil }
        return groups.map { name, quantity in
            let qtyText = formatShareQuantity(
                quantity,
                assetType: aggregatedHolding.assetType,
                includeShareSuffix: true
            )
            return "\(name) \(qtyText)"
        }.joined(separator: " · ")
    }
    
    private func formatShareQuantity(
        _ quantity: Decimal,
        assetType: AssetType,
        includeShareSuffix: Bool
    ) -> String {
        let maxFractionDigits = assetType == .crypto ? 8 : 4
        let formatted = quantity.formattedQuantityInput(maxFractionDigits: maxFractionDigits)
        if includeShareSuffix, assetType != .crypto {
            return "\(formatted)股"
        }
        return formatted
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
                        BuyTradeFormView(market: market, prefill: buyPrefill, onSubmit: {
                            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
                        })
                    case .sell:
                        SellTradeFormView(market: market, prefill: sellPrefill, onSubmit: { _ in
                            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
                        })
                    }
                }
                .navigationTitle(sheet == .buy ? "買入\(aggregatedHolding.symbol)" : "賣出\(aggregatedHolding.symbol)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        SnapToolbarIconButton(icon: .close, action: { activeTradeSheet = nil })
                    }
                }
            }
            .snapFormSheetChrome()
            .presentationDetents([.large])
        }
    }
}

// MARK: - 買入批次表（FIFO 區塊 UI）
private struct FIFOLotTableRow: Identifiable {
    let id: String
    let brokerName: String
    let lot: FIFOLotSnapshot
}

struct HoldingFIFOLotsTableSection: View {
    let fifoLotsByAccount: [FIFOLotsByAccountSnapshot]
    let assetType: AssetType
    let currency: Currency
    let currentPrice: Decimal?
    var amountDisplay: HoldingDetailView.MetricAmountDisplay = .original
    var usdToTwdRate: Decimal = 32

    @State private var buyDateSort: HoldingsMarketValueSort = .descending
    @State private var sortByAccountFirst = false
    
    private var showsAccountColumn: Bool {
        fifoLotsByAccount.count > 1
    }
    
    private var tableRows: [FIFOLotTableRow] {
        let rows = fifoLotsByAccount.flatMap { group in
            group.lots.map { lot in
                FIFOLotTableRow(
                    id: lot.id,
                    brokerName: group.accountName,
                    lot: lot
                )
            }
        }
        
        return rows.sorted { lhs, rhs in
            if sortByAccountFirst, showsAccountColumn {
                let accountOrder = lhs.brokerName.localizedStandardCompare(rhs.brokerName)
                if accountOrder != .orderedSame {
                    return accountOrder == .orderedAscending
                }
            }
            switch buyDateSort {
            case .descending:
                return lhs.lot.buyDate > rhs.lot.buyDate
            case .ascending:
                return lhs.lot.buyDate < rhs.lot.buyDate
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("買入批次")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text("賣出時依買入先後扣庫存")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 8) {
                    AssetsFilterChipButton(
                        title: "日期",
                        icon: buyDateSort.iconName,
                        isActive: true
                    ) {
                        withAnimation(ChartMotion.switchSpring) {
                            buyDateSort.cycle()
                        }
                    }
                    
                    if showsAccountColumn {
                        AssetsFilterChipButton(
                            title: "帳戶",
                            icon: "building.columns.fill",
                            isActive: sortByAccountFirst
                        ) {
                            withAnimation(ChartMotion.switchSpring) {
                                sortByAccountFirst.toggle()
                            }
                        }
                    }
                }
            }
            
            if tableRows.isEmpty {
                Text("尚無買入批次")
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
                            assetType: assetType,
                            currency: currency,
                            currentPrice: currentPrice,
                            amountDisplay: amountDisplay,
                            usdToTwdRate: usdToTwdRate,
                            showsAccount: showsAccountColumn,
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
                .animation(ChartMotion.switchSpring, value: buyDateSort)
                .animation(ChartMotion.switchSpring, value: sortByAccountFirst)
            }
        }
    }
    
    private var tableHeaderRow: some View {
        HStack(spacing: 6) {
            if showsAccountColumn {
                headerCell("帳戶", alignment: .leading)
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
    let assetType: AssetType
    let currency: Currency
    let currentPrice: Decimal?
    let amountDisplay: HoldingDetailView.MetricAmountDisplay
    let usdToTwdRate: Decimal
    let showsAccount: Bool
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
            if showsAccount {
                dataCell(row.brokerName, alignment: .leading, weight: .regular)
                    .frame(minWidth: 52, maxWidth: 72, alignment: .leading)
                    .lineLimit(2)
            }
            dataCell(formatBuyDate(row.lot.buyDate), alignment: .leading, weight: .medium)
                .frame(width: 54, alignment: .leading)
            dataCell(formatLotQuantity(row.lot.remainingQuantity), alignment: .trailing, weight: .semibold)
                .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
            dataCell(
                displayCostPerUnit.formattedDisplayUnitPrice(
                    currency: displayCurrency,
                    convertedFromForeignToTWD: useTWDDisplay
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
        let maxFractionDigits = assetType == .crypto ? 8 : 4
        return quantity.formattedQuantityInput(maxFractionDigits: maxFractionDigits)
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
