//
//  PortfolioAllocationChartView.swift
//  Snapvest
//
//  首頁圓餅圖：總資產 / 投資組合 / 所有細項
//

import SwiftUI
import Charts

// MARK: - 圓餅圖數據項
struct PieChartDataItem: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let marketValue: Decimal
    let color: Color
    
    init(symbol: String, name: String, marketValue: Decimal, color: Color) {
        self.id = symbol
        self.symbol = symbol
        self.name = name
        self.marketValue = marketValue
        self.color = color
    }
    
    var value: Double {
        NSDecimalNumber(decimal: marketValue).doubleValue
    }
}

enum PieChartDisplayMode: String, CaseIterable, Identifiable {
    case totalAssets = "總資產"
    case portfolio = "投資組合"
    case allDetails = "所有細項"
    
    var id: String { rawValue }
}

enum PortfolioPieChartBuilder {
    /// 總資產：五大類
    static func totalAssetsItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        let rate = inputs.usdToTwdRate
        var tw: Decimal = 0, us: Decimal = 0, crypto: Decimal = 0
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)
        for h in inputs.aggregatedHoldings {
            guard let mv = HoldingChartMetrics.marketValueTWD(holding: h, priceMap: priceMap, rate: rate) else { continue }
            switch h.assetType {
            case .stockTW: tw += mv
            case .stockUS: us += mv
            case .crypto: crypto += mv
            case .cash: break
            }
        }
        let segments: [(String, String, Decimal, Color)] = [
            ("twd_cash", "台幣現金", inputs.twdCash, AppColors.allocationTwdCash),
            ("usd_cash", "美金現金", inputs.usdCash * rate, AppColors.allocationUsdCash),
            ("stock_us", "美股", us, AppColors.allocationStockUS),
            ("stock_tw", "台股", tw, AppColors.allocationStockTW),
            ("crypto", "加密貨幣", crypto, AppColors.allocationCrypto),
        ]
        return segments.filter { $0.2 > 0 }.map {
            PieChartDataItem(symbol: $0.0, name: $0.1, marketValue: $0.2, color: $0.3)
        }
    }
    
    /// 投資組合：各檔持股（不含現金）
    static func portfolioItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        holdingItems(inputs: inputs, includeCash: false)
    }
    
    /// 所有細項：現金 + 各檔持股
    static func allDetailsItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        holdingItems(inputs: inputs, includeCash: true)
    }
    
    static func denominator(mode: PieChartDisplayMode, inputs: PieChartInputs, totalAssets: Decimal, totalInvestments: Decimal) -> Decimal {
        switch mode {
        case .totalAssets, .allDetails:
            return totalAssets > 0 ? totalAssets : sumOfItems(mode: mode, inputs: inputs)
        case .portfolio:
            return totalInvestments > 0 ? totalInvestments : sumOfItems(mode: mode, inputs: inputs)
        }
    }
    
    static func items(
        mode: PieChartDisplayMode,
        inputs: PieChartInputs
    ) -> [PieChartDataItem] {
        switch mode {
        case .totalAssets: return totalAssetsItems(inputs: inputs)
        case .portfolio: return portfolioItems(inputs: inputs)
        case .allDetails: return allDetailsItems(inputs: inputs)
        }
    }
    
    private static func sumOfItems(mode: PieChartDisplayMode, inputs: PieChartInputs) -> Decimal {
        items(mode: mode, inputs: inputs).reduce(0) { $0 + $1.marketValue }
    }
    
    private static func holdingItems(inputs: PieChartInputs, includeCash: Bool) -> [PieChartDataItem] {
        let rate = inputs.usdToTwdRate
        var result: [PieChartDataItem] = []
        if includeCash {
            if inputs.twdCash > 0 {
                result.append(PieChartDataItem(
                    symbol: "twd_cash", name: "台幣現金",
                    marketValue: inputs.twdCash, color: AppColors.allocationTwdCash
                ))
            }
            let usdTWD = inputs.usdCash * rate
            if usdTWD > 0 {
                result.append(PieChartDataItem(
                    symbol: "usd_cash", name: "美金現金",
                    marketValue: usdTWD, color: AppColors.allocationUsdCash
                ))
            }
        }
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)
        var stockRows: [(AggregatedHoldingSnapshot, Decimal)] = []
        for h in inputs.aggregatedHoldings {
            guard h.assetType != .cash,
                  let mv = HoldingChartMetrics.marketValueTWD(holding: h, priceMap: priceMap, rate: rate) else { continue }
            stockRows.append((h, mv))
        }
        stockRows.sort { $0.1 > $1.1 }
        for (index, row) in stockRows.enumerated() {
            let h = row.0
            let displayName: String
            if h.assetType == .stockTW, let n = h.name, !n.isEmpty { displayName = n }
            else { displayName = h.symbol }
            let color = HoldingChartMetrics.colorForHolding(h, index: index)
            result.append(PieChartDataItem(
                symbol: "\(h.assetType.rawValue)_\(h.symbol)",
                name: displayName,
                marketValue: row.1,
                color: color
            ))
        }
        return result
    }
}

