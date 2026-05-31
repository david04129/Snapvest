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
            subtitle: "記錄帳戶、投資、負債與其他資產，輕鬆掌握資產走勢。",
            visual: .dashboard
        ),
        OnboardingPage(
            id: "accounts",
            title: "第一步，建立你的帳戶",
            subtitle: "可以新增現金帳戶、台股、美股、加密錢包，也可以管理負債。",
            visual: .accounts
        ),
        OnboardingPage(
            id: "records",
            title: "用交易和估值累積你的紀錄",
            subtitle: "買入、賣出、現金收支會影響投資與現金；房產、基金、保單等輕鬆自定義。",
            visual: .records
        ),
        OnboardingPage(
            id: "backup",
            title: "每天累積走勢，記得備份",
            subtitle: "Walleaf 會把走勢點保存在手機。資料屬於你，建議定期備份到自己的 iCloud Drive。",
            visual: .backup
        )
    ]
}

private enum OnboardingVisual {
    case dashboard
    case accounts
    case records
    case backup
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

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(page.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 6)
            }

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .dashboard:
            OnboardingDashboardMock(animate: animate)
        case .accounts:
            OnboardingAccountListMock(animate: animate)
        case .records:
            OnboardingRecordsMock(animate: animate)
        case .backup:
            OnboardingBackupMock(animate: animate)
        }
    }
}

private struct OnboardingDashboardMock: View {
    let animate: Bool

    var body: some View {
        VStack(spacing: 12) {
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
                    CurrencyCodeChip(currency: .TWD)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(animate ? "1,268,420" : "0")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                        .contentTransition(.numericText())
                    Text(animate ? "+42,180 (+3.44%)" : "+0 (+0.00%)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.profitGreen)
                    Text("2026年5月31日")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondaryText)
                }

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appPrimary.opacity(0.06))
                    VStack(spacing: 26) {
                        ForEach(["130萬", "126萬", "122萬"], id: \.self) { label in
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.separator.opacity(0.45))
                                    .frame(height: 0.6)
                                Text(label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondaryText)
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.horizontal, 10)

                    OnboardingTrendArea(progress: animate ? 1 : 0)
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimary.opacity(0.24), Color.appPrimary.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.trailing, 40)
                        .padding(.vertical, 12)

                    OnboardingTrendLine(progress: animate ? 1 : 0)
                        .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        .padding(.trailing, 40)
                        .padding(.vertical, 12)
                }
                .frame(height: 94)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.10), Color.cardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 14, x: 0, y: 5)

            OnboardingNetWorthSummaryCard(animate: animate)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 12)
        }
        .animation(.easeOut(duration: 0.7), value: animate)
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

private struct OnboardingRecordsMock: View {
    let animate: Bool

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今日紀錄")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Text("3 筆")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.secondaryBackground)
                        .clipShape(Capsule())
                }

                OnboardingTransactionRow(
                    icon: "arrow.down.circle.fill",
                    title: "買入 VOO",
                    subtitle: "美股證券 · 投資交易",
                    amount: animate ? "-24,360" : "0",
                    currency: .TWD,
                    tint: .stockUSColor
                )
                OnboardingTransactionRow(
                    icon: "plus.circle.fill",
                    title: "現金存入",
                    subtitle: "現金帳戶 · 收入",
                    amount: animate ? "+50,000" : "0",
                    currency: .TWD,
                    tint: .appPrimary
                )
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 4)

            HStack(spacing: 12) {
                OnboardingAssetValueCard(
                    icon: "house.fill",
                    title: "房地產",
                    value: animate ? "8,200,000" : "0",
                    tint: .appPrimary
                )
                OnboardingAssetValueCard(
                    icon: "shield.fill",
                    title: "保單",
                    value: animate ? "320,000" : "0",
                    tint: .stockUSColor
                )
            }
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 18)
        }
        .animation(.easeOut(duration: 0.65), value: animate)
    }
}

private struct OnboardingBackupMock: View {
    let animate: Bool

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("走勢累積")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.appPrimary)
                        .scaleEffect(animate ? 1 : 0.72)
                }

                OnboardingTrendLine(progress: animate ? 1 : 0.22)
                    .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(height: 130)
                    .overlay {
                        HStack {
                            Circle().fill(Color.appPrimary).frame(width: 10, height: 10)
                            Spacer()
                            Circle().fill(Color.appPrimary).frame(width: 10, height: 10).opacity(animate ? 1 : 0)
                            Spacer()
                            Circle().fill(Color.appPrimary).frame(width: 10, height: 10).opacity(animate ? 1 : 0)
                        }
                        .padding(.horizontal, 18)
                        .offset(y: 28)
                    }
            }
            .padding(20)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 14, x: 0, y: 5)

            Text("本機資料 + iCloud Drive 備份")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondaryText)
                .opacity(animate ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.7), value: animate)
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