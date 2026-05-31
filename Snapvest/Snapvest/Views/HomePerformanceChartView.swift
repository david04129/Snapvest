//
//  HomePerformanceChartView.swift
//  Snapvest
//
//  首頁績效圖（炫風圖）：未實現損益金額 / 報酬率
//

import SwiftUI

struct HomePerformanceChartSection: View {
    let inputs: PieChartInputs?
    let pieMode: PieChartDisplayMode
    @ObservedObject var groupingStore: PieChartGroupingStore
    @Binding var mode: PerformanceDisplayMode
    let currency: Currency
    let twdPerBaseCurrency: Decimal
    @State private var contentPhase: CGFloat = 1
    
    private var rows: [HoldingPerformanceRow] {
        guard let inputs else { return [] }
        let all = PieChartGroupingModeSupport.performanceRows(
            inputs: inputs,
            groups: groupingStore.groups,
            pieMode: pieMode,
            isGroupingEnabled: groupingStore.isGroupingEnabled
        )
        if mode == .gainLoss { return all }
        return all.sorted {
            $0.returnPercentDouble > $1.returnPercentDouble
        }
    }

    private var isInteractionLocked: Bool {
        groupingStore.isEditingGroups
    }
    
    private var maxAbsChartValue: Double {
        let values = rows.map { chartValue(for: $0) }
        return values.map { abs($0) }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartHeader(
                title: "績效圖",
                subtitle: mode.rawValue,
                currency: mode == .gainLoss ? currency : nil
            )
            
            ChartSegmentedControl(
                options: PerformanceDisplayMode.allCases,
                selection: $mode,
                label: { $0.rawValue },
                isInteractionEnabled: !isInteractionLocked
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: mode) { _, _ in
                guard !isInteractionLocked else { return }
                withAnimation(ChartMotion.switchQuick) { contentPhase = 0.72 }
                withAnimation(ChartMotion.switchSpring) { contentPhase = 1 }
            }
            
            if rows.isEmpty {
                Text("尚無可顯示的持股績效")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        PerformanceTornadoRow(
                            row: row,
                            mode: mode,
                            maxAbsValue: maxAbsChartValue,
                            currency: currency,
                            twdPerBaseCurrency: twdPerBaseCurrency
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(ChartMotion.switchSpring, value: mode)
                .animation(ChartMotion.switchSpring, value: groupingStore.isGroupingEnabled)
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
                .opacity(contentPhase)
                .scaleEffect(0.98 + contentPhase * 0.02)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        .allowsHitTesting(!isInteractionLocked)
        .opacity(isInteractionLocked ? 0.45 : 1)
        .animation(ChartMotion.switchQuick, value: isInteractionLocked)
    }

    private func chartHeader(title: String, subtitle: String, currency: Currency? = nil) -> some View {
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
        .animation(ChartMotion.switchSpring, value: subtitle)
    }
    
    private func chartValue(for row: HoldingPerformanceRow) -> Double {
        switch mode {
        case .gainLoss:
            let baseDivisor: Decimal = currency == .TWD ? 1 : (twdPerBaseCurrency > 0 ? twdPerBaseCurrency : 1)
            return NSDecimalNumber(decimal: row.unrealizedGainLossTWD / baseDivisor).doubleValue
        case .returnRate: return row.returnPercentDouble
        }
    }
}

// MARK: - 單列炫風長條
private struct PerformanceTornadoRow: View {
    let row: HoldingPerformanceRow
    let mode: PerformanceDisplayMode
    let maxAbsValue: Double
    let currency: Currency
    let twdPerBaseCurrency: Decimal
    
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
            if hideHomeAmounts {
                return HomeAmountPrivacyFormat.masked
            }
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
                        .animation(ChartMotion.switchSpring, value: normalizedWidth)
                        .animation(ChartMotion.switchSpring, value: isPositive)
                }
            }
            .frame(height: 22)
            
            Text(valueText)
                .font(.snapChartRowValue)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 88, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(ChartMotion.switchSpring, value: valueText)
        }
        .animation(ChartMotion.switchSpring, value: mode)
    }
}
