//
//  DashboardView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var userId: String = "test-user-id" // TODO: 從認證系統獲取
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 總覽卡片
                    SummaryCardView(viewModel: viewModel)
                    
                    // 資產分配圓餅圖
                    AssetAllocationChartView(holdings: viewModel.holdings)
                    
                    // 持股列表
                    HoldingsListView(holdings: viewModel.holdings)
                }
                .padding()
            }
            .navigationTitle("資產總覽")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh(userId: userId)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.toggleViewCurrency()
                    }) {
                        Text(viewModel.viewCurrency.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .task {
                await viewModel.loadData(userId: userId)
            }
        }
    }
}

// MARK: - 總覽卡片
struct SummaryCardView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("總覽")
                .font(.headline)
            
            // 總資產
            SummaryRowView(
                title: "總資產",
                value: viewModel.totalAssets.formatted(currency: viewModel.viewCurrency),
                color: .blue
            )
            
            // 總負債
            SummaryRowView(
                title: "總負債",
                value: viewModel.totalLiabilities.formatted(currency: viewModel.viewCurrency),
                subtitle: viewModel.totalAssets > 0 ? 
                    "\((viewModel.totalLiabilities / viewModel.totalAssets * 100).formatted(fractionDigits: 1))%" : "0%",
                color: .red
            )
            
            // 總現金
            SummaryRowView(
                title: "總現金",
                value: viewModel.totalCash.formatted(currency: viewModel.viewCurrency),
                subtitle: viewModel.totalAssets > 0 ? 
                    "\((viewModel.totalCash / viewModel.totalAssets * 100).formatted(fractionDigits: 1))%" : "0%",
                color: .green
            )
            
            // 總投資
            SummaryRowView(
                title: "總投資",
                value: viewModel.totalInvestments.formatted(currency: viewModel.viewCurrency),
                subtitle: viewModel.totalAssets > 0 ? 
                    "\((viewModel.totalInvestments / viewModel.totalAssets * 100).formatted(fractionDigits: 1))%" : "0%",
                color: .purple
            )
            
            Divider()
            
            // 未實現損益
            SummaryRowView(
                title: "未實現損益",
                value: viewModel.unrealizedGainLoss.formatted(currency: viewModel.viewCurrency),
                subtitle: viewModel.totalInvestments > 0 ? 
                    "\((viewModel.unrealizedGainLoss / viewModel.totalInvestments * 100).formatted(fractionDigits: 2))%" : "0%",
                color: viewModel.unrealizedGainLoss >= 0 ? .green : .red
            )
            
            // 已實現損益
            SummaryRowView(
                title: "已實現損益",
                value: viewModel.realizedGainLoss.formatted(currency: viewModel.viewCurrency),
                color: viewModel.realizedGainLoss >= 0 ? .green : .red
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 總覽行視圖
struct SummaryRowView: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 資產分配圓餅圖
struct AssetAllocationChartView: View {
    let holdings: [HoldingSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("資產分配")
                .font(.headline)
                .padding(.horizontal)
            
            // TODO: 實作圓餅圖（使用 Charts 框架）
            // 目前顯示佔位符
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                
                VStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("圓餅圖\n（待實作）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }
}

// MARK: - 持股列表
struct HoldingsListView: View {
    let holdings: [HoldingSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("持股明細")
                .font(.headline)
                .padding(.horizontal)
            
            if holdings.isEmpty {
                Text("尚無持股")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(holdings) { holding in
                    HoldingRowView(holding: holding)
                }
            }
        }
    }
}

// MARK: - 持股行視圖
struct HoldingRowView: View {
    let holding: HoldingSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.holding.symbol)
                        .font(.headline)
                    
                    Text(holding.holding.assetType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let marketValue = holding.marketValue {
                        Text(marketValue.formatted(currency: holding.holding.currency))
                            .font(.headline)
                    }
                    
                    if let gainLoss = holding.unrealizedGainLoss,
                       let percent = holding.unrealizedGainLossPercent {
                        HStack(spacing: 4) {
                            Image(systemName: gainLoss >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text(gainLoss.formatted(currency: holding.holding.currency))
                            Text("(\(percent.formatted(fractionDigits: 2))%)")
                        }
                        .font(.caption)
                        .foregroundColor(gainLoss >= 0 ? .green : .red)
                    }
                }
            }
            
            // 投資佔比和資產佔比
            HStack {
                if let investmentRatio = holding.investmentRatio {
                    Text("投資佔比: \(investmentRatio.formatted(fractionDigits: 2))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let assetRatio = holding.assetRatio {
                    Text("資產佔比: \(assetRatio.formatted(fractionDigits: 2))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    DashboardView()
}

