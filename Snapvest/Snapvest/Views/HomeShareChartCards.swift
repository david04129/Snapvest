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

    private var isGroupingEnabled: Bool {
        config.pieIsGroupingEnabled
    }
    
    private var baseItems: [PieChartDataItem] {
        guard let inputs else { return [] }
        return PieChartGroupingModeSupport.effectiveBaseItems(
            mode: config.pieMode,
            inputs: inputs,
            isGroupingEnabled: isGroupingEnabled
        )
    }
    
    private var displayItems: [PieChartDataItem] {
        PieChartGroupingEngine.applyGroups(
            baseItems: baseItems,
            groups: PieChartGroupingStore.shared.groups,
            mode: config.pieMode,
            isGroupingEnabled: isGroupingEnabled
        )
    }
    
    private var legendRows: [PieChartLegendRow] {
        PieChartGroupingEngine.legendRows(
            baseItems: baseItems,
            displayItems: displayItems,
            groups: PieChartGroupingStore.shared.groups,
            mode: config.pieMode,
            isGroupingEnabled: isGroupingEnabled
        )
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

            if displayItems.isEmpty {
                Text("尚無可顯示的資料")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                HomeShareLabeledDonutChart(
                    data: displayItems,
                    denominator: denominator,
                    centerTitle: config.pieMode.rawValue,
                    showsSliceLabels: config.pieShowsSliceLabels
                )
                .padding(.top, 4)
                .padding(.bottom, 2)

                if config.pieShowsLegend {
                    PortfolioGroupedAllocationLegend(
                        rows: legendRows,
                        displayMode: config.pieMode,
                        denominator: denominator,
                        selectedId: .constant(nil),
                        isGroupingEnabled: config.pieIsGroupingEnabled,
                        isEditingGroups: false,
                        selectedMemberIds: .constant([]),
                        expandedGroupIds: .constant(config.pieExpandedGroupIds),
                        addToGroupId: .constant(nil),
                        selectionEditCategory: .constant(nil),
                        onRenameGroup: { _ in },
                        onRequestDissolveGroup: { _ in },
                        onRemoveMember: { _, _ in },
                        onToggleAddToGroup: { _ in },
                        onToggleMemberSelection: { _ in },
                        showsGroupActions: false
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                } else {
                    Spacer(minLength: 10)
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HomeShareLabeledDonutChart: View {
    let data: [PieChartDataItem]
    let denominator: Decimal
    let centerTitle: String
    let showsSliceLabels: Bool

    private let chartSize: CGFloat = 196
    private let chartAreaHeight: CGFloat = 250
    private let innerRadiusRatio: CGFloat = 0.78
    private let labelWidth: CGFloat = 104

    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }

    private var chartTotalDouble: Double {
        max(data.reduce(0.0) { $0 + $1.value }, 0.001)
    }

    private var labelCandidates: [HomeSharePieSliceLabel] {
        var startAngle: Double = 0
        let candidates = data.compactMap { item -> HomeSharePieSliceLabel? in
            let pct = item.value / totalDouble
            let span = max((item.value / chartTotalDouble) * 360, 0)
            defer { startAngle += span }

            guard pct > 0.05 else { return nil }
            return HomeSharePieSliceLabel(
                item: item,
                percentage: pct,
                midAngleDegrees: startAngle + span / 2
            )
        }

        return candidates
            .sorted { $0.percentage > $1.percentage }
            .reduce(into: [HomeSharePieSliceLabel]()) { accepted, label in
                let sameSideLabels = accepted.filter { $0.isRightSide == label.isRightSide }
                guard sameSideLabels.allSatisfy({ abs($0.verticalOffset - label.verticalOffset) >= 26 }) else { return }
                accepted.append(label)
            }
            .sorted { $0.midAngleDegrees < $1.midAngleDegrees }
    }

    var body: some View {
        ZStack {
            chart
                .frame(width: chartSize, height: chartSize)

            centerSummary
                .frame(width: chartSize * innerRadiusRatio * 1.18)

            if showsSliceLabels {
                ForEach(labelCandidates) { label in
                    labelCallout(label)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartAreaHeight)
    }

    private var chart: some View {
        Chart {
            ForEach(data) { item in
                SectorMark(
                    angle: .value("配置", item.value),
                    innerRadius: .ratio(innerRadiusRatio),
                    outerRadius: .ratio(1.0),
                    angularInset: 2.0
                )
                .foregroundStyle(item.color)
            }
        }
        .chartLegend(.hidden)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var centerSummary: some View {
        VStack(spacing: 4) {
            Text(centerTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("配置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
    }

    private func labelCallout(_ label: HomeSharePieSliceLabel) -> some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let textX = label.isRightSide
                ? center.x + chartSize / 2 + 28
                : center.x - chartSize / 2 - 28
            let textY = min(max(center.y + label.verticalOffset, 30), chartAreaHeight - 30)

            HStack(spacing: 5) {
                Circle()
                    .fill(label.item.color)
                    .frame(width: 6, height: 6)

                Text(labelText(for: label))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .frame(width: labelWidth, alignment: label.isRightSide ? .leading : .trailing)
            .background(Color.cardBackground.opacity(0.94))
            .clipShape(Capsule())
            .position(x: textX, y: textY)
        }
        .allowsHitTesting(false)
    }

    private func labelText(for label: HomeSharePieSliceLabel) -> String {
        "\(shortName(label.item.name)) \(percentText(label.percentage, fractionDigits: 0))"
    }

    private func shortName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 6 else { return trimmed }
        return String(trimmed.prefix(6))
    }

    private func percentText(_ value: Double, fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f%%", value * 100)
    }

}

private struct HomeSharePieSliceLabel: Identifiable {
    let item: PieChartDataItem
    let percentage: Double
    let midAngleDegrees: Double

    var id: String { item.id }

    var isRightSide: Bool {
        midAngleDegrees < 180
    }

    var verticalOffset: CGFloat {
        CGFloat(-cos(midAngleDegrees * .pi / 180)) * 88
    }
}

// MARK: - 績效圖

struct HomePerformanceChartShareCard: View {
    let config: HomeShareRenderConfig

    private var rows: [HoldingPerformanceRow] {
        guard let inputs = config.pieInputs else { return [] }
        let groups = PieChartGroupingStore.shared.groups
        let all: [HoldingPerformanceRow]
        all = PieChartGroupingModeSupport.performanceRows(
            inputs: inputs,
            groups: groups,
            pieMode: config.pieMode,
            isGroupingEnabled: config.pieIsGroupingEnabled
        )
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
