//
//  HomeShareChartCards.swift
//  Snapvest
//
//  分享用圖表卡片（靜態、無互動控制項）
//

import SwiftUI
import Charts

// MARK: - 走勢圖

struct HomeTrendChartShareCard: View {
    let config: HomeShareRenderConfig

    @Environment(\.homeAmountsHidden) private var hideHomeAmounts

    private var filteredPoints: [TrendChartPoint] {
        config.effectiveTrendPoints
    }

    private var displayPoint: TrendChartPoint? {
        filteredPoints.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shareCardHeader(
                title: "走勢圖",
                subtitle: "\(config.trendMetricMode.rawValue) · \(config.trendTimeRange.rawValue)"
            )

            if let endPoint = displayPoint, let startPoint = filteredPoints.first {
                TrendChartValueInfo(
                    endPoint: endPoint,
                    rangeStartPoint: startPoint,
                    metricMode: config.trendMetricMode,
                    currency: config.currency,
                    isSelected: false,
                    hideAmounts: hideHomeAmounts
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            if filteredPoints.count >= 2 {
                trendChart
                    .frame(height: 200)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var trendChart: some View {
        Chart {
            ForEach(filteredPoints) { point in
                let value = point.displayValue(for: config.trendMetricMode)
                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("金額", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appPrimary.opacity(0.22), Color.appPrimary.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("日期", point.date),
                    y: .value("金額", value)
                )
                .foregroundStyle(Color.appPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if let selected = displayPoint {
                let selectedValue = selected.displayValue(for: config.trendMetricMode)
                PointMark(
                    x: .value("日期", selected.date),
                    y: .value("金額", selectedValue)
                )
                .foregroundStyle(Color.appPrimary)
                .symbolSize(64)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.separator.opacity(0.35))
                if !hideHomeAmounts {
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(compactAxisLabel(doubleValue, domain: yAxisDomain))
                                .font(.system(size: 10))
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .chartYScale(domain: yAxisDomain)
    }

    private var yAxisDomain: ClosedRange<Double> {
        let values = filteredPoints.map {
            NSDecimalNumber(decimal: $0.displayValue(for: config.trendMetricMode)).doubleValue
        }
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        let padding = max((maxV - minV) * 0.08, maxV * 0.02)
        return (minV - padding)...(maxV + padding)
    }

    private func compactAxisLabel(_ value: Double, domain: ClosedRange<Double>) -> String {
        let span = domain.upperBound - domain.lowerBound
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 10_000 {
            let wan = absValue / 10_000
            return sign + String(format: span < 100_000 ? "%.1f萬" : "%.0f萬", wan)
        }
        if absValue >= 1_000 {
            let k = absValue / 1_000
            return sign + String(format: span < 10_000 ? "%.1fK" : "%.0fK", k)
        }
        return sign + String(format: "%.0f", absValue)
    }
}

// MARK: - 圓餅圖

struct HomePieChartShareCard: View {
    let config: HomeShareRenderConfig

    private var inputs: PieChartInputs? { config.pieInputs }

    private var currentItems: [PieChartDataItem] {
        guard let inputs else { return [] }
        return PortfolioPieChartBuilder.items(mode: config.pieMode, inputs: inputs)
    }

    private var denominator: Decimal {
        guard let inputs else { return config.totalAssets }
        return PortfolioPieChartBuilder.denominator(
            mode: config.pieMode,
            inputs: inputs,
            totalAssets: config.totalAssets,
            totalInvestments: config.totalInvestments
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shareCardHeader(title: "圓餅圖", subtitle: config.pieMode.rawValue)

            if currentItems.isEmpty {
                Text("尚無可顯示的資料")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                PortfolioDonutChart(
                    data: currentItems,
                    denominator: denominator,
                    selectedId: .constant(currentItems.max(by: { $0.value < $1.value })?.id),
                    displayMode: config.pieMode
                )
                .padding(.vertical, 4)

                PortfolioAllocationLegend(
                    data: currentItems,
                    denominator: denominator,
                    selectedId: .constant(currentItems.max(by: { $0.value < $1.value })?.id),
                    mode: config.pieMode
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 績效圖

struct HomePerformanceChartShareCard: View {
    let config: HomeShareRenderConfig

    private var rows: [HoldingPerformanceRow] {
        guard let inputs = config.pieInputs else { return [] }
        let all = HoldingChartMetrics.performanceRows(inputs: inputs)
        if config.performanceMode == .gainLoss { return all }
        return all.sorted { $0.returnPercentDouble > $1.returnPercentDouble }
    }

    private var maxAbsChartValue: Double {
        let values = rows.map { chartValue(for: $0) }
        return values.map { abs($0) }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shareCardHeader(title: "績效圖", subtitle: config.performanceMode.rawValue)

            if rows.isEmpty {
                Text("尚無可顯示的持股績效")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        HomeSharePerformanceRow(
                            row: row,
                            mode: config.performanceMode,
                            maxAbsValue: maxAbsChartValue
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chartValue(for row: HoldingPerformanceRow) -> Double {
        switch config.performanceMode {
        case .gainLoss: return row.gainLossDouble
        case .returnRate: return row.returnPercentDouble
        }
    }
}

// MARK: - 共用

private func shareCardHeader(title: String, subtitle: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.primaryText)
        Text("·")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppColors.tertiaryText)
        Text(subtitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppColors.appPrimary)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
}

private struct HomeSharePerformanceRow: View {
    let row: HoldingPerformanceRow
    let mode: PerformanceDisplayMode
    let maxAbsValue: Double

    @Environment(\.homeAmountsHidden) private var hideHomeAmounts

    private var value: Double {
        switch mode {
        case .gainLoss: return row.gainLossDouble
        case .returnRate: return row.returnPercentDouble
        }
    }

    private var isPositive: Bool { value >= 0 }

    private var normalizedWidth: CGFloat {
        guard maxAbsValue > 0 else { return 0 }
        return CGFloat(min(1.0, abs(value) / maxAbsValue))
    }

    private var valueText: String {
        switch mode {
        case .gainLoss:
            if hideHomeAmounts { return HomeAmountPrivacyFormat.masked }
            let prefix = row.unrealizedGainLossTWD >= 0 ? "+" : ""
            return prefix + row.unrealizedGainLossTWD.formatted(currency: .TWD, fractionDigits: 0)
        case .returnRate:
            let sign = row.returnPercent >= 0 ? "+" : ""
            let n = NSDecimalNumber(decimal: row.returnPercent).doubleValue
            return String(format: "%@%.2f%%", sign, n)
        }
    }

    private var valueColor: Color {
        if value > 0 { return .marketUp }
        if value < 0 { return .marketDown }
        return .secondaryText
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(row.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(row.color)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)

            GeometryReader { geo in
                let totalW = geo.size.width
                let barH: CGFloat = 10
                let halfW = totalW / 2
                let barLen = halfW * normalizedWidth
                let midY = geo.size.height / 2
                let centerX = totalW / 2

                ZStack {
                    Rectangle()
                        .fill(Color.primaryText.opacity(0.08))
                        .frame(width: 1, height: barH + 6)
                        .position(x: centerX, y: midY)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(row.color)
                        .frame(width: max(barLen, value != 0 ? 3 : 0), height: barH)
                        .position(
                            x: isPositive ? centerX + barLen / 2 : centerX - barLen / 2,
                            y: midY
                        )
                }
            }
            .frame(height: 22)

            Text(valueText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 88, alignment: .trailing)
        }
    }
}
