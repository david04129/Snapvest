//
//  HomeView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var userId: String = "test-user-id"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 淨資產卡片
                    NetWorthCardView(viewModel: viewModel)
                    
                    // 投資資產卡片
                    InvestmentAssetsCardView(viewModel: viewModel)
                    
                    // 現金卡片
                    CashCardView(viewModel: viewModel)
                    
                    // 今日損益卡片
                    TodayPLCardView(viewModel: viewModel)
                    
                    // 已實現損益卡片
                    RealizedPLCardView(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("首頁")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 用戶頭像/名稱（佔位符，後續加入登入功能）
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
            .refreshable {
                await viewModel.loadData(userId: userId)
            }
            .task {
                await viewModel.loadData(userId: userId)
            }
        }
    }
}

// MARK: - 淨資產卡片
struct NetWorthCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
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
        TitledCardView(title: "淨資產") {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON（藍色主題）
                    ZStack {
                        Circle()
                            .stroke(Color.appPrimary.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue))
                            .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(netWorthRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    }
                    
                    // 主要數字
                    Text(netWorth.formatted(currency: viewModel.viewCurrency))
                        .font(.system(size: 28, weight: .bold))
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
                            Text(netWorth.formatted(currency: viewModel.viewCurrency))
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
                            Text(viewModel.totalLiabilities.formatted(currency: viewModel.viewCurrency))
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
                        Text(viewModel.totalAssets.formatted(currency: viewModel.viewCurrency))
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
        TitledCardView(title: "投資資產") {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON（綠色主題）
                    ZStack {
                        Circle()
                            .stroke(Color.profitGreen.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: investmentRatio / 100).doubleValue))
                            .stroke(Color.profitGreen, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(investmentRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.profitGreen)
                    }
                    
                    // 主要數字
                    Text(viewModel.totalInvestments.formatted(currency: viewModel.viewCurrency))
                        .font(.system(size: 28, weight: .bold))
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
                            (progress: animatedGainLossProgress, color: viewModel.unrealizedGainLoss >= 0 ? .profitGreen : .lossRed, gradient: viewModel.unrealizedGainLoss >= 0 ? [.profitGreen, .profitGreen.opacity(0.8)] : [.lossRed, .lossRed.opacity(0.8)])
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
                            Text(cost.formatted(currency: viewModel.viewCurrency))
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
                                Text(viewModel.unrealizedGainLoss.formatted(currency: viewModel.viewCurrency))
                                if cost > 0 {
                                    Text("(\((viewModel.unrealizedGainLoss / cost * 100).formatted(fractionDigits: 2))%)")
                                        .font(.caption2)
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.unrealizedGainLoss >= 0 ? .profitGreen : .lossRed)
                        }
                    }
                    
                    Divider()
                    
                    // 總市值（下面）
                    HStack {
                        Text("目前總市值")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(viewModel.totalInvestments.formatted(currency: viewModel.viewCurrency))
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
        TitledCardView(title: "現金") {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON（金黃/橙色主題）
                    ZStack {
                        let cashColor = Color(red: 1.0, green: 0.65, blue: 0.0)  // 金黃/橙色
                        Circle()
                            .stroke(cashColor.opacity(0.15), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: cashRatio / 100).doubleValue))
                            .stroke(cashColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(cashRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(cashColor)
                    }
                    
                    // 主要數字
                    Text(viewModel.totalCash.formatted(currency: viewModel.viewCurrency))
                        .font(.system(size: 28, weight: .bold))
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
                            (progress: animatedTWDCashProgress, color: .appPrimary, gradient: [.appPrimary, .appPrimary.opacity(0.8)]),
                            (progress: animatedUSDCashProgress, color: .profitGreen, gradient: [.profitGreen, .profitGreen.opacity(0.8)])
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
                                    .fill(Color.appPrimary)
                                    .frame(width: 8, height: 8)
                                Text("台幣餘額")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            let twdCash = viewModel.cashByCurrency[.TWD] ?? 0
                            Text(twdCash.formatted(currency: .TWD))
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
                                    .fill(Color.profitGreen)
                                    .frame(width: 8, height: 8)
                            }
                            let usdCash = viewModel.cashByCurrency[.USD] ?? 0
                            Text(usdCash.formatted(currency: .USD))
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
    
    // TODO: 實作今日損益計算
    var todayPL: Decimal = 0
    var todayPLPercent: Decimal = 0
    
    var body: some View {
        StatCardView(
            title: "今日損益",
            value: todayPL.formatted(currency: viewModel.viewCurrency),
            subtitle: "↑ \(todayPLPercent.formatted(fractionDigits: 2))%",
            valueColor: todayPL >= 0 ? .profitGreen : .lossRed,
            icon: "chart.line.uptrend.xyaxis"
        )
    }
}

// MARK: - 已實現損益卡片
struct RealizedPLCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    
    var body: some View {
        TitledCardView(title: "已實現損益") {
            VStack(spacing: 12) {
                Text(viewModel.realizedGainLoss.formatted(currency: viewModel.viewCurrency))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(viewModel.realizedGainLoss >= 0 ? .profitGreen : .lossRed)
                
                if viewModel.realizedGainLoss == 0 {
                    Text("尚無已實現損益")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                
                // TODO: 實作已實現損益表格
                // 目前先顯示佔位符
            }
        }
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
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.85))
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
    HomeView()
}

