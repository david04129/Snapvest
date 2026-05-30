//
//  AssetsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AssetsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var viewModel: AssetsViewModel
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var userId: String = AppUser.id
    @State private var selectedSort: SortOption = .totalAssets
    @State private var selectedHolding: HoldingNavigationItem?
    @State private var navigationStackResetID = UUID()
    @State private var holdingsSelectedCategories: Set<AssetType> = []
    @State private var holdingsRatioType: HoldingRatioType = HoldingRatioPreference.get()
    @State private var holdingsCurrencyDisplay: AssetsCurrencyDisplay = .twd
    
    enum SortOption: String, CaseIterable {
        case totalAssets = "總資產由高到低"
        case todayPL = "今日損益由高到低"
    }
    
    private func holdingNavigationItem(for holding: AggregatedHoldingSnapshot) -> HoldingNavigationItem {
        HoldingNavigationBuilder.make(
            aggregatedHolding: holding,
            assetPriceSnapshots: viewModel.assetPriceSnapshots,
            totalAssets: viewModel.totalAssets,
            totalInvestments: viewModel.totalInvestments
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading && !viewModel.hasLoadedOnce {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("載入中...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            AssetsDisplayControlsBar(
                                ratioType: $holdingsRatioType,
                                currencyDisplay: $holdingsCurrencyDisplay
                            )
                            
                            AssetCategorySummariesSection(
                                aggregatedHoldings: viewModel.aggregatedHoldings,
                                assetPriceSnapshots: viewModel.assetPriceSnapshots,
                                totalAssets: viewModel.totalAssets,
                                totalInvestments: viewModel.totalInvestments,
                                usdToTwdRate: viewModel.usdToTwdRate,
                                baseCurrency: portfolioViewModel.viewCurrency,
                                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
                                ratioType: holdingsRatioType,
                                currencyDisplay: holdingsCurrencyDisplay,
                                selectedCategories: holdingsSelectedCategories,
                                onCategoryTap: { assetType in
                                    let willSelect = !holdingsSelectedCategories.contains(assetType)
                                    withAnimation(ChartMotion.switchSpring) {
                                        AssetCategoryFilterSelection.toggle(
                                            assetType,
                                            in: &holdingsSelectedCategories
                                        )
                                    }
                                    guard willSelect else { return }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation(ChartMotion.switchQuick) {
                                            scrollProxy.scrollTo("allHoldings", anchor: .top)
                                        }
                                    }
                                }
                            )
                            
                            AllHoldingsSection(
                                aggregatedHoldings: viewModel.aggregatedHoldings,
                                assetPriceSnapshots: viewModel.assetPriceSnapshots,
                                totalAssets: viewModel.totalAssets,
                                totalInvestments: viewModel.totalInvestments,
                                usdToTwdRate: viewModel.usdToTwdRate,
                                baseCurrency: portfolioViewModel.viewCurrency,
                                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
                                ratioType: holdingsRatioType,
                                currencyDisplay: holdingsCurrencyDisplay,
                                selectedCategories: $holdingsSelectedCategories,
                                onHoldingTap: navigateToHoldingDetail
                            )
                            .id("allHoldings")
                            
                            DataFreshnessFooterView(style: .valuationTabs)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBar(icon: "chart.bar.fill", title: "投資")
            }
            .refreshable {
                await SnapshotRefreshCoordinator.rebuildAndNotify(userId: userId)
            }
            .onAppear {
                holdingsCurrencyDisplay = .twd
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: viewModel,
                        rebuildAccountDetailCache: false
                    )
                    await refreshSelectedHoldingIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                Task { await refreshSelectedHoldingIfNeeded() }
            }
            .navigationDestination(item: $selectedHolding) { item in
                HoldingDetailView(
                    aggregatedHolding: item.aggregatedHolding,
                    assetPriceSnapshot: item.assetPriceSnapshot,
                    totalAssets: item.totalAssets,
                    totalInvestments: item.totalInvestments,
                    initialUsdToTwdRate: viewModel.usdToTwdRate,
                    initialTwdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency
                )
                .id(item)
            }
        }
        .id(navigationStackResetID)
        .resetNavigationWhenTabReappears(selectedTab: $selectedTab, resignedTab: .assets) {
            holdingsCurrencyDisplay = .twd
            selectedHolding = nil
            navigationStackResetID = UUID()
        }
    }
    
    // MARK: - 詳情頁同步（買入／賣出後刷新個股頁）
    
    /// 若正在看個股詳情，用最新快照更新；全賣光則 pop 回列表
    private func refreshSelectedHoldingIfNeeded() async {
        guard let current = selectedHolding else { return }
        
        do {
            if let freshItem = try await HoldingNavigationBuilder.loadFromPersisted(
                userId: userId,
                assetType: current.aggregatedHolding.assetType,
                symbol: current.aggregatedHolding.symbol
            ) {
                if freshItem != current {
                    selectedHolding = freshItem
                }
            } else {
                selectedHolding = nil
            }
        } catch {
            if let updated = viewModel.aggregatedHoldings.first(where: { $0.id == current.id }) {
                let newItem = holdingNavigationItem(for: updated)
                if newItem != current {
                    selectedHolding = newItem
                }
            } else {
                selectedHolding = nil
            }
        }
    }
    
    // MARK: - 導航到持股詳細頁面
    private func navigateToHoldingDetail(_ holding: AggregatedHoldingSnapshot) {
        selectedHolding = holdingNavigationItem(for: holding)
    }
    
    // MARK: - 自定義標題欄
    private func customHeaderBar(icon: String, title: String) -> some View {
        HStack {
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
            
            AppHeaderMoreButton(action: openSettings)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
}

// MARK: - 所有持股區塊（Phase 3）
struct AllHoldingsSection: View {
    let aggregatedHoldings: [AggregatedHoldingSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let totalAssets: Decimal
    let totalInvestments: Decimal
    let usdToTwdRate: Decimal
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let ratioType: HoldingRatioType
    let currencyDisplay: AssetsCurrencyDisplay
    @Binding var selectedCategories: Set<AssetType>
    let onHoldingTap: (AggregatedHoldingSnapshot) -> Void
    
    @State private var marketValueSort: HoldingsMarketValueSort = .descending
    @State private var sortByCategoryFirst: Bool = false
    
    private var activeCategoryFilter: Set<AssetType> {
        AssetCategoryFilterSelection.activeFilter(from: selectedCategories)
    }
    
    private var showOriginalCurrency: Bool {
        currencyDisplay == .original
    }
    
    private var filteredHoldings: [AggregatedHoldingSnapshot] {
        let active = activeCategoryFilter
        guard !active.isEmpty else { return aggregatedHoldings }
        return aggregatedHoldings.filter { active.contains($0.assetType) }
    }
    
    private var filterSummaryText: String? {
        let active = activeCategoryFilter
        guard !active.isEmpty else { return nil }
        return AssetCategoryFilterSelection.displayOrder
            .filter { active.contains($0) }
            .map(\.displayName)
            .joined(separator: "、")
    }
    
    // 計算所有持股的市值（台幣）
    var allHoldingsData: [AllHoldingItem] {
        let rate = usdToTwdRate
        var items: [AllHoldingItem] = []
        var priceMap: [String: AssetPriceSnapshot] = [:]
        
        // 建立價格映射
        for snapshot in assetPriceSnapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            priceMap[key] = snapshot
        }
        
        for holding in filteredHoldings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            
            // 計算市值（原幣）
            let marketValue = holding.totalQuantity * currentPrice
            
            // 使用即時匯率轉換市值為台幣
            let marketValueTWD: Decimal
            if holding.currency == .TWD {
                marketValueTWD = marketValue
            } else if holding.currency == .USD {
                marketValueTWD = marketValue * rate
            } else {
                continue
            }
            
            // 計算總成本（台幣）
            // 注意：totalCost 在 AggregatedHoldingSnapshot 中已使用購買時匯率計算
            // 但這裡需要轉換為台幣顯示，所以需要知道購買時的匯率
            // 由於 AggregatedHoldingSnapshot.totalCost 已經是原幣的總成本，
            // 我們需要根據 FIFO lots 中的 exchangeRate 來轉換，或者使用即時匯率作為近似值
            // 為了準確性，應該使用購買時匯率，但為了簡化，暫時使用即時匯率
            // TODO: 未來應該從 FIFOLotSnapshot.exchangeRate 計算準確的總成本（台幣）
            let totalCostTWD: Decimal
            if holding.currency == .TWD {
                totalCostTWD = holding.totalCost
            } else if holding.currency == .USD {
                // 注意：這裡應該使用購買時匯率，但為了簡化暫時使用即時匯率
                // 未來需要從 FIFOLotSnapshot.exchangeRate 計算
                totalCostTWD = holding.totalCost * rate
            } else {
                continue
            }
            
            // 計算未實現損益（台幣）
            let unrealizedGainLoss = marketValueTWD - totalCostTWD
            
            // 計算未實現損益百分比
            let unrealizedGainLossPercent: Decimal = totalCostTWD > 0 ? (unrealizedGainLoss / totalCostTWD) * 100 : 0
            
            // 計算佔比（根據選擇的類型）
            let ratio: Decimal
            if ratioType == .totalAssets {
                ratio = totalAssets > 0 ? (marketValueTWD / totalAssets) * 100 : 0
            } else {
                ratio = totalInvestments > 0 ? (marketValueTWD / totalInvestments) * 100 : 0
            }
            
            // 獲取顯示名稱
            let displayName: String
            switch holding.assetType {
            case .stockTW:
                displayName = SymbolListService.displayName(
                    assetType: holding.assetType,
                    symbol: holding.symbol,
                    storedName: holding.name
                )
            case .crypto:
                displayName = SymbolListService.cryptoDisplayName(for: holding.symbol, storedName: holding.name)
            case .stockUS:
                displayName = holding.symbol.uppercased()
            default:
                displayName = holding.symbol
            }
            
            items.append(AllHoldingItem(
                aggregatedHolding: holding,
                displayName: displayName,
                marketValue: marketValueTWD,
                totalCost: totalCostTWD,
                unrealizedGainLoss: unrealizedGainLoss,
                unrealizedGainLossPercent: unrealizedGainLossPercent,
                ratio: ratio,
                currentPrice: currentPrice,
                currency: holding.assetType.quoteCurrency
            ))
        }
        
        return sortedHoldings(items)
    }
    
    private var listRefreshToken: String {
        let filterKey = activeCategoryFilter.map(\.rawValue).sorted().joined(separator: ",")
        return "\(ratioType.rawValue)_\(currencyDisplay.rawValue)_\(filterKey)_\(marketValueSort)_\(sortByCategoryFirst)"
    }
    
    private func sortedHoldings(_ items: [AllHoldingItem]) -> [AllHoldingItem] {
        items.sorted { lhs, rhs in
            if sortByCategoryFirst {
                let lo = AssetCategoryFilterSelection.categorySortOrder(lhs.aggregatedHolding.assetType)
                let ro = AssetCategoryFilterSelection.categorySortOrder(rhs.aggregatedHolding.assetType)
                if lo != ro { return lo < ro }
            }
            switch marketValueSort {
            case .descending:
                return lhs.marketValue > rhs.marketValue
            case .ascending:
                return lhs.marketValue < rhs.marketValue
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("所有持股")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    AssetsFilterChipButton(
                        title: "市值",
                        icon: marketValueSort.iconName,
                        isActive: true
                    ) {
                        withAnimation(ChartMotion.switchSpring) {
                            marketValueSort.cycle()
                        }
                    }
                    
                    AssetsFilterChipButton(
                        title: "類別",
                        icon: "square.grid.2x2",
                        isActive: sortByCategoryFirst
                    ) {
                        withAnimation(ChartMotion.switchSpring) {
                            sortByCategoryFirst.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            if let filterSummaryText {
                HStack(spacing: 8) {
                    Text("篩選：\(filterSummaryText)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    Button {
                        withAnimation(ChartMotion.switchSpring) {
                            selectedCategories.removeAll()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                if allHoldingsData.isEmpty {
                    Text(activeCategoryFilter.isEmpty ? "尚無持股" : "此篩選尚無持股")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(allHoldingsData) { item in
                        AllHoldingCard(
                            item: item,
                            ratioType: ratioType,
                            baseCurrency: baseCurrency,
                            twdPerBaseCurrency: twdPerBaseCurrency,
                            showOriginalCurrency: showOriginalCurrency,
                            onTap: {
                                onHoldingTap(item.aggregatedHolding)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
            }
            .animation(ChartMotion.switchSpring, value: listRefreshToken)
        }
        .padding(.vertical, 8)
        .animation(ChartMotion.switchSpring, value: currencyDisplay)
    }
}

// MARK: - 所有持股項目數據
struct AllHoldingItem: Identifiable {
    let id: String // 使用 aggregatedHolding 的 id
    let aggregatedHolding: AggregatedHoldingSnapshot
    let displayName: String
    let marketValue: Decimal // 市值（台幣）
    let totalCost: Decimal // 總成本（台幣）
    let unrealizedGainLoss: Decimal // 未實現損益（台幣）
    let unrealizedGainLossPercent: Decimal // 未實現損益百分比
    let ratio: Decimal // 佔比（根據選擇的類型）
    let currentPrice: Decimal // 當前價格（原幣）
    let currency: Currency // 原幣
    
    init(aggregatedHolding: AggregatedHoldingSnapshot,
         displayName: String,
         marketValue: Decimal,
         totalCost: Decimal,
         unrealizedGainLoss: Decimal,
         unrealizedGainLossPercent: Decimal,
         ratio: Decimal,
         currentPrice: Decimal,
         currency: Currency) {
        self.id = aggregatedHolding.id
        self.aggregatedHolding = aggregatedHolding
        self.displayName = displayName
        self.marketValue = marketValue
        self.totalCost = totalCost
        self.unrealizedGainLoss = unrealizedGainLoss
        self.unrealizedGainLossPercent = unrealizedGainLossPercent
        self.ratio = ratio
        self.currentPrice = currentPrice
        self.currency = currency
    }
}

// MARK: - 所有持股卡片
struct AllHoldingCard: View {
    let item: AllHoldingItem
    let ratioType: HoldingRatioType
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let showOriginalCurrency: Bool // false = 台幣, true = 原幣
    let onTap: () -> Void
    
    var holdingColor: Color {
        switch item.aggregatedHolding.assetType {
        case .stockTW: return Color.stockTWColor
        case .stockUS: return Color.stockUSColor
        case .crypto: return Color.cryptoColor
        case .cash: return Color.appPrimary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 圓形比例圖標
                ZStack {
                    Circle()
                        .stroke(holdingColor.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, NSDecimalNumber(decimal: item.ratio / 100).doubleValue)))
                        .stroke(holdingColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(item.ratio.formatted(fractionDigits: 1))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                // 持股信息（只顯示名稱）
                VStack(alignment: .leading, spacing: 4) {
                    CurrencyTitleLabel(
                        title: item.displayName,
                        currency: showOriginalCurrency ? item.currency : baseCurrency,
                        font: .headline,
                        weight: .semibold,
                        color: .primaryText,
                        chipTint: holdingColor,
                        titleLineLimit: 1
                    )
                }
                
                Spacer()
                
                // 市值和損益（根據 showOriginalCurrency 顯示）
                VStack(alignment: .trailing, spacing: 4) {
                    // 根據 showOriginalCurrency 決定顯示台幣還是原幣
                    if showOriginalCurrency {
                        // 顯示原幣市值
                        let originalMarketValue = item.aggregatedHolding.totalQuantity * item.currentPrice
                        CurrencyAmountLabel(
                            text: originalMarketValue.formatted(currency: item.currency),
                            currency: item.currency,
                            font: .snapAmountRow,
                            weight: .semibold,
                            color: .primaryText,
                            chipTint: holdingColor
                        )
                    } else {
                        let displayValue = twdPerBaseCurrency > 0 ? item.marketValue / twdPerBaseCurrency : item.marketValue
                        CurrencyAmountLabel(
                            text: displayValue.formatted(currency: baseCurrency),
                            currency: baseCurrency,
                            font: .snapAmountRow,
                            weight: .semibold,
                            color: .primaryText,
                            chipTint: holdingColor
                        )
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: item.unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        if showOriginalCurrency {
                            // 顯示原幣損益
                            let originalCost = item.aggregatedHolding.totalCost
                            let originalMarketValue = item.aggregatedHolding.totalQuantity * item.currentPrice
                            let originalGainLoss = originalMarketValue - originalCost
                            let originalGainLossPercent: Decimal = originalCost > 0 ? (originalGainLoss / originalCost) * 100 : 0
                            Text(originalGainLoss.formatted(currency: item.currency, showSymbol: false))
                                .font(.caption)
                            Text("(\(originalGainLossPercent.formatted(fractionDigits: 1))%)")
                                .font(.caption)
                        } else {
                            let displayGainLoss = twdPerBaseCurrency > 0 ? item.unrealizedGainLoss / twdPerBaseCurrency : item.unrealizedGainLoss
                            Text(displayGainLoss.formatted(currency: baseCurrency, showSymbol: false))
                                .font(.caption)
                            Text("(\(item.unrealizedGainLossPercent.formatted(fractionDigits: 1))%)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(Color.marketColor(for: item.unrealizedGainLoss))
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                // 左側色條
                HStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(holdingColor)
                        .frame(width: 4)
                    Spacer()
                }
            )
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AssetsView(selectedTab: .constant(AppTab.assets.rawValue))
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
}

