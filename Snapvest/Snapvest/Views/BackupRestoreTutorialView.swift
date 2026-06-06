//
//  BackupRestoreTutorialView.swift
//  Snapvest
//
//  更多分頁：如何備份與還原圖文教學
//

import SwiftUI

struct BackupRestoreTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0
    @State private var animate = false

    private let pages = BackupRestoreTutorialPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        BackupRestoreTutorialPageView(
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
            .navigationTitle("如何備份與還原")
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
                } label: {
                    Text("知道了")
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

private enum BackupRestoreTutorialTextRun: Equatable {
    case normal(String)
    case strong(String)
}

private enum BackupRestoreTutorialVisual: Equatable {
    case openSettingsFlow
    case exportBackupFlow
    case restoreBackupFlow
}

private struct BackupRestoreTutorialPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detailBullets: [[BackupRestoreTutorialTextRun]]
    let visual: BackupRestoreTutorialVisual

    static let all: [BackupRestoreTutorialPage] = [
        BackupRestoreTutorialPage(
            id: "open",
            title: "開啟「更多」",
            subtitle: "備份與還原都在「更多」頁面，任何分頁右上角都能進入。",
            detailBullets: [
                [.normal("點選畫面右上角「"), .strong("⋯"), .normal("」更多按鈕")],
                [.normal("在「"), .strong("備份與還原"), .normal("」區塊進行操作")],
            ],
            visual: .openSettingsFlow
        ),
        BackupRestoreTutorialPage(
            id: "export",
            title: "匯出備份檔",
            subtitle: "將帳戶、交易、持股、走勢與偏好匯出成 JSON 備份檔，可存到 iCloud Drive。",
            detailBullets: [
                [.normal("按「"), .strong("備份到 iCloud Drive"), .normal("」")],
                [.normal("選擇儲存位置（建議 iCloud Drive）")],
                [.normal("妥善保管備份檔，換機或重裝時可還原")],
            ],
            visual: .exportBackupFlow
        ),
        BackupRestoreTutorialPage(
            id: "restore",
            title: "從備份還原",
            subtitle: "還原會完全取代這台裝置上的現有資料，不會合併。",
            detailBullets: [
                [.normal("按「"), .strong("從備份還原"), .normal("」並選取備份 JSON")],
                [.normal("仔細閱讀警告：現有紀錄將被移除")],
                [.normal("確認後按「"), .strong("仍要還原"), .normal("」")],
                [.normal("若仍需要目前資料，請先匯出一份新備份")],
            ],
            visual: .restoreBackupFlow
        ),
    ]
}

private enum BackupRestoreTutorialLayout {
    static let visualHeight: CGFloat = 500
    /// 高亮框外擴空間，避免被 phone chrome 裁切
    static let highlightGutter: CGFloat = 10
}

private struct BackupRestoreTutorialPageView: View {
    let page: BackupRestoreTutorialPage
    let animate: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                visual
                    .padding(.horizontal, 4)
                    .padding(.vertical, BackupRestoreTutorialLayout.highlightGutter)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: BackupRestoreTutorialLayout.visualHeight, alignment: .top)

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
                                BackupRestoreTutorialBulletText(runs: runs)
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
        case .openSettingsFlow:
            BackupRestoreOpenSettingsFlowMock(animate: animate)
        case .exportBackupFlow:
            BackupRestoreExportFlowMock(animate: animate)
        case .restoreBackupFlow:
            BackupRestoreRestoreFlowMock(animate: animate)
        }
    }
}

private struct BackupRestoreTutorialBulletText: View {
    let runs: [BackupRestoreTutorialTextRun]

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

private enum BackupRestoreTutorialMotion {
    static let highlightSpring = Animation.easeInOut(duration: 0.38)
    static let pressSpring = Animation.easeInOut(duration: 0.36)
    static let pressHold: UInt64 = 480
    static let highlightDwell: UInt64 = 820
    static let stepPause: UInt64 = 620
}

private struct BackupRestoreTutorialHighlightModifier: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = 12
    var prominent: Bool = false

    @State private var pulseExpanded = false

    private var outerPadding: CGFloat { prominent ? -5 : -3 }
    private var strokeWidth: CGFloat { prominent ? 3 : 2.5 }
    private var glowRadius: CGFloat { prominent ? 10 : 8 }

