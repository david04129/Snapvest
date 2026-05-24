//
//  HomePerformanceChartView.swift
//  Snapvest
//
//  首頁績效圖（炫風圖）：未實現損益金額 / 報酬率
//

import SwiftUI

struct HomePerformanceChartSection: View {
    let inputs: PieChartInputs?
    @State private var mode: PerformanceDisplayMode = .gainLoss
    @State private var contentPhase: CGFloat = 1
    
    private var rows: [HoldingPerformanceRow] {
        guard let inputs else { return [] }
        let all = HoldingChartMetrics.performanceRows(inputs: inputs)
        if mode == .gainLoss { return all }
        return all.sorted {
            $0.returnPercentDouble > $1.returnPercentDouble
        }
    }
    
    private var maxAbsChartValue: Double {
        let values = rows.map { chartValue(for: $0) }
        return values.map { abs($0) }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartHeader(title: "績效圖", subtitle: mode.rawValue)
            
            ChartSegmentedControl(
                options: PerformanceDisplayMode.allCases,
                selection: $mode,
                label: { $0.rawValue }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: mode) { _, _ in
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
                            maxAbsValue: maxAbsChartValue
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(ChartMotion.switchSpring, value: mode)
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
                .opacity(contentPhase)
                .scaleEffect(0.98 + contentPhase * 0.02)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private func chartHeader(title: String, subtitle: String) -> some View {
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
        .animation(ChartMotion.switchSpring, value: subtitle)
    }
    
    private func chartValue(for row: HoldingPerformanceRow) -> Double {
        switch mode {
        case .gainLoss: return row.gainLossDouble
        case .returnRate: return row.returnPercentDouble
        }
    }
}

// MARK: - 單列炫風長條
private struct PerformanceTornadoRow: View {
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
            if hideHomeAmounts {
                return HomeAmountPrivacyFormat.masked
            }
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
                        .animation(ChartMotion.switchSpring, value: normalizedWidth)
                        .animation(ChartMotion.switchSpring, value: isPositive)
                }
            }
            .frame(height: 22)
            
            Text(valueText)
                .font(.system(size: 13, weight: .semibold))
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
