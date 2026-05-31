//
//  OnboardingView.swift
//  Snapvest
//
//  Native first-run onboarding and reusable empty-state guidance cards.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    let onDemoMode: () async -> Void

    @State private var pageIndex = 0
    @State private var animate = false
    @State private var isStartingDemoMode = false

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            Color.mainBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page, animate: animate && pageIndex == index)
                            .tag(index)
                            .padding(.horizontal, 22)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .allowsHitTesting(!isStartingDemoMode)

            if isStartingDemoMode {
                OnboardingDemoLoadingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isStartingDemoMode)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                animate = true
            }
        }
        .onChange(of: pageIndex) { _, _ in
            animate = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.45)) {
                    animate = true
                }
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                SnapvestBrandMark(iconSize: 30, wordmarkSize: 0, spacing: 0, showsWordmark: false)
                Text("Walleaf")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primaryText)
            }

            Spacer()

            Button("略過") {
                onFinish()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondaryText)
            .disabled(isStartingDemoMode)
            .opacity(isStartingDemoMode ? 0.4 : 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? Color.appPrimary : Color.separator)
                        .frame(width: index == pageIndex ? 22 : 7, height: 7)
                        .animation(ChartMotion.switchSpring, value: pageIndex)
                }
            }

            if pageIndex == pages.count - 1 {
                HStack(spacing: 12) {
                    Button {
                        onFinish()
                    } label: {
                        Text("開始使用")
                            .font(.headline.weight(.bold))
                            .foregroundColor(AppColors.actionForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.appPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingDemoMode)
                    .opacity(isStartingDemoMode ? 0.55 : 1)

                    Button {
                        Task { await startDemoMode() }
                    } label: {
                        HStack(spacing: 8) {
                            if isStartingDemoMode {
                                ProgressView()
                                    .tint(.appPrimary)
                            }
                            Text(isStartingDemoMode ? "準備示範…" : "示範模式")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundColor(.appPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appPrimary.opacity(0.32), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingDemoMode)
                }
            } else {
                Button {
                    withAnimation(ChartMotion.switchSpring) {
                        pageIndex += 1
                    }
                } label: {
                    Text("下一步")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private func startDemoMode() async {
        guard !isStartingDemoMode else { return }
        isStartingDemoMode = true
        await onDemoMode()
    }
}

private struct OnboardingDemoLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.appPrimary)

                Text("正在準備示範資料…")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Text("會載入一組範例帳戶、持股與走勢")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 16, x: 0, y: 6)
            .padding(.horizontal, 36)
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let visual: OnboardingVisual

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome",
            title: "隨手開啟，掌握資產的成長",
            subtitle: "整合你的帳戶與投資，用一個畫面掌握所有資產",
            visual: .pieChart
        ),
        OnboardingPage(
            id: "accounts",
            title: "第一步：新增帳戶",
            subtitle: "資產與負債，一站式管理",
            visual: .accounts
        ),
        OnboardingPage(
            id: "holdings",
            title: "第二步：新增持股",
            subtitle: "整合台股、美股、加密貨幣，清楚呈現投資績效",
            visual: .performance
        ),
        OnboardingPage(
            id: "finale",
            title: "讓 Walleaf 與你同行",
            subtitle: "資產像葉子一樣持續生長，錢包般整合，一打開就能清楚看見你的財富故事",
            visual: .finale
        )
    ]
}