// MARK: - 首頁圓餅圖區塊
struct HomePieChartSection: View {
    let inputs: PieChartInputs?
    let totalAssets: Decimal
    let totalInvestments: Decimal
    
    @State private var mode: PieChartDisplayMode = .totalAssets
    @State private var selectedId: String?
    @State private var contentPhase: CGFloat = 1
    
    private var currentItems: [PieChartDataItem] {
        guard let inputs else { return [] }
        return PortfolioPieChartBuilder.items(mode: mode, inputs: inputs)
    }
    
    private var denominator: Decimal {
        guard let inputs else { return totalAssets }
        return PortfolioPieChartBuilder.denominator(
            mode: mode,
            inputs: inputs,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pieChartHeader
            
            ChartSegmentedControl(
                options: PieChartDisplayMode.allCases,
                selection: $mode,
                label: { $0.rawValue },
                fontSize: 12
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: mode) { _, _ in
                withAnimation(ChartMotion.switchQuick) { contentPhase = 0.72 }
                withAnimation(ChartMotion.switchSpring) {
                    contentPhase = 1
                    selectedId = currentItems.max(by: { $0.value < $1.value })?.id
                }
            }
            
            if currentItems.isEmpty {
                Text("尚無可顯示的資料")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                Group {
                    PortfolioDonutChart(
                        data: currentItems,
                        denominator: denominator,
                        selectedId: $selectedId,
                        displayMode: mode
                    )
                    .padding(.vertical, 4)
                    
                    PortfolioAllocationLegend(
                        data: currentItems,
                        denominator: denominator,
                        selectedId: $selectedId,
                        mode: mode
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .animation(ChartMotion.switchSpring, value: mode)
                .opacity(contentPhase)
                .scaleEffect(0.98 + contentPhase * 0.02)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        .onAppear { pickLargest() }
        .onChange(of: inputs?.aggregatedHoldings.count) { _, _ in pickLargest() }
    }
    
    private func pickLargest() {
        selectedId = currentItems.max(by: { $0.value < $1.value })?.id
    }
    
    private var pieChartHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("圓餅圖")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primaryText)
            Text("·")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.tertiaryText)
            Text(mode.rawValue)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.appPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .animation(ChartMotion.switchSpring, value: mode)
    }
}

// MARK: - 細環甜甜圈
struct PortfolioDonutChart: View {
    let data: [PieChartDataItem]
    let denominator: Decimal
    @Binding var selectedId: String?
    var displayMode: PieChartDisplayMode = .totalAssets
    @State private var selectedAngle: Double?
    
    private let chartSize: CGFloat = 228
    /// 環變瘦：內徑比例越大環越細
    private let innerRadiusRatio: CGFloat = 0.78
    
    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }
    
