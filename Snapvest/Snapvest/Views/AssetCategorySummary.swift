//
//  AssetCategorySummary.swift
//  Snapvest
//
//  資產分頁：全局控制 + 台股／美股／加密三格摘要（方向 A）
//

import SwiftUI

// MARK: - 全局顯示選項

enum AssetsCurrencyDisplay: String, CaseIterable, Identifiable {
    case twd
    case original
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .twd: return "台幣"
        case .original: return "原幣"
        }
    }
}

enum AssetCategoryFilterSelection {
    static let allCategories: Set<AssetType> = [.stockTW, .stockUS, .crypto]
    static let displayOrder: [AssetType] = [.stockTW, .stockUS, .crypto]
    
    /// 空集合或全選 → 不篩選（顯示全部）
    static func activeFilter(from selection: Set<AssetType>) -> Set<AssetType> {
        if selection.isEmpty || selection == allCategories {
            return []
        }
        return selection
    }
    
    static func toggle(_ type: AssetType, in selection: inout Set<AssetType>) {
        if selection.contains(type) {
            selection.remove(type)
        } else {
            selection.insert(type)
        }
        if selection == allCategories {
            selection.removeAll()
        }
    }
    
    static func categorySortOrder(_ type: AssetType) -> Int {
        displayOrder.firstIndex(of: type) ?? 99
    }
}

// MARK: - 小 chip 按鈕（與「所有持股」排序鈕同款）

struct AssetsFilterChipLabel: View {
    let title: String
    var icon: String? = nil
    var isActive: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .contentTransition(.interpolate)
        }
        .foregroundColor(isActive ? .appPrimary : .secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.appPrimary.opacity(0.35) : Color.separator.opacity(0.35), lineWidth: 1)
        )
    }
}

struct AssetsFilterChipButton: View {
    let title: String
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AssetsFilterChipLabel(title: title, icon: icon, isActive: isActive)
        }
        .buttonStyle(.plain)
    }
}

/// 持股列表依市值排序（資產分頁、帳戶詳情共用）
enum HoldingsMarketValueSort {
    case descending
    case ascending
    
    mutating func cycle() {
        switch self {
        case .descending: self = .ascending
        case .ascending: self = .descending
        }
    }
    
    var iconName: String {
        switch self {
        case .descending: return "arrow.down"
        case .ascending: return "arrow.up"
        }
    }
}

/// Toolbar 用 chip（透明底 + 描邊，避免與導航列 glass 背景疊成雙層泡泡）
struct AccountToolbarChip: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.appPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appPrimary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

struct TransactionHistoryToolbarChip: View {
    let action: () -> Void
    
    var body: some View {
        AccountToolbarChip(icon: "clock.fill", title: "交易紀錄", action: action)
    }
}

struct TransactionImportToolbarChip: View {
    let action: () -> Void
    
    var body: some View {
        AccountToolbarChip(icon: "square.and.arrow.down", title: "匯入", action: action)
    }
}

// MARK: - 頂部控制列

struct AssetsDisplayControlsBar: View {
    @Binding var ratioType: HoldingRatioType
    @Binding var currencyDisplay: AssetsCurrencyDisplay
    
    private var ratioIcon: String {
        ratioType == .totalAssets ? "chart.pie.fill" : "chart.bar.fill"
    }
    
    private var currencyIcon: String {
        currencyDisplay == .twd ? "dollarsign.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                AssetsFilterChipButton(
                    title: ratioType.segmentLabel,
                    icon: ratioIcon,
                    isActive: true
                ) {
                    let newType: HoldingRatioType = ratioType == .totalAssets ? .totalInvestments : .totalAssets
                    withAnimation(ChartMotion.switchSpring) {
                        ratioType = newType
                    }
                    HoldingRatioPreference.set(newType)
                }
                .animation(ChartMotion.switchSpring, value: ratioType)
                
                AssetsFilterChipButton(
                    title: currencyDisplay.label,
                    icon: currencyIcon,
                    isActive: true
                ) {
                    withAnimation(ChartMotion.switchSpring) {
                        currencyDisplay = currencyDisplay == .twd ? .original : .twd
                    }
                }
                .animation(ChartMotion.switchSpring, value: currencyDisplay)
            }
        }
    }
}

