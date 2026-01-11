//
//  AssetsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AssetsView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var userId: String = "test-user-id"
    @State private var selectedSort: SortOption = .totalAssets
    
    enum SortOption: String, CaseIterable {
        case totalAssets = "總資產由高到低"
        case todayPL = "今日損益由高到低"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 台股卡片
                    AssetCategoryCardView(
                        title: "台股",
                        icon: "chart.line.uptrend.xyaxis",
                        holdings: viewModel.holdings.filter { $0.holding.assetType == .stockTW },
                        viewModel: viewModel
                    )
                    
                    // 美股卡片
                    AssetCategoryCardView(
                        title: "美股",
                        icon: "dollarsign.circle.fill",
                        holdings: viewModel.holdings.filter { $0.holding.assetType == .stockUS },
                        viewModel: viewModel
                    )
                    
                    // 加密貨幣卡片
                    AssetCategoryCardView(
                        title: "加密貨幣",
                        icon: "bitcoinsign.circle.fill",
                        holdings: viewModel.holdings.filter { $0.holding.assetType == .crypto },
                        viewModel: viewModel
                    )
                    
                    // 所有持股
                    AllHoldingsSection(holdings: viewModel.holdings, sortOption: selectedSort)
                }
                .padding()
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBarWithAddButton(icon: "chart.bar.fill", title: "資產", addButtonText: "新增資產", addButtonAction: {
                    // TODO: 新增資產的功能
                })
            }
            .refreshable {
                await viewModel.loadData(userId: userId)
            }
            .task {
                await viewModel.loadData(userId: userId)
            }
        }
    }
    
    // MARK: - 自定義標題欄（帶新增按鈕）
    private func customHeaderBarWithAddButton(icon: String, title: String, addButtonText: String, addButtonAction: @escaping () -> Void) -> some View {
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
            
            // 右側：新增按鈕 + 使用者頭像
            HStack(spacing: 12) {
                Button(action: addButtonAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(addButtonText)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
}

// MARK: - 資產類別卡片
struct AssetCategoryCardView: View {
    let title: String
    let icon: String
    let holdings: [HoldingSnapshot]
    @ObservedObject var viewModel: PortfolioViewModel
    
    var totalValue: Decimal {
        holdings.compactMap { $0.marketValue }.reduce(0, +)
    }
    
    var totalCost: Decimal {
        holdings.map { $0.holding.totalCost }.reduce(0, +)
    }
    
    var unrealizedGainLoss: Decimal {
        holdings.compactMap { $0.unrealizedGainLoss }.reduce(0, +)
    }
    
    var unrealizedGainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    var body: some View {
        TitledCardView(title: title) {
            VStack(spacing: 16) {
                // 標題和總值
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.appPrimary)
                        .font(.title2)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(totalValue.formatted(currency: viewModel.viewCurrency))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Image(systemName: unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(unrealizedGainLoss.formatted(currency: viewModel.viewCurrency))
                            Text("(\(unrealizedGainLossPercent.formatted(fractionDigits: 2))%)")
                        }
                        .font(.subheadline)
                        .foregroundColor(unrealizedGainLoss >= 0 ? .profitGreen : .lossRed)
                    }
                }
                
                // 圓餅圖（佔位符，待實作）
                if !holdings.isEmpty {
                    AssetAllocationPieChart(holdings: holdings)
                        .frame(height: 200)
                }
                
                // 統計數據
                VStack(spacing: 8) {
                    StatRow(label: "總資產", value: totalValue.formatted(currency: viewModel.viewCurrency))
                    StatRow(label: "總成本", value: totalCost.formatted(currency: viewModel.viewCurrency))
                    StatRow(
                        label: "未實現損益",
                        value: unrealizedGainLoss.formatted(currency: viewModel.viewCurrency),
                        valueColor: unrealizedGainLoss >= 0 ? .profitGreen : .lossRed
                    )
                    StatRow(label: "已實現損益", value: "0")
                }
                
                // 立即交易按鈕
                Button(action: {
                    // TODO: 導航到交易頁面
                }) {
                    Text("立即交易")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brown)
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - 圓餅圖（佔位符）
struct AssetAllocationPieChart: View {
    let holdings: [HoldingSnapshot]
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondaryBackground)
                .frame(width: 180, height: 180)
            
            VStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondaryText)
                Text("圓餅圖\n（待實作）")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - 統計行
struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primaryText
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 所有持股區塊
struct AllHoldingsSection: View {
    let holdings: [HoldingSnapshot]
    let sortOption: AssetsView.SortOption
    
    var sortedHoldings: [HoldingSnapshot] {
        switch sortOption {
        case .totalAssets:
            return holdings.sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
        case .todayPL:
            // TODO: 實作今日損益排序
            return holdings
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有持股")
                .font(.headline)
                .padding(.horizontal)
            
            // 排序選項
            Picker("排序", selection: Binding(
                get: { sortOption },
                set: { _ in }
            )) {
                ForEach(AssetsView.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // 持股列表
            ForEach(sortedHoldings) { holding in
                HoldingRowCard(holding: holding)
            }
        }
    }
}

// MARK: - 持股行卡片
struct HoldingRowCard: View {
    let holding: HoldingSnapshot
    
    var body: some View {
        CardView {
            HStack(spacing: 12) {
                // 圖示
                Circle()
                    .fill(holding.unrealizedGainLoss ?? 0 >= 0 ? Color.profitGreen.opacity(0.2) : Color.lossRed.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: holding.unrealizedGainLoss ?? 0 >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(holding.unrealizedGainLoss ?? 0 >= 0 ? .profitGreen : .lossRed)
                    }
                
                // 資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.holding.symbol)
                        .font(.headline)
                    
                    Text(holding.holding.assetType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // 金額和損益
                VStack(alignment: .trailing, spacing: 4) {
                    if let marketValue = holding.marketValue {
                        Text(marketValue.formatted(currency: holding.holding.currency))
                            .font(.headline)
                    }
                    
                    if let gainLoss = holding.unrealizedGainLoss,
                       let percent = holding.unrealizedGainLossPercent {
                        HStack(spacing: 4) {
                            Text(gainLoss >= 0 ? "↑" : "↓")
                            Text(gainLoss.formatted(currency: holding.holding.currency))
                            Text("(\(percent.formatted(fractionDigits: 2))%)")
                        }
                        .font(.caption)
                        .foregroundColor(gainLoss >= 0 ? .profitGreen : .lossRed)
                    }
                }
            }
        }
    }
}

#Preview {
    AssetsView()
}