    func body(content: Content) -> some View {
        content
            .padding(BackupRestoreTutorialLayout.highlightGutter)
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.22), lineWidth: prominent ? 5 : 4)
                        .padding(BackupRestoreTutorialLayout.highlightGutter - 2)
                        .scaleEffect(pulseExpanded ? 1.04 : 1)

                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .stroke(Color.appPrimary, lineWidth: strokeWidth)
                        .padding(BackupRestoreTutorialLayout.highlightGutter - 1)
                        .shadow(color: Color.appPrimary.opacity(0.45), radius: glowRadius, x: 0, y: 0)
                }
            }
            .padding(-BackupRestoreTutorialLayout.highlightGutter)
            .scaleEffect(active ? 0.985 : 1)
            .animation(BackupRestoreTutorialMotion.highlightSpring, value: active)
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

private struct BackupRestoreTutorialPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.93 : 1)
            .animation(BackupRestoreTutorialMotion.pressSpring, value: isPressed)
    }
}

private extension View {
    func backupTutorialHighlight(
        _ active: Bool,
        cornerRadius: CGFloat = 12,
        prominent: Bool = false
    ) -> some View {
        modifier(BackupRestoreTutorialHighlightModifier(
            active: active,
            cornerRadius: cornerRadius,
            prominent: prominent
        ))
    }

    func backupTutorialPress(_ isPressed: Bool) -> some View {
        modifier(BackupRestoreTutorialPressModifier(isPressed: isPressed))
    }
}

