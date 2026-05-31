//
//  HomeTrendChartView.swift
//  Snapvest
//
//  首頁走勢圖：總資產 / 淨資產，可互動顯示當日數值
//

import SwiftUI
import Charts

// MARK: - 資料模型

struct TrendChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let totalAssets: Decimal
    let netWorth: Decimal
    let unrealizedGainLoss: Decimal
    
    func displayValue(for mode: TrendMetricMode) -> Decimal {
        mode == .totalAssets ? totalAssets : netWorth
    }

    /// 未實現損益報酬率（相對於總資產扣除未實現損益的近似成本）
    var unrealizedReturnPercent: Decimal {
        let costBasis = totalAssets - unrealizedGainLoss
        guard costBasis > 0 else { return 0 }
        return (unrealizedGainLoss / costBasis) * 100
    }
}

extension TrendChartPoint {
    init(localSnapshot snapshot: LocalDailyTrendSnapshot) {
        self.init(
            id: snapshot.id,
            date: snapshot.date,
            totalAssets: snapshot.totalAssets,
            netWorth: snapshot.netWorth,
            unrealizedGainLoss: snapshot.unrealizedGainLoss
        )
    }
}

enum TrendMetricMode: String, CaseIterable, Identifiable {
    case netWorth = "淨資產"
    case totalAssets = "總資產"
    
    var id: String { rawValue }
}

/// 走勢區間起點 → 終點的漲跌（起點固定為區間第一筆）
struct TrendChartIntervalChange {
    let startPoint: TrendChartPoint
    let endPoint: TrendChartPoint
    let metricMode: TrendMetricMode

    var startValue: Decimal { startPoint.displayValue(for: metricMode) }
    var endValue: Decimal { endPoint.displayValue(for: metricMode) }
    var changeAmount: Decimal { endValue - startValue }

    var changePercent: Decimal {
        guard startValue != 0 else { return 0 }
        return (changeAmount / abs(startValue)) * 100
    }
}

// MARK: - 走勢資料篩選

enum TrendChartDataFilter {
    static func filtered(
        points: [TrendChartPoint],
        range: DateRangePreset,
        now: Date = Date(),
        customStart: Date,
        customEnd: Date
    ) -> [TrendChartPoint] {
        let interval = DateRangePresetCalculator.dateInterval(
            for: range,
            now: now,
            customStart: customStart,
            customEnd: customEnd
        )
        return points.filter { interval.contains($0.date) }
    }

    static func dateInterval(
        range: DateRangePreset,
        now: Date = Date(),
        customStart: Date,
        customEnd: Date
    ) -> DateInterval {
        DateRangePresetCalculator.dateInterval(
            for: range,
            now: now,
            customStart: customStart,
            customEnd: customEnd
        )
    }
}

// MARK: - 圖表繪製用序列（固定 path + X 視窗）

enum TrendChartSeries {
    /// 一年日資料約 365 點；線性插值下全繪仍可接受，超過才降採樣。
    static let maxRenderPoints = 366

    static func sorted(_ points: [TrendChartPoint]) -> [TrendChartPoint] {
        points.sorted { $0.date < $1.date }
    }

