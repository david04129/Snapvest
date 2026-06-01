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
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

struct CurrencyDisplayChipButton: View {
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                if currencyDisplay == .twd {
                    CurrencyCodeChip(currency: baseCurrency, tint: .appPrimary)
                } else {
                    Text(currencyDisplay.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(isActive ? .appPrimary : .secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.appPrimary.opacity(0.35) : Color.separator.opacity(0.35), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    @ObservedObject private var baseCurrency = BaseCurrencyManager.shared

    @Binding var ratioType: HoldingRatioType
    @Binding var currencyDisplay: AssetsCurrencyDisplay

    private var ratioIcon: String {
        ratioType == .totalAssets ? "chart.pie.fill" : "chart.bar.fill"
    }
    
    private var currencyIcon: String {
        currencyDisplay == .twd ? "dollarsign.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    private var currencyTitle: String {
        currencyDisplay == .twd ? baseCurrency.baseCurrency.rawValue : currencyDisplay.label
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
                
                CurrencyDisplayChipButton(
                    currencyDisplay: currencyDisplay,
                    baseCurrency: baseCurrency.baseCurrency,
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
    @ObservedObject private var baseCurrency = BaseCurrencyManager.shared

    @Binding var currencyDisplay: AssetsCurrencyDisplay
    var shareDisplayMode: Binding<ManagementShareDisplayMode>? = nil
    var showsEditControl: Bool = false
    var isEditingOrder: Bool = false
    var isEditDisabled: Bool = false
    var onEditTapped: (() -> Void)? = nil
    
    private var currencyIcon: String {
        currencyDisplay == .twd ? "dollarsign.circle.fill" : "arrow.triangle.2.circlepath"
    }
    
    private var currencyTitle: String {
        currencyDisplay == .twd ? baseCurrency.baseCurrency.rawValue : currencyDisplay.label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if showsEditControl, let onEditTapped {
                    AssetsFilterChipButton(
                        title: isEditingOrder ? "完成" : "編輯排序",
                        icon: isEditingOrder ? "checkmark" : "square.and.pencil",
                        isActive: !isEditDisabled
                    ) {
                        onEditTapped()
                    }
                    .disabled(isEditDisabled)
                    .opacity(isEditDisabled ? 0.45 : 1)
                }
                
                if let shareDisplayMode {
                    AssetsFilterChipButton(
                        title: shareDisplayMode.wrappedValue.chipTitle,
                        icon: shareDisplayMode.wrappedValue.chipIcon,
                        isActive: shareDisplayMode.wrappedValue == .shareRing
                    ) {
                        withAnimation(ChartMotion.switchSpring) {
                            let next: ManagementShareDisplayMode =
                                shareDisplayMode.wrappedValue == .shareRing ? .currencyIcon : .shareRing
                            shareDisplayMode.wrappedValue = next
                            ManagementShareDisplayPreference.set(next)
                        }
                    }
                    .disabled(isEditingOrder)
                    .opacity(isEditingOrder ? 0.45 : 1)
                }

                Spacer(minLength: 0)
                
                CurrencyDisplayChipButton(
                    currencyDisplay: currencyDisplay,
                    baseCurrency: baseCurrency.baseCurrency,
                    icon: currencyIcon,
                    isActive: true
                ) {
                    withAnimation(ChartMotion.switchSpring) {
                        currencyDisplay = currencyDisplay == .twd ? .original : .twd
                    }
                }
                .disabled(isEditingOrder)
                .opacity(isEditingOrder ? 0.45 : 1)
                .animation(ChartMotion.switchSpring, value: currencyDisplay)
            }
            
            if isEditingOrder {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("正在編輯帳戶排序，拖曳帳戶右側控制點調整順序，完成後才能進行其他操作。")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(ChartMotion.switchSpring, value: isEditingOrder)
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
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let ratioType: HoldingRatioType
    let currencyDisplay: AssetsCurrencyDisplay
    let selectedCategories: Set<AssetType>
    let marketStatus: MarketStatusSnapshot?
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
                if metrics.holdingCount == 0 {
                    EmptyView()
                } else {
                AssetCategorySummaryCard(
                    assetType: assetType,
                    metrics: metrics,
                    ratioType: ratioType,
                    baseCurrency: baseCurrency,
                    twdPerBaseCurrency: twdPerBaseCurrency,
                    currencyDisplay: currencyDisplay,
                    marketStatus: marketStatus,
                    isSelected: selectedCategories.contains(assetType),
                    onTap: { onCategoryTap(assetType) }
                )
                }
            }
        }
    }
}

// MARK: - 單格摘要卡

struct AssetCategorySummaryCard: View {
    let assetType: AssetType
    let metrics: AssetCategorySummaryMetrics
    let ratioType: HoldingRatioType
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let marketStatus: MarketStatusSnapshot?
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
    
    private var usesOriginalAmounts: Bool {
        currencyDisplay == .original
    }
    
    private var displayCurrency: Currency {
        usesOriginalAmounts ? assetType.quoteCurrency : baseCurrency
    }
    
    private var displayMarketValue: Decimal {
        guard !usesOriginalAmounts else { return metrics.marketValueOriginal }
        return twdPerBaseCurrency > 0 ? metrics.marketValueTWD / twdPerBaseCurrency : metrics.marketValueTWD
    }
    
    private var displayUnrealized: Decimal {
        guard !usesOriginalAmounts else { return metrics.unrealizedGainLossOriginal }
        return twdPerBaseCurrency > 0 ? metrics.unrealizedGainLossTWD / twdPerBaseCurrency : metrics.unrealizedGainLossTWD
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
        usesOriginalAmounts || baseCurrency != .TWD ? 2 : 0
    }

    private var unrealizedSummaryText: String {
        let amount = displayUnrealized.formatted(
            currency: displayCurrency,
            fractionDigits: marketValueFractionDigits,
            showSymbol: false
        )
        let percent = displayUnrealizedPercent.formatted(fractionDigits: 1)
        return "\(amount) (\(percent)%)"
    }

    private var portfolioRatioText: String {
        "\(ratioType.segmentLabel) \(metrics.portfolioRatio.formatted(fractionDigits: 1))%"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(assetType.displayName)
                            .font(.snapOverviewText)
                            .foregroundColor(.primaryText)
                            .snapOverviewFittingLine()
                        if let chip = MarketSessionDisplay.categorySessionChip(
                            assetType: assetType,
                            marketStatus: marketStatus
                        ) {
                            PriceSessionChip(chip: chip)
                        }
                    }
                    Text(countLabel)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .layoutPriority(1)
                
                Spacer(minLength: 8)
                
                VStack(alignment: .trailing, spacing: 4) {
                    CurrencyAmountWithChip(
                        text: displayMarketValue.formatted(currency: displayCurrency, fractionDigits: marketValueFractionDigits),
                        currency: displayCurrency,
                        font: .snapOverviewAmount,
                        weight: .bold,
                        color: .primaryText,
                        chipTint: accentColor,
                        minimumScaleFactor: SnapOverviewBarMetrics.minScaleFactor
                    )
                    .monospacedDigit()
                    .snapOverviewFittingLine()

                    HStack(spacing: 4) {
                        if metrics.holdingCount > 0 {
                            Image(systemName: MarketDirectionSymbol.systemName(for: displayUnrealized))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(plColor)
                        }
                        Text(unrealizedSummaryText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(plColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Text(portfolioRatioText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText())
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .snapCappedDynamicTypeSize()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.cardBackground)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor)
                    .frame(width: SnapOverviewBarMetrics.overviewWidth)
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