// MARK: - 帳戶分頁：幣別切換（與資產分頁 chip 同款）

struct AccountsCurrencyControlsBar: View {
    @Binding var currencyDisplay: AssetsCurrencyDisplay
    
    private var currencyIcon: String {
        currencyDisplay == .twd ? "dollarsign.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            AssetsFilterChipButton(
                title: currencyDisplay.label,
                icon: currencyIcon,
                isActive: true
            ) {
                withAnimation(ChartMotion.switchSpring) {
                    currencyDisplay = currencyDisplay == .twd ? .original : .twd
                }
            }
            .animation(ChartMotion.switchSpring, value: currencyDisplay)
        }
    }
}

// MARK: - 類別摘要數據

struct AssetCategorySummaryMetrics {
    let holdingCount: Int
    let marketValueTWD: Decimal
    let totalCostTWD: Decimal
    let marketValueOriginal: Decimal
    let totalCostOriginal: Decimal
    let portfolioRatio: Decimal
    
    var unrealizedGainLossTWD: Decimal { marketValueTWD - totalCostTWD }
    var unrealizedGainLossOriginal: Decimal { marketValueOriginal - totalCostOriginal }
    
    var unrealizedGainLossPercentTWD: Decimal {
        guard totalCostTWD > 0 else { return 0 }
        return (unrealizedGainLossTWD / totalCostTWD) * 100
    }
    
    var unrealizedGainLossPercentOriginal: Decimal {
        guard totalCostOriginal > 0 else { return 0 }
        return (unrealizedGainLossOriginal / totalCostOriginal) * 100
    }
    
    static func compute(
        holdings: [AggregatedHoldingSnapshot],
        assetPriceSnapshots: [AssetPriceSnapshot],
        usdToTwdRate: Decimal,
        ratioType: HoldingRatioType,
        totalAssets: Decimal,
        totalInvestments: Decimal,
        assetType: AssetType
    ) -> AssetCategorySummaryMetrics {
        let categoryHoldings = holdings.filter { $0.assetType == assetType }
        var priceMap: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            priceMap["\(snapshot.assetType.rawValue)_\(snapshot.symbol)"] = snapshot
        }
        
        var marketValueTWD: Decimal = 0
        var marketValueOriginal: Decimal = 0
        
        for holding in categoryHoldings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            let mv = holding.totalQuantity * currentPrice
            marketValueOriginal += mv
            if holding.currency == .TWD {
                marketValueTWD += mv
            } else if holding.currency == .USD {
                marketValueTWD += mv * usdToTwdRate
            }
        }
        
        var totalCostTWD: Decimal = 0
        var totalCostOriginal: Decimal = 0
        for holding in categoryHoldings {
            totalCostOriginal += holding.totalCost
            if holding.currency == .TWD {
                totalCostTWD += holding.totalCost
            } else if holding.currency == .USD {
                totalCostTWD += holding.totalCost * usdToTwdRate
            }
        }
        
        let denominator = ratioType == .totalAssets ? totalAssets : totalInvestments
        let ratio = denominator > 0 ? (marketValueTWD / denominator) * 100 : 0
        
        return AssetCategorySummaryMetrics(
            holdingCount: categoryHoldings.count,
            marketValueTWD: marketValueTWD,
            totalCostTWD: totalCostTWD,
            marketValueOriginal: marketValueOriginal,
            totalCostOriginal: totalCostOriginal,
            portfolioRatio: ratio
        )
    }
}

// MARK: - 三格摘要區

