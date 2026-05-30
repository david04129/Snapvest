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

// MARK: - 歷史雲端 + 當日即時合併

enum TrendChartPointMerger {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 過去日期用雲端快照；今天一律以本機 HomeDashboardSnapshot 覆蓋（與首頁卡片同源）。
    static func merged(
        historicalPoints: [TrendChartPoint],
        liveSnapshot: HomeDashboardSnapshot?,
        now: Date = Date()
    ) -> [TrendChartPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var points = historicalPoints.filter { !calendar.isDate($0.date, inSameDayAs: today) }

        guard let snapshot = liveSnapshot else {
            return points.sorted { $0.date < $1.date }
        }

        let unrealized = snapshot.totalAssets - snapshot.totalCash - snapshot.totalInvestmentsCost
        points.append(
            TrendChartPoint(
                id: dayFormatter.string(from: today),
                date: today,
                totalAssets: snapshot.totalAssets,
                netWorth: snapshot.netWorth,
                unrealizedGainLoss: unrealized
            )
        )
        return points.sorted { $0.date < $1.date }
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
}

// MARK: - 首頁走勢圖區塊

struct HomeTrendChartSection: View {
    var userId: String
    var currency: Currency = .TWD
    
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @Binding var metricMode: TrendMetricMode
    @Binding var timeRange: DateRangePreset
    @Binding var trendPoints: [TrendChartPoint]
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    @State private var isLoading = false
    @State private var loadFailed = false
    
    private var shouldShowLoading: Bool {
        isLoading && !HomeTrendChartSessionCache.isLoaded(for: userId)
    }
    
    @State private var selectedPoint: TrendChartPoint?
    @State private var activeCustomDateField: CustomDatePickerField?
    @State private var contentPhase: CGFloat = 1
    
    private var filteredPoints: [TrendChartPoint] {
        TrendChartDataFilter.filtered(
            points: trendPoints,
            range: timeRange,
            customStart: customStartDate,
            customEnd: customEndDate
        )
    }
    
    private var earliestChartDate: Date {
        trendPoints.map(\.date).min()
            ?? Calendar.current.date(byAdding: .day, value: -120, to: Date())
            ?? Date()
    }
    
    private var rangeStartPoint: TrendChartPoint? {
        filteredPoints.first
    }

    private var displayPoint: TrendChartPoint? {
        selectedPoint ?? filteredPoints.last
    }
    
    private var baseDivisor: Decimal {
        guard currency != .TWD, portfolioViewModel.twdPerBaseCurrency > 0 else { return 1 }
        return portfolioViewModel.twdPerBaseCurrency
    }

    private func chartDisplayValue(for point: TrendChartPoint) -> Decimal {
        point.displayValue(for: metricMode) / baseDivisor
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
                animateContentSwitch()
            }
            
