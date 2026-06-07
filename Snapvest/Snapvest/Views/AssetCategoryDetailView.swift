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
            if showsCurrencyToggle {
                ToolbarItem(placement: .navigationBarTrailing) {
                    AccountsCurrencyControlsBar(currencyDisplay: $currencyDisplay)
                }
                .sharedBackgroundVisibility(.hidden)
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
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                MetricTile(
                    title: "未實現損益",
                    value: displayUnrealized.formatted(
                        currency: displayCurrency,
                        fractionDigits: marketValueFractionDigits,
                        showSymbol: false
                    ),
                    currency: displayCurrency,
                    valueColor: Color.marketColor(for: displayUnrealized),
                    footnote: "\(displayUnrealizedPercent.formatted(fractionDigits: 1))%",
                    footnoteColor: Color.marketColor(for: displayUnrealized),
                    accentColor: accentColor
                )
                MetricTile(
                    title: "成本",
                    value: displayTotalCost.formatted(
                        currency: displayCurrency,
                        fractionDigits: marketValueFractionDigits,
                        showSymbol: false
                    ),
                    currency: displayCurrency,
                    accentColor: accentColor
                )
            }

            AssetCategoryRealizedPLSection(
                assetType: assetType,
                accentColor: accentColor,
                displayCurrency: displayCurrency,
                usesOriginalAmounts: usesOriginalAmounts,
                twdPerBaseCurrency: twdPerBaseCurrency,
                usdToTwdRate: assetsViewModel.usdToTwdRate,
                baseCurrency: portfolioViewModel.viewCurrency
            )

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
                    accentColor: accentColor
                )
                MetricTile(
                    title: "投資組合佔比",
                    value: "\(portfolioRatio.formatted(fractionDigits: 1))%",
                    valueColor: accentColor,
                    accentColor: accentColor
                )
            }
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

            VStack(alignment: .leading, spacing: 4) {
                Text("持股市值")
                    .font(.caption)
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
                        chipTint: accentColor
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
}

// MARK: - 類別已實現損益（可展開，邏輯對齊首頁 RealizedPLCardView）

private struct AssetCategoryRealizedPLSection: View {
    let assetType: AssetType
    let accentColor: Color
    let displayCurrency: Currency
    let usesOriginalAmounts: Bool
    let twdPerBaseCurrency: Decimal
    let usdToTwdRate: Decimal
    let baseCurrency: Currency

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

    private var categorySells: [Transaction] {
        let _ = detailsRevision
        return RealizedPLDetailCache.sellTransactions.filter { $0.assetType == assetType }
    }

    private var realizedCurrencySections: [RealizedCurrencySection] {
        let grouped = Dictionary(grouping: categorySells, by: \.currency)
        return grouped.compactMap { currency, transactions in
            let realizedTransactions = transactions.filter { $0.realizedGainLoss != nil }
            let total = realizedTransactions.reduce(Decimal.zero) { partial, transaction in
                partial + (transaction.realizedGainLoss ?? 0)
            }
            guard !realizedTransactions.isEmpty else { return nil }
            return RealizedCurrencySection(
                currency: currency,
                transactions: realizedTransactions.sorted { $0.transactionDate > $1.transactionDate },
                total: total
            )
        }
        .sorted { currencySortRank($0.currency) < currencySortRank($1.currency) }
    }

    private var headerRealizedTotal: Decimal {
        if usesOriginalAmounts, let section = realizedCurrencySections.first {
            return section.total
        }
        return realizedCurrencySections.reduce(Decimal.zero) { partial, section in
            partial + convertToDisplayCurrency(amount: section.total, currency: section.currency)
        }
    }

    private var headerRealizedCurrency: Currency {
        usesOriginalAmounts ? assetType.quoteCurrency : displayCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已實現損益")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondaryText)
                        CurrencyAmountWithChip(
                            text: headerRealizedTotal.formatted(
                                currency: headerRealizedCurrency,
                                fractionDigits: usesOriginalAmounts || baseCurrency != .TWD ? 2 : 0,
                                showSymbol: false
                            ),
                            currency: headerRealizedCurrency,
                            font: .snapAmountSecondary,
                            weight: .bold,
                            color: Color.marketColor(for: headerRealizedTotal),
                            chipTint: accentColor
                        )
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
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
                    VStack(spacing: 16) {
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

    private func convertToDisplayCurrency(amount: Decimal, currency: Currency) -> Decimal {
        if currency == displayCurrency { return amount }
        if currency == .USD, displayCurrency == baseCurrency, twdPerBaseCurrency > 0 {
            return (amount * usdToTwdRate) / twdPerBaseCurrency
        }
        if currency == .TWD, displayCurrency == baseCurrency, twdPerBaseCurrency > 0 {
            return amount / twdPerBaseCurrency
        }
        return amount
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

    private func realizedSection(transactions: [Transaction], currency: Currency, total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("已實現損益")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)

                Spacer(minLength: 8)

                CurrencyAmountWithChip(
                    text: total.formatted(currency: currency),
                    currency: currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: Color.marketColor(for: total)
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
                        if let realizedText = display.realizedGainLossText,
                           let realized = transaction.realizedGainLoss {
                            Text(realizedText)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        return formatter.string(from: date)
    }
}
