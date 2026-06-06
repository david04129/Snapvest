//
//  AddInvestmentTutorialView.swift
//  Snapvest
//
//  投資分頁空白狀態：如何新增持倉圖文教學
//

import SwiftUI

struct AddInvestmentTutorialView: View {
    let onStartAdding: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var animate = false

    private let pages = InvestmentTutorialPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        InvestmentTutorialPageView(
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
            .navigationTitle("如何新增持倉")
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

            if pageIndex == pages.count - 1 {
                Button {
                    dismiss()
                    onStartAdding()
                } label: {
                    Text("開始新增")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
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
                        .frame(height: 50)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Pages

private enum InvestmentTutorialTextRun: Equatable {
    case normal(String)
    case strong(String)
}

private enum InvestmentTutorialVisual: Equatable {
    case createAccountFlow
    case tradeFlow
}

private struct InvestmentTutorialPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detailBullets: [[InvestmentTutorialTextRun]]
    let visual: InvestmentTutorialVisual

    static let all: [InvestmentTutorialPage] = [
        InvestmentTutorialPage(
            id: "create",
            title: "建立投資帳戶",
            subtitle: "持倉會彙總在投資分頁，但需先到管理分頁建立投資帳戶（示範：台股證券）。",
            detailBullets: [
                [.normal("點選底部「"), .strong("管理"), .normal("」分頁")],
                [.normal("按右上角「"), .strong("新增項目"), .normal("」")],
                [
                    .normal("在「"),
                    .strong("投資帳戶"),
                    .normal("」選台股、美股或加密其中一種"),
                ],
                [.normal("填寫名稱後按「"), .strong("建立帳戶"), .normal("」")],
            ],
            visual: .createAccountFlow
        ),
        InvestmentTutorialPage(
            id: "trade",
            title: "記錄交易、查看持倉",
            subtitle: "進入帳戶記錄買賣後，持倉會出現在投資分頁。",
            detailBullets: [
                [.normal("在管理分頁點擊剛建立的帳戶")],
                [.normal("按底部「"), .strong("新增交易"), .normal("」")],
                [.normal("填寫代號、數量與價格後確認")],
                [.normal("返回投資分頁即可看到持倉")],
            ],
            visual: .tradeFlow
        ),
    ]
}

private enum InvestmentTutorialLayout {
    /// 高亮框外擴空間，避免被 phone chrome 裁切
    static let highlightGutter: CGFloat = 10

    static func visualHeight(for visual: InvestmentTutorialVisual) -> CGFloat {
        switch visual {
        case .createAccountFlow: return 480
        case .tradeFlow: return 480
        }
    }
}

private struct InvestmentTutorialPageView: View {
    let page: InvestmentTutorialPage
    let animate: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                visual
                    .padding(.horizontal, 4)
                    .padding(.vertical, InvestmentTutorialLayout.highlightGutter)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(
                        height: InvestmentTutorialLayout.visualHeight(for: page.visual),
                        alignment: .top
                    )

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

                if !page.detailBullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(page.detailBullets.enumerated()), id: \.offset) { index, runs in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.appPrimary.opacity(0.85))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                InvestmentTutorialBulletText(runs: runs)
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
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .createAccountFlow:
            InvestmentTutorialCreateAccountFlowMock(animate: animate)
        case .tradeFlow:
            InvestmentTutorialTradeFlowMock(animate: animate)
        }
    }
}

private struct InvestmentTutorialBulletText: View {
    let runs: [InvestmentTutorialTextRun]

    var body: some View {
        Text(attributedContent)
    }

    private var attributedContent: AttributedString {
        runs.reduce(into: AttributedString()) { result, run in
            switch run {
            case .normal(let string):
                var segment = AttributedString(string)
                var style = AttributeContainer()
                style.font = .caption.weight(.medium)
                style.foregroundColor = Color.secondaryText
                segment.mergeAttributes(style)
                result.append(segment)
            case .strong(let string):
                var segment = AttributedString(string)
                var style = AttributeContainer()
                style.font = .caption.weight(.bold)
                style.foregroundColor = Color.primaryText
                segment.mergeAttributes(style)
                result.append(segment)
            }
        }
    }
}

// MARK: - Shared mock chrome

private struct InvestmentTutorialPhoneChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.mainBackground)

            content
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.separator.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: AppColors.shadowMedium, radius: 10, x: 0, y: 3)
    }
}

private enum InvestmentTutorialMotion {
    static let highlightSpring = Animation.easeInOut(duration: 0.38)
    static let pressSpring = Animation.easeInOut(duration: 0.36)
    static let pressHold: UInt64 = 480
    static let highlightDwell: UInt64 = 820
    static let stepPause: UInt64 = 620
}

private struct InvestmentTutorialHighlightModifier: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = 12
    var prominent: Bool = false

    @State private var pulseExpanded = false

    private var strokeWidth: CGFloat { prominent ? 3 : 2.5 }
    private var glowRadius: CGFloat { prominent ? 10 : 8 }

    func body(content: Content) -> some View {
        content
            .padding(InvestmentTutorialLayout.highlightGutter)
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.22), lineWidth: prominent ? 5 : 4)
                        .padding(InvestmentTutorialLayout.highlightGutter - 2)
                        .scaleEffect(pulseExpanded ? 1.04 : 1)

                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .stroke(Color.appPrimary, lineWidth: strokeWidth)
                        .padding(InvestmentTutorialLayout.highlightGutter - 1)
                        .shadow(color: Color.appPrimary.opacity(0.45), radius: glowRadius, x: 0, y: 0)
                }
            }
            .padding(-InvestmentTutorialLayout.highlightGutter)
            .scaleEffect(active ? 0.985 : 1)
            .animation(InvestmentTutorialMotion.highlightSpring, value: active)
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

private struct InvestmentTutorialPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.93 : 1)
            .animation(InvestmentTutorialMotion.pressSpring, value: isPressed)
    }
}

private extension View {
    func investmentTutorialHighlight(
        _ active: Bool,
        cornerRadius: CGFloat = 12,
        prominent: Bool = false
    ) -> some View {
        modifier(InvestmentTutorialHighlightModifier(
            active: active,
            cornerRadius: cornerRadius,
            prominent: prominent
        ))
    }

    func investmentTutorialPress(_ isPressed: Bool) -> some View {
        modifier(InvestmentTutorialPressModifier(isPressed: isPressed))
    }
}

/// 整版 sheet mock（對齊 App 全屏 sheet：蓋住 Tab Bar、含導覽列）
private struct InvestmentTutorialFullScreenSheetMock<Content: View>: View {
    let title: String
    var showsBack: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        showsBack: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsBack = showsBack
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if showsBack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appPrimary)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .frame(width: 24, height: 24)
                }
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.mainBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.separator.opacity(0.35))
                    .frame(height: 0.5)
            }

            ScrollView {
                content
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.mainBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mainBackground)
    }
}

private struct InvestmentTutorialTabBarMock: View {
    let selectedTab: AppTab
    let highlightTab: AppTab?
    let isTabPressed: Bool

    private struct TabItem {
        let tab: AppTab
        let title: String
        let icon: String
    }

    private static let items: [TabItem] = [
        TabItem(tab: .home, title: "首頁", icon: "house.fill"),
        TabItem(tab: .accounts, title: "管理", icon: "building.columns.fill"),
        TabItem(tab: .assets, title: "投資", icon: "chart.bar.fill"),
        TabItem(tab: .transactions, title: "紀錄", icon: "clock.fill"),
    ]

    var body: some View {
        HStack {
            ForEach(Self.items, id: \.tab) { item in
                let isSelected = selectedTab == item.tab
                let isHighlighted = highlightTab == item.tab
                VStack(spacing: 3) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(item.title)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(isSelected ? .appPrimary : .secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
                .investmentTutorialHighlight(isHighlighted, cornerRadius: 12, prominent: true)
                .investmentTutorialPress(isHighlighted && isTabPressed)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.separator.opacity(0.35))
                .frame(height: 0.5)
        }
    }
}

private struct InvestmentTutorialManagementHeaderMock: View {
    let highlightAddButton: Bool
    let isAddPressed: Bool