    /// 均勻降採樣，維持首尾；繪圖用，不影響數值讀取。
    static func downsampled(_ points: [TrendChartPoint], maxCount: Int = maxRenderPoints) -> [TrendChartPoint] {
        guard points.count > maxCount, maxCount >= 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            let sourceIndex = Int((Double(index) * step).rounded())
            return points[min(sourceIndex, points.count - 1)]
        }
    }

    static func visibleXDomain(
        in points: [TrendChartPoint],
        interval: DateInterval
    ) -> ClosedRange<Date>? {
        let visible = points.filter { interval.contains($0.date) }
        guard let first = visible.first?.date, let last = visible.last?.date else { return nil }
        if first == last {
            let pad = 86_400.0
            let lower = Date(timeIntervalSince1970: first.timeIntervalSince1970 - pad)
            let upper = Date(timeIntervalSince1970: last.timeIntervalSince1970 + pad)
            return lower...upper
        }
        return first...last
    }

    /// 假設 `points` 已按日期遞增排序。
    static func nearestIndex(to date: Date, in points: [TrendChartPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        if date <= points[0].date { return 0 }
        if date >= points[points.count - 1].date { return points.count - 1 }

        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }

        if low == 0 { return 0 }
        let previous = low - 1
        let lhs = points[previous].date.timeIntervalSince(date)
        let rhs = points[low].date.timeIntervalSince(date)
        return abs(lhs) <= abs(rhs) ? previous : low
    }

    /// 與 LineMark `.linear` 插值一致，讓選取圓點落在可見曲線上。
    static func interpolatedY(
        at date: Date,
        renderPoints: [TrendChartPoint],
        yValuesByPointId: [String: Double]
    ) -> Double? {
        guard let first = renderPoints.first, let last = renderPoints.last else { return nil }
        if date <= first.date {
            return yValuesByPointId[first.id]
        }
        if date >= last.date {
            return yValuesByPointId[last.id]
        }

        for index in 1..<renderPoints.count {
            let left = renderPoints[index - 1]
            let right = renderPoints[index]
            guard date >= left.date, date <= right.date else { continue }

            let y0 = yValuesByPointId[left.id] ?? 0
            let y1 = yValuesByPointId[right.id] ?? 0
            let t0 = left.date.timeIntervalSince1970
            let t1 = right.date.timeIntervalSince1970
            guard t1 > t0 else { return y0 }
            let progress = (date.timeIntervalSince1970 - t0) / (t1 - t0)
            return y0 + (y1 - y0) * progress
        }
        return nil
    }
}

/// 走勢圖繪製快取（避免每次 body 重算排序／降採樣／Y domain）。
private struct TrendChartRenderBundle: Equatable {
    let renderPoints: [TrendChartPoint]
    let yValuesByPointId: [String: Double]
    let filteredPoints: [TrendChartPoint]
    let yDomain: ClosedRange<Double>
    let xDomain: ClosedRange<Date>
    let xDomainKey: String

    static func make(
        trendPoints: [TrendChartPoint],
        metricMode: TrendMetricMode,
        baseDivisor: Decimal,
        timeRange: DateRangePreset,
        customStart: Date,
        customEnd: Date
    ) -> TrendChartRenderBundle? {
        let sorted = TrendChartSeries.sorted(trendPoints)
        guard !sorted.isEmpty else { return nil }

        let interval = TrendChartDataFilter.dateInterval(
            range: timeRange,
            customStart: customStart,
            customEnd: customEnd
        )
        let filtered = sorted.filter { interval.contains($0.date) }
        guard !filtered.isEmpty,
              let xDomain = TrendChartSeries.visibleXDomain(in: sorted, interval: interval) else {
            return nil
        }

        let renderPoints = TrendChartSeries.downsampled(sorted)
        var yValuesByPointId: [String: Double] = [:]
        yValuesByPointId.reserveCapacity(renderPoints.count)
        for point in renderPoints {
            let decimalValue = point.displayValue(for: metricMode) / baseDivisor
            yValuesByPointId[point.id] = NSDecimalNumber(decimal: decimalValue).doubleValue
        }

        let visibleValues = filtered.map { point in
            NSDecimalNumber(decimal: point.displayValue(for: metricMode) / baseDivisor).doubleValue
        }
        guard let minV = visibleValues.min(), let maxV = visibleValues.max() else { return nil }
        let padding = max((maxV - minV) * 0.08, abs(maxV) * 0.02, 1)
        let yDomain = (minV - padding)...(maxV + padding)
        let xDomainKey = "\(xDomain.lowerBound.timeIntervalSince1970)-\(xDomain.upperBound.timeIntervalSince1970)"

        return TrendChartRenderBundle(
            renderPoints: renderPoints,
            yValuesByPointId: yValuesByPointId,
            filteredPoints: filtered,
            yDomain: yDomain,
            xDomain: xDomain,
            xDomainKey: xDomainKey
        )
    }
}

// MARK: - 首頁走勢圖區塊

struct HomeTrendChartSection: View {
    var userId: String
    var currency: Currency = .TWD
    
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    private let dataService: DataServiceProtocol = MockDataService.shared
    @Binding var metricMode: TrendMetricMode
    @Binding var timeRange: DateRangePreset
    @Binding var trendPoints: [TrendChartPoint]
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isLoading = false
    @State private var loadFailed = false
    
    private var shouldShowLoading: Bool {
        isLoading && trendPoints.isEmpty
    }
    