            if let endPoint = displayPoint, let startPoint = rangeStartPoint {
                TrendChartValueInfo(
                    endPoint: endPoint,
                    rangeStartPoint: startPoint,
                    metricMode: metricMode,
                    currency: currency,
                    twdPerBaseCurrency: baseDivisor,
                    isSelected: selectedPoint != nil,
                    hideAmounts: hideHomeAmounts
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .opacity(contentPhase)
            }
            
            if shouldShowLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if filteredPoints.count < 2 {
                emptyState
            } else {
                trendChart
                    .frame(height: 220)
                    .padding(.horizontal, 8)
                    .opacity(contentPhase)
                    .animation(ChartMotion.switchSpring, value: metricMode)
                    .animation(ChartMotion.switchSpring, value: timeRange)
            }
            
            DateRangePresetPicker(selection: $timeRange)
                .padding(.horizontal, 12)
                .padding(.top, filteredPoints.count < 2 ? 8 : 4)
                .padding(.bottom, timeRange == .custom ? 0 : 14)
                .onChange(of: timeRange) { _, newRange in
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
                    resetSelectionToLatest()
                    animateContentSwitch()
                }
            )
        }
        .onAppear {
            applyCachedTrendPointsIfAvailable()
            if !HomeTrendChartSessionCache.isLoaded(for: userId) {
                refreshMergedTrendPoints()
            }
            resetSelectionToLatest()
        }
        .task(id: userId) {
            if HomeTrendChartSessionCache.isLoaded(for: userId) {
                applyCachedTrendPointsIfAvailable()
                return
            }
            await loadHistoricalTrendPoints()
        }
        .onChange(of: portfolioViewModel.homeSnapshot) { _, _ in
            refreshMergedTrendPoints()
        }
        .onChange(of: filteredPoints.count) { _, _ in resetSelectionToLatest() }
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
            CurrencyCodeChip(currency: currency, tint: AppColors.appPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var trendChart: some View {
        Chart {
            ForEach(filteredPoints) { point in
                let value = chartDisplayValue(for: point)
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
            
            if let selected = selectedPoint ?? filteredPoints.last {
                let selectedValue = chartDisplayValue(for: selected)
                RuleMark(x: .value("選取", selected.date))
                    .foregroundStyle(Color.secondaryText.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                
                PointMark(
                    x: .value("日期", selected.date),
                    y: .value("金額", selectedValue)
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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                updateSelection(at: gesture.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        let values = filteredPoints.map {
            NSDecimalNumber(decimal: chartDisplayValue(for: $0)).doubleValue
        }
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        let padding = max((maxV - minV) * 0.08, maxV * 0.02)
        return (minV - padding)...(maxV + padding)
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
    
    private func refreshMergedTrendPoints() {
        let historical = HomeTrendChartSessionCache.isLoaded(for: userId)
            ? HomeTrendChartSessionCache.historicalPoints
            : []
        trendPoints = TrendChartPointMerger.merged(
            historicalPoints: historical,
            liveSnapshot: portfolioViewModel.homeSnapshot
        )
    }
    
    private func applyCachedTrendPointsIfAvailable() {
        guard HomeTrendChartSessionCache.isLoaded(for: userId) else { return }
        loadFailed = HomeTrendChartSessionCache.loadFailed
        refreshMergedTrendPoints()
        isLoading = false
    }
    
    private func loadHistoricalTrendPoints() async {
        guard !HomeTrendChartSessionCache.isLoaded(for: userId) else {
            applyCachedTrendPointsIfAvailable()
            return
        }
        
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        
        guard SupabaseConfig.isConfigured else {
            HomeTrendChartSessionCache.applyHistorical(userId: userId, points: [], failed: false)
            refreshMergedTrendPoints()
            return
        }
        
        do {
            let start = Calendar.current.date(byAdding: .day, value: -400, to: Date())
            let fetched = try await SupabaseDailySnapshotService.fetchTrendPoints(
                userId: userId,
                startDate: start,
                endDate: Date()
            )
            HomeTrendChartSessionCache.applyHistorical(userId: userId, points: fetched, failed: false)
            loadFailed = false
            refreshMergedTrendPoints()
        } catch {
            HomeTrendChartSessionCache.applyHistorical(userId: userId, points: [], failed: true)
            loadFailed = true
            refreshMergedTrendPoints()
            #if DEBUG
            print("[HomeTrendChart] load failed: \(error.localizedDescription)")
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
    
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let xPosition = location.x - origin.x
        guard xPosition >= 0, xPosition <= geometry[plotFrame].width else { return }
        guard let date: Date = proxy.value(atX: xPosition) else { return }
        selectedPoint = nearestPoint(to: date, in: filteredPoints)
    }
    
    private func nearestPoint(to date: Date, in points: [TrendChartPoint]) -> TrendChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
    
    private func normalizeCustomRange() {
        if customStartDate > customEndDate {
            swap(&customStartDate, &customEndDate)
        }
    }
    
    private func resetSelectionToLatest() {
        selectedPoint = nil
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
            CurrencyAmountLabel(
                text: hideAmounts
                    ? HomeAmountPrivacyFormat.masked
                    : displayValue.formatted(currency: currency),
                currency: currency,
                font: .system(size: 28, weight: .bold, design: .rounded),
                weight: .bold,
                color: valueColor
            )
                .contentTransition(.numericText())
                .animation(ChartMotion.switchSpring, value: displayValue)

            Text(intervalChangeText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.marketColor(for: changeAmount))
                .contentTransition(.numericText())
                .animation(ChartMotion.switchSpring, value: changeAmount)

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
