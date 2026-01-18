//
//  HoldingDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import Charts

struct HoldingDetailView: View {
    let aggregatedHolding: AggregatedHoldingSnapshot
    let assetPriceSnapshot: AssetPriceSnapshot?
    let totalAssets: Decimal
    let totalInvestments: Decimal
    
    @Environment(\.dismiss) private var dismiss
    @State private var ratioType: HoldingRatioType = HoldingRatioPreference.get()
    
    // 計算市值（台幣）
    var marketValue: Decimal {
        guard let priceSnapshot = assetPriceSnapshot,
              let currentPrice = priceSnapshot.displayPrice else { return 0 }
        
        let usdToTwdRate: Decimal = 32 // TODO: 從匯率服務獲取
        let marketValue = aggregatedHolding.totalQuantity * currentPrice
        
        if aggregatedHolding.currency == .TWD {
            return marketValue
        } else if aggregatedHolding.currency == .USD {
            return marketValue * usdToTwdRate
        }
        return 0
    }
    
    // 計算總成本（台幣）
    var totalCostTWD: Decimal {
        let usdToTwdRate: Decimal = 32 // TODO: 從匯率服務獲取
        
        if aggregatedHolding.currency == .TWD {
            return aggregatedHolding.totalCost
        } else if aggregatedHolding.currency == .USD {
            return aggregatedHolding.totalCost * usdToTwdRate
        }
        return 0
    }
    
    // 計算未實現損益（台幣）
    var unrealizedGainLoss: Decimal {
        marketValue - totalCostTWD
    }
    
    // 計算未實現損益百分比
    var unrealizedGainLossPercent: Decimal {
        guard totalCostTWD > 0 else { return 0 }
        return (unrealizedGainLoss / totalCostTWD) * 100
    }
    
    // 計算佔比
    var ratio: Decimal {
        if ratioType == .totalAssets {
            return totalAssets > 0 ? (marketValue / totalAssets) * 100 : 0
        } else {
            return totalInvestments > 0 ? (marketValue / totalInvestments) * 100 : 0
        }
    }
    
    // 顯示名稱
    var displayName: String {
        if aggregatedHolding.assetType == .stockTW,
           let name = aggregatedHolding.name,
           !name.isEmpty {
            return name
        }
        return aggregatedHolding.symbol
    }
    
    // 當前價格（原幣）
    var currentPrice: Decimal? {
        assetPriceSnapshot?.displayPrice
    }
    
    // 獲取顏色
    var holdingColor: Color {
        HoldingColorPreferences.getColor(for: aggregatedHolding.symbol, assetType: aggregatedHolding.assetType)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 標題區域
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text(aggregatedHolding.symbol)
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // 主要指標卡片
                    mainMetricsCard
                        .padding(.horizontal, 20)
                }
                
                // FIFO 批次列表（按帳戶分組）
                if !aggregatedHolding.fifoLotsByAccount.isEmpty {
                    fifoLotsSection
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100) // 為底部按鈕留出空間
        }
        .background(Color.mainBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 底部買入/賣出按鈕
            bottomActionButtons
        }
    }
    
    // MARK: - 主要指標卡片
    private var mainMetricsCard: some View {
        VStack(spacing: 16) {
            // 第一行：當前價格和數量
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("當前價格")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    if let price = currentPrice {
                        Text(price.formatted(currency: aggregatedHolding.currency))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryText)
                    } else {
                        Text("--")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("持有數量")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(aggregatedHolding.totalQuantity.formatted(fractionDigits: 4))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                }
            }
            
            Divider()
            
            // 第二行：市值和平均成本
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("市值（台幣）")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(marketValue.formatted(currency: .TWD))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均成本")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(aggregatedHolding.weightedAverageCost.formatted(currency: aggregatedHolding.currency))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
            }
            
            Divider()
            
            // 第三行：未實現損益和佔比
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("未實現損益")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(unrealizedGainLoss.formatted(currency: .TWD))
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("(\(unrealizedGainLossPercent.formatted(fractionDigits: 1))%)")
                            .font(.caption)
                    }
                    .foregroundColor(unrealizedGainLoss >= 0 ? .profitGreen : .lossRed)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(ratioType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(holdingColor.opacity(0.2), lineWidth: 3)
                                .frame(width: 30, height: 30)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(min(1.0, NSDecimalNumber(decimal: ratio / 100).doubleValue)))
                                .stroke(holdingColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 30, height: 30)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text("\(ratio.formatted(fractionDigits: 1))%")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                    }
                    
                    // 切換按鈕
                    Button(action: {
                        let newType: HoldingRatioType = ratioType == .totalAssets ? .totalInvestments : .totalAssets
                        ratioType = newType
                        HoldingRatioPreference.set(newType)
                    }) {
                        Text("切換")
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(holdingColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - FIFO 批次列表
    private var fifoLotsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FIFO 批次（按帳戶分組）")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            ForEach(aggregatedHolding.fifoLotsByAccount) { accountGroup in
                FIFOAccountGroupCard(
                    accountGroup: accountGroup,
                    currency: aggregatedHolding.currency,
                    currentPrice: currentPrice
                )
            }
        }
    }
    
    // MARK: - 底部操作按鈕
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            // 買入按鈕
            Button(action: {
                // TODO: 實作買入功能
                print("買入: \(aggregatedHolding.symbol)")
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("買入")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.profitGreen)
                .cornerRadius(12)
            }
            
            // 賣出按鈕
            Button(action: {
                // TODO: 實作賣出功能
                print("賣出: \(aggregatedHolding.symbol)")
            }) {
                HStack {
                    Image(systemName: "minus.circle.fill")
                    Text("賣出")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.separator.opacity(0.3)),
            alignment: .top
        )
    }
}