private struct BackupRestoreTutorialPhoneChrome<Content: View>: View {
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

private struct BackupRestoreTutorialSettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.appPrimary)
            .frame(width: 30, height: 30)
            .background(Color.appPrimary.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct BackupRestoreTutorialTabBarMock: View {
    let selectedTab: AppTab

    var body: some View {
        HStack {
            tabItem(tab: .home, title: "首頁", icon: "house.fill")
            tabItem(tab: .accounts, title: "管理", icon: "building.columns.fill")
            tabItem(tab: .assets, title: "投資", icon: "chart.bar.fill")
            tabItem(tab: .transactions, title: "紀錄", icon: "clock.fill")
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

    private func tabItem(tab: AppTab, title: String, icon: String) -> some View {
        let isSelected = selectedTab == tab
        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(isSelected ? .appPrimary : .secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

private struct BackupRestoreHomeScreenMock: View {
    var highlightMoreButton = false
    var isMorePressed = false

    var body: some View {
        VStack(spacing: 0) {
            homeHeader

            ScrollView {
                VStack(spacing: 10) {
                    trendChartCard
                    netWorthCard
                    investmentCard
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            BackupRestoreTutorialTabBarMock(selectedTab: .home)
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                Text("首頁")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primaryText)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(Color.appPrimary.opacity(0.14))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }

            Circle()
                .fill(Color.appPrimary.opacity(0.14))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }

            Circle()
                .fill(Color.appPrimary.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appPrimary)
                }
                .backupTutorialHighlight(highlightMoreButton, cornerRadius: 16, prominent: true)
                .backupTutorialPress(isMorePressed)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color.mainBackground)
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                chartSegment(title: "淨資產", selected: true)
                chartSegment(title: "總資產", selected: false)
            }
            .padding(3)
            .background(Color.separator.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("淨資產")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondaryText)
                Text("NT$ 3,420,000")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("+2.4%")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.profitGreen)
            }

            BackupRestoreMiniTrendLine()
                .frame(height: 56)
                .padding(.horizontal, 2)

            HStack(spacing: 6) {
                ForEach(["7天", "1月", "3月", "1年"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: label == "7天" ? .bold : .semibold))
                        .foregroundColor(label == "7天" ? AppColors.actionForeground : .secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(label == "7天" ? Color.appPrimary : Color.separator.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }

    private func chartSegment(title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(selected ? AppColors.actionForeground : .secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selected ? Color.appPrimary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var netWorthCard: some View {
        mockAccentCard(title: "淨資產", accent: .homeNetWorthAccent) {
            HStack(spacing: 10) {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(Color.homeNetWorthAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text("72%")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondaryText)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NT$ 3,420,000")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                    Text("TWD")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.separator.opacity(0.25))
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var investmentCard: some View {
        mockAccentCard(title: "投資資產", accent: .homeInvestmentsAccent) {
            HStack {
                Text("NT$ 2,180,000")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
        }
    }

    private func mockAccentCard<Content: View>(
        title: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primaryText)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
}

private struct BackupRestoreMiniTrendLine: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: 0, y: h * 0.72))
                path.addCurve(
                    to: CGPoint(x: w * 0.35, y: h * 0.48),
                    control1: CGPoint(x: w * 0.12, y: h * 0.68),
                    control2: CGPoint(x: w * 0.22, y: h * 0.42)
                )
                path.addCurve(
                    to: CGPoint(x: w * 0.68, y: h * 0.55),
                    control1: CGPoint(x: w * 0.48, y: h * 0.54),
                    control2: CGPoint(x: w * 0.58, y: h * 0.62)
                )
                path.addCurve(
                    to: CGPoint(x: w, y: h * 0.28),
                    control1: CGPoint(x: w * 0.82, y: h * 0.48),
                    control2: CGPoint(x: w * 0.92, y: h * 0.32)
                )
            }
            .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct BackupRestoreSettingsSheetMock: View {
    var highlightBackupSection = false
    var highlightExportRow = false
    var highlightRestoreRow = false
    var isExportPressed = false
    var isRestorePressed = false
    var showsExportLoading = false
    var showsExportSuccess = false
    /// 第 2、3 頁只顯示備份區塊，避免內容被裁切
    var focusesOnBackupSection = false

    var body: some View {
        VStack(spacing: 0) {
            settingsNavBar

            VStack(spacing: 12) {
                if !focusesOnBackupSection {
                    plusCardMock

                    settingsSectionBlock(title: "顯示") {
                        settingsRow(icon: "circle.lefthalf.filled", title: "深淺模式", value: "跟隨系統")
                    }
                }

                settingsSectionBlock(
                    title: "備份與還原",
                    highlightSection: highlightBackupSection
                ) {
                    backupRow(
                        icon: "icloud.and.arrow.up.fill",
                        title: "備份到 iCloud Drive",
                        subtitle: "匯出帳戶、交易、其他資產、走勢點與偏好",
                        actionTitle: "備份",
                        actionColor: .appPrimary,
                        highlighted: highlightExportRow,
                        isPressed: isExportPressed
                    )

                    Divider().padding(.leading, 56)

                    backupRow(
                        icon: "icloud.and.arrow.down.fill",
                        title: "從備份還原",
                        subtitle: "選取備份檔；還原會完全取代目前本機資料",
                        actionTitle: "還原",
                        actionColor: .lossRed,
                        highlighted: highlightRestoreRow,
                        isPressed: isRestorePressed
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mainBackground)
        .overlay {
            if showsExportLoading {
                loadingOverlay(title: "正在準備備份…", message: "匯出帳戶、交易與偏好設定")
            }
            if showsExportSuccess {
                successBanner
            }
        }
    }

    private var settingsNavBar: some View {
        HStack {
            Text("完成")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appPrimary)
            Spacer()
            Text("更多")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.separator.opacity(0.35))
                .frame(height: 0.5)
        }
    }

    private var plusCardMock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Walleaf Plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primaryText)
                        Text("PLUS")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.appPrimary.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    Text("解鎖更多投資追蹤、分享與進階設定功能")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.primaryText.opacity(0.78))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack {
                Text("訂閱功能即將推出")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.primaryText.opacity(0.7))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primaryText.opacity(0.55))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#B7E99A"), Color(hex: "#7ED957"), Color(hex: "#F2C078")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    private func settingsSectionBlock<Content: View>(
        title: String,
        highlightSection: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.separator.opacity(0.45), lineWidth: 1)
            }
            .backupTutorialHighlight(highlightSection, cornerRadius: 18, prominent: true)
        }
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            BackupRestoreTutorialSettingsIcon(systemName: icon)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(.secondaryText)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func backupRow(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String,
        actionColor: Color,
        highlighted: Bool,
        isPressed: Bool
    ) -> some View {
        HStack(spacing: 12) {
            BackupRestoreTutorialSettingsIcon(systemName: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primaryText)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(actionTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(actionColor == .lossRed ? .lossRed : .appPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(actionColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .backupTutorialHighlight(highlighted, cornerRadius: 16, prominent: true)
        .backupTutorialPress(isPressed)
    }

    private func loadingOverlay(title: String, message: String) -> some View {
        ZStack {
            Color.black.opacity(0.18)
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.appPrimary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primaryText)
                Text(message)
                    .font(.system(size: 8))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        }
    }

    private var successBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appPrimary)
                Text("備份檔已建立")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
            Spacer()
        }
        .padding(.top, 12)
    }
}

// MARK: - Page 1: 開啟更多

private struct BackupRestoreOpenSettingsFlowMock: View {
    let animate: Bool

    @State private var highlightMoreButton = false
    @State private var isMorePressed = false
    @State private var showSettingsSheet = false
    @State private var highlightBackupSection = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        BackupRestoreTutorialPhoneChrome {
            ZStack(alignment: .top) {
                BackupRestoreHomeScreenMock(
                    highlightMoreButton: highlightMoreButton && !showSettingsSheet,
                    isMorePressed: isMorePressed
                )
                .opacity(showSettingsSheet ? 0.28 : 1)

                if showSettingsSheet {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        BackupRestoreSettingsSheetMock(
                            highlightBackupSection: highlightBackupSection
                        )
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(Color.mainBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: -4)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: showSettingsSheet)
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

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightMoreButton = true }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(BackupRestoreTutorialMotion.pressSpring) { isMorePressed = true }
                }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                        isMorePressed = false
                        highlightMoreButton = false
                        showSettingsSheet = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.stepPause))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightBackupSection = true }
                try? await Task.sleep(for: .milliseconds(1800))
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func resetState() {
        highlightMoreButton = false
        isMorePressed = false
        showSettingsSheet = false
        highlightBackupSection = false
    }
}