    var body: some View {
        HStack {
            Text("管理")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primaryText)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("新增項目")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.actionForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appPrimary)
            .clipShape(Capsule())
            .investmentTutorialHighlight(highlightAddButton, cornerRadius: 20, prominent: true)
            .investmentTutorialPress(isAddPressed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mainBackground)
    }
}

private struct InvestmentTutorialAccountCardMock: View {
    let name: String
    let highlighted: Bool
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AccountType.twdSecurities.color)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Text("總資產")
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            Text("—")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondaryText)
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(AccountType.twdSecurities.color)
                .frame(width: 3)
        }
        .investmentTutorialHighlight(highlighted, cornerRadius: 16, prominent: true)
        .investmentTutorialPress(isPressed)
    }
}

// MARK: - Page 1: 管理 + 新增帳戶

private struct InvestmentTutorialCreateAccountFlowMock: View {
    let animate: Bool

    @State private var selectedTab: AppTab = .assets
    @State private var highlightTab: AppTab?
    @State private var isTabPressed = false
    @State private var highlightAddButton = false
    @State private var isAddPressed = false
    @State private var showFullSheet = false
    @State private var sheetShowsForm = false
    @State private var highlightInvestment = false
    @State private var highlightTWSecurities = false
    @State private var isTWPressed = false
    @State private var accountName = ""
    @State private var highlightCreateButton = false
    @State private var isCreatePressed = false
    @State private var showCreatedAccount = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        InvestmentTutorialPhoneChrome {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    tabContentArea
                        .frame(maxHeight: .infinity, alignment: .top)

                    if !showFullSheet {
                        InvestmentTutorialTabBarMock(
                            selectedTab: showCreatedAccount ? .accounts : selectedTab,
                            highlightTab: highlightTab,
                            isTabPressed: isTabPressed
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if showFullSheet {
                    InvestmentTutorialFullScreenSheetMock(
                        title: sheetShowsForm ? "台股證券" : "新增項目",
                        showsBack: sheetShowsForm
                    ) {
                        if sheetShowsForm {
                            accountFormContent
                        } else {
                            addItemHubContent
                        }
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: selectedTab)
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: showFullSheet)
        .animation(.easeInOut(duration: 0.28), value: sheetShowsForm)
        .onChange(of: animate) { _, active in
            active ? startLoop() : stopLoop()
        }
        .onAppear {
            if animate { startLoop() }
        }
        .onDisappear {
            stopLoop()
        }
    }

    private var tabContentArea: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                investmentEmptyContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                managementEmptyContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                managementWithAccountContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .offset(x: tabContentOffset(in: geo))
            .animation(.spring(response: 0.52, dampingFraction: 0.86), value: selectedTab)
            .animation(.spring(response: 0.52, dampingFraction: 0.86), value: showCreatedAccount)
        }
    }

    private func tabContentOffset(in geo: GeometryProxy) -> CGFloat {
        if showCreatedAccount {
            return -geo.size.width * 2
        }
        if selectedTab == .accounts {
            return -geo.size.width
        }
        return 0
    }

