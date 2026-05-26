//
//  HomeView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: Int
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        // 走勢圖（過去：Supabase 每日快照；今天：本機即時）
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
                        HomePieChartSection(
                            inputs: viewModel.pieChartInputs,
                            totalAssets: viewModel.totalAssets,
                            totalInvestments: viewModel.totalInvestments,
                            mode: $pieChartMode,
                            groupingStore: pieGroupingStore
                        )
                        
                        HomePerformanceChartSection(
                            inputs: viewModel.pieChartInputs,
                            pieMode: pieChartMode,
                            groupingStore: pieGroupingStore,
                            mode: $performanceMode
                        )
                    }
                    
                    DataFreshnessFooterView(style: .valuationTabs)
                }
                .padding()
                .animation(.easeInOut(duration: 0.22), value: homePrivacy.isAmountHidden)
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBar(icon: "house.fill", title: "首頁")
            }
            .refreshable {
                guard !pieGroupingStore.isEditingGroups else { return }
                await SnapshotRefreshCoordinator.rebuildAndNotify(userId: userId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: viewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel
                    )
                }
            }
        }
        .environment(\.homeAmountsHidden, homePrivacy.isAmountHidden)
        .sheet(isPresented: $isShareSheetPresented) {
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
                currency: viewModel.viewCurrency
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
                MarketColorConventionToggleButton()
                    .disabled(pieGroupingStore.isEditingGroups)
                    .opacity(pieGroupingStore.isEditingGroups ? 0.45 : 1)
                ThemeToggleButton()
                    .disabled(pieGroupingStore.isEditingGroups)
                    .opacity(pieGroupingStore.isEditingGroups ? 0.45 : 1)
            }
            
            // 右側：使用者頭像
            Button(action: {
                // TODO: 點擊後的功能
            }) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.appPrimary)
                            .font(.caption)
                    }
            }
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
            HStack(alignment: .center, spacing: 16) {
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
    var valueColor: Color = .primaryText
    var emphasized: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .fontWeight(emphasized ? .bold : .semibold)
                .foregroundColor(valueColor)
        }
    }
}

private struct HomeCardCurrencyDetailRow: View {
    let dotColor: Color
    let label: String
    let value: String
    var footnote: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
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
        AccentBarCard(title: "淨資產", accentColor: .appPrimary) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    ZStack {
                        let netWorthShare = CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue)

                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(Color.appPrimary.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)

