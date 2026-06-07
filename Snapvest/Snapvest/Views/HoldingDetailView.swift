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
    @Environment(\.openPlusPaywall) private var openPlusPaywall
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var baseCurrencyManager = BaseCurrencyManager.shared
    @State private var usdToTwdRate: Decimal = ExchangeRateSessionCache.usdToTwd ?? 0
    @State private var twdPerBaseCurrency: Decimal = 1
    @State private var activeTradeSheet: HoldingTradeSheet?
    @State private var metricAmountDisplay: MetricAmountDisplay
    @State private var marketStatus: MarketStatusSnapshot?
    @State private var buyGateAlertMessage: String?
    
    enum MetricAmountDisplay {
        case twd
        case original
    }

    init(
        aggregatedHolding: AggregatedHoldingSnapshot,
        assetPriceSnapshot: AssetPriceSnapshot?,
        totalAssets: Decimal,
        totalInvestments: Decimal,
        initialUsdToTwdRate: Decimal? = nil,
        initialTwdPerBaseCurrency: Decimal? = nil
    ) {
        self.aggregatedHolding = aggregatedHolding
        self.assetPriceSnapshot = assetPriceSnapshot
        self.totalAssets = totalAssets
        self.totalInvestments = totalInvestments
        let resolvedUsdToTwdRate = initialUsdToTwdRate ?? ExchangeRateSessionCache.usdToTwd ?? 0
        _usdToTwdRate = State(initialValue: resolvedUsdToTwdRate)
        _twdPerBaseCurrency = State(initialValue: Self.initialTwdPerBaseCurrency(
            baseCurrency: BaseCurrencyManager.shared.baseCurrency,
            initialRate: initialTwdPerBaseCurrency,
            usdToTwdRate: resolvedUsdToTwdRate
        ))
        _metricAmountDisplay = State(initialValue: .twd)
    }

    private static func initialTwdPerBaseCurrency(
        baseCurrency: Currency,
        initialRate: Decimal?,
        usdToTwdRate: Decimal
    ) -> Decimal {
        if let initialRate, initialRate > 0 { return initialRate }
        if baseCurrency == .TWD { return 1 }
        if baseCurrency == .USD, usdToTwdRate > 0 { return usdToTwdRate }
        return 1
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
    
    private var selectedDisplayCurrency: Currency {
        metricAmountDisplay == .twd ? baseCurrencyManager.baseCurrency : aggregatedHolding.currency
    }

    private func amountInSelectedCurrency(fromTWD amount: Decimal) -> Decimal {
        guard selectedDisplayCurrency != .TWD,
              twdPerBaseCurrency > 0 else {
            return amount
        }
        return amount / twdPerBaseCurrency
    }

    // 顯示名稱
    var displayName: String {
        switch aggregatedHolding.assetType {
        case .stockTW:
            return SymbolListService.displayName(
                assetType: aggregatedHolding.assetType,
                symbol: aggregatedHolding.symbol,
                storedName: aggregatedHolding.name
            )
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
        aggregatedHolding.currency
    }
    
    var displayedCurrentPrice: Decimal? {
        currentPrice
    }

    private var currentPriceFractionDigits: Int {
        aggregatedHolding.assetType == .crypto ? 4 : 2
    }
    
    private var displayedDailyPriceChange: (amount: Decimal, percent: Decimal)? {
        dailyPriceChange
    }

    private var dailyGainLossOriginal: Decimal? {
        guard let dailyPriceChange else { return nil }
        return dailyPriceChange.amount * aggregatedHolding.totalQuantity
    }

    private var dailyGainLossTWD: Decimal? {
        guard let dailyGainLossOriginal else { return nil }
        switch aggregatedHolding.currency {
        case .TWD:
            return dailyGainLossOriginal
        case .USD:
            return usdToTwdRate > 0 ? dailyGainLossOriginal * usdToTwdRate : dailyGainLossOriginal
        default:
            return dailyGainLossOriginal
        }
    }
    
    private var canToggleCurrency: Bool {
        aggregatedHolding.currency != baseCurrencyManager.baseCurrency
    }
    
    /// 美股／加密：原幣單價 × 即時匯率後以台幣顯示（僅格式化，不影響計算）
    private var showsForeignUnitPriceInTWD: Bool {
        false
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
            return amountInSelectedCurrency(fromTWD: marketValue).formatted(
                currency: selectedDisplayCurrency,
                fractionDigits: selectedDisplayCurrency == .TWD ? 0 : 2
            )
        case .original:
            return marketValueInOriginalCurrency.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedTotalCostText: String {
        switch metricAmountDisplay {
        case .twd:
            return amountInSelectedCurrency(fromTWD: totalCostTWD).formatted(
                currency: selectedDisplayCurrency,
                fractionDigits: selectedDisplayCurrency == .TWD ? 0 : 2
            )
        case .original:
            return aggregatedHolding.totalCost.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }
    
    private var displayedAverageCostText: String {
        switch metricAmountDisplay {
        case .twd:
            return amountInSelectedCurrency(fromTWD: averageCostTWD).formattedTradePrice(currency: selectedDisplayCurrency)
        case .original:
            return aggregatedHolding.weightedAverageCost.formattedTradePrice(currency: aggregatedHolding.currency)
        }
    }
    
    private var displayedUnrealizedAmountText: String {
        switch metricAmountDisplay {
        case .twd:
            return amountInSelectedCurrency(fromTWD: unrealizedGainLoss).formatted(
                currency: selectedDisplayCurrency,
                fractionDigits: selectedDisplayCurrency == .TWD ? 0 : 2
            )
        case .original:
            return unrealizedGainLossOriginal.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }

    private var displayedDailyGainLossText: String? {
        switch metricAmountDisplay {
        case .twd:
            guard let dailyGainLossTWD else { return nil }
            return amountInSelectedCurrency(fromTWD: dailyGainLossTWD).formatted(
                currency: selectedDisplayCurrency,
                fractionDigits: selectedDisplayCurrency == .TWD ? 0 : 2
            )
        case .original:
            guard let dailyGainLossOriginal else { return nil }
            return dailyGainLossOriginal.formatted(currency: aggregatedHolding.currency, fractionDigits: 2)
        }
    }

    private var displayedDailyGainLossColor: Color {
        guard let dailyGainLossTWD else { return .secondaryText }
        return Color.marketColor(for: dailyGainLossTWD)
    }

    private var displayedDailyGainLossPercentText: String? {
        guard let dailyPriceChange else { return nil }
        let sign = dailyPriceChange.percent >= 0 ? "+" : ""
        return "\(sign)\(dailyPriceChange.percent.formatted(fractionDigits: 2))%"
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
    
    /// 單日漲跌：現價相對本機 snapshot 昨收（與首頁 TodayPL 同源，不拉 21 天 history）。
    private var dailyPriceChange: (amount: Decimal, percent: Decimal)? {
        guard let snapshot = assetPriceSnapshot else { return nil }
        return DailyReferenceCloseResolver.dailyChange(snapshot: snapshot)
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
                
                if showsTradeHistorySection {
                    HoldingTradeHistorySection(
                        aggregatedHolding: aggregatedHolding,
                        currentPrice: currentPrice
                    )
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
            marketStatus = await MarketStatusService.fetchIfNeeded()
            if let cached = ExchangeRateSessionCache.usdToTwd, cached > 0 {
                updateUsdToTwdRateIfNeeded(cached)
            } else if usdToTwdRate <= 0 {
                updateUsdToTwdRateIfNeeded(
                    (try? await MockDataService.shared.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate) ?? 0
                )
            }
            await loadBaseCurrencyRate()
        }
        .onChange(of: baseCurrencyManager.baseCurrency) { _, _ in
            Task { await loadBaseCurrencyRate() }
        }
        .sheet(item: $activeTradeSheet) { sheet in
            holdingTradeSheetContent(for: sheet)
        }
        .alert("需要 Walleaf Plus", isPresented: Binding(
            get: { buyGateAlertMessage != nil },
            set: { if !$0 { buyGateAlertMessage = nil } }
        )) {
            Button("了解 Plus") {
                buyGateAlertMessage = nil
                openPlusPaywall()
            }
            Button("知道了", role: .cancel) {
                buyGateAlertMessage = nil
            }
        } message: {
            Text(buyGateAlertMessage ?? "")
        }
    }
    
    @MainActor
    private func loadBaseCurrencyRate() async {
        let currency = baseCurrencyManager.baseCurrency
        guard currency != .TWD else {
            updateTwdPerBaseCurrencyIfNeeded(1)
            return
        }
        if currency == .USD, usdToTwdRate > 0 {
            updateTwdPerBaseCurrencyIfNeeded(usdToTwdRate)
            return
        }
        updateTwdPerBaseCurrencyIfNeeded(
            (try? await MockDataService.shared.fetchExchangeRate(from: currency, to: .TWD, date: nil)?.rate) ?? 1
        )
    }

    @MainActor
    private func updateUsdToTwdRateIfNeeded(_ newValue: Decimal) {
        guard newValue > 0, newValue != usdToTwdRate else { return }
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            usdToTwdRate = newValue
        }
    }

    @MainActor
    private func updateTwdPerBaseCurrencyIfNeeded(_ newValue: Decimal) {
        guard newValue > 0, newValue != twdPerBaseCurrency else { return }
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            twdPerBaseCurrency = newValue
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
                
                if let snapshot = assetPriceSnapshot {
                    let annotation = PriceFreshnessFormatter.annotation(
                        for: snapshot,
                        marketStatus: marketStatus
                    )
                    PriceFreshnessAnnotationView(
                        chip: annotation.chip,
                        timestamp: annotation.timestamp
                    )
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Group {
                        if let price = displayedCurrentPrice {
                            CurrencyAmountWithChip(
                                text: price.formatted(
                                    currency: displayedPriceCurrency,
                                    fractionDigits: currentPriceFractionDigits,
                                    showSymbol: false
                                ),
                                currency: displayedPriceCurrency,
                                font: .snapStockPriceHero,
                                weight: .bold,
                                color: .primaryText,
                                chipTint: assetAccentColor
                            )
                        } else {
                            Text("--")
                                .font(.snapStockPriceHero)
                                .fontWeight(.bold)
                                .foregroundColor(.secondaryText)
                        }
                    }
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
            Image(systemName: MarketDirectionSymbol.systemName(isUp: up))
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
                currency: selectedDisplayCurrency,
                prominence: .featured,
                accentColor: assetAccentColor
            )
            if let displayedDailyGainLossText {
                MetricTile(
                    title: "單日損益",
                    value: displayedDailyGainLossText,
                    currency: selectedDisplayCurrency,
                    valueColor: displayedDailyGainLossColor,
                    footnote: displayedDailyGainLossPercentText,
                    footnoteColor: displayedDailyGainLossColor,
                    prominence: .featured,
                    accentColor: displayedDailyGainLossColor
                )
            }
            MetricTile(
                title: "未實現損益",
                value: displayedUnrealizedAmountText,
                currency: selectedDisplayCurrency,
                valueColor: displayedUnrealizedColor,
                footnote: displayedUnrealizedPercentText,
                footnoteColor: displayedUnrealizedColor,
                prominence: .featured,
                accentColor: displayedUnrealizedColor
            )
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MetricTile(
                    title: "總成本",
                    value: displayedTotalCostText,
                    currency: selectedDisplayCurrency
                )
                MetricTile(
                    title: "平均成本",
                    value: displayedAverageCostText,
                    currency: selectedDisplayCurrency
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

    private var showsTradeHistorySection: Bool {
        TradeMarket(assetType: aggregatedHolding.assetType) != nil
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
                Task { await openBuySheetIfAllowed() }
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

    private func openBuySheetIfAllowed() async {
        do {
            let snapshot = try await PlusFeatureGate.loadSnapshot(userId: aggregatedHolding.userId)
            let decision = PlusFeatureGate.canOpenBuyFlow(
                assetType: aggregatedHolding.assetType,
                snapshot: snapshot,
                isPlusActive: subscriptionManager.isPlusActive
            )
            switch decision {
            case .allowed:
                activeTradeSheet = .buy
            case .blocked(let reason):
                buyGateAlertMessage = PlusFeatureGate.message(for: reason)
            }
        } catch {
            buyGateAlertMessage = "無法驗證 Free 上限：\(error.localizedDescription)"
        }
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
                            activeTradeSheet = nil
                        })
                    case .sell:
                        SellTradeFormView(market: market, prefill: sellPrefill, onSubmit: { _ in
                            activeTradeSheet = nil
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
