//
//  PieChartGroupingTutorialView.swift
//  Snapvest
//
//  首頁圓餅圖：明細 / 群組操作教學
//

import SwiftUI

struct PieChartGroupingTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var animate = false

    private let pages = PieGroupingTutorialPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        PieGroupingTutorialPageView(
                            page: page,
                            animate: animate && pageIndex == index
                        )
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
            .background(Color.mainBackground)
            .navigationTitle("明細與群組")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
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

            Button {
                if pageIndex == pages.count - 1 {
                    dismiss()
                } else {
                    withAnimation(ChartMotion.switchSpring) {
                        pageIndex += 1
                    }
                }
            } label: {
                Text(pageIndex == pages.count - 1 ? "知道了" : "下一步")
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Pages

private enum PieGroupingTutorialTextRun: Equatable {
    case normal(String)
    case strong(String)
}

private enum PieGroupingTutorialVisual: Equatable {
    case modeDifference
    case createGroupFlow
}

private struct PieGroupingTutorialPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detailBullets: [[PieGroupingTutorialTextRun]]
    let visual: PieGroupingTutorialVisual

    static let all: [PieGroupingTutorialPage] = [
        PieGroupingTutorialPage(
            id: "difference",
            title: "明細與群組怎麼看？",
            subtitle: "明細會列出每一個資產項目；群組會把你選擇的項目合併，讓圓餅圖用你的分類方式呈現。",
            detailBullets: [
                [.strong("明細"), .normal("：適合查看每一檔持股、現金或其他資產")],
                [.strong("群組"), .normal("：適合整理成核心 ETF、科技股、長期配置等自訂分類")],
                [.normal("切換後，圓餅圖與下方清單會一起更新")],
            ],
            visual: .modeDifference
        ),
        PieGroupingTutorialPage(
            id: "create",
            title: "建立群組後再命名",
            subtitle: "先進入群組編輯，勾選要合併的項目並按「組合」；建立後，再點群組旁的小鉛筆修改名稱。",
            detailBullets: [
                [.normal("按「"), .strong("編輯群組"), .normal("」進入編輯模式")],
                [.normal("勾選 2 個以上項目後按「"), .strong("組合"), .normal("」")],
                [.normal("群組建立後，點小鉛筆改成好辨識的名稱")],
            ],
            visual: .createGroupFlow
        ),
    ]
}

private enum PieGroupingTutorialLayout {
    static let highlightGutter: CGFloat = 10

    static func visualHeight(for visual: PieGroupingTutorialVisual) -> CGFloat {
        switch visual {
        case .modeDifference: return 360
        case .createGroupFlow: return 385
        }
    }
}

private struct PieGroupingTutorialPageView: View {
    let page: PieGroupingTutorialPage
    let animate: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                visual
                    .padding(.horizontal, 4)
                    .padding(.vertical, PieGroupingTutorialLayout.highlightGutter)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(
                        height: PieGroupingTutorialLayout.visualHeight(for: page.visual),
                        alignment: .top
                    )
                    .clipped()

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)

                    Text(page.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(page.detailBullets.enumerated()), id: \.offset) { index, runs in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            PieGroupingTutorialBulletText(runs: runs)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(animate ? 1 : 0)
                        .offset(y: animate ? 0 : 6)
                        .animation(.easeOut(duration: 0.32).delay(Double(index) * 0.05), value: animate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .modeDifference:
            PieGroupingModeDifferenceMock(animate: animate)
        case .createGroupFlow:
            PieGroupingCreateFlowMock(animate: animate)
        }
    }
}

private struct PieGroupingTutorialBulletText: View {
    let runs: [PieGroupingTutorialTextRun]

    var body: some View {
        Text(attributedText)
            .font(.footnote)
            .foregroundColor(.secondaryText)
            .lineSpacing(3)
    }

    private var attributedText: AttributedString {
        var result = AttributedString()
        for run in runs {
            switch run {
            case .normal(let text):
                var part = AttributedString(text)
                part.foregroundColor = .secondaryText
                result += part
            case .strong(let text):
                var part = AttributedString(text)
                part.foregroundColor = .primaryText
                part.font = .footnote.weight(.bold)
                result += part
            }
        }
        return result
    }
}

