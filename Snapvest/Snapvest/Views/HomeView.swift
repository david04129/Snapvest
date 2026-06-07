//
//  HomeView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int
    var onOpenSettings: () -> Void = {}
    @EnvironmentObject private var viewModel: PortfolioViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @ObservedObject private var homePrivacy = HomePrivacyManager.shared
    @State private var userId: String = AppUser.id
    @State private var navigationStackResetID = UUID()
    @State private var isShareSheetPresented = false

    @State private var trendMetricMode: TrendMetricMode = .netWorth
    @State private var trendTimeRange: DateRangePreset = .sevenDays
    @State private var trendPoints: [TrendChartPoint] = []
    @State private var trendCustomStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var trendCustomEndDate: Date = Date()
    @State private var pieChartMode: PieChartDisplayMode = .totalAssets
    @State private var performanceMode: PerformanceDisplayMode = .gainLoss
    @ObservedObject private var pieGroupingStore = PieChartGroupingStore.shared

    private var showsHomeOnboardingEmpty: Bool {
        accountsViewModel.accounts.filter { !$0.isArchived }.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 20) {
                    if showsHomeOnboardingEmpty {
                        OnboardingEmptyStateCard(
                            icon: "house.fill",
                            title: "歡迎使用 Walleaf",
                            message: "建立帳戶後，這裡會顯示淨資產、走勢圖與資產配置。",
                            actionTitle: "去新增帳戶"
                        ) {
                            selectedTab = AppTab.accounts.rawValue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                NotificationCenter.default.post(name: .openAddAccountSheet, object: nil)
                            }
                        }
                    }

                    Group {
                        HomeTrendChartSection(
                            userId: userId,
                            currency: viewModel.viewCurrency,
                            metricMode: $trendMetricMode,
                            timeRange: $trendTimeRange,
                            trendPoints: $trendPoints,
                            customStartDate: $trendCustomStartDate,
                            customEndDate: $trendCustomEndDate
                        )
                        
                        // 淨資產卡片
                        NetWorthCardView(viewModel: viewModel)
                        
                        // 投資資產卡片
                        InvestmentAssetsCardView(viewModel: viewModel)
                        
                        // 現金卡片
                        CashCardView(viewModel: viewModel)
                        
                        // 今日損益卡片
                        TodayPLCardView(viewModel: viewModel)
                        
                        // 已實現損益卡片（隱私模式整塊隱藏）
                        if !homePrivacy.isAmountHidden {
                            RealizedPLCardView(viewModel: viewModel, userId: userId)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .allowsHitTesting(!pieGroupingStore.isEditingGroups)
                    .opacity(pieGroupingStore.isEditingGroups ? 0.5 : 1)
                    .animation(ChartMotion.switchQuick, value: pieGroupingStore.isEditingGroups)
                    
                    // 圓餅圖（總資產 / 投資組合 / 所有細項）
                    if viewModel.pieChartInputs != nil {
                        Group {
                            HomePieChartSection(
                                inputs: viewModel.pieChartInputs,
                                totalAssets: viewModel.totalAssets,
                                totalInvestments: viewModel.totalInvestments,
                                currency: viewModel.viewCurrency,
                                twdPerBaseCurrency: viewModel.twdPerBaseCurrency,
                                onScrollToChart: {
                                    withAnimation(.easeInOut(duration: 0.38)) {
                                        scrollProxy.scrollTo(
                                            HomePieChartScrollAnchor.donut,
                                            anchor: UnitPoint(x: 0.5, y: 0.12)
                                        )
                                    }
                                },
                                mode: $pieChartMode,
                                groupingStore: pieGroupingStore
                            )
                            
                            HomePerformanceChartSection(
                                inputs: viewModel.pieChartInputs,
                                pieMode: pieChartMode,
                                groupingStore: pieGroupingStore,
                                mode: $performanceMode,
                                currency: viewModel.viewCurrency,
                                twdPerBaseCurrency: viewModel.twdPerBaseCurrency
                            )
                            .snapHomeSummaryMetricStyle()
                        }
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.22), value: homePrivacy.isAmountHidden)
            }
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                AppTabTopChrome {
                    customHeaderBar(icon: "house.fill", title: "首頁")
                }
            }
            .refreshable {
                guard !pieGroupingStore.isEditingGroups else { return }
                await ManualRefreshCooldown.shared.performIfAllowed {
                    await SnapshotRefreshCoordinator.refreshOnUserPull(
                        userId: userId,
                        portfolioViewModel: viewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { notification in
                guard notification.userInfo?[SnapshotUpdateUserInfoKey.alreadyApplied] as? Bool != true else { return }
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: viewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel,
                        rebuildAccountDetailCache: false
                    )
                }
            }
        }
        .environment(\.homeAmountsHidden, homePrivacy.isAmountHidden)
        .fullScreenCover(isPresented: $isShareSheetPresented) {
            HomeShareSheet(
                trendPoints: $trendPoints,
                trendMetricMode: trendMetricMode,
                trendTimeRange: trendTimeRange,
                trendCustomStart: trendCustomStartDate,
                trendCustomEnd: trendCustomEndDate,
                pieInputs: viewModel.pieChartInputs,
                pieMode: pieChartMode,
                totalAssets: viewModel.totalAssets,
                totalInvestments: viewModel.totalInvestments,
                performanceMode: performanceMode,
                currency: viewModel.viewCurrency,
                twdPerBaseCurrency: viewModel.twdPerBaseCurrency
            )
        }
        .id(navigationStackResetID)
        .resetNavigationWhenTabReappears(selectedTab: $selectedTab, resignedTab: .home) {
            navigationStackResetID = UUID()
        }
    }

    private func customHeaderBar(icon: String, title: String) -> some View {
        HStack {
            // 左側：ICON + 標題
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                HomeShareButton {
                    guard !pieGroupingStore.isEditingGroups else { return }
                    isShareSheetPresented = true
                }
                .disabled(pieGroupingStore.isEditingGroups)
                .opacity(pieGroupingStore.isEditingGroups ? 0.45 : 1)
                HomeAmountPrivacyToggleButton()
                    .disabled(pieGroupingStore.isEditingGroups)
                    .opacity(pieGroupingStore.isEditingGroups ? 0.45 : 1)
            }
            
            AppHeaderMoreButton(action: onOpenSettings)
            .disabled(pieGroupingStore.isEditingGroups)
            .opacity(pieGroupingStore.isEditingGroups ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
}

// MARK: - 首頁可展開卡片標頭

private struct HomeCardExpandChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondaryText)
            .frame(width: 24, height: 24)
    }
}