// MARK: - FIFO 帳戶組卡片
struct FIFOAccountGroupCard: View {
    let accountGroup: FIFOLotsByAccountSnapshot
    let currency: Currency
    let currentPrice: Decimal?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 帳戶名稱
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                
                Text(accountGroup.accountName)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text("\(accountGroup.lots.count)個批次")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Divider()
            
            // 批次列表
            VStack(spacing: 8) {
                ForEach(accountGroup.lots.sorted(by: { $0.buyDate < $1.buyDate })) { lot in
                    FIFOLotRow(
                        lot: lot,
                        currency: currency,
                        currentPrice: currentPrice
                    )
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - FIFO 批次行
struct FIFOLotRow: View {
    let lot: FIFOLotSnapshot
    let currency: Currency
    let currentPrice: Decimal?
    
    // 計算市值（原幣）
    var marketValue: Decimal {
        guard let price = currentPrice else { return 0 }
        return lot.remainingQuantity * price
    }
    
    // 計算總成本（原幣）
    var totalCost: Decimal {
        lot.remainingQuantity * lot.costPerUnit
    }
    
    // 計算未實現損益（原幣）
    var unrealizedGainLoss: Decimal {
        marketValue - totalCost
    }
    
    // 計算未實現損益百分比
    var unrealizedGainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 買入日期和數量
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("買入日期")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Text(lot.buyDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("剩餘數量")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Text(lot.remainingQuantity.formatted(fractionDigits: 4))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
            }
            
            // 單位成本和當前價格
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("單位成本")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Text(lot.costPerUnit.formatted(currency: currency))
                        .font(.caption)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                if let price = currentPrice {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("當前價格")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                        
                        Text(price.formatted(currency: currency))
                            .font(.caption)
                            .foregroundColor(.primaryText)
                    }
                }
            }
            
            Divider()
            
            // 總成本和未實現損益
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總成本")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    Text(totalCost.formatted(currency: currency))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("未實現損益")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(unrealizedGainLoss.formatted(currency: currency))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("(\(unrealizedGainLossPercent.formatted(fractionDigits: 1))%)")
                            .font(.caption2)
                    }
                    .foregroundColor(unrealizedGainLoss >= 0 ? .profitGreen : .lossRed)
                }
            }
        }
        .padding(12)
        .background(Color.secondaryBackground)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        HoldingDetailView(
            aggregatedHolding: AggregatedHoldingSnapshot(
                userId: "test-user",
                assetType: .stockTW,
                symbol: "2330",
                name: "台積電",
                currency: .TWD,
                totalQuantity: 10,
                weightedAverageCost: 500,
                totalCost: 5000,
                sourceAccountIds: ["account1", "account2"],
                fifoLotsByAccount: [
                    FIFOLotsByAccountSnapshot(
                        accountId: "account1",
                        accountName: "台新證券",
                        lots: [
                            FIFOLotSnapshot(
                                id: "lot1",
                                accountId: "account1",
                                accountName: "台新證券",
                                buyDate: Date(),
                                remainingQuantity: 5,
                                costPerUnit: 480,
                                currency: .TWD
                            )
                        ]
                    )
                ]
            ),
            assetPriceSnapshot: AssetPriceSnapshot(
                assetType: .stockTW,
                symbol: "2330",
                name: "台積電",
                currency: .TWD,
                currentPrice: 550
            ),
            totalAssets: 100000,
            totalInvestments: 80000
        )
    }
}
