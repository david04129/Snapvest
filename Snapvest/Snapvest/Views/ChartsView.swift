//
//  ChartsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct ChartsView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var userId: String = "test-user-id"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 資產走勢圖
                    TrendChartView(viewModel: viewModel)
                    
                    // 資產分配圓餅圖
                    AssetAllocationChartView(holdings: viewModel.holdings)
                    
                    // 投資 vs 資產比例（炫風圖）
                    InvestmentVsAssetChartView(holdings: viewModel.holdings)
                }
                .padding()
            }
            .navigationTitle("圖表分析")
            .task {
                await viewModel.loadData(userId: userId)
            }
        }
    }
}

// MARK: - 走勢圖
struct TrendChartView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("資產走勢")
                .font(.headline)
            
            // TODO: 實作走勢圖（使用 Charts 框架）
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.placeholderFill)
                    .frame(height: 200)
                
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("走勢圖\n（待實作）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - 投資 vs 資產比例（炫風圖）
struct InvestmentVsAssetChartView: View {
    let holdings: [HoldingSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投資比例 vs 資產比例")
                .font(.headline)
            
            // TODO: 實作炫風圖
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.placeholderFill)
                    .frame(height: 200)
                
                VStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("炫風圖\n（待實作）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

#Preview {
    ChartsView()
}