private enum OnboardingVisual {
    case pieChart
    case accounts
    case performance
    case finale
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let animate: Bool

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 12)

            visual
                .frame(height: 310)
                .frame(maxWidth: .infinity)
                .clipped()

            onboardingTextBlock

            Spacer(minLength: 8)
        }
    }

    private var onboardingTextBlock: some View {
        VStack(spacing: 12) {
            onboardingTitle

            Text(page.subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var onboardingTitle: some View {
        let titleFont = Font.system(size: 30, weight: .bold, design: .rounded)
        if page.visual == .finale {
            HStack(spacing: 0) {
                Text("讓 ")
                    .foregroundColor(.primaryText)
                Text("Walleaf")
                    .foregroundColor(.appPrimary)
                Text(" 與你同行")
                    .foregroundColor(.primaryText)
            }
            .font(titleFont)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        } else {
            Text(page.title)
                .font(titleFont)
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .pieChart:
            OnboardingPieChartMock(animate: animate)
        case .accounts:
            OnboardingAccountListMock(animate: animate)
        case .performance:
            OnboardingPerformanceMock(animate: animate)
        case .finale:
            OnboardingFinaleMock(animate: animate)
        }
    }
}

// MARK: - 第一頁：圓餅圖（對齊首頁 HomePieChartSection）

private struct OnboardingPieChartMock: View {
    let animate: Bool

    @State private var selectedId: String? = "twd_cash"

    private static let chartSize: CGFloat = 152
    private static let demoDenominator: Decimal = 1_268_420

    private static let demoItems: [PieChartDataItem] = [
        PieChartDataItem(
            symbol: "twd_cash",
            name: "台幣",
            marketValue: 431_262,
            color: AppColors.holdingChartColor(at: 0)
        ),
        PieChartDataItem(
            symbol: "stock_us",
            name: "美股",
            marketValue: 279_054,
            color: AppColors.holdingChartColor(at: 1)
        ),
        PieChartDataItem(
            symbol: "stock_tw",
            name: "台股",
            marketValue: 329_709,
            color: AppColors.holdingChartColor(at: 2)
        ),
        PieChartDataItem(
            symbol: "crypto",
            name: "加密貨幣",
            marketValue: 228_395,
            color: AppColors.holdingChartColor(at: 3)
        )
    ]

    private var progress: Decimal {
        animate ? 1 : 0
    }

    private var displayItems: [PieChartDataItem] {
        Self.demoItems.map { item in
            PieChartDataItem(
                symbol: item.symbol,
                name: item.name,
                marketValue: item.marketValue * progress,
                color: item.color
            )
        }
    }

    private var displayDenominator: Decimal {
        let scaled = Self.demoDenominator * progress
        return scaled > 0 ? scaled : Self.demoDenominator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("圓餅圖")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primaryText)
                    Text(" · ")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.tertiaryText)
                    Text(PieChartDisplayMode.totalAssets.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.appPrimary)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 2)

            PortfolioDonutChart(
                data: displayItems,
                denominator: displayDenominator,
                selectedId: $selectedId,
                displayMode: .totalAssets,
                allowsSelection: animate,
                chartSize: Self.chartSize
            )
            .padding(.vertical, 0)
            .animation(ChartMotion.pieMorphSpring, value: animate)

            OnboardingPieCompactLegend(
                items: displayItems,
                denominator: displayDenominator
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
            .animation(ChartMotion.pieMorphSpring, value: animate)
        }
        .frame(maxWidth: .infinity, maxHeight: 310, alignment: .top)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

/// 新手教學用精簡圖例（兩欄），避免佔滿螢幕擠壓標語
private struct OnboardingPieCompactLegend: View {
    let items: [PieChartDataItem]
    let denominator: Decimal

    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }

    private var orderedItems: [PieChartDataItem] {
        let order = ["twd_cash", "stock_us", "stock_tw", "crypto"]
        return order.compactMap { id in items.first(where: { $0.id == id }) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(orderedItems) { item in
                let pct = (NSDecimalNumber(decimal: item.marketValue).doubleValue / totalDouble) * 100
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text(String(format: "%.1f%%", pct))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondaryText)
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct OnboardingAccountListMock: View {
    let animate: Bool

    private let items: [(String, String, Color)] = [
        ("banknote.fill", "現金帳戶", .appPrimary),
        ("chart.line.uptrend.xyaxis", "台股帳戶", .stockTWColor),
        ("building.2.fill", "美股帳戶", .stockUSColor),
        ("bitcoinsign.circle.fill", "加密錢包", .cryptoColor),
        ("creditcard.fill", "負債管理", .lossRed)
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    Image(systemName: item.0)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(item.2)
                        .frame(width: 38, height: 38)
                        .background(item.2.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(item.1)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPrimary)
                }
                .padding(14)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: AppColors.shadowLow, radius: 6, x: 0, y: 2)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 14)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.08), value: animate)
            }
        }
    }
}

// MARK: - 第三頁：績效圖

private struct OnboardingPerformanceMock: View {
    let animate: Bool

    private let rows: [(name: String, color: Color, gain: CGFloat, positive: Bool)] = [
        ("VOO", .stockUSColor, 0.82, true),
        ("2330", .stockTWColor, 0.58, true),
        ("BTC", .cryptoColor, 0.44, false),
        ("0050", .stockTWColor, 0.36, true)
    ]

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("績效圖")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primaryText)
                    Text("·")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.tertiaryText)
                    Text("未實現損益")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appPrimary)
                    CurrencyCodeChip(currency: .TWD)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                HStack(spacing: 8) {
                    Text("未實現損益")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(Capsule())
                    Text("報酬率")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.secondaryBackground)
                        .clipShape(Capsule())
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                VStack(spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        OnboardingPerformanceTornadoRow(
                            name: row.name,
                            color: row.color,
                            normalizedWidth: animate ? row.gain : 0,
                            isPositive: row.positive,
                            valueText: animate ? (row.positive ? "+\(rowValue(index))" : "-\(rowValue(index))") : "0"
                        )
                        .opacity(animate ? 1 : 0)
                        .offset(y: animate ? 0 : 10)
                        .animation(.easeOut(duration: 0.42).delay(0.08 + Double(index) * 0.07), value: animate)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 14, x: 0, y: 5)
        }
        .animation(.easeOut(duration: 0.7), value: animate)
    }

    private func rowValue(_ index: Int) -> String {
        ["128,400", "86,200", "24,600", "31,800"][index]
    }
}