private struct HomeExpandableCardHeader<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                content()
                Spacer(minLength: 0)
                HomeCardExpandChevron(isExpanded: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 首頁卡片展開明細列
private struct HomeCardDetailRow: View {
    let label: String
    let value: String
    var currency: Currency? = nil
    var valueColor: Color = .primaryText
    var emphasized: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer(minLength: 8)
            if let currency {
                CurrencyAmountWithChip(
                    text: value,
                    currency: currency,
                    font: .subheadline,
                    weight: emphasized ? .bold : .semibold,
                    color: valueColor
                )
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(emphasized ? .bold : .semibold)
                    .foregroundColor(valueColor)
            }
        }
    }
}

private struct HomeCardCurrencyDetailRow: View {
    let dotColor: Color
    let label: String
    let value: String
    let currency: Currency
    var footnote: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CurrencyCodeChip(currency: currency, tint: dotColor)

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                CurrencyAmountLabel(
                    text: value,
                    currency: currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: .primaryText,
                    chipTint: dotColor
                )
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

// MARK: - 淨資產卡片
struct NetWorthCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isExpanded: Bool = false
    
    var netWorth: Decimal {
        viewModel.totalAssets - viewModel.totalLiabilities
    }

    var netWorthRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (netWorth / viewModel.totalAssets) * 100
    }

    private var debtRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalLiabilities / viewModel.totalAssets) * 100
    }

    var body: some View {
        AccentBarCard(title: "淨資產", titleCurrency: viewModel.viewCurrency, accentColor: .homeNetWorthAccent) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    AdaptivePercentageRingView(
                        sharePercent: netWorthRatio,
                        accentColor: .homeNetWorthAccent,
                        ringSize: 50,
                        lineWidth: 7,
                        animatesProgressChanges: false
                    )

                    CurrencyAmountWithChip(
                        text: HomeAmountPrivacyFormat.currency(netWorth, currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                        currency: viewModel.viewCurrency,
                        font: .snapAmountHero,
                        weight: .bold,
                        color: .primaryText,
                        animatesNumericContentTransition: false
                    )
                }
                
                if isExpanded {
                    VStack(spacing: 10) {
                        HomeCardDetailRow(
                            label: "總資產",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalAssets,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency
                        )
                        HomeCardDetailRow(
                            label: viewModel.totalLiabilities > 0
                                ? "負債（占總資產 \(debtRatio.formatted(fractionDigits: 1))%）"
                                : "負債",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalLiabilities,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency,
                            valueColor: viewModel.totalLiabilities > 0 ? .lossRed : .primaryText
                        )
                        Divider()
                        HomeCardDetailRow(
                            label: "淨資產",
                            value: HomeAmountPrivacyFormat.currency(
                                netWorth,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency,
                            valueColor: .homeNetWorthAccent,
                            emphasized: true
                        )
                    }
                }
            }
        }
        .snapHomeSummaryMetricStyle()
    }
}