    private var selectedItem: PieChartDataItem? {
        guard let selectedId else { return nil }
        return data.first(where: { $0.id == selectedId })
    }
    
    var body: some View {
        ZStack {
            Chart {
                ForEach(data) { item in
                    let selected = selectedItem?.id == item.id
                    SectorMark(
                        angle: .value("配置", item.value),
                        innerRadius: .ratio(innerRadiusRatio),
                        outerRadius: .ratio(1.0),
                        angularInset: 2.0
                    )
                    .foregroundStyle(item.color)
                    .opacity(selected ? 1.0 : (selectedId == nil ? 1.0 : 0.42))
                }
            }
            .animation(ChartMotion.switchSpring, value: displayMode)
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)
            .onChange(of: selectedAngle) { _, v in
                if let v { updateSelection(from: v) }
            }
            .frame(width: chartSize, height: chartSize)
            
            if let selected = selectedItem ?? data.max(by: { $0.value < $1.value }) {
                VStack(spacing: 2) {
                    Text(selected.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.opacity)
                    Text(percentageText(for: selected))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(selected.color)
                        .contentTransition(.numericText())
                }
                .frame(width: chartSize * innerRadiusRatio * 1.2)
                .animation(ChartMotion.switchSpring, value: selectedId)
                .animation(ChartMotion.switchSpring, value: displayMode)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func percentageText(for item: PieChartDataItem) -> String {
        let pct = (item.value / totalDouble) * 100
        return String(format: "%.2f%%", pct)
    }
    
    private func updateSelection(from value: Double) {
        let sum = data.reduce(0.0) { $0 + $1.value }
        guard sum > 0 else { return }
        if value >= 0, value <= sum * 1.001 {
            var cumulative: Double = 0
            for item in data {
                cumulative += item.value
                if value <= cumulative {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedId = item.id
                    }
                    return
                }
            }
            selectedId = data.last?.id
            return
        }
        var angle = value
        while angle < 0 { angle += 360 }
        while angle >= 360 { angle -= 360 }
        let normalized = (angle - 90) < -90 ? angle - 90 + 360 : angle - 90
        var start: Double = -90
        for item in data {
            let span = max((item.value / sum) * 360, 1)
            if normalized >= start - 1 && normalized < start + span + 1 {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    selectedId = item.id
                }
                return
            }
            start += span
        }
    }
}

// MARK: - 圖例
struct PortfolioAllocationLegend: View {
    let data: [PieChartDataItem]
    let denominator: Decimal
    @Binding var selectedId: String?
    let mode: PieChartDisplayMode
    
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    
    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }
    
    private var orderedRows: [PieChartDataItem] {
        switch mode {
        case .totalAssets:
            let order = ["twd_cash", "usd_cash", "stock_us", "stock_tw", "crypto"]
            return order.compactMap { id in data.first(where: { $0.id == id }) }
        case .portfolio:
            return data.sorted { $0.marketValue > $1.marketValue }
        case .allDetails:
            let cash = data.filter { $0.id == "twd_cash" || $0.id == "usd_cash" }
            let stocks = data.filter { $0.id != "twd_cash" && $0.id != "usd_cash" }
                .sorted { $0.marketValue > $1.marketValue }
            return cash + stocks
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(orderedRows) { item in
                legendRow(item: item)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(ChartMotion.switchSpring, value: mode)
    }
    
    private func legendRow(item: PieChartDataItem) -> some View {
        let pct = (NSDecimalNumber(decimal: item.marketValue).doubleValue / totalDouble) * 100
        let isSelected = selectedId == item.id
        return Button {
            withAnimation(ChartMotion.switchSpring) {
                selectedId = item.id
            }
        } label: {
            HStack(spacing: 12) {
                Circle().fill(item.color).frame(width: 10, height: 10)
                Text(item.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primaryText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f%%", pct))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                    if !hideHomeAmounts {
                        Text(item.marketValue.formatted(currency: .TWD, fractionDigits: 0))
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.primaryText.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