private struct OnboardingPerformanceTornadoRow: View {
    let name: String
    let color: Color
    let normalizedWidth: CGFloat
    let isPositive: Bool
    let valueText: String

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .lineLimit(1)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                let totalW = geo.size.width
                let barH: CGFloat = 10
                let halfW = totalW / 2
                let barLen = halfW * min(max(normalizedWidth, 0), 1)
                let midY = geo.size.height / 2
                let centerX = totalW / 2

                ZStack {
                    Rectangle()
                        .fill(Color.primaryText.opacity(0.08))
                        .frame(width: 1, height: barH + 6)
                        .position(x: centerX, y: midY)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(barLen, normalizedWidth > 0 ? 3 : 0), height: barH)
                        .position(
                            x: isPositive ? centerX + barLen / 2 : centerX - barLen / 2,
                            y: midY
                        )
                }
            }
            .frame(height: 22)

            Text(valueText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isPositive ? .marketUp : .marketDown)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - 第四頁：Logo + 走勢

private struct OnboardingFinaleMock: View {
    let animate: Bool

    var body: some View {
        VStack(spacing: 16) {
            SnapvestBrandMark(iconSize: 72, wordmarkSize: 0, spacing: 0, showsWordmark: false)
                .scaleEffect(animate ? 1 : 0.7)
                .opacity(animate ? 1 : 0.2)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: animate)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("走勢圖")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primaryText)
                    Text("·")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondaryText)
                    Text("淨資產")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.appPrimary)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(animate ? "1,268,420" : "0")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                        .contentTransition(.numericText())
                    Text(animate ? "+42,180 (+3.44%)" : "+0 (+0.00%)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.profitGreen)
                }

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appPrimary.opacity(0.06))

                    OnboardingTrendArea(progress: animate ? 1 : 0)
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimary.opacity(0.24), Color.appPrimary.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.trailing, 8)
                        .padding(.vertical, 10)

                    OnboardingTrendLine(progress: animate ? 1 : 0)
                        .stroke(
                            Color.appPrimary,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                        .padding(.trailing, 8)
                        .padding(.vertical, 10)
                }
                .frame(height: 108)
            }
            .padding(18)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 14, x: 0, y: 5)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 16)
            .animation(.easeOut(duration: 0.65).delay(0.1), value: animate)
        }
    }
}

private struct MiniMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OnboardingNetWorthSummaryCard: View {
    let animate: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondaryBackground, lineWidth: 8)
                    .frame(width: 58, height: 58)
                Circle()
                    .trim(from: 0, to: animate ? 0.68 : 0.08)
                    .stroke(
                        Color.appPrimary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))
                Text(animate ? "68%" : "0%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.appPrimary)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("淨資產")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primaryText)
                    CurrencyCodeChip(currency: .TWD)
                }
                Text(animate ? "1,268,420" : "0")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .contentTransition(.numericText())
            }

            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondaryText)
        }
        .padding(15)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppColors.shadowLow, radius: 8, x: 0, y: 2)
    }
}

private struct OnboardingTransactionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: String
    let currency: Currency
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primaryText)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            CurrencyAmountLabel(
                text: amount,
                currency: currency,
                font: .system(size: 17, weight: .bold),
                weight: .bold,
                color: amount.hasPrefix("+") ? .profitGreen : .primaryText
            )
        }
        .padding(12)
        .background(Color.secondaryBackground.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OnboardingAssetValueCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                CurrencyCodeChip(currency: .TWD, tint: tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondaryText)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppColors.shadowLow, radius: 6, x: 0, y: 2)
    }
}

private struct OnboardingTrendLine: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.minX, y: rect.maxY * 0.72),
            CGPoint(x: rect.width * 0.28, y: rect.maxY * 0.55),
            CGPoint(x: rect.width * 0.52, y: rect.maxY * 0.62),
            CGPoint(x: rect.width * 0.76, y: rect.maxY * 0.34),
            CGPoint(x: rect.maxX, y: rect.maxY * 0.22)
        ]
        return trimmedPath(points: points, progress: progress)
    }

    private func trimmedPath(points: [CGPoint], progress: CGFloat) -> Path {
        guard points.count > 1 else { return Path() }
        let clamped = min(max(progress, 0), 1)
        let maxSegment = CGFloat(points.count - 1) * clamped
        var path = Path()
        path.move(to: points[0])

        for index in 1..<points.count {
            let segmentProgress = min(max(maxSegment - CGFloat(index - 1), 0), 1)
            guard segmentProgress > 0 else { break }
            let start = points[index - 1]
            let end = points[index]
            let point = CGPoint(
                x: start.x + (end.x - start.x) * segmentProgress,
                y: start.y + (end.y - start.y) * segmentProgress
            )
            path.addLine(to: point)
            if segmentProgress < 1 { break }
        }

        return path
    }
}

private struct OnboardingTrendArea: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = OnboardingTrendLine(progress: progress).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct OnboardingEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 52, height: 52)
                .background(Color.appPrimary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.separator.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: AppColors.shadowLow, radius: 8, x: 0, y: 2)
    }
}