//
//  AssetCategoryDetailView.swift
//  Snapvest
//
//  投資分頁：台股／美股／加密貨幣類別總覽詳情
//

import SwiftUI

struct AssetCategoryNavigationItem: Identifiable, Hashable {
    let assetType: AssetType
    let ratioType: HoldingRatioType
    let currencyDisplay: AssetsCurrencyDisplay

    var id: String { assetType.rawValue }
}

struct AssetCategoryDetailView: View {
    let assetType: AssetType
    let ratioType: HoldingRatioType
    let marketStatus: MarketStatusSnapshot?
    let onHoldingTap: (AggregatedHoldingSnapshot) -> Void

    @State private var currencyDisplay: AssetsCurrencyDisplay
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel

    init(
        assetType: AssetType,
        ratioType: HoldingRatioType,
        currencyDisplay: AssetsCurrencyDisplay,
        marketStatus: MarketStatusSnapshot?,
        onHoldingTap: @escaping (AggregatedHoldingSnapshot) -> Void
    ) {
        self.assetType = assetType
        self.ratioType = ratioType
        self.marketStatus = marketStatus
        self.onHoldingTap = onHoldingTap
        _currencyDisplay = State(initialValue: currencyDisplay)
    }

    private var metrics: AssetCategorySummaryMetrics {
        AssetCategorySummaryMetrics.compute(
            holdings: assetsViewModel.aggregatedHoldings,
            assetPriceSnapshots: assetsViewModel.assetPriceSnapshots,
            usdToTwdRate: assetsViewModel.usdToTwdRate,
            ratioType: ratioType,
            totalAssets: assetsViewModel.totalAssets,
            totalInvestments: assetsViewModel.totalInvestments,
            assetType: assetType
        )
    }

    private var categoryHoldings: [AggregatedHoldingSnapshot] {
        assetsViewModel.aggregatedHoldings.filter { $0.assetType == assetType }
    }

    private var accentColor: Color {
        switch assetType {
        case .stockTW: return .stockTWColor
        case .stockUS: return .stockUSColor
        case .crypto: return .cryptoColor
        case .cash: return .appPrimary
        }
    }

    private var usesOriginalAmounts: Bool {
        showsCurrencyToggle && currencyDisplay == .original
    }

    /// 類別原幣與主幣相同時（如台股＋TWD），不需原幣／主幣切換
    private var showsCurrencyToggle: Bool {
        assetType.quoteCurrency != portfolioViewModel.viewCurrency
    }

    private var displayCurrency: Currency {
        usesOriginalAmounts ? assetType.quoteCurrency : portfolioViewModel.viewCurrency
    }

    private func toggleCategoryDisplayCurrency() {
        guard showsCurrencyToggle else { return }
        withAnimation(ChartMotion.switchSpring) {
            currencyDisplay = currencyDisplay == .twd ? .original : .twd
        }
    }

    private var twdPerBaseCurrency: Decimal {
        portfolioViewModel.twdPerBaseCurrency
    }

    private var displayMarketValue: Decimal {
        guard !usesOriginalAmounts else { return metrics.marketValueOriginal }
        return twdPerBaseCurrency > 0 ? metrics.marketValueTWD / twdPerBaseCurrency : metrics.marketValueTWD
    }

    private var displayUnrealized: Decimal {
        guard !usesOriginalAmounts else { return metrics.unrealizedGainLossOriginal }
        return twdPerBaseCurrency > 0 ? metrics.unrealizedGainLossTWD / twdPerBaseCurrency : metrics.unrealizedGainLossTWD
    }

    private var displayUnrealizedPercent: Decimal {
        usesOriginalAmounts ? metrics.unrealizedGainLossPercentOriginal : metrics.unrealizedGainLossPercentTWD
    }

    private var displayTotalCost: Decimal {
        guard !usesOriginalAmounts else { return metrics.totalCostOriginal }
        return twdPerBaseCurrency > 0 ? metrics.totalCostTWD / twdPerBaseCurrency : metrics.totalCostTWD
    }

    private var totalAssetsRatio: Decimal {
        assetsViewModel.totalAssets > 0 ? (metrics.marketValueTWD / assetsViewModel.totalAssets) * 100 : 0
    }

    private var portfolioRatio: Decimal {
        assetsViewModel.totalInvestments > 0 ? (metrics.marketValueTWD / assetsViewModel.totalInvestments) * 100 : 0
    }

    private var marketValueFractionDigits: Int {
        usesOriginalAmounts || portfolioViewModel.viewCurrency != .TWD ? 2 : 0
    }

