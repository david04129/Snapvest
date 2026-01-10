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
                    // 圓圈比例ICON
                    ZStack {
                        let grayColor = Color(red: 0.5, green: 0.5, blue: 0.5)
                        Circle()
                            .stroke(grayColor.opacity(0.2), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue))
                            .stroke(grayColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(netWorthRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(grayColor)
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
                    // 進度條
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // 淨資產（藍色）
                            let netWorthWidth = max(0, min(geometry.size.width, geometry.size.width * CGFloat(NSDecimalNumber(decimal: netWorthRatio / 100).doubleValue)))
                            Rectangle()
                                .fill(Color.appPrimary)
                                .frame(width: netWorthWidth)
                            
                            // 負債（紅色）
                            let debtWidth = max(0, min(geometry.size.width, geometry.size.width * CGFloat(NSDecimalNumber(decimal: (100 - netWorthRatio) / 100).doubleValue)))
                            Rectangle()
                                .fill(Color.lossRed)
                                .frame(width: debtWidth)
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
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
    
    var investmentRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalInvestments / viewModel.totalAssets) * 100
    }
    
    var body: some View {
        TitledCardView(title: "投資資產") {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON
                    ZStack {
                        let grayColor = Color(red: 0.5, green: 0.5, blue: 0.5)
                        Circle()
                            .stroke(grayColor.opacity(0.2), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: investmentRatio / 100).doubleValue))
                            .stroke(grayColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(investmentRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(grayColor)
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
                    // 進度條（成本 vs 未實現損益）
                    let cost = viewModel.totalInvestments - viewModel.unrealizedGainLoss
                    let totalForRatio = viewModel.totalInvestments > 0 ? viewModel.totalInvestments : 1
                    let costRatio = totalForRatio > 0 ? (cost / totalForRatio) : 0
                    let gainLossRatio = totalForRatio > 0 ? (abs(viewModel.unrealizedGainLoss) / totalForRatio) : 0
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // 成本（灰色）
                            Rectangle()
                                .fill(Color.secondaryText.opacity(0.3))
                                .frame(width: geometry.size.width * CGFloat(NSDecimalNumber(decimal: costRatio).doubleValue))
                            
                            // 未實現損益（綠色或紅色）
                            if viewModel.unrealizedGainLoss != 0 {
                                Rectangle()
                                    .fill(viewModel.unrealizedGainLoss >= 0 ? Color.profitGreen : Color.lossRed)
                                    .frame(width: geometry.size.width * CGFloat(NSDecimalNumber(decimal: gainLossRatio).doubleValue))
                            }
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
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
    
    var cashRatio: Decimal {
        guard viewModel.totalAssets > 0 else { return 0 }
        return (viewModel.totalCash / viewModel.totalAssets) * 100
    }
    
    var body: some View {
        TitledCardView(title: "現金") {
            VStack(spacing: 16) {
                // 標題和圓圈比例ICON
                HStack(alignment: .center, spacing: 16) {
                    // 圓圈比例ICON
                    ZStack {
                        let grayColor = Color(red: 0.5, green: 0.5, blue: 0.5)
                        Circle()
                            .stroke(grayColor.opacity(0.2), lineWidth: 7)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(NSDecimalNumber(decimal: cashRatio / 100).doubleValue))
                            .stroke(grayColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(cashRatio.formatted(fractionDigits: 1))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(grayColor)
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
                    // 進度條（台幣 vs 美金）
                    let twdCashValue = viewModel.cashByCurrency[.TWD] ?? 0
                    let usdCashValue = viewModel.cashByCurrency[.USD] ?? 0
                    let usdToTwdRate: Decimal = 32
                    let totalCashForRatio = twdCashValue + (usdCashValue * usdToTwdRate)
                    let twdRatio = totalCashForRatio > 0 ? (twdCashValue / totalCashForRatio) : 0
                    let usdRatio = totalCashForRatio > 0 ? ((usdCashValue * usdToTwdRate) / totalCashForRatio) : 0
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // 台幣現金（藍色）
                            Rectangle()
                                .fill(Color.appPrimary)
                                .frame(width: geometry.size.width * CGFloat(NSDecimalNumber(decimal: twdRatio).doubleValue))
                            
                            // 美金現金（綠色）
                            Rectangle()
                                .fill(Color.profitGreen)
                                .frame(width: geometry.size.width * CGFloat(NSDecimalNumber(decimal: usdRatio).doubleValue))
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
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

#Preview {
    HomeView()
}