// MARK: - Page 2: 匯出備份

private struct BackupRestoreExportFlowMock: View {
    let animate: Bool

    @State private var highlightExportRow = false
    @State private var isExportPressed = false
    @State private var showsExportLoading = false
    @State private var showsExportSuccess = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        BackupRestoreTutorialPhoneChrome {
            BackupRestoreSettingsSheetMock(
                highlightExportRow: highlightExportRow,
                isExportPressed: isExportPressed,
                showsExportLoading: showsExportLoading,
                showsExportSuccess: showsExportSuccess,
                focusesOnBackupSection: true
            )
        }
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

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightExportRow = true }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(BackupRestoreTutorialMotion.pressSpring) { isExportPressed = true }
                }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isExportPressed = false
                        highlightExportRow = false
                        showsExportLoading = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        showsExportLoading = false
                        showsExportSuccess = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(2200))
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func resetState() {
        highlightExportRow = false
        isExportPressed = false
        showsExportLoading = false
        showsExportSuccess = false
    }
}

// MARK: - Page 3: 還原備份

private struct BackupRestoreRestoreFlowMock: View {
    let animate: Bool

    @State private var highlightRestoreRow = false
    @State private var isRestorePressed = false
    @State private var showFilePicker = false
    @State private var showRestoreAlert = false
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        BackupRestoreTutorialPhoneChrome {
            ZStack {
                BackupRestoreSettingsSheetMock(
                    highlightRestoreRow: highlightRestoreRow,
                    isRestorePressed: isRestorePressed,
                    focusesOnBackupSection: true
                )

                if showFilePicker {
                    filePickerOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }

                if showRestoreAlert {
                    restoreAlertOverlay
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showFilePicker)
        .animation(.easeInOut(duration: 0.24), value: showRestoreAlert)
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

    private var filePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.22)
            VStack(spacing: 12) {
                HStack {
                    Text("取消")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.appPrimary)
                    Spacer()
                    Text("選擇備份檔")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primaryText)
                    Spacer()
                    Text("開啟")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.appPrimary.opacity(0.45))
                }

                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.appPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Drive")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primaryText)
                        Text("Walleaf-Backup-local.json")
                            .font(.system(size: 9))
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimary)
                }
                .padding(12)
                .background(Color.mainBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.appPrimary, lineWidth: 2)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var restoreAlertOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
            VStack(spacing: 10) {
                Text("還原將取代目前資料？")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)

                Text("還原後，這台裝置上的現有資料會被移除，並以備份檔內容完全取代。")
                    .font(.system(size: 8))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                HStack(spacing: 8) {
                    Text("取消")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.separator.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("仍要還原")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.lossRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.lossRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .backupTutorialHighlight(true, cornerRadius: 8, prominent: true)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 22)
        }
    }

    private func startLoop() {
        stopLoop()
        loopTask = Task {
            while !Task.isCancelled {
                await MainActor.run { resetState() }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                await MainActor.run { highlightRestoreRow = true }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.highlightDwell))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(BackupRestoreTutorialMotion.pressSpring) { isRestorePressed = true }
                }
                try? await Task.sleep(for: .milliseconds(BackupRestoreTutorialMotion.pressHold))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isRestorePressed = false
                        highlightRestoreRow = false
                        showFilePicker = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(1100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        showFilePicker = false
                        showRestoreAlert = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(2600))
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func resetState() {
        highlightRestoreRow = false
        isRestorePressed = false
        showFilePicker = false
        showRestoreAlert = false
    }
}

#Preview("如何備份與還原教學") {
    BackupRestoreTutorialView()
}