// MARK: - Motion

private enum PieGroupingTutorialMotion {
    static let highlightSpring = Animation.easeInOut(duration: 0.38)
    static let pressSpring = Animation.easeInOut(duration: 0.36)
    static let pressHold: UInt64 = 480
    static let highlightDwell: UInt64 = 820
    static let stepPause: UInt64 = 620
}

private struct PieGroupingTutorialHighlightModifier: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = 12
    var prominent: Bool = false

    @State private var pulseExpanded = false

    private var strokeWidth: CGFloat { prominent ? 3 : 2.5 }
    private var glowRadius: CGFloat { prominent ? 10 : 8 }

    func body(content: Content) -> some View {
        content
            .padding(PieGroupingTutorialLayout.highlightGutter)
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.22), lineWidth: prominent ? 5 : 4)
                        .padding(PieGroupingTutorialLayout.highlightGutter - 2)
                        .scaleEffect(pulseExpanded ? 1.04 : 1)

                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .stroke(Color.appPrimary, lineWidth: strokeWidth)
                        .padding(PieGroupingTutorialLayout.highlightGutter - 1)
                        .shadow(color: Color.appPrimary.opacity(0.45), radius: glowRadius, x: 0, y: 0)
                }
            }
            .padding(-PieGroupingTutorialLayout.highlightGutter)
            .scaleEffect(active ? 0.985 : 1)
            .animation(PieGroupingTutorialMotion.highlightSpring, value: active)
            .onChange(of: active) { _, isActive in
                if isActive {
                    pulseExpanded = false
                    withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                        pulseExpanded = true
                    }
                } else {
                    pulseExpanded = false
                }
            }
    }
}

private struct PieGroupingTutorialPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.93 : 1)
            .animation(PieGroupingTutorialMotion.pressSpring, value: isPressed)
    }
}

private extension View {
    func pieGroupingTutorialHighlight(
        _ active: Bool,
        cornerRadius: CGFloat = 12,
        prominent: Bool = false
    ) -> some View {
        modifier(PieGroupingTutorialHighlightModifier(
            active: active,
            cornerRadius: cornerRadius,
            prominent: prominent
        ))
    }

    func pieGroupingTutorialPress(_ isPressed: Bool) -> some View {
        modifier(PieGroupingTutorialPressModifier(isPressed: isPressed))
    }
}

// MARK: - Mock Data

private struct PieGroupingTutorialItem: Identifiable {
    let id: String
    let name: String
    let value: Double
    let color: Color

    var marketValue: Decimal {
        Decimal(value * 10_000)
    }
}

private enum PieGroupingTutorialMockData {
    static let detailItems: [PieGroupingTutorialItem] = [
        PieGroupingTutorialItem(id: "voo", name: "VOO", value: 34, color: .stockUSColor),
        PieGroupingTutorialItem(id: "qqq", name: "QQQ", value: 26, color: .cryptoColor),
        PieGroupingTutorialItem(id: "aapl", name: "AAPL", value: 18, color: .stockUSDeep),
        PieGroupingTutorialItem(id: "0050", name: "0050", value: 22, color: .stockTWColor),
    ]

    static let groupedItems: [PieGroupingTutorialItem] = [
        PieGroupingTutorialItem(id: "core", name: "核心 ETF", value: 56, color: .stockUSColor),
        PieGroupingTutorialItem(id: "tech", name: "科技股", value: 44, color: .cryptoColor),
    ]
}

// MARK: - Shared Mock Views

private struct PieGroupingTutorialCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primaryText)
                Text("·")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.tertiaryText)
                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            content
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

private struct PieGroupingTutorialModeChip: View {
    let title: String
    let icon: String
    let isHighlighted: Bool
    let isPressed: Bool

    var body: some View {
        AssetsFilterChipButton(
            title: title,
            icon: icon,
            isActive: true,
            action: {}
        )
        .pieGroupingTutorialHighlight(isHighlighted, cornerRadius: 12, prominent: true)
        .pieGroupingTutorialPress(isPressed)
    }
}