// MARK: - 投資資產卡片
struct InvestmentAssetsCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isExpanded: Bool = false
    
    var investmentRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalInvestments / viewModel.totalAssets) * 100
    }

    var body: some View {
        AccentBarCard(title: "投資資產", titleCurrency: viewModel.viewCurrency, accentColor: .homeInvestmentsAccent) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    AdaptivePercentageRingView(
                        sharePercent: investmentRatio,
                        accentColor: .homeInvestmentsAccent,
                        ringSize: 50,
                        lineWidth: 7,
                        animatesProgressChanges: false
                    )

                    CurrencyAmountWithChip(
                        text: HomeAmountPrivacyFormat.currency(viewModel.totalInvestments, currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                        currency: viewModel.viewCurrency,
                        font: .snapAmountHero,
                        weight: .bold,
                        color: .primaryText,
                        chipTint: .homeInvestmentsAccent,
                        animatesNumericContentTransition: false
                    )
                }
                
                if isExpanded {
                    let cost = viewModel.totalInvestments - viewModel.unrealizedGainLoss
                    let returnPercent = cost > 0
                        ? (viewModel.unrealizedGainLoss / cost * 100).formatted(fractionDigits: 2)
                        : nil
                    let gainLossColor = Color.marketColor(for: viewModel.unrealizedGainLoss)

                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("未實現損益")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            Spacer(minLength: 8)
                            HStack(spacing: 4) {
                                if !hideHomeAmounts {
                                    Image(systemName: MarketDirectionSymbol.systemName(for: viewModel.unrealizedGainLoss))
                                        .font(.caption2)
                                        .foregroundColor(gainLossColor)
                                }
                                if hideHomeAmounts, let returnPercent {
                                    Text("(\(returnPercent)%)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(gainLossColor)
                                } else {
                                    Text(
                                        HomeAmountPrivacyFormat.currencyNumber(
                                            viewModel.unrealizedGainLoss,
                                            currency: viewModel.viewCurrency,
                                            hidden: hideHomeAmounts
                                        )
                                        + (returnPercent.map { " (\($0)%)" } ?? "")
                                    )
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(gainLossColor)
                                }
                            }
                        }

                        HomeCardDetailRow(
                            label: "成本",
                            value: HomeAmountPrivacyFormat.currency(
                                cost,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency
                        )

                        Divider()

                        HomeCardDetailRow(
                            label: "目前總市值",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalInvestments,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency,
                            emphasized: true
                        )
                        HomeCardDetailRow(
                            label: "占總資產",
                            value: "\(investmentRatio.formatted(fractionDigits: 1))%",
                            valueColor: .homeInvestmentsAccent
                        )
                    }
                }
            }
        }
        .snapHomeSummaryMetricStyle()
    }
}