    @State private var pinnedSelectionIndex: Int?
    @State private var scrubIndex: Int?
    @State private var isScrubbing = false
    @State private var activeCustomDateField: CustomDatePickerField?
    @State private var contentPhase: CGFloat = 1
    @State private var chartBundle: TrendChartRenderBundle?
    @State private var chartXDomain: ClosedRange<Date> = Date()...Date()

    private var filteredPoints: [TrendChartPoint] {
        chartBundle?.filteredPoints ?? []
    }
    
    private var earliestChartDate: Date {
        chartBundle?.renderPoints.first?.date
            ?? trendPoints.map(\.date).min()
            ?? Calendar.current.date(byAdding: .day, value: -120, to: Date())
            ?? Date()
    }
    
    private var rangeStartPoint: TrendChartPoint? {
        filteredPoints.first
    }

    private var activeDisplayIndex: Int? {
        if let scrubIndex, filteredPoints.indices.contains(scrubIndex) {
            return scrubIndex
        }
        if let pinnedSelectionIndex, filteredPoints.indices.contains(pinnedSelectionIndex) {
            return pinnedSelectionIndex
        }
        guard !filteredPoints.isEmpty else { return nil }
        return filteredPoints.count - 1
    }

    private var displayPoint: TrendChartPoint? {
        guard let index = activeDisplayIndex else { return nil }
        return filteredPoints[index]
    }

    private var isChartSelectionActive: Bool {
        isScrubbing || pinnedSelectionIndex != nil
    }

    private var trendChartReloadToken: String {
        let stamp = portfolioViewModel.homeSnapshot?.lastUpdated.timeIntervalSince1970 ?? 0
        return "\(userId)-\(stamp)"
    }
    
    private var baseDivisor: Decimal {
        guard currency != .TWD, portfolioViewModel.twdPerBaseCurrency > 0 else { return 1 }
        return portfolioViewModel.twdPerBaseCurrency
    }

    private func chartDisplayValue(for point: TrendChartPoint) -> Decimal {
        point.displayValue(for: metricMode) / baseDivisor
    }