private struct PieGroupingTutorialDonut: View {
    let items: [PieGroupingTutorialItem]
    let selectedId: String?
    var isGroupingEnabled: Bool
    var size: CGFloat = 178

    private var chartItems: [PieChartDataItem] {
        items.map {
            PieChartDataItem(
                symbol: $0.id,
                name: $0.name,
                marketValue: $0.marketValue,
                color: $0.color
            )
        }
    }

    private var denominator: Decimal {
        max(chartItems.reduce(Decimal(0)) { $0 + $1.marketValue }, 1)
    }

    var body: some View {
        PortfolioDonutChart(
            data: chartItems,
            denominator: denominator,
            selectedId: .constant(selectedId),
            displayMode: .allDetails,
            displayCurrency: .TWD,
            twdPerDisplayCurrency: 1,
            isGroupingEnabled: isGroupingEnabled,
            allowsSelection: false,
            chartSize: size
        )
        .animation(ChartMotion.pieMorphSpring, value: items.map(\.id).joined())
    }
}

private struct PieGroupingTutorialLegendRow: View {
    let item: PieGroupingTutorialItem
    let isSelected: Bool
    var isChecked = false
    var showsCheckbox = false
    var highlight = false
    var isPressed = false

    var body: some View {
        HStack(spacing: 10) {
            if showsCheckbox {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isChecked ? .appPrimary : .secondaryText)
                    .frame(width: 18)
            }

            Circle()
                .fill(item.color)
                .frame(width: 9, height: 9)

            Text(item.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primaryText)

            Spacer(minLength: 0)

            Text(String(format: "%.1f%%", item.value))
                .font(.snapChartRowValue)
                .foregroundColor(.primaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.primaryText.opacity(0.06) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .pieGroupingTutorialHighlight(highlight, cornerRadius: 12, prominent: true)
        .pieGroupingTutorialPress(isPressed)
    }
}

private struct PieGroupingTutorialGroupRow: View {
    let name: String
    let value: Double
    let color: Color
    let highlightPencil: Bool
    let isPencilPressed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(Color.primaryText.opacity(0.04))
                    .clipShape(Circle())
                    .pieGroupingTutorialHighlight(highlightPencil, cornerRadius: 16, prominent: true)
                    .pieGroupingTutorialPress(isPencilPressed)

                Spacer(minLength: 0)
                Text(String(format: "%.1f%%", value))
                    .font(.snapChartRowValue)
                    .foregroundColor(.primaryText)
            }

            Divider()
                .padding(.leading, 22)
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                Spacer().frame(width: 18)
                Circle().fill(Color.stockUSColor).frame(width: 8, height: 8)
                Text("VOO")
                Spacer()
                Circle().fill(Color.cryptoColor).frame(width: 8, height: 8)
                Text("QQQ")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondaryText)
        }
        .padding(8)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 6)
        }
    }
}

// MARK: - Page 1

private struct PieGroupingModeDifferenceMock: View {
    let animate: Bool

    @State private var pieMode: PieChartDisplayMode = .allDetails
    @State private var showsGrouped = false
    @State private var highlightModeChip = false
    @State private var isModePressed = false
    @State private var loopTask: Task<Void, Never>?

    private var items: [PieGroupingTutorialItem] {
        showsGrouped ? PieGroupingTutorialMockData.groupedItems : PieGroupingTutorialMockData.detailItems
    }