    private var countLabel: String {
        metrics.holdingCount == 0 ? "尚無持股" : "\(metrics.holdingCount) 檔"
    }

    private var categoryTodayPL: TodayPLCategorySummary? {
        portfolioViewModel.todayPLSummary.categories.first { $0.assetType == assetType }
    }

    private var displayedDailyChange: (amount: Decimal, percent: Decimal)? {
        guard let summary = categoryTodayPL else { return nil }
        guard summary.priorMarketValueTWD > 0 || summary.changeTWD != 0 else { return nil }
        let percent = summary.changePercent
        if usesOriginalAmounts {
            if assetType.quoteCurrency == .TWD {
                return (summary.changeTWD, percent)
            }
            if assetType.quoteCurrency == .USD, assetsViewModel.usdToTwdRate > 0 {
                return (summary.changeTWD / assetsViewModel.usdToTwdRate, percent)
            }
        }
        let amount = twdPerBaseCurrency > 0 ? summary.changeTWD / twdPerBaseCurrency : summary.changeTWD
        return (amount, percent)
    }

    private var dailyChangeAmountFractionDigits: Int {
        if usesOriginalAmounts, assetType.quoteCurrency == .USD, displayCurrency == .TWD {
            return 1
        }
        return marketValueFractionDigits == 0 ? 0 : 2
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                metricsSection

                AllHoldingsSection(
                    sectionTitle: "持股列表",
                    aggregatedHoldings: categoryHoldings,
                    assetPriceSnapshots: assetsViewModel.assetPriceSnapshots,
                    totalAssets: assetsViewModel.totalAssets,
                    totalInvestments: assetsViewModel.totalInvestments,
                    usdToTwdRate: assetsViewModel.usdToTwdRate,
                    baseCurrency: portfolioViewModel.viewCurrency,
                    twdPerBaseCurrency: twdPerBaseCurrency,
                    ratioType: ratioType,
                    currencyDisplay: currencyDisplay,
                    categoryFilter: assetType,
                    showsCategorySort: false,
                    onHoldingTap: onHoldingTap
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.mainBackground)
        .navigationBarBackButtonHidden(true)
        .enableNavigationSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                SnapToolbarIconButton(icon: .back) { dismiss() }
            }
        }
        .onAppear {
            if !showsCurrencyToggle {
                currencyDisplay = .twd
            }
        }
    }

    private var metricsSection: some View {
        VStack(spacing: 10) {
            AssetCategoryGainLossSection(
                assetType: assetType,
                categoryHoldings: categoryHoldings,
                assetPriceSnapshots: assetsViewModel.assetPriceSnapshots,
                accentColor: accentColor,
                displayUnrealized: displayUnrealized,
                displayUnrealizedPercent: displayUnrealizedPercent,
                displayCurrency: displayCurrency,
                usesOriginalAmounts: usesOriginalAmounts,
                twdPerBaseCurrency: twdPerBaseCurrency,
                usdToTwdRate: assetsViewModel.usdToTwdRate,
                baseCurrency: portfolioViewModel.viewCurrency,
                amountFractionDigits: marketValueFractionDigits,
                canToggleCurrency: showsCurrencyToggle,
                onCurrencyToggle: toggleCategoryDisplayCurrency
            )

            categoryRatioSummaryTile
        }
    }

    private var categoryRatioSummaryTile: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "總資產佔比",
                value: "\(totalAssetsRatio.formatted(fractionDigits: 1))%",
                valueColor: accentColor,
                accentColor: accentColor,
                compact: true
            )
            MetricTile(
                title: "投資組合佔比",
                value: "\(portfolioRatio.formatted(fractionDigits: 1))%",
                valueColor: accentColor,
                accentColor: accentColor,
                compact: true
            )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(assetType.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primaryText)
                        CurrencyToggleChip(
                            currency: displayCurrency,
                            tint: accentColor,
                            isEnabled: showsCurrencyToggle,
                            action: toggleCategoryDisplayCurrency
                        )
                        if let chip = MarketSessionDisplay.categorySessionChip(
                            assetType: assetType,
                            marketStatus: marketStatus
                        ) {
                            PriceSessionChip(chip: chip)
                        }
                    }
                    Text(countLabel)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                Spacer(minLength: 8)
                Text("投資類別")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("持股市值")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        CurrencyAmountWithChip(
                            text: displayMarketValue.formatted(
                                currency: displayCurrency,
                                fractionDigits: marketValueFractionDigits
                            ),
                            currency: displayCurrency,
                            font: .snapAmountHero,
                            weight: .bold,
                            color: .primaryText,
                            chipTint: accentColor,
                            showsChip: false
                        )
                        if let daily = displayedDailyChange {
                            dailyChangeBadge(
                                amount: daily.amount,
                                percent: daily.percent,
                                currency: displayCurrency
                            )
                        }
                        Spacer(minLength: 0)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("成本")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    CurrencyAmountWithChip(
                        text: displayTotalCost.formatted(
                            currency: displayCurrency,
                            fractionDigits: marketValueFractionDigits
                        ),
                        currency: displayCurrency,
                        font: .snapAmountSecondary,
                        weight: .bold,
                        color: .primaryText,
                        chipTint: accentColor,
                        spacing: 5,
                        showsChip: false,
                        minimumScaleFactor: 0.72
                    )
                }
                .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }

    private func dailyChangeBadge(
        amount: Decimal,
        percent: Decimal,
        currency: Currency
    ) -> some View {
        let up = amount >= 0
        let color: Color = up ? .marketUp : .marketDown
        return HStack(spacing: 4) {
            Image(systemName: MarketDirectionSymbol.systemName(isUp: up))
                .font(.caption2.weight(.bold))
            Text("\(amount.formatted(currency: currency, fractionDigits: dailyChangeAmountFractionDigits, showSymbol: false)) (\(percent.formatted(fractionDigits: 2))%)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func compactRatioColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(accentColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 類別損益（可展開，已實現邏輯對齊首頁 RealizedPLCardView）

private struct AssetCategoryGainLossSection: View {
    let assetType: AssetType
    let categoryHoldings: [AggregatedHoldingSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let accentColor: Color
    let displayUnrealized: Decimal
    let displayUnrealizedPercent: Decimal
    let displayCurrency: Currency
    let usesOriginalAmounts: Bool
    let twdPerBaseCurrency: Decimal
    let usdToTwdRate: Decimal
    let baseCurrency: Currency
    let amountFractionDigits: Int
    let canToggleCurrency: Bool
    let onCurrencyToggle: () -> Void

    @State private var isExpanded = false
    @State private var expandedTransactionIds: Set<String> = []
    @State private var isLoadingDetails = false
    @State private var detailLoadFailed = false
    @State private var detailsRevision = UUID()

    private struct RealizedCurrencySection: Identifiable {
        let currency: Currency
        let transactions: [Transaction]
        let total: Decimal

        var id: Currency { currency }
    }

    private struct UnrealizedRow: Identifiable {
        let id: String
        let name: String
        let amount: Decimal
        let percent: Decimal
    }

    private var categorySells: [Transaction] {
        let _ = detailsRevision
        return RealizedPLDetailCache.sellTransactions.filter { $0.assetType == assetType }
    }

    private var realizedCurrencySections: [RealizedCurrencySection] {
        let realizedTransactions = categorySells
            .filter { $0.realizedGainLoss != nil }
            .sorted { $0.transactionDate > $1.transactionDate }
        guard !realizedTransactions.isEmpty else { return [] }
        let total = realizedTransactions.reduce(Decimal.zero) { partial, transaction in
            partial + (realizedDisplayAmount(for: transaction, currency: displayCurrency) ?? 0)
        }
        return [
            RealizedCurrencySection(
                currency: displayCurrency,
                transactions: realizedTransactions,
                total: total
            )
        ]
    }

    private var headerRealizedTotal: Decimal {
        realizedCurrencySections.first?.total ?? 0
    }

    private var headerRealizedCurrency: Currency {
        displayCurrency
    }

    private var unrealizedRows: [UnrealizedRow] {
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            priceMap["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }

        return categoryHoldings.compactMap { holding in
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let currentPrice = priceMap[key]?.displayPrice else { return nil }
            let marketValueOriginal = holding.totalQuantity * currentPrice
            let unrealizedOriginal = marketValueOriginal - holding.totalCost
            let displayAmount = usesOriginalAmounts
                ? unrealizedOriginal
                : convertToDisplayCurrency(amount: unrealizedOriginal, currency: holding.currency)
            let percent = holding.totalCost > 0 ? (unrealizedOriginal / holding.totalCost) * 100 : 0
            return UnrealizedRow(
                id: holding.id,
                name: displayName(for: holding),
                amount: displayAmount,
                percent: percent
            )
        }
        .sorted {
            NSDecimalNumber(decimal: abs($0.amount)).compare(NSDecimalNumber(decimal: abs($1.amount))) == .orderedDescending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    CurrencyToggleTitleLabel(
                        title: "損益",
                        currency: displayCurrency,
                        font: .subheadline,
                        weight: .medium,
                        color: .secondaryText,
                        chipTint: accentColor,
                        titleLineLimit: 1,
                        canToggle: canToggleCurrency,
                        action: onCurrencyToggle
                    )
                    HStack(alignment: .top, spacing: 12) {
                        gainLossHeaderColumn(
                            title: "未實現損益",
                            amount: displayUnrealized,
                            percentText: "\(displayUnrealizedPercent.formatted(fractionDigits: 1))%"
                        )
                        Divider()
                            .frame(minHeight: 52)
                            .overlay(Color.separator.opacity(0.45))
                        gainLossHeaderColumn(
                            title: "已實現損益",
                            amount: headerRealizedTotal,
                            percentText: nil
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleExpanded)
                }
                Spacer(minLength: 0)
                Button(action: toggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(spacing: 16) {
                    unrealizedSection
                    if isLoadingDetails {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if detailLoadFailed {
                        Text("無法載入明細，請稍後再試")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    } else if realizedCurrencySections.isEmpty {
                        Text("尚無已實現損益交易")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    } else {
                        ForEach(realizedCurrencySections) { section in
                            realizedSection(
                                transactions: section.transactions,
                                currency: section.currency,
                                total: section.total
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.separator.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            Task { await loadDetailsIfNeeded(force: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
            scheduleDetailsRefresh(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            scheduleDetailsRefresh(force: true)
        }
        .task {
            await loadDetailsIfNeeded(force: false)
        }
    }

    private func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
    }

    private func gainLossHeaderColumn(title: String, amount: Decimal, percentText: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            CurrencyAmountWithChip(
                text: amount.formatted(
                    currency: displayCurrency,
                    fractionDigits: amountFractionDigits,
                    showSymbol: false
                ),
                currency: displayCurrency,
                font: .headline,
                weight: .bold,
                color: Color.marketColor(for: amount),
                chipTint: accentColor,
                spacing: 5,
                showsChip: false,
                minimumScaleFactor: 0.68
            )
            .lineLimit(1)
            if let percentText {
                Text(percentText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.marketColor(for: amount))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func convertToDisplayCurrency(amount: Decimal, currency: Currency) -> Decimal {
        if currency == displayCurrency { return amount }
        if let converted = convertedAmount(
            amount,
            from: currency,
            to: displayCurrency,
            usdToTwdRate: usdToTwdRate
        ) {
            return converted
        }
        if displayCurrency == baseCurrency, twdPerBaseCurrency > 0 {
            if currency == .USD {
                return (amount * usdToTwdRate) / twdPerBaseCurrency
            }
            if currency == .TWD {
                return amount / twdPerBaseCurrency
            }
        }
        return amount
    }

    private func realizedDisplayAmount(for transaction: Transaction, currency: Currency) -> Decimal? {
        guard let realized = transaction.realizedGainLoss else { return nil }
        let tradeCurrency = TransactionDisplayFormatter(transaction: transaction).tradePriceCurrency
        return convertedAmount(
            realized,
            from: tradeCurrency,
            to: currency,
            usdToTwdRate: transaction.exchangeRate ?? usdToTwdRate
        )
    }

    private func convertedAmount(
        _ amount: Decimal,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        usdToTwdRate rate: Decimal?
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

    private func scheduleDetailsRefresh(force: Bool) {
        RealizedPLDetailCache.invalidate()
        detailsRevision = UUID()
        guard isExpanded else { return }
        Task { await loadDetailsIfNeeded(force: force) }
    }

    private func loadDetailsIfNeeded(force: Bool) async {
        let userId = AppUser.id
        if !force, RealizedPLDetailCache.isLoaded(for: userId) {
            detailsRevision = UUID()
            return
        }
        isLoadingDetails = true
        detailLoadFailed = false
        defer { isLoadingDetails = false }

        do {
            let allTransactions = try await MockDataService.shared.fetchAllTransactions(userId: userId)
            RealizedPLDetailCache.apply(userId: userId, transactions: allTransactions)
            detailsRevision = UUID()
        } catch {
            detailLoadFailed = true
        }
    }

    private var unrealizedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CurrencyTitleLabel(
                title: "未實現損益",
                currency: displayCurrency,
                font: .subheadline,
                weight: .semibold,
                color: .primaryText,
                chipTint: accentColor,
                titleLineLimit: 1
            )

            if unrealizedRows.isEmpty {
                Text("尚無可計算的未實現損益")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                CardView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("名稱")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondaryText)
                                .frame(width: 90, alignment: .leading)

                            Spacer(minLength: 8)

                            Text("損益")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondaryText)
                                .frame(width: 120, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(Color.secondaryBackground)
                        .cornerRadius(8)

                        VStack(spacing: 0) {
                            ForEach(unrealizedRows) { row in
                                unrealizedHoldingRow(row)
                                if row.id != unrealizedRows.last?.id {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func realizedSection(transactions: [Transaction], currency: Currency, total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CurrencyTitleLabel(
                    title: "已實現損益",
                    currency: currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: .primaryText,
                    chipTint: accentColor,
                    titleLineLimit: 1
                )

                Spacer(minLength: 8)

                CurrencyAmountWithChip(
                    text: total.formatted(currency: currency),
                    currency: currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: Color.marketColor(for: total),
                    chipTint: accentColor,
                    showsChip: false
                )
            }

            CardView {
                VStack(spacing: 0) {
                    HStack {
                        Text("名稱")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                            .frame(width: 90, alignment: .leading)

                        Spacer(minLength: 8)

                        Text("損益")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .background(Color.secondaryBackground)
                    .cornerRadius(8)

                    VStack(spacing: 0) {
                        ForEach(transactions) { transaction in
                            realizedTransactionRow(transaction: transaction, currency: currency)

                            if transaction.id != transactions.last?.id {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    private func unrealizedHoldingRow(_ row: UnrealizedRow) -> some View {
        HStack {
            Text(row.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.amount.formatted(
                    currency: displayCurrency,
                    fractionDigits: amountFractionDigits,
                    showSymbol: false
                ))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.marketColor(for: row.amount))

                Text("(\(row.percent.formattedPercentValue(maxFractionDigits: 1))%)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func realizedTransactionRow(transaction: Transaction, currency: Currency) -> some View {
        let display = TransactionDisplayFormatter(transaction: transaction)
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleTransaction(transaction.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName(for: transaction))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        Text(formatDate(transaction.transactionDate))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(width: 90, alignment: .leading)

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        if let realized = realizedDisplayAmount(for: transaction, currency: currency) {
                            Text(realized.formatted(
                                currency: currency,
                                fractionDigits: currency == .TWD ? 0 : 2,
                                showSymbol: false
                            ))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.marketColor(for: realized))
                        } else {
                            Text("--")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondaryText)
                        }

                        if let percentText = display.realizedGainLossPercentText {
                            Text(percentText)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .frame(width: 120, alignment: .trailing)

                    Image(systemName: expandedTransactionIds.contains(transaction.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expandedTransactionIds.contains(transaction.id) {
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("數量")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Text(display.realizedQuantityText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 32)
                        .background(Color.separator.opacity(0.7))

                    VStack(spacing: 6) {
                        Text("成本價")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        if let costText = display.realizedCostPerUnitText {
                            Text(costText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        } else {
                            Text("--")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 32)
                        .background(Color.separator.opacity(0.7))

                    VStack(spacing: 6) {
                        Text("成交均價")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Text(display.realizedSellPriceText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.secondaryBackground)
                .cornerRadius(10)
            }
        }
    }

    private func currencySortRank(_ currency: Currency) -> Int {
        Currency.allCases.firstIndex(of: currency) ?? Int.max
    }

    private func toggleTransaction(_ id: String) {
        if expandedTransactionIds.contains(id) {
            expandedTransactionIds.remove(id)
        } else {
            expandedTransactionIds.insert(id)
        }
    }

    private func displayName(for transaction: Transaction) -> String {
        switch transaction.assetType {
        case .stockTW:
            return SymbolListService.twDisplayName(for: transaction.symbol) ?? transaction.symbol
        case .crypto:
            return SymbolListService.cryptoDisplayName(
                for: transaction.symbol,
                storedName: transaction.buySymbolNameFromNotes
            )
        case .stockUS:
            return transaction.symbol.uppercased()
        default:
            return transaction.symbol
        }
    }

    private func displayName(for holding: AggregatedHoldingSnapshot) -> String {
        switch holding.assetType {
        case .stockTW:
            return SymbolListService.twDisplayName(for: holding.symbol) ?? holding.name ?? holding.symbol
        case .crypto:
            return SymbolListService.cryptoDisplayName(for: holding.symbol, storedName: holding.name)
        case .stockUS:
            return holding.symbol.uppercased()
        default:
            return holding.name ?? holding.symbol
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        return formatter.string(from: date)
    }
}