// MARK: - 現金卡片
struct CashCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isExpanded: Bool = false
    
    var cashRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalCash / viewModel.totalAssets) * 100
    }

    private var displayUsdToTwdRate: Decimal {
        let fromPie = viewModel.pieChartInputs?.usdToTwdRate ?? 0
        if fromPie > 0 { return fromPie }
        return ExchangeRateSessionCache.usdToTwd ?? 0
    }
    private var cashRows: [(currency: Currency, amount: Decimal, valueTWD: Decimal, color: Color)] {
        Currency.baseCurrencyOptions.compactMap { currency in
            guard let amount = viewModel.cashByCurrency[currency],
                  amount > 0,
                  let valueTWD = cashValueInTWD(currency: currency, amount: amount),
                  valueTWD > 0 else {
                return nil
            }
            return (
                currency: currency,
                amount: amount,
                valueTWD: valueTWD,
                color: cashColor(for: currency)
            )
        }
    }
    private var totalCashTWDForRows: Decimal {
        cashRows.reduce(0) { $0 + $1.valueTWD }
    }

    private func baseCurrencyAmount(fromTWD amount: Decimal) -> Decimal {
        guard viewModel.viewCurrency != .TWD,
              viewModel.twdPerBaseCurrency > 0 else {
            return amount
        }
        return amount / viewModel.twdPerBaseCurrency
    }
    
    private func cashValueInTWD(currency: Currency, amount: Decimal) -> Decimal? {
        if let inputs = viewModel.pieChartInputs {
            return inputs.cashValueInTWD(currency: currency, amount: amount)
        }
        if currency == .TWD { return amount }
        if currency == .USD, displayUsdToTwdRate > 0 { return amount * displayUsdToTwdRate }
        return nil
    }
    private func cashColor(for currency: Currency) -> Color {
        guard let inputs = viewModel.pieChartInputs else {
            return currency == .USD ? .allocationUsdCash : .allocationTwdCash
        }
        return HoldingChartMetrics.chartColor(
            forItemId: PieChartGroupingEngine.cashItemId(for: currency),
            inputs: inputs
        )
    }
    var body: some View {
        AccentBarCard(title: "現金", titleCurrency: viewModel.viewCurrency, accentColor: .homeCashAccent) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    AdaptivePercentageRingView(
                        sharePercent: cashRatio,
                        accentColor: .homeCashAccent,
                        trimStyle: .counterclockwiseTail,
                        ringSize: 50,
                        lineWidth: 7,
                        animatesProgressChanges: false
                    )

                    CurrencyAmountWithChip(
                        text: HomeAmountPrivacyFormat.currency(viewModel.totalCash, currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                        currency: viewModel.viewCurrency,
                        font: .snapAmountHero,
                        weight: .bold,
                        color: .primaryText,
                        chipTint: .homeCashAccent,
                        animatesNumericContentTransition: false
                    )
                }
                
                if !isExpanded {
                    UsdTwdRateCaptionView(
                        preferredRate: displayUsdToTwdRate,
                        displayCurrency: viewModel.viewCurrency,
                        twdPerDisplayCurrency: viewModel.twdPerBaseCurrency,
                        alignment: .leading
                    )
                }

                if isExpanded {
                    VStack(spacing: 10) {
                        ForEach(cashRows, id: \.currency) { row in
                            let pct = totalCashTWDForRows > 0 ? (row.valueTWD / totalCashTWDForRows * 100) : 0
                            let baseEquivalentText = HomeAmountPrivacyFormat.currencyNumber(
                                baseCurrencyAmount(fromTWD: row.valueTWD),
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            )
                            let footnote = row.currency == viewModel.viewCurrency || hideHomeAmounts
                                ? nil
                                : "≈ \(baseEquivalentText)"
                            HomeCardCurrencyDetailRow(
                                dotColor: row.color,
                                label: "\(pct.formatted(fractionDigits: 1))%",
                                value: HomeAmountPrivacyFormat.currency(row.amount, currency: row.currency, hidden: hideHomeAmounts),
                                currency: row.currency,
                                footnote: footnote
                            )
                        }
                        Divider()
                        HomeCardDetailRow(
                            label: "合計",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalCash,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            currency: viewModel.viewCurrency,
                            emphasized: true
                        )
                        HomeCardDetailRow(
                            label: "占總資產",
                            value: "\(cashRatio.formatted(fractionDigits: 1))%",
                            valueColor: .homeCashAccent
                        )
                        UsdTwdRateCaptionView(
                            preferredRate: displayUsdToTwdRate,
                            displayCurrency: viewModel.viewCurrency,
                            twdPerDisplayCurrency: viewModel.twdPerBaseCurrency,
                            alignment: .leading
                        )
                    }
                }
            }
        }
        .snapHomeSummaryMetricStyle()
    }
}