    var body: some View {
        PieGroupingTutorialCard(
            title: "圓餅圖",
            subtitle: showsGrouped ? "群組" : "明細"
        ) {
            VStack(spacing: 0) {
                ChartSegmentedControl(
                    options: PieChartDisplayMode.allCases,
                    selection: $pieMode,
                    label: { $0.rawValue },
                    fontSize: 12
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 4)

                PieGroupingTutorialDonut(
                    items: items,
                    selectedId: items.first?.id,
                    isGroupingEnabled: showsGrouped,
                    size: 132
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 1)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    if showsGrouped {
                        PieGroupingTutorialModeChip(
                            title: "編輯群組",
                            icon: "square.and.pencil",
                            isHighlighted: false,
                            isPressed: false
                        )
                    }
                    PieGroupingTutorialModeChip(
                        title: showsGrouped ? "群組" : "明細",
                        icon: showsGrouped ? "square.grid.2x2.fill" : "list.bullet",
                        isHighlighted: highlightModeChip,
                        isPressed: isModePressed
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                VStack(spacing: 2) {
                    ForEach(items) { item in
                        PieGroupingTutorialLegendRow(
                            item: item,
                            isSelected: item.id == items.first?.id
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .onAppear { if animate { startLoop() } }
        .onChange(of: animate) { _, isAnimating in
            isAnimating ? startLoop() : stopLoop()
        }
        .onDisappear { stopLoop() }
    }

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightModeChip = true }
                try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(PieGroupingTutorialMotion.pressSpring) {
                        isModePressed = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(ChartMotion.pieMorphSpring) {
                        isModePressed = false
                        highlightModeChip = false
                        showsGrouped.toggle()
                    }
                }
                try? await Task.sleep(for: .milliseconds(2200))
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        Task { @MainActor in resetState() }
    }

    @MainActor
    private func resetState() {
        showsGrouped = false
        highlightModeChip = false
        isModePressed = false
    }
}

// MARK: - Page 2

private struct PieGroupingCreateFlowMock: View {
    let animate: Bool

    @State private var pieMode: PieChartDisplayMode = .allDetails
    @State private var isEditing = false
    @State private var selectedIds: Set<String> = []
    @State private var groupCreated = false
    @State private var groupName = "群組1"
    @State private var showRenameSheet = false
    @State private var renameText = ""
    @State private var highlightEditButton = false
    @State private var isEditPressed = false
    @State private var highlightedItemId: String?
    @State private var pressedItemId: String?
    @State private var highlightCombine = false
    @State private var isCombinePressed = false
    @State private var highlightPencil = false
    @State private var isPencilPressed = false
    @State private var highlightSave = false
    @State private var isSavePressed = false
    @State private var loopTask: Task<Void, Never>?

    private var detailItems: [PieGroupingTutorialItem] {
        PieGroupingTutorialMockData.detailItems
    }

    var body: some View {
        PieGroupingTutorialCard(title: "圓餅圖", subtitle: "群組") {
            VStack(spacing: 0) {
                ChartSegmentedControl(
                    options: PieChartDisplayMode.allCases,
                    selection: $pieMode,
                    label: { $0.rawValue },
                    fontSize: 12
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 4)

                PieGroupingTutorialDonut(
                    items: groupCreated
                        ? [PieGroupingTutorialItem(id: "group", name: groupName, value: 60, color: .stockUSColor), detailItems[2], detailItems[3]]
                        : detailItems,
                    selectedId: groupCreated ? "group" : highlightedItemId,
                    isGroupingEnabled: true,
                    size: 108
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    if isEditing {
                        PieGroupingTutorialModeChip(
                            title: "結束編輯",
                            icon: "checkmark",
                            isHighlighted: highlightEditButton,
                            isPressed: isEditPressed
                        )
                    } else {
                        PieGroupingTutorialModeChip(
                            title: "編輯群組",
                            icon: "square.and.pencil",
                            isHighlighted: highlightEditButton,
                            isPressed: isEditPressed
                        )
                    }

                    PieGroupingTutorialModeChip(
                        title: "群組",
                        icon: "square.grid.2x2.fill",
                        isHighlighted: false,
                        isPressed: false
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                if isEditing {
                    actionBar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }

                legendArea
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            .overlay {
                if showRenameSheet {
                    renameOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .onAppear { if animate { startLoop() } }
        .onChange(of: animate) { _, isAnimating in
            isAnimating ? startLoop() : stopLoop()
        }
        .onDisappear { stopLoop() }
    }

    @ViewBuilder
    private var legendArea: some View {
        if groupCreated {
            PieGroupingTutorialGroupRow(
                name: groupName,
                value: 60,
                color: .stockUSColor,
                highlightPencil: highlightPencil,
                isPencilPressed: isPencilPressed
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            VStack(spacing: 2) {
                Text(isEditing ? "投資類" : "明細")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)

                ForEach(detailItems) { item in
                    PieGroupingTutorialLegendRow(
                        item: item,
                        isSelected: highlightedItemId == item.id,
                        isChecked: selectedIds.contains(item.id),
                        showsCheckbox: isEditing,
                        highlight: highlightedItemId == item.id,
                        isPressed: pressedItemId == item.id
                    )
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Text("已選 \(selectedIds.count) 項")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondaryText)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("組合")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(selectedIds.count >= 2 ? .appPrimary : .secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((selectedIds.count >= 2 ? Color.appPrimary : Color.secondaryText).opacity(0.12))
            .clipShape(Capsule())
            .pieGroupingTutorialHighlight(highlightCombine, cornerRadius: 18, prominent: true)
            .pieGroupingTutorialPress(isCombinePressed)
        }
    }

    private var renameOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
            VStack(spacing: 12) {
                Text("編輯群組名稱")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primaryText)
                Text(renameText.isEmpty ? "群組名稱" : renameText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(renameText.isEmpty ? .tertiaryText : .primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                HStack(spacing: 10) {
                    Text("取消")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                    Text("儲存")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .pieGroupingTutorialHighlight(highlightSave, cornerRadius: 12, prominent: true)
                        .pieGroupingTutorialPress(isSavePressed)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 4)
            .padding(.horizontal, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }

                await tapEditButton()
                try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await tapItem("voo")
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }

                await tapItem("qqq")
                try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await tapCombine()
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await tapPencil()
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.35)) {
                        renameText = "美股大盤"
                    }
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await tapSave()
                try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await tapEndEditing()
                try? await Task.sleep(for: .milliseconds(1800))
            }
        }
    }

    @MainActor
    private func tapEditButton() async {
        highlightEditButton = true
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { isEditPressed = true }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            isEditPressed = false
            highlightEditButton = false
            isEditing = true
        }
    }

    @MainActor
    private func tapItem(_ id: String) async {
        highlightedItemId = id
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { pressedItemId = id }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(ChartMotion.switchSpring) {
            pressedItemId = nil
            highlightedItemId = nil
            selectedIds.insert(id)
        }
    }

    @MainActor
    private func tapCombine() async {
        highlightCombine = true
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { isCombinePressed = true }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(ChartMotion.pieMorphSpring) {
            isCombinePressed = false
            highlightCombine = false
            groupCreated = true
            selectedIds.removeAll()
        }
    }

    @MainActor
    private func tapPencil() async {
        highlightPencil = true
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { isPencilPressed = true }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(.easeInOut(duration: 0.28)) {
            isPencilPressed = false
            highlightPencil = false
            showRenameSheet = true
        }
    }

    @MainActor
    private func tapSave() async {
        highlightSave = true
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { isSavePressed = true }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
            isSavePressed = false
            highlightSave = false
            showRenameSheet = false
            groupName = renameText.isEmpty ? "美股大盤" : renameText
        }
    }

    @MainActor
    private func tapEndEditing() async {
        highlightEditButton = true
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.highlightDwell))
        withAnimation(PieGroupingTutorialMotion.pressSpring) { isEditPressed = true }
        try? await Task.sleep(for: .milliseconds(PieGroupingTutorialMotion.pressHold))
        withAnimation(ChartMotion.switchSpring) {
            isEditPressed = false
            highlightEditButton = false
            isEditing = false
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        Task { @MainActor in resetState() }
    }

    @MainActor
    private func resetState() {
        isEditing = false
        selectedIds.removeAll()
        groupCreated = false
        groupName = "群組1"
        showRenameSheet = false
        renameText = ""
        highlightEditButton = false
        isEditPressed = false
        highlightedItemId = nil
        pressedItemId = nil
        highlightCombine = false
        isCombinePressed = false
        highlightPencil = false
        isPencilPressed = false
        highlightSave = false
        isSavePressed = false
    }
}

#if DEBUG
#Preview("明細與群組教學") {
    PieChartGroupingTutorialView()
}
#endif