                        Circle()
                            .trim(from: 0, to: netWorthShare)
                            .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))

                        Text("\(netWorthRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    }
                    
                    Text(HomeAmountPrivacyFormat.currency(netWorth, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
                }
                
                if isExpanded {
                    VStack(spacing: 10) {
                        HomeCardDetailRow(
                            label: "總資產",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalAssets,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            )
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
                            valueColor: .appPrimary,
                            emphasized: true
                        )
                    }
                }
            }
        }
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
        AccentBarCard(title: "投資資產", accentColor: .stockUSColor) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    ZStack {
                        let investmentRatioDouble = CGFloat(NSDecimalNumber(decimal: investmentRatio / 100).doubleValue)
                        
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(Color.stockUSColor.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: investmentRatioDouble)
                            .stroke(Color.stockUSColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(investmentRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.stockUSColor)
                    }
                    
                    Text(HomeAmountPrivacyFormat.currency(viewModel.totalInvestments, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
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
                                    Image(systemName: viewModel.unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
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
                                        HomeAmountPrivacyFormat.currency(
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
                            )
                        )

                        Divider()

                        HomeCardDetailRow(
                            label: "目前總市值",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalInvestments,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            emphasized: true
                        )
                        HomeCardDetailRow(
                            label: "占總資產",
                            value: "\(investmentRatio.formatted(fractionDigits: 1))%",
                            valueColor: .stockUSColor
                        )
                    }
                }
            }
        }
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
    
    var body: some View {
        AccentBarCard(title: "現金", accentColor: .allocationTwdCash) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    ZStack {
                        let cashColor = Color.allocationTwdCash
                        let cashRatioDouble = CGFloat(NSDecimalNumber(decimal: cashRatio / 100).doubleValue)
                        
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(cashColor.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 1.0 - cashRatioDouble, to: 1.0)
                            .stroke(cashColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(cashRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(cashColor)
                    }
                    
                    Text(HomeAmountPrivacyFormat.currency(viewModel.totalCash, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
                }
                
                if !isExpanded {
                    UsdTwdRateCaptionView(preferredRate: displayUsdToTwdRate, alignment: .leading)
                }

                if isExpanded {
                    let twdCash = viewModel.cashByCurrency[.TWD] ?? 0
                    let usdCash = viewModel.cashByCurrency[.USD] ?? 0
                    let usdToTwdRate = displayUsdToTwdRate
                    let usdCashTWD = usdCash * usdToTwdRate
                    let totalCashTWD = twdCash + usdCashTWD
                    let twdPct = totalCashTWD > 0 ? (twdCash / totalCashTWD * 100) : 0
                    let usdPct = totalCashTWD > 0 ? (usdCashTWD / totalCashTWD * 100) : 0
                    let usdFootnote: String? = {
                        guard !hideHomeAmounts, usdCash > 0, usdToTwdRate > 0 else { return nil }
                        return "≈ \(usdCashTWD.formatted(currency: .TWD, fractionDigits: 0))"
                    }()

                    VStack(spacing: 10) {
                        HomeCardCurrencyDetailRow(
                            dotColor: .allocationTwdCash,
                            label: "台幣（\(twdPct.formatted(fractionDigits: 1))%）",
                            value: HomeAmountPrivacyFormat.currency(twdCash, currency: .TWD, hidden: hideHomeAmounts)
                        )
                        HomeCardCurrencyDetailRow(
                            dotColor: .allocationUsdCash,
                            label: "美金（\(usdPct.formatted(fractionDigits: 1))%）",
                            value: HomeAmountPrivacyFormat.currency(usdCash, currency: .USD, hidden: hideHomeAmounts),
                            footnote: usdFootnote
                        )
                        Divider()
                        HomeCardDetailRow(
                            label: "合計",
                            value: HomeAmountPrivacyFormat.currency(
                                viewModel.totalCash,
                                currency: viewModel.viewCurrency,
                                hidden: hideHomeAmounts
                            ),
                            emphasized: true
                        )
                        HomeCardDetailRow(
                            label: "占總資產",
                            value: "\(cashRatio.formatted(fractionDigits: 1))%",
                            valueColor: .allocationTwdCash
                        )
                        UsdTwdRateCaptionView(preferredRate: displayUsdToTwdRate, alignment: .leading)
                    }
                }
            }
        }
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
        AccentBarCard(title: "今日損益", accentColor: .appPrimary) {
            VStack(spacing: 16) {
                if summary.hasData, !summary.categories.isEmpty {
                    HomeExpandableCardHeader(isExpanded: $isExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(HomeAmountPrivacyFormat.currency(displayChange, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                                .font(.snapAmountHero)
                                .foregroundColor(Color.marketColor(for: summary.totalChangeTWD))

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
                                Text(HomeAmountPrivacyFormat.currency(displayChange, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                                    .font(.snapAmountHero)
                                    .foregroundColor(Color.marketColor(for: summary.totalChangeTWD))

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
                Text(HomeAmountPrivacyFormat.currency(displayAmount(category.changeTWD), currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.marketColor(for: category.changeTWD))

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
            Image(systemName: up ? "arrow.up" : "arrow.down")
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
        guard viewModel.viewCurrency == .USD,
              let rate = viewModel.pieChartInputs?.usdToTwdRate,
              rate > 0 else {
            return twdAmount
        }
        return twdAmount / rate
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
    
    private var realizedTransactionsByCurrency: [Currency: [Transaction]] {
        let _ = detailsRevision
        let sells = RealizedPLDetailCache.sellTransactions
        return Dictionary(grouping: sells, by: { $0.currency })
    }
    
    var body: some View {
        AccentBarCard(title: "已實現損益", accentColor: .appPrimary) {
            VStack(spacing: 16) {
                HomeExpandableCardHeader(isExpanded: $isExpanded) {
                    Text(viewModel.realizedGainLoss.formatted(currency: viewModel.viewCurrency))
                        .font(.snapAmountHero)
                        .foregroundColor(Color.marketColor(for: viewModel.realizedGainLoss))
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
                    } else if realizedTransactionsByCurrency.isEmpty {
                        Text("尚無已實現損益交易")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    } else {
                        VStack(spacing: 16) {
                            realizedSection(title: "台幣已實現損益", transactions: realizedTransactionsByCurrency[.TWD] ?? [], currency: .TWD)
                            realizedSection(title: "美金已實現損益", transactions: realizedTransactionsByCurrency[.USD] ?? [], currency: .USD)
                        }
                    }
                }
            }
        }
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

    private func realizedSection(title: String, transactions: [Transaction], currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
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

