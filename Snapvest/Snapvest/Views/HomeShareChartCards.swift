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

    private var chartBundle: TrendChartRenderBundle? {
        TrendChartRenderBundle.make(
            trendPoints: config.trendPoints,
            metricMode: config.trendMetricMode,
            baseDivisor: baseDivisor,
            timeRange: config.trendTimeRange,
            customStart: config.trendCustomStart,
            customEnd: config.trendCustomEnd
        )
    }

    private var filteredPoints: [TrendChartPoint] {
        chartBundle?.filteredPoints ?? config.effectiveTrendPoints
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
                    twdPerBaseCurrency: config.twdPerBaseCurrency,
                    isSelected: false,
                    hideAmounts: hideHomeAmounts
                )
                .freeLimitBlurred(.numbers)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            if filteredPoints.count >= 2 {
                trendChart
                    .freeLimitBlurred(.charts)
                    .frame(height: 200)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var trendChart: some View {
        Group {
            if let bundle = chartBundle {
                Chart {
                    ForEach(bundle.renderPoints) { point in
                        let value = bundle.yValuesByPointId[point.id] ?? 0
                        AreaMark(
                            x: .value("日期", point.date),
                            yStart: .value("基準", bundle.yDomain.lowerBound),
                            yEnd: .value("金額", value)
                        )
                        .foregroundStyle(Color.appPrimary.opacity(0.14))
                        .interpolationMethod(.linear)

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("金額", value)
                        )
                        .foregroundStyle(Color.appPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                        .interpolationMethod(.linear)
                    }

                    if let selected = displayPoint,
                       let plotY = TrendChartSeries.interpolatedY(
                           at: selected.date,
                           renderPoints: bundle.renderPoints,
                           yValuesByPointId: bundle.yValuesByPointId
                       ) {
                        PointMark(
                            x: .value("日期", selected.date),
                            y: .value("金額", plotY)
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
                                    Text(compactAxisLabel(doubleValue, domain: bundle.yDomain))
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
                .chartXScale(domain: bundle.xDomain)
                .chartYScale(domain: bundle.yDomain)
            }
        }
    }

    private var baseDivisor: Decimal {
        guard config.currency != .TWD, config.twdPerBaseCurrency > 0 else { return 1 }
        return config.twdPerBaseCurrency
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
            shareCardHeader(title: "圓餅圖", subtitle: config.pieMode.rawValue, currency: config.currency)

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
                .freeLimitBlurred(.pie)
                .padding(.top, 4)
                .padding(.bottom, 2)

                if config.pieShowsLegend {
                    PortfolioGroupedAllocationLegend(
                        rows: legendRows,
                        displayMode: config.pieMode,
                        denominator: denominator,
                        displayCurrency: config.currency,
                        twdPerDisplayCurrency: config.twdPerBaseCurrency,
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
                    .freeLimitBlurred(.numbers, .pie)
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

    private let chartSize: CGFloat = 164
    private let innerRadiusRatio: CGFloat = 0.78
    private let minVisibleShare: Double = 0.01
    private let sideColumnGap: CGFloat = 8
    private let labelColumnWidth: CGFloat = 84
    private let minLabelSpacing: CGFloat = 17

    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }

    private var chartTotalDouble: Double {
        max(data.reduce(0.0) { $0 + $1.value }, 0.001)
    }

    private var rawSliceLabels: [HomeSharePieSliceLabel] {
        var startAngle: Double = 0
        return data.compactMap { item -> HomeSharePieSliceLabel? in
            let pct = item.value / totalDouble
            let span = max((item.value / chartTotalDouble) * 360, 0)
            defer { startAngle += span }

            guard pct >= minVisibleShare else { return nil }
            return HomeSharePieSliceLabel(
                item: item,
                percentage: pct,
                midAngleDegrees: startAngle + span / 2
            )
        }
    }

    private var chartAreaHeight: CGFloat {
        let rightCount = rawSliceLabels.filter(\.isRightSide).count
        let leftCount = rawSliceLabels.count - rightCount
        let maxSide = max(rightCount, leftCount, 1)
        return max(268, CGFloat(maxSide) * minLabelSpacing + 96)
    }

    private var sliceLabels: [HomeSharePieSliceLabel] {
        layoutSliceLabels(
            rawSliceLabels,
            verticalLimit: chartAreaHeight / 2 - 26
        )
    }

    private func layoutSliceLabels(
        _ candidates: [HomeSharePieSliceLabel],
        verticalLimit: CGFloat
    ) -> [HomeSharePieSliceLabel] {
        func layoutSide(_ sideLabels: [HomeSharePieSliceLabel]) -> [HomeSharePieSliceLabel] {
            let sorted = sideLabels.sorted { $0.idealVerticalOffset < $1.idealVerticalOffset }
            var laidOut: [HomeSharePieSliceLabel] = []
            var previousY: CGFloat?

            for var label in sorted {
                var y = label.idealVerticalOffset
                if let previousY, y - previousY < minLabelSpacing {
                    y = previousY + minLabelSpacing
                }
                y = min(max(y, -verticalLimit), verticalLimit)
                label.layoutVerticalOffset = y
                laidOut.append(label)
                previousY = y
            }
            return laidOut
        }

        let right = layoutSide(candidates.filter(\.isRightSide))
        let left = layoutSide(candidates.filter { !$0.isRightSide })
        return (right + left).sorted { $0.midAngleDegrees < $1.midAngleDegrees }
    }

    var body: some View {
        ZStack {
            if showsSliceLabels {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    ForEach(sliceLabels) { label in
                        leaderLine(for: label, center: center)
                    }
                }
            }

            chart
                .frame(width: chartSize, height: chartSize)

            centerSummary
                .frame(width: chartSize * innerRadiusRatio * 1.15)

            if showsSliceLabels {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    ForEach(sliceLabels) { label in
                        labelCallout(label, center: center)
                    }
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
                    angularInset: 1.6
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
        VStack(spacing: 3) {
            Text(centerTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("配置")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
    }

    private func labelAnchorX(for label: HomeSharePieSliceLabel, center: CGPoint) -> CGFloat {
        let halfColumn = labelColumnWidth / 2
        if label.isRightSide {
            return center.x + chartSize / 2 + sideColumnGap + halfColumn
        }
        return center.x - chartSize / 2 - sideColumnGap - halfColumn
    }

    private func dotAnchor(for label: HomeSharePieSliceLabel, center: CGPoint) -> CGPoint {
        let columnX = labelAnchorX(for: label, center: center)
        let dotX = label.isRightSide
            ? columnX - labelColumnWidth / 2 + 4
            : columnX + labelColumnWidth / 2 - 4
        return CGPoint(x: dotX, y: center.y + label.layoutVerticalOffset)
    }

    private func leaderLine(for label: HomeSharePieSliceLabel, center: CGPoint) -> some View {
        let angleRad = label.midAngleDegrees * Double.pi / 180
        let rim = Double(chartSize / 2 + 1)
        let slicePoint = CGPoint(
            x: center.x + CGFloat(sin(angleRad) * rim),
            y: center.y - CGFloat(cos(angleRad) * rim)
        )
        let dotPoint = dotAnchor(for: label, center: center)
        let elbowX = label.isRightSide
            ? slicePoint.x + 10
            : slicePoint.x - 10

        return Path { path in
            path.move(to: slicePoint)
            path.addLine(to: CGPoint(x: elbowX, y: slicePoint.y))
            path.addLine(to: dotPoint)
        }
        .stroke(
            label.item.color.opacity(0.42),
            style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
        )
        .allowsHitTesting(false)
    }

    private func labelCallout(_ label: HomeSharePieSliceLabel, center: CGPoint) -> some View {
        let anchorX = labelAnchorX(for: label, center: center)
        let anchorY = center.y + label.layoutVerticalOffset

        return HStack(spacing: 0) {
            if label.isRightSide {
                HStack(spacing: 5) {
                    Circle()
                        .fill(label.item.color)
                        .frame(width: 7, height: 7)
                    labelText(for: label)
                }
                .frame(width: labelColumnWidth, alignment: .leading)
            } else {
                HStack(spacing: 5) {
                    labelText(for: label)
                    Circle()
                        .fill(label.item.color)
                        .frame(width: 7, height: 7)
                }
                .frame(width: labelColumnWidth, alignment: .trailing)
            }
        }
        .position(x: anchorX, y: anchorY)
        .allowsHitTesting(false)
    }

    private func labelText(for label: HomeSharePieSliceLabel) -> some View {
        HStack(spacing: 3) {
            Text(displayTitle(for: label.item))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(percentText(label.percentage))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
    }

    private func displayTitle(for item: PieChartDataItem) -> String {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return item.symbol }
        if name.count <= 8 {
            return name
        }
        return String(name.prefix(7)) + "…"
    }

    private func percentText(_ value: Double) -> String {
        if value >= 0.01 {
            return String(format: "%.0f%%", value * 100)
        }
        return String(format: "%.1f%%", value * 100)
    }
}

private struct HomeSharePieSliceLabel: Identifiable {
    let item: PieChartDataItem
    let percentage: Double
    let midAngleDegrees: Double
    let idealVerticalOffset: CGFloat
    var layoutVerticalOffset: CGFloat

    var id: String { item.id }

    init(item: PieChartDataItem, percentage: Double, midAngleDegrees: Double) {
        self.item = item
        self.percentage = percentage
        self.midAngleDegrees = midAngleDegrees
        let angleRad = midAngleDegrees * Double.pi / 180
        let ideal = CGFloat(-cos(angleRad) * 82)
        self.idealVerticalOffset = ideal
        self.layoutVerticalOffset = ideal
    }

    var isRightSide: Bool {
        sin(midAngleDegrees * Double.pi / 180) >= 0
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
            shareCardHeader(
                title: "績效圖",
                subtitle: config.performanceMode.rawValue,
                currency: config.performanceMode == .gainLoss ? config.currency : nil
            )

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
                            maxAbsValue: maxAbsChartValue,
                            currency: config.currency,
                            twdPerBaseCurrency: config.twdPerBaseCurrency,
                            blurHoldingNames: config.applyFreeLimitBlur
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
        case .gainLoss:
            let baseDivisor: Decimal = config.currency == .TWD ? 1 : (config.twdPerBaseCurrency > 0 ? config.twdPerBaseCurrency : 1)
            return NSDecimalNumber(decimal: row.unrealizedGainLossTWD / baseDivisor).doubleValue
        case .returnRate: return row.returnPercentDouble
        }
    }
}

// MARK: - 共用

private func shareCardHeader(title: String, subtitle: String, currency: Currency? = nil) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.primaryText)
        Text("·")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppColors.tertiaryText)
        Text(subtitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppColors.appPrimary)
        if let currency {
            CurrencyCodeChip(currency: currency, tint: .appPrimary)
        }
        Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
}

private struct HomeSharePerformanceRow: View {
    let row: HoldingPerformanceRow
    let mode: PerformanceDisplayMode
    let maxAbsValue: Double
    let currency: Currency
    let twdPerBaseCurrency: Decimal
    var blurHoldingNames: Bool = false

    @Environment(\.homeAmountsHidden) private var hideHomeAmounts

    private var value: Double {
        switch mode {
        case .gainLoss:
            return NSDecimalNumber(decimal: displayGainLoss).doubleValue
        case .returnRate: return row.returnPercentDouble
        }
    }

    private var displayGainLoss: Decimal {
        guard currency != .TWD,
              twdPerBaseCurrency > 0 else {
            return row.unrealizedGainLossTWD
        }
        return row.unrealizedGainLossTWD / twdPerBaseCurrency
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
            let digits = currency == .TWD ? 0 : 2
            return prefix + displayGainLoss.formatted(currency: currency, fractionDigits: digits, showSymbol: false)
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

    @ViewBuilder
    private var holdingNameLabel: some View {
        let label = Text(row.displayName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(row.color)
            .lineLimit(1)
            .frame(width: 76, alignment: .leading)

        if blurHoldingNames {
            label.freeLimitBlurred(.numbers)
        } else {
            label
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            holdingNameLabel

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
            .freeLimitBlurred(.charts)
            .frame(height: 22)

            Group {
                if mode == .gainLoss {
                    CurrencyAmountWithChip(
                        text: valueText,
                        currency: currency,
                        font: .snapChartRowValue,
                        weight: .semibold,
                        color: valueColor,
                        chipTint: row.color,
                        spacing: 4
                    )
                } else {
                    Text(valueText)
                        .font(.snapChartRowValue)
                        .foregroundColor(valueColor)
                }
            }
            .freeLimitBlurred(.numbers)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: mode == .gainLoss ? 108 : 88, alignment: .trailing)
        }
    }
}