struct AssetCategorySummariesSection: View {
    let aggregatedHoldings: [AggregatedHoldingSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let totalAssets: Decimal
    let totalInvestments: Decimal
    let usdToTwdRate: Decimal
    let ratioType: HoldingRatioType
    let currencyDisplay: AssetsCurrencyDisplay
    let selectedCategories: Set<AssetType>
    let onCategoryTap: (AssetType) -> Void
    
    private var categories: [AssetType] { AssetCategoryFilterSelection.displayOrder }
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(categories, id: \.self) { assetType in
                let metrics = AssetCategorySummaryMetrics.compute(
                    holdings: aggregatedHoldings,
                    assetPriceSnapshots: assetPriceSnapshots,
                    usdToTwdRate: usdToTwdRate,
                    ratioType: ratioType,
                    totalAssets: totalAssets,
                    totalInvestments: totalInvestments,
                    assetType: assetType
                )
                AssetCategorySummaryCard(
                    assetType: assetType,
                    metrics: metrics,
                    ratioType: ratioType,
                    currencyDisplay: currencyDisplay,
                    isSelected: selectedCategories.contains(assetType),
                    onTap: { onCategoryTap(assetType) }
                )
            }
        }
    }
}

// MARK: - 單格摘要卡

struct AssetCategorySummaryCard: View {
    let assetType: AssetType
    let metrics: AssetCategorySummaryMetrics
    let ratioType: HoldingRatioType
    let currencyDisplay: AssetsCurrencyDisplay
    let isSelected: Bool
    let onTap: () -> Void
    
    private var accentColor: Color {
        switch assetType {
        case .stockTW: return .stockTWColor
        case .stockUS: return .stockUSColor
        case .crypto: return .cryptoColor
        case .cash: return .appPrimary
        }
    }
    
    private var categoryIcon: String {
        switch assetType {
        case .stockTW: return "chart.line.uptrend.xyaxis"
        case .stockUS: return "dollarsign.circle.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .cash: return "banknote.fill"
        }
    }
    
    private var usesOriginalAmounts: Bool {
        currencyDisplay == .original && assetType != .stockTW
    }
    
    private var displayCurrency: Currency {
        usesOriginalAmounts ? .USD : .TWD
    }
    
    private var displayMarketValue: Decimal {
        usesOriginalAmounts ? metrics.marketValueOriginal : metrics.marketValueTWD
    }
    
    private var displayUnrealized: Decimal {
        usesOriginalAmounts ? metrics.unrealizedGainLossOriginal : metrics.unrealizedGainLossTWD
    }
    
    private var displayUnrealizedPercent: Decimal {
        usesOriginalAmounts ? metrics.unrealizedGainLossPercentOriginal : metrics.unrealizedGainLossPercentTWD
    }
    
    private var plColor: Color {
        if displayUnrealized > 0 { return .marketUp }
        if displayUnrealized < 0 { return .marketDown }
        return .secondaryText
    }
    
    private var countLabel: String {
        metrics.holdingCount == 0 ? "尚無持股" : "\(metrics.holdingCount) 檔"
    }
    
    private var marketValueFractionDigits: Int {
        usesOriginalAmounts ? 2 : 0
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(assetType.displayName)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text(countLabel)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer(minLength: 8)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(displayMarketValue.formatted(currency: displayCurrency, fractionDigits: marketValueFractionDigits))
                        .font(.snapAmountRow)
                        .foregroundColor(.primaryText)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    HStack(spacing: 4) {
                        if metrics.holdingCount > 0 {
                            Image(systemName: displayUnrealized >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2.weight(.bold))
                        }
                        Text(displayUnrealized.formatted(currency: displayCurrency, fractionDigits: marketValueFractionDigits))
                        Text("(\(displayUnrealizedPercent.formatted(fractionDigits: 1))%)")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(plColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    
                    Text("\(ratioType.segmentLabel) \(metrics.portfolioRatio.formatted(fractionDigits: 1))%")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.cardBackground)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor)
                    .frame(width: isSelected ? 5 : 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? accentColor.opacity(0.5) : Color.separator.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected ? accentColor.opacity(0.18) : AppColors.shadowMedium,
                radius: isSelected ? 8 : 6,
                x: 0,
                y: isSelected ? 3 : 2
            )
            .scaleEffect(isSelected ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .animation(ChartMotion.switchSpring, value: isSelected)
        .animation(ChartMotion.switchSpring, value: currencyDisplay)
    }
}