// MARK: - 今日損益卡片
struct TodayPLCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isExpanded = false

    private var summary: TodayPLSummary {
        viewModel.todayPLSummary
    }

    private var displayChange: Decimal {
        displayAmount(summary.totalChangeTWD)
    }

    var body: some View {
        AccentBarCard(title: "今日損益", titleCurrency: viewModel.viewCurrency, accentColor: .appPrimary) {
            VStack(spacing: 16) {
                if summary.hasData, !summary.categories.isEmpty {
                    HomeExpandableCardHeader(isExpanded: $isExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            CurrencyAmountWithChip(
                                text: HomeAmountPrivacyFormat.currency(displayChange, currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                                currency: viewModel.viewCurrency,
                                font: .snapAmountHero,
                                weight: .bold,
                                color: Color.marketColor(for: summary.totalChangeTWD),
                                animatesNumericContentTransition: false
                            )

                            todayPLPercentLabel(
                                percent: summary.totalChangePercent,
                                font: .subheadline,
                                weight: .semibold
                            )
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            if summary.hasData {
                                CurrencyAmountWithChip(
                                    text: HomeAmountPrivacyFormat.currency(displayChange, currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                                    currency: viewModel.viewCurrency,
                                    font: .snapAmountHero,
                                    weight: .bold,
                                    color: Color.marketColor(for: summary.totalChangeTWD),
                                    animatesNumericContentTransition: false
                                )

                                todayPLPercentLabel(
                                    percent: summary.totalChangePercent,
                                    font: .subheadline,
                                    weight: .semibold
                                )
                            } else {
                                Text("—")
                                    .font(.snapAmountHero)
                                    .foregroundColor(.secondaryText)
                                Text("尚無足夠股價資料")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                        Spacer()
                    }
                }

                if isExpanded, summary.hasData {
                    VStack(spacing: 10) {
                        ForEach(summary.categories) { category in
                            todayPLCategoryRow(category)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .snapHomeSummaryMetricStyle()
    }

    @ViewBuilder
    private func todayPLCategoryRow(_ category: TodayPLCategorySummary) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor(for: category.assetType))
                .frame(width: 4, height: 32)

            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                CurrencyAmountWithChip(
                    text: HomeAmountPrivacyFormat.currency(displayAmount(category.changeTWD), currency: viewModel.viewCurrency, hidden: hideHomeAmounts),
                    currency: viewModel.viewCurrency,
                    font: .subheadline,
                    weight: .semibold,
                    color: Color.marketColor(for: category.changeTWD)
                )

                todayPLPercentLabel(
                    percent: category.changePercent,
                    font: .caption,
                    weight: .medium
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func todayPLPercentLabel(percent: Decimal, font: Font, weight: Font.Weight) -> some View {
        let up = percent >= 0
        return HStack(spacing: 3) {
            Image(systemName: MarketDirectionSymbol.systemName(isUp: up))
                .font(.caption2.weight(.bold))
            Text("\(signedPercent(percent))%")
                .font(font)
                .fontWeight(weight)
        }
        .foregroundColor(Color.marketColor(for: percent))
    }

    private func signedPercent(_ value: Decimal) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + value.formatted(fractionDigits: 2)
    }

    private func displayAmount(_ twdAmount: Decimal) -> Decimal {
        guard viewModel.viewCurrency != .TWD,
              viewModel.twdPerBaseCurrency > 0 else {
            return twdAmount
        }
        return twdAmount / viewModel.twdPerBaseCurrency
    }

    private func accentColor(for assetType: AssetType) -> Color {
        switch assetType {
        case .stockTW: return .stockTWDeepAmber
        case .stockUS: return .stockUSDeep
        case .crypto: return .cryptoDeep
        default: return .appPrimary
        }
    }
}

// MARK: - 已實現損益卡片
struct RealizedPLCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    let userId: String
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
    
    private var realizedTransactionsByCurrency: [Currency: [Transaction]] {
        let _ = detailsRevision
        let sells = RealizedPLDetailCache.sellTransactions
        return Dictionary(grouping: sells, by: { $0.currency })
    }

    private var realizedCurrencySections: [RealizedCurrencySection] {
        realizedTransactionsByCurrency.compactMap { currency, transactions in
            let realizedTransactions = transactions.filter { $0.realizedGainLoss != nil }
            let total = realizedTransactions.reduce(Decimal(0)) { partial, transaction in
                partial + (transaction.realizedGainLoss ?? 0)
            }
            guard !realizedTransactions.isEmpty, total != 0 else { return nil }
            return RealizedCurrencySection(
                currency: currency,
                transactions: realizedTransactions,
                total: total
            )
        }
        .sorted { lhs, rhs in
            currencySortRank(lhs.currency) < currencySortRank(rhs.currency)
        }
    }
    
    var body: some View {
        AccentBarCard(title: "已實現損益", titleCurrency: viewModel.viewCurrency, accentColor: .appPrimary) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    CurrencyAmountWithChip(
                        text: viewModel.realizedGainLoss.formatted(currency: viewModel.viewCurrency),
                        currency: viewModel.viewCurrency,
                        font: .snapAmountHero,
                        weight: .bold,
                        color: Color.marketColor(for: viewModel.realizedGainLoss),
                        animatesNumericContentTransition: false
                    )
                }
                
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
        }
        .snapHomeSummaryMetricStyle()
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
    }

    private func scheduleDetailsRefresh(force: Bool) {
        RealizedPLDetailCache.invalidate()
        detailsRevision = UUID()
        guard isExpanded else { return }
        Task { await loadDetailsIfNeeded(force: force) }
    }
    
    private func loadDetailsIfNeeded(force: Bool) async {
        if !force, RealizedPLDetailCache.isLoaded(for: userId) {
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
            
            if transactions.isEmpty {
                Text("尚無交易")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            } else {
                CardView {
                    VStack(spacing: 0) {
                        // 表頭
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
                                let display = TransactionDisplayFormatter(transaction: transaction)
                                VStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            toggleTransaction(transaction.id)
                                        }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(displayName(for: transaction, currency: currency))
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
                                    .buttonStyle(PlainButtonStyle())
                                    
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
    
    private func displayName(for transaction: Transaction, currency: Currency) -> String {
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

#Preview {
    HomeView(selectedTab: .constant(AppTab.home.rawValue))
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
}

