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
    @ObservedObject private var homePrivacy = HomePrivacyManager.shared
    @State private var userId: String = "test-user-id"
    @State private var navigationStackResetID = UUID()
    @State private var isShareSheetPresented = false

    @State private var trendMetricMode: TrendMetricMode = .netWorth
    @State private var trendTimeRange: DateRangePreset = .sevenDays
    @State private var trendPoints: [TrendChartPoint] = []
    @State private var trendCustomStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var trendCustomEndDate: Date = Date()
    @State private var pieChartMode: PieChartDisplayMode = .totalAssets
    @State private var performanceMode: PerformanceDisplayMode = .gainLoss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 走勢圖（Supabase 每日快照）
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
                    
                    // 圓餅圖（總資產 / 投資組合 / 所有細項）
                    if viewModel.pieChartInputs != nil {
                        HomePieChartSection(
                            inputs: viewModel.pieChartInputs,
                            totalAssets: viewModel.totalAssets,
                            totalInvestments: viewModel.totalInvestments,
                            mode: $pieChartMode
                        )
                        
                        HomePerformanceChartSection(
                            inputs: viewModel.pieChartInputs,
                            mode: $performanceMode
                        )
                    }
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
                await viewModel.refreshDashboardTotals(userId: userId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
                Task {
                    await viewModel.refreshDashboardTotals(userId: userId)
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
                HomeShareButton { isShareSheetPresented = true }
                HomeAmountPrivacyToggleButton()
                MarketColorConventionToggleButton()
                ThemeToggleButton()
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

// MARK: - 淨資產卡片
struct NetWorthCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isExpanded: Bool = false
    @State private var animatedNetWorthProgress: Double = 0.0
    @State private var animatedDebtProgress: Double = 0.0
    @State private var touchLocation: CGPoint? = nil
    @State private var showingInfo: String? = nil
    
    var netWorth: Decimal {
        viewModel.totalAssets - viewModel.totalLiabilities
    }
    
    var netWorthRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (netWorth / viewModel.totalAssets) * 100
    }
    
    var body: some View {
        AccentBarCard(title: "淨資產", accentColor: .appPrimary) {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON（藍色主題，剩餘部分用實色紅色）
                    ZStack {
                        // 背景圓圈（實色紅色，代表負債，與長條圖顏色一致）
                        let debtRatio = 1.0 - CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue)
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(Color.lossRed, lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        // 淨資產弧段
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue))
                            .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        // 負債部分（實色紅色，與長條圖顏色一致）
                        if debtRatio > 0 {
                            Circle()
                                .trim(from: CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue), to: 1.0)
                                .stroke(Color.lossRed, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text("\(netWorthRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    }
                    
                    // 主要數字
                    Text(HomeAmountPrivacyFormat.currency(netWorth, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    // 展開/縮合按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                
                // 展開時顯示的內容
                if isExpanded {
                    // 進度條（連續形式，帶動畫、觸摸互動）
                    InteractiveProgressBar(
                        segments: [
                            (progress: animatedNetWorthProgress, color: .appPrimary, gradient: [.appPrimary, .appPrimary.opacity(0.8)]),
                            (progress: animatedDebtProgress, color: .lossRed, gradient: [.lossRed, .lossRed.opacity(0.8)])
                        ],
                        cornerRadius: 4,
                        height: 8,
                        touchLocation: $touchLocation,
                        showingInfo: $showingInfo,
                        infoProvider: { x, width in
                            let netWorthWidth = width * animatedNetWorthProgress
                            if x <= netWorthWidth {
                                return "淨資產 \(netWorthRatio.formatted(fractionDigits: 1))%"
                            } else {
                                return "負債 \((100 - netWorthRatio).formatted(fractionDigits: 1))%"
                            }
                        }
                    )
                    .frame(height: 8)
                    .onAppear {
                        // 載入動畫：從0開始動畫到目標比例
                        let netWorthTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue)))
                        let debtTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: (100 - netWorthRatio) / 100).doubleValue)))
                        animatedNetWorthProgress = 0.0
                        animatedDebtProgress = 0.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                                animatedNetWorthProgress = netWorthTarget
                                animatedDebtProgress = debtTarget
                            }
                        }
                    }
                    .id("networth-\(viewModel.totalAssets)-\(viewModel.totalLiabilities)")  // 當數據更新時，視圖會重新創建
                    
                    // 詳細資訊
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("淨資產")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(HomeAmountPrivacyFormat.currency(netWorth, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.appPrimary)
                            Text("\(netWorthRatio.formatted(fractionDigits: 1))%")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("負債")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(HomeAmountPrivacyFormat.currency(viewModel.totalLiabilities, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.lossRed)
                            Text("\((100 - netWorthRatio).formatted(fractionDigits: 1))%")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("總資產")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(HomeAmountPrivacyFormat.currency(viewModel.totalAssets, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
    @State private var animatedCostProgress: Double = 0.0
    @State private var animatedGainLossProgress: Double = 0.0
    @State private var touchLocation: CGPoint? = nil
    @State private var showingInfo: String? = nil
    
    var investmentRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalInvestments / viewModel.totalAssets) * 100
    }
    
    var body: some View {
        AccentBarCard(title: "投資資產", accentColor: .stockUSColor) {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON（綠色主題，剩餘部分用淺綠色）
                    ZStack {
                        let investmentRatioDouble = CGFloat(NSDecimalNumber(decimal: investmentRatio / 100).doubleValue)
                        
                        // 背景圓圈（未填滿部分）
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(Color.stockUSColor.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        // 投資資產弧段
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
                    
                    // 主要數字
                    Text(HomeAmountPrivacyFormat.currency(viewModel.totalInvestments, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    // 展開/縮合按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                
                // 展開時顯示的內容
                if isExpanded {
                    // 進度條（成本 vs 未實現損益，連續形式，帶動畫、觸摸互動）
                    let cost = viewModel.totalInvestments - viewModel.unrealizedGainLoss
                    let totalForRatio = viewModel.totalInvestments > 0 ? viewModel.totalInvestments : 1
                    let costRatio = totalForRatio > 0 ? (cost / totalForRatio) : 0
                    let gainLossRatio = totalForRatio > 0 ? (abs(viewModel.unrealizedGainLoss) / totalForRatio) : 0
                    
                    InteractiveProgressBar(
                        segments: [
                            (progress: animatedCostProgress, color: .secondaryText, gradient: [Color.secondaryText.opacity(0.4), Color.secondaryText.opacity(0.3)]),
                            (progress: animatedGainLossProgress, color: Color.marketColor(for: viewModel.unrealizedGainLoss), gradient: viewModel.unrealizedGainLoss >= 0 ? [Color.marketUp, Color.marketUp] : [Color.marketDown, Color.marketDown.opacity(0.8)])
                        ],
                        cornerRadius: 4,
                        height: 8,
                        touchLocation: $touchLocation,
                        showingInfo: $showingInfo,
                        infoProvider: { x, width in
                            let costWidth = width * animatedCostProgress
                            if x <= costWidth {
                                return "成本 \((costRatio * 100).formatted(fractionDigits: 1))%"
                            } else {
                                return "未實現損益 \((gainLossRatio * 100).formatted(fractionDigits: 1))%"
                            }
                        }
                    )
                    .frame(height: 8)
                    .onAppear {
                        // 載入動畫：從0開始動畫到目標比例
                        let costTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: costRatio).doubleValue)))
                        let gainLossTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: gainLossRatio).doubleValue)))
                        animatedCostProgress = 0.0
                        animatedGainLossProgress = 0.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                                animatedCostProgress = costTarget
                                animatedGainLossProgress = gainLossTarget
                            }
                        }
                    }
                    .id("investment-\(viewModel.totalInvestments)-\(viewModel.unrealizedGainLoss)")  // 當數據更新時，視圖會重新創建
                    
                    // 成本（左邊）和未實現損益（右邊）
                    HStack(spacing: 16) {
                        // 成本（左邊）
                        VStack(alignment: .leading, spacing: 4) {
                            Text("成本")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(HomeAmountPrivacyFormat.currency(cost, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                        
                        Spacer()
                        
                        // 未實現損益（右邊）
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("未實現損益")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                if hideHomeAmounts {
                                    if cost > 0 {
                                        Text("(\((viewModel.unrealizedGainLoss / cost * 100).formatted(fractionDigits: 2))%)")
                                            .font(.caption2)
                                    }
                                } else {
                                    Text(viewModel.unrealizedGainLoss.formatted(currency: viewModel.viewCurrency))
                                    if cost > 0 {
                                        Text("(\((viewModel.unrealizedGainLoss / cost * 100).formatted(fractionDigits: 2))%)")
                                            .font(.caption2)
                                    }
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.marketColor(for: viewModel.unrealizedGainLoss))
                        }
                    }
                    
                    Divider()
                    
                    // 總市值（下面）
                    HStack {
                        Text("目前總市值")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(HomeAmountPrivacyFormat.currency(viewModel.totalInvestments, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
    @State private var animatedTWDCashProgress: Double = 0.0
    @State private var animatedUSDCashProgress: Double = 0.0
    @State private var touchLocation: CGPoint? = nil
    @State private var showingInfo: String? = nil
    
    var cashRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalCash / viewModel.totalAssets) * 100
    }
    
    var body: some View {
        AccentBarCard(title: "現金", accentColor: .allocationTwdCash) {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        let cashColor = Color.allocationTwdCash
                        let cashRatioDouble = CGFloat(NSDecimalNumber(decimal: cashRatio / 100).doubleValue)
                        
                        // 背景圓圈（淺藍綠色，代表未畫到的部分）
                        Circle()
                            .trim(from: 0, to: 1.0)
                            .stroke(cashColor.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        // 現金部分（藍綠色，從12點開始逆時針繪製）
                        Circle()
                            .trim(from: 1.0 - cashRatioDouble, to: 1.0)  // 從1-value到1，實現逆時針
                            .stroke(cashColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))  // -90度 = 從12點開始
                        
                        Text("\(cashRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(cashColor)
                    }
                    
                    // 主要數字
                    Text(HomeAmountPrivacyFormat.currency(viewModel.totalCash, currency: viewModel.viewCurrency, hidden: hideHomeAmounts))
                        .font(.snapAmountHero)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    // 展開/縮合按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                
                // 展開時顯示的內容
                if isExpanded {
                    // 進度條（台幣 vs 美金，連續形式，帶動畫、觸摸互動）
                    let twdCashValue = viewModel.cashByCurrency[.TWD] ?? 0
                    let usdCashValue = viewModel.cashByCurrency[.USD] ?? 0
                    let usdToTwdRate: Decimal = 32
                    let totalCashForRatio = twdCashValue + (usdCashValue * usdToTwdRate)
                    let twdRatio = totalCashForRatio > 0 ? (twdCashValue / totalCashForRatio) : 0
                    let usdRatio = totalCashForRatio > 0 ? ((usdCashValue * usdToTwdRate) / totalCashForRatio) : 0
                    
                    InteractiveProgressBar(
                        segments: [
                            (progress: animatedTWDCashProgress, color: Color.allocationTwdCash, gradient: [Color.allocationTwdCash, Color.allocationTwdCash.opacity(0.8)]),
                            (progress: animatedUSDCashProgress, color: Color.allocationUsdCash, gradient: [Color.allocationUsdCash, Color.allocationUsdCash.opacity(0.8)])
                        ],
                        cornerRadius: 4,
                        height: 8,
                        touchLocation: $touchLocation,
                        showingInfo: $showingInfo,
                        infoProvider: { x, width in
                            let twdWidth = width * animatedTWDCashProgress
                            if x <= twdWidth {
                                return "台幣餘額 \((twdRatio * 100).formatted(fractionDigits: 1))%"
                            } else {
                                return "美金餘額 \((usdRatio * 100).formatted(fractionDigits: 1))%"
                            }
                        }
                    )
                    .frame(height: 8)
                    .onAppear {
                        // 載入動畫：從0開始動畫到目標比例
                        let twdTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: twdRatio).doubleValue)))
                        let usdTarget = max(0.0, min(1.0, Double(NSDecimalNumber(decimal: usdRatio).doubleValue)))
                        animatedTWDCashProgress = 0.0
                        animatedUSDCashProgress = 0.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                                animatedTWDCashProgress = twdTarget
                                animatedUSDCashProgress = usdTarget
                            }
                        }
                    }
                    .id("cash-\(twdCashValue)-\(usdCashValue)")  // 當數據更新時，視圖會重新創建
                    
                    // 台幣餘額（左邊）和美金餘額（右邊）
                    HStack(spacing: 16) {
                        // 台幣餘額（左邊）
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.allocationTwdCash)
                                    .frame(width: 8, height: 8)
                                Text("台幣餘額")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            let twdCash = viewModel.cashByCurrency[.TWD] ?? 0
                            Text(HomeAmountPrivacyFormat.currency(twdCash, currency: .TWD, hidden: hideHomeAmounts))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            Text("\((twdRatio * 100).formatted(fractionDigits: 1))%")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        // 美金餘額（右邊）
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("美金餘額")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                Circle()
                                    .fill(Color.allocationUsdCash)
                                    .frame(width: 8, height: 8)
                            }
                            let usdCash = viewModel.cashByCurrency[.USD] ?? 0
                            Text(HomeAmountPrivacyFormat.currency(usdCash, currency: .USD, hidden: hideHomeAmounts))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            Text("\((usdRatio * 100).formatted(fractionDigits: 1))%")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
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

                    if summary.hasData, !summary.categories.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondaryText)
                                .frame(width: 24, height: 24)
                        }
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
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @State private var isExpanded = false
    @State private var expandedTransactionIds: Set<String> = []
    
    private var realizedTransactionsByCurrency: [Currency: [Transaction]] {
        let sells = transactionsViewModel.transactions.filter { $0.type == .sell }
        return Dictionary(grouping: sells, by: { $0.currency })
    }
    
    var body: some View {
        AccentBarCard(title: "已實現損益", accentColor: .appPrimary) {
            VStack(spacing: 16) {
                HStack {
                    Text(viewModel.realizedGainLoss.formatted(currency: viewModel.viewCurrency))
                        .font(.snapAmountHero)
                        .foregroundColor(Color.marketColor(for: viewModel.realizedGainLoss))
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                }
                
                if isExpanded {
                    if realizedTransactionsByCurrency.isEmpty {
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
        .task {
            await transactionsViewModel.loadTransactions(userId: userId)
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
                                                if let realized = transaction.realizedGainLoss {
                                                    Text(realized.formatted(currency: transaction.currency))
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(Color.marketColor(for: realized))
                                                } else {
                                                    Text("--")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.secondaryText)
                                                }
                                                
                                                if let percent = transaction.realizedGainLossPercent {
                                                    Text("(\(percent.formatted(fractionDigits: 2))%)")
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
                                                Text(transaction.quantity.formatted(fractionDigits: 4))
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
                                                if let costPerUnit = transaction.realizedCostPerUnit {
                                                    Text(costPerUnit.formattedTradePrice(currency: transaction.currency))
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
                                                Text(transaction.price.formattedTradePrice(currency: transaction.currency))
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
        if currency == .TWD {
            return SymbolListService.twDisplayName(for: transaction.symbol) ?? transaction.symbol
        }
        return transaction.symbol
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - 互動式進度條組件
struct InteractiveProgressBar: View {
    let segments: [(progress: Double, color: Color, gradient: [Color])]
    let cornerRadius: CGFloat
    let height: CGFloat
    @Binding var touchLocation: CGPoint?
    @Binding var showingInfo: String?
    let infoProvider: (CGFloat, CGFloat) -> String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景（帶圓角）
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondaryBackground)
                    .frame(height: height)
                
                // 進度條（使用 RoundedRectangle，通過 clipShape 確保整體圓角）
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        if segment.progress > 0 {
                            RoundedRectangle(cornerRadius: 0) // 先創建矩形，然後通過 clipShape 處理圓角
                                .fill(
                                    LinearGradient(
                                        colors: segment.gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * segment.progress, height: height)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius)) // 整體圓角，確保在動畫過程中一直存在
            }
            .overlay(
                // 觸摸檢測區域
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                touchLocation = value.location
                                showingInfo = infoProvider(x, geometry.size.width)
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.1)) {
                                    touchLocation = nil
                                    showingInfo = nil
                                }
                            }
                    )
            )
            .overlay(
                // 浮動資訊框（在進度條上方）
                Group {
                    if let location = touchLocation, let info = showingInfo {
                        VStack(spacing: 0) {
                            Text(info)
                                .font(.caption)
                                .foregroundColor(AppColors.actionForeground)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColors.overlayDark)
                                )
                        }
                        .position(
                            x: max(50, min(geometry.size.width - 50, location.x)),
                            y: -25
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                },
                alignment: .topLeading
            )
        }
    }
}

#Preview {
    HomeView(selectedTab: .constant(AppTab.home.rawValue))
        .environmentObject(PortfolioViewModel())
}