    private func chartDisplayDouble(for point: TrendChartPoint) -> Double {
        NSDecimalNumber(decimal: chartDisplayValue(for: point)).doubleValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartTitleHeader
            
            ChartSegmentedControl(
                options: TrendMetricMode.allCases,
                selection: $metricMode,
                label: { $0.rawValue }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: metricMode) { _, _ in
                refreshChartBundle(animateXDomain: false)
                animateContentSwitch()
            }
            if let endPoint = displayPoint, let startPoint = rangeStartPoint {
                TrendChartValueInfo(
                    endPoint: endPoint,
                    rangeStartPoint: startPoint,
                    metricMode: metricMode,
                    currency: currency,
                    twdPerBaseCurrency: baseDivisor,
                    isSelected: isChartSelectionActive,
                    hideAmounts: hideHomeAmounts,
                    animateNumericTransitions: !isScrubbing
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .opacity(contentPhase)
            }
            
            if shouldShowLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if chartBundle == nil {
                emptyState
            } else {
                trendChart
                    .frame(height: 220)
                    .padding(.horizontal, 8)
                    .opacity(contentPhase)
            }
            
            DateRangePresetPicker(selection: $timeRange)
                .padding(.horizontal, 12)
                .padding(.top, filteredPoints.isEmpty ? 8 : 4)
                .padding(.bottom, timeRange == .custom ? 0 : 14)
                .onChange(of: timeRange) { _, newRange in
                    refreshChartBundle(animateXDomain: true)
                    if newRange != .custom {
                        resetSelectionToLatest()
                        animateContentSwitch()
                    }
                }
            
            if timeRange == .custom {
                CustomDateRangeBar(
                    startDate: customStartDate,
                    endDate: customEndDate,
                    onStartTapped: { activeCustomDateField = .start },
                    onEndTapped: { activeCustomDateField = .end }
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        .sheet(item: $activeCustomDateField) { field in
            WheelDatePickerSheet(
                title: field.title,
                selection: field == .start ? $customStartDate : $customEndDate,
                earliestDate: earliestChartDate,
                onDone: {
                    normalizeCustomRange()
                    activeCustomDateField = nil
                    refreshChartBundle(animateXDomain: true)
                    resetSelectionToLatest()
                    animateContentSwitch()
                }
            )
        }
        .onAppear {
            resetSelectionToLatest()
            refreshChartBundle(animateXDomain: false)
        }
        .task(id: trendChartReloadToken) {
            await loadLocalTrendPoints()
            refreshChartBundle(animateXDomain: false)
        }
        .onChange(of: trendPoints) { _, _ in
            refreshChartBundle(animateXDomain: false)
            resetSelectionToLatest()
        }
        .onChange(of: portfolioViewModel.twdPerBaseCurrency) { _, _ in
            refreshChartBundle(animateXDomain: false)
        }
        .onChange(of: customStartDate) { _, _ in
            refreshChartBundle(animateXDomain: true)
            resetSelectionToLatest()
            animateContentSwitch()
        }
        .onChange(of: customEndDate) { _, _ in
            refreshChartBundle(animateXDomain: true)
            resetSelectionToLatest()
            animateContentSwitch()
        }
        .animation(ChartMotion.switchSpring, value: timeRange == .custom)
    }
    
    private var chartTitleHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("走勢圖")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primaryText)
            Text("·")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.tertiaryText)
            Text(metricMode.rawValue)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.appPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var trendChart: some View {
        Group {
            if let bundle = chartBundle {
                trendChartContent(bundle: bundle)
            }
        }
    }

    private func trendChartContent(bundle: TrendChartRenderBundle) -> some View {
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
                RuleMark(x: .value("選取", selected.date))
                    .foregroundStyle(Color.secondaryText.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("日期", selected.date),
                    y: .value("金額", plotY)
                )
                .foregroundStyle(Color.appPrimary)
                .symbolSize(64)
                .annotation(position: .overlay) {
                    Circle()
                        .strokeBorder(Color.cardBackground, lineWidth: 2)
                        .background(Circle().fill(Color.appPrimary))
                        .frame(width: 10, height: 10)
                }
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
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: bundle.yDomain)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(proxy: proxy, geometry: geometry, filteredPoints: bundle.filteredPoints))
            }
        }
    }

    private func scrubGesture(
        proxy: ChartProxy,
        geometry: GeometryProxy,
        filteredPoints: [TrendChartPoint]
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isScrubbing {
                    isScrubbing = true
                }
                updateScrubIndex(
                    at: gesture.location,
                    proxy: proxy,
                    geometry: geometry,
                    filteredPoints: filteredPoints
                )
            }
            .onEnded { _ in
                if let scrubIndex {
                    pinnedSelectionIndex = scrubIndex
                }
                isScrubbing = false
                self.scrubIndex = nil
            }
    }
    
    private func refreshChartBundle(animateXDomain: Bool) {
        guard let bundle = TrendChartRenderBundle.make(
            trendPoints: trendPoints,
            metricMode: metricMode,
            baseDivisor: baseDivisor,
            timeRange: timeRange,
            customStart: customStartDate,
            customEnd: customEndDate
        ) else {
            chartBundle = nil
            return
        }

        chartBundle = bundle
        if animateXDomain {
            withAnimation(ChartMotion.switchSpring) {
                chartXDomain = bundle.xDomain
            }
        } else {
            chartXDomain = bundle.xDomain
        }
    }
    
    private var emptyState: some View {
        Text(emptyStateMessage)
            .font(.subheadline)
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private var emptyStateMessage: String {
        if loadFailed { return "無法載入走勢資料" }
        return "尚無足夠資料顯示走勢"
    }
    
    private func loadLocalTrendPoints() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let start = Calendar.current.date(byAdding: .day, value: -400, to: Date())
            let snapshots = try await dataService.fetchLocalDailyTrendSnapshots(
                userId: userId,
                startDate: start,
                endDate: Date()
            )
            let loadedPoints = snapshots.map(TrendChartPoint.init(localSnapshot:))
            if loadedPoints != trendPoints {
                trendPoints = loadedPoints
            }
            loadFailed = false
        } catch {
            loadFailed = true
            #if DEBUG
            print("[HomeTrendChart] local load failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Y 軸標籤：台幣優先用「萬」，並依區間跨度決定小數位，避免 1.8M～2.0M 全部顯示成 2M
    private func compactAxisLabel(_ value: Double, domain: ClosedRange<Double>) -> String {
        let span = domain.upperBound - domain.lowerBound
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        if absValue >= 10_000 {
            let wan = absValue / 10_000
            if span < 100_000 {
                return sign + String(format: "%.1f萬", wan)
            }
            return sign + String(format: "%.0f萬", wan)
        }
        if absValue >= 1_000 {
            let k = absValue / 1_000
            if span < 10_000 {
                return sign + String(format: "%.1fK", k)
            }
            return sign + String(format: "%.0fK", k)
        }
        return sign + String(format: "%.0f", absValue)
    }
    
    private func updateScrubIndex(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        filteredPoints: [TrendChartPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let xPosition = location.x - origin.x
        guard xPosition >= 0, xPosition <= geometry[plotFrame].width else { return }
        guard let date: Date = proxy.value(atX: xPosition),
              let index = TrendChartSeries.nearestIndex(to: date, in: filteredPoints),
              scrubIndex != index else {
            return
        }
        scrubIndex = index
    }
    
    private func normalizeCustomRange() {
        if customStartDate > customEndDate {
            swap(&customStartDate, &customEndDate)
        }
    }
    
    private func resetSelectionToLatest() {
        pinnedSelectionIndex = nil
        scrubIndex = nil
        isScrubbing = false
    }
    
    private func animateContentSwitch() {
        withAnimation(ChartMotion.switchQuick) { contentPhase = 0.72 }
        withAnimation(ChartMotion.switchSpring) { contentPhase = 1 }
    }
}

// MARK: - 數值資訊區（與圖表分離）

struct TrendChartValueInfo: View {
    let endPoint: TrendChartPoint
    let rangeStartPoint: TrendChartPoint
    let metricMode: TrendMetricMode
    let currency: Currency
    let twdPerBaseCurrency: Decimal
    let isSelected: Bool
    var hideAmounts: Bool = false
    /// 拖曳 scrub 時關閉數字 spring，避免每個資料點都觸發動畫。
    var animateNumericTransitions: Bool = true

    private var baseDivisor: Decimal {
        guard currency != .TWD, twdPerBaseCurrency > 0 else { return 1 }
        return twdPerBaseCurrency
    }

    private var displayValue: Decimal {
        endPoint.displayValue(for: metricMode) / baseDivisor
    }

    private var changeAmount: Decimal {
        displayValue - (rangeStartPoint.displayValue(for: metricMode) / baseDivisor)
    }

    private var changePercent: Decimal {
        let startValue = rangeStartPoint.displayValue(for: metricMode) / baseDivisor
        guard startValue != 0 else { return 0 }
        return (changeAmount / abs(startValue)) * 100
    }

    private var valueColor: Color {
        if metricMode == .netWorth && displayValue < 0 {
            return .lossRed
        }
        return .primaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CurrencyAmountWithChip(
                text: hideAmounts
                    ? HomeAmountPrivacyFormat.masked
                    : displayValue.formatted(currency: currency),
                currency: currency,
                font: .system(size: 28, weight: .bold, design: .rounded),
                weight: .bold,
                color: valueColor,
                chipTint: AppColors.appPrimary
            )
                .modifier(TrendChartNumericTransitionModifier(
                    enabled: animateNumericTransitions,
                    value: displayValue
                ))

            Text(intervalChangeText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.marketColor(for: changeAmount))
                .modifier(TrendChartNumericTransitionModifier(
                    enabled: animateNumericTransitions,
                    value: changeAmount
                ))

            Text(formatDate(endPoint.date))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? AppColors.appPrimary : .secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intervalChangeText: String {
        let percent = formatPercent(changePercent)
        if hideAmounts {
            return percent
        }
        let prefix = changeAmount >= 0 ? "+" : ""
        let amount = prefix + changeAmount.formatted(currency: currency, showSymbol: false)
        return "\(amount) (\(percent))"
    }

    private func formatPercent(_ value: Decimal) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + value.formatted(fractionDigits: 2) + "%"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

private struct TrendChartNumericTransitionModifier: ViewModifier {
    let enabled: Bool
    let value: Decimal

    func body(content: Content) -> some View {
        if enabled {
            content
                .contentTransition(.numericText())
                .animation(ChartMotion.switchSpring, value: value)
        } else {
            content
        }
    }
}