    private var investmentEmptyContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appPrimary)
                Text("投資")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            VStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.appPrimary.opacity(0.7))
                Text("還沒有持股")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Text("建立投資帳戶並記錄買賣後會出現")
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
    }

    private var managementEmptyContent: some View {
        VStack(spacing: 0) {
            InvestmentTutorialManagementHeaderMock(
                highlightAddButton: highlightAddButton && !showFullSheet,
                isAddPressed: isAddPressed
            )

            VStack(spacing: 8) {
                Text("還沒有帳戶")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Text("先建立現金、台股、美股或加密錢包")
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(12)

            Spacer(minLength: 0)
        }
    }

    private var managementWithAccountContent: some View {
        VStack(spacing: 0) {
            InvestmentTutorialManagementHeaderMock(
                highlightAddButton: false,
                isAddPressed: false
            )

            InvestmentTutorialAccountCardMock(
                name: "元大證券",
                highlighted: false,
                isPressed: false
            )
            .padding(12)

            Spacer(minLength: 0)
        }
    }

    private var addItemHubContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniHeroCard(title: "新增項目", subtitle: "選擇要建立的帳戶、負債或其他資產")

            VStack(alignment: .leading, spacing: 8) {
                Text("帳戶")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primaryText)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AccountType.twdSecurities.color.opacity(0.85))
                            .frame(width: 3, height: 10)
                        Text("投資帳戶")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondaryText)
                    }
                    .investmentTutorialHighlight(highlightInvestment, cornerRadius: 10, prominent: true)

                    VStack(spacing: 0) {
                        twSecuritiesRow
                        Divider().padding(.leading, 10)
                        hubRow(title: "美股證券", color: AccountType.usdAccount.color)
                        Divider().padding(.leading, 10)
                        hubRow(title: "加密貨幣錢包", color: AccountType.cryptoWallet.color)
                    }
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.separator.opacity(0.3), lineWidth: 1)
                    }
                }
                .padding(10)
                .background(Color.appPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var twSecuritiesRow: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AccountType.twdSecurities.color)
                .frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("台股證券")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primaryText)
                Text("買賣台股、台股 ETF")
                    .font(.system(size: 8))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .investmentTutorialHighlight(highlightTWSecurities, cornerRadius: 10, prominent: true)
        .investmentTutorialPress(isTWPressed)
    }

    private func hubRow(title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 22)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var accountFormContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            miniHeroCard(
                title: "台股證券",
                subtitle: AccountType.twdSecurities.description,
                badge: "新增帳戶",
                accent: AccountType.twdSecurities.color
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("帳戶名稱")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.primaryText)
                Text(accountName.isEmpty ? "例如：元大證券" : accountName)
                    .font(.system(size: 10))
                    .foregroundColor(accountName.isEmpty ? .tertiaryText : .primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(12)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("建立帳戶")
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .investmentTutorialHighlight(highlightCreateButton, cornerRadius: 12, prominent: true)
                .investmentTutorialPress(isCreatePressed)
        }
    }

    private func miniHeroCard(
        title: String,
        subtitle: String,
        badge: String? = nil,
        accent: Color = .appPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let badge {
                Text(badge)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.primaryText)
            Text(subtitle)
                .font(.system(size: 8))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(accent)
                .frame(width: 3)
        }
    }

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightTab = .accounts }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isTabPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                        isTabPressed = false
                        highlightTab = nil
                        selectedTab = .accounts
                    }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightAddButton = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isAddPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) {
                        isAddPressed = false
                        highlightAddButton = false
                        showFullSheet = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightInvestment = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    highlightInvestment = false
                    highlightTWSecurities = true
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isTWPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        isTWPressed = false
                        highlightTWSecurities = false
                        sheetShowsForm = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.45)) { accountName = "元大證券" }
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightCreateButton = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isCreatePressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                        isCreatePressed = false
                        highlightCreateButton = false
                        showFullSheet = false
                        sheetShowsForm = false
                        showCreatedAccount = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(2800))
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
        selectedTab = .assets
        highlightTab = nil
        isTabPressed = false
        highlightAddButton = false
        isAddPressed = false
        showFullSheet = false
        sheetShowsForm = false
        highlightInvestment = false
        highlightTWSecurities = false
        isTWPressed = false
        accountName = ""
        highlightCreateButton = false
        isCreatePressed = false
        showCreatedAccount = false
    }
}

// MARK: - Page 2: 進入帳戶 + 新增交易

private struct InvestmentTutorialTradeFlowMock: View {
    let animate: Bool

    @State private var showAccountDetail = false
    @State private var highlightAccount = false
    @State private var isAccountPressed = false
    @State private var highlightTradeButton = false
    @State private var isTradePressed = false
    @State private var showFullSheet = false
    @State private var symbolText = ""
    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var highlightSubmit = false
    @State private var isSubmitPressed = false
    @State private var showHoldingsResult = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        InvestmentTutorialPhoneChrome {
            ZStack(alignment: .top) {
                if showHoldingsResult {
                    investmentResultContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    mainFlowContent
                        .transition(.opacity)
                }

                if showFullSheet {
                    InvestmentTutorialFullScreenSheetMock(title: "新增交易", showsBack: false) {
                        tradeFormContent
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: showAccountDetail)
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: showFullSheet)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: showHoldingsResult)
        .onChange(of: animate) { _, active in
            active ? startLoop() : stopLoop()
        }
        .onAppear {
            if animate { startLoop() }
        }
        .onDisappear {
            stopLoop()
        }
    }

    private var mainFlowContent: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                managementListContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                accountDetailContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .offset(x: showAccountDetail ? -geo.size.width : 0)
            .animation(.spring(response: 0.46, dampingFraction: 0.86), value: showAccountDetail)
        }
    }

    private var managementListContent: some View {
        VStack(spacing: 0) {
            InvestmentTutorialManagementHeaderMock(
                highlightAddButton: false,
                isAddPressed: false
            )

            InvestmentTutorialAccountCardMock(
                name: "元大證券",
                highlighted: highlightAccount,
                isPressed: isAccountPressed
            )
            .padding(12)

            Spacer(minLength: 0)

            InvestmentTutorialTabBarMock(
                selectedTab: .accounts,
                highlightTab: nil,
                isTabPressed: false
            )
        }
    }

    private var accountDetailContent: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appPrimary)
                Text("元大證券")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 8) {
                metricTile(title: "現金餘額", value: "—")
                metricTile(title: "持股市值", value: "—")
            }
            .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("目前持股")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Text("尚無持股")
                    .font(.system(size: 9))
                    .foregroundColor(.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(12)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("新增交易")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.profitGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .investmentTutorialHighlight(highlightTradeButton && !showFullSheet, cornerRadius: 10, prominent: true)
                .investmentTutorialPress(isTradePressed)

                HStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                    Text("調整餘額")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.mainBackground)
        }
    }

    private var tradeFormContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("台股")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.stockTWColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.stockTWColor.opacity(0.14))
                    .clipShape(Capsule())

                HStack(spacing: 0) {
                    Text("買入")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.profitGreen)
                        .clipShape(Capsule())
                    Text("賣出")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .padding(3)
                .background(Color.cardBackground)
                .clipShape(Capsule())
            }

            formField(title: "代號", value: symbolText, placeholder: "0050")
            formField(title: "數量", value: quantityText, placeholder: "10")
            formField(title: "單價", value: priceText, placeholder: "150")

            Text("買入")
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.profitGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .investmentTutorialHighlight(highlightSubmit, cornerRadius: 12, prominent: true)
                .investmentTutorialPress(isSubmitPressed)
        }
    }

    private var investmentResultContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appPrimary)
                Text("投資")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primaryText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.stockTWColor)
                    .frame(width: 3, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("0050")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primaryText)
                    Text("元大台灣50")
                        .font(.system(size: 9))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Text("10 股")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primaryText)
            }
            .padding(12)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.stockTWColor)
                    .frame(width: 3)
            }
            .padding(12)

            Spacer(minLength: 0)

            InvestmentTutorialTabBarMock(
                selectedTab: .assets,
                highlightTab: nil,
                isTabPressed: false
            )
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8))
                .foregroundColor(.secondaryText)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formField(title: String, value: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondaryText)
            Text(value.isEmpty ? placeholder : value)
                .font(.system(size: 10, weight: value.isEmpty ? .regular : .semibold))
                .foregroundColor(value.isEmpty ? .tertiaryText : .primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightAccount = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isAccountPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                        isAccountPressed = false
                        highlightAccount = false
                        showAccountDetail = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightTradeButton = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isTradePressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) {
                        isTradePressed = false
                        highlightTradeButton = false
                        showFullSheet = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) { symbolText = "0050" }
                }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) { quantityText = "10" }
                }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) { priceText = "150" }
                }
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightSubmit = true }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(InvestmentTutorialMotion.pressSpring) { isSubmitPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(InvestmentTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                        isSubmitPressed = false
                        highlightSubmit = false
                        showFullSheet = false
                        showAccountDetail = false
                        showHoldingsResult = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(2800))
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
        showAccountDetail = false
        highlightAccount = false
        isAccountPressed = false
        highlightTradeButton = false
        isTradePressed = false
        showFullSheet = false
        symbolText = ""
        quantityText = ""
        priceText = ""
        highlightSubmit = false
        isSubmitPressed = false
        showHoldingsResult = false
    }
}

#if DEBUG
#Preview("如何新增持倉教學") {
    AddInvestmentTutorialView(onStartAdding: {})
}
#endif
