//
//  ContentView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var pieGroupingStore = PieChartGroupingStore.shared
    @ObservedObject private var privacy = HomePrivacyManager.shared
    @ObservedObject private var demoMode = DemoModeManager.shared
    @EnvironmentObject private var launchSessionState: LaunchSessionState
    @EnvironmentObject private var dataFreshness: DataFreshnessStore
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0
    @State private var privacyBlockedTab: Int?
    @State private var showsPrivacyModeTabAlert = false
    @State private var isRevertingTabForPrivacy = false
    @State private var isSettingsPresented = false
    @State private var showsExitDemoModeAlert = false
    @State private var isPortfolioMutationRefreshing = false
    @State private var portfolioMutationRefreshDepth = 0
    @State private var portfolioMutationRefreshTitle = "正在更新資料…"
    @State private var portfolioMutationRefreshMessage = "交易完成後會自動顯示最新結果"
    @State private var showsManualRefreshBlockedAlert = false
    @State private var manualRefreshBlockedAlertMessage = ""
    @State private var isPaywallPresented = false

    private var complianceSnapshot: PortfolioLimitSnapshot {
        SubscriptionComplianceState.snapshot(
            accounts: accountsViewModel.accounts,
            holdings: assetsViewModel.aggregatedHoldings
        )
    }

    var body: some View {
        tabRootWithChrome
            .overlay(alignment: .bottomTrailing, content: demoModeBadgeOverlay)
            .overlay(content: portfolioMutationOverlay)
            .fullScreenCover(isPresented: $isPaywallPresented) {
                WalleafPlusPaywallView()
            }
            .animation(.easeInOut(duration: 0.18), value: isPortfolioMutationRefreshing)
            .animation(.easeInOut(duration: 0.18), value: demoMode.isSwitching)
            .modifier(ContentViewEventModifier(
                selectedTab: $selectedTab,
                isRevertingTabForPrivacy: $isRevertingTabForPrivacy,
                privacyBlockedTab: $privacyBlockedTab,
                showsPrivacyModeTabAlert: $showsPrivacyModeTabAlert,
                isSettingsPresented: $isSettingsPresented,
                showsManualRefreshBlockedAlert: $showsManualRefreshBlockedAlert,
                manualRefreshBlockedAlertMessage: $manualRefreshBlockedAlertMessage,
                portfolioViewModel: portfolioViewModel,
                accountsViewModel: accountsViewModel,
                assetsViewModel: assetsViewModel,
                dataFreshness: dataFreshness,
                onPortfolioMutationBegan: { beginPortfolioMutationRefresh(notification: $0) },
                onPortfolioMutationEnded: { finishPortfolioMutationRefresh() }
            ))
            .alert("目前為隱藏金額模式", isPresented: $showsPrivacyModeTabAlert) {
                privacyModeAlertActions()
            } message: {
                Text("為了避免顯示帳戶明細、持股成本與交易紀錄，隱藏金額模式下只能瀏覽首頁。若要查看其他頁面，請先關閉隱藏金額。")
            }
            .alert("結束示範模式？", isPresented: $showsExitDemoModeAlert) {
                exitDemoModeAlertActions()
            } message: {
                Text("結束後會回到你的真實資料，沙盒中的操作不會保留。")
            }
            .alert("無法更新", isPresented: $showsManualRefreshBlockedAlert) {
                manualRefreshBlockedAlertActions()
            } message: {
                Text(manualRefreshBlockedAlertMessage)
            }
    }

    private var tabRootWithChrome: some View {
        mainTabView
            .background(Color.mainBackground)
            .tint(.appPrimary)
            .toolbarBackground(Color.cardBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .id(themeManager.appearanceRefreshToken)
            .transaction { transaction in
                transaction.animation = nil
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if let notice = launchSessionState.startupNotice {
                        StartupNoticeBanner(message: notice) {
                            launchSessionState.clearStartupNotice()
                        }
                    }
                    if !PlusFeatureGate.shouldBypassLimits(isPlusActive: subscriptionManager.isPlusActive),
                       complianceSnapshot.isOverFreeHoldingLimits {
                        SubscriptionComplianceBanner(snapshot: complianceSnapshot) {
                            isPaywallPresented = true
                        }
                    }
                }
            }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab) {
                isSettingsPresented = true
            }
            .tabItem { Label("首頁", systemImage: "house.fill") }
            .tag(AppTab.home.rawValue)

            AccountsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem { Label("管理", systemImage: "building.columns.fill") }
                .tag(AppTab.accounts.rawValue)

            AssetsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem { Label("投資", systemImage: "chart.bar.fill") }
                .tag(AppTab.assets.rawValue)

            TransactionsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem { Label("紀錄", systemImage: "clock.fill") }
                .tag(AppTab.transactions.rawValue)
        }
    }

    @ViewBuilder
    private func demoModeBadgeOverlay() -> some View {
        if demoMode.isEnabled {
            DemoModeFloatingBadge { showsExitDemoModeAlert = true }
                .padding(.trailing, 12)
                .padding(.bottom, 52)
        }
    }

    @ViewBuilder
    private func portfolioMutationOverlay() -> some View {
        if isPortfolioMutationRefreshing {
            OperationLoadingOverlay(
                title: portfolioMutationRefreshTitle,
                message: portfolioMutationRefreshMessage
            )
            .transition(.opacity)
        } else if demoMode.isSwitching {
            OperationLoadingOverlay(
                title: "正在準備示範資料…",
                message: "會載入一組範例帳戶、持股與走勢"
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func privacyModeAlertActions() -> some View {
        Button("繼續隱藏", role: .cancel) { privacyBlockedTab = nil }
        Button("關閉隱藏金額") {
            let targetTab = privacyBlockedTab
            privacyBlockedTab = nil
            privacy.setAmountHidden(false)
            if let targetTab { selectedTab = targetTab }
        }
    }

    @ViewBuilder
    private func exitDemoModeAlertActions() -> some View {
        Button("取消", role: .cancel) {}
        Button("結束示範模式", role: .destructive) {
            Task { await demoMode.exitDemoMode() }
        }
    }

    @ViewBuilder
    private func manualRefreshBlockedAlertActions() -> some View {
        Button("好", role: .cancel) {
            ManualRefreshCooldown.shared.dismissAlert()
            showsManualRefreshBlockedAlert = false
            manualRefreshBlockedAlertMessage = ""
        }
    }

    private func beginPortfolioMutationRefresh(notification: Notification? = nil) {
        portfolioMutationRefreshTitle = notification?.userInfo?[PortfolioMutationRefreshUserInfoKey.title] as? String
            ?? "正在更新資料…"
        portfolioMutationRefreshMessage = notification?.userInfo?[PortfolioMutationRefreshUserInfoKey.message] as? String
            ?? "交易完成後會自動顯示最新結果"
        portfolioMutationRefreshDepth += 1
        isPortfolioMutationRefreshing = true
    }

    private func finishPortfolioMutationRefresh() {
        portfolioMutationRefreshDepth = max(0, portfolioMutationRefreshDepth - 1)
        if portfolioMutationRefreshDepth == 0 {
            isPortfolioMutationRefreshing = false
            portfolioMutationRefreshTitle = "正在更新資料…"
            portfolioMutationRefreshMessage = "交易完成後會自動顯示最新結果"
        }
    }
}

// MARK: - Lifecycle（拆出以減輕 ContentView.body 型別推斷負擔）

private struct ContentViewEventModifier: ViewModifier {
    @Binding var selectedTab: Int
    @Binding var isRevertingTabForPrivacy: Bool
    @Binding var privacyBlockedTab: Int?
    @Binding var showsPrivacyModeTabAlert: Bool
    @Binding var isSettingsPresented: Bool
    @Binding var showsManualRefreshBlockedAlert: Bool
    @Binding var manualRefreshBlockedAlertMessage: String

    @ObservedObject private var pieGroupingStore = PieChartGroupingStore.shared
    @ObservedObject private var privacy = HomePrivacyManager.shared
    @ObservedObject private var demoMode = DemoModeManager.shared
    @ObservedObject private var manualRefreshCooldown = ManualRefreshCooldown.shared

    let portfolioViewModel: PortfolioViewModel
    let accountsViewModel: AccountsViewModel
    let assetsViewModel: AssetsViewModel
    let dataFreshness: DataFreshnessStore
    let onPortfolioMutationBegan: (Notification?) -> Void
    let onPortfolioMutationEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .portfolioMutationRefreshBegan)) { notification in
                onPortfolioMutationBegan(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioMutationRefreshEnded)) { _ in
                onPortfolioMutationEnded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
                if let tab = notification.userInfo?[TabResignUserInfoKey.tabIndex] as? Int {
                    selectedTab = tab
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { notification in
                guard let request = notification.object as? PortfolioMutationRefreshRequest else { return }
                Task {
                    await PortfolioMutationCoordinator.performRefresh(
                        request,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel,
                        dataService: MockDataService.shared
                    )
                    dataFreshness.refresh()
                }
            }
            .onChange(of: selectedTab) { previousTab, newTab in
                handleSelectedTabChange(previousTab: previousTab, newTab: newTab)
            }
            .onChange(of: privacy.isAmountHidden) { _, isHidden in
                guard isHidden, selectedTab != AppTab.home.rawValue else { return }
                privacyBlockedTab = selectedTab
                isRevertingTabForPrivacy = true
                selectedTab = AppTab.home.rawValue
                showsPrivacyModeTabAlert = true
            }
            .onChange(of: manualRefreshCooldown.alertMessage) { _, message in
                if let message {
                    manualRefreshBlockedAlertMessage = message
                    showsManualRefreshBlockedAlert = true
                }
            }
            .onAppear { dataFreshness.refresh() }
            .onChange(of: demoMode.isEnabled) { _, _ in
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: AppUser.id,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel,
                        dataService: MockDataService.shared
                    )
                    dataFreshness.refresh()
                    NotificationCenter.default.post(
                        name: .snapshotsDidUpdate,
                        object: nil,
                        userInfo: [SnapshotUpdateUserInfoKey.alreadyApplied: true]
                    )
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
    }

    private func handleSelectedTabChange(previousTab: Int, newTab: Int) {
        if isRevertingTabForPrivacy, newTab == AppTab.home.rawValue {
            isRevertingTabForPrivacy = false
            return
        }
        if pieGroupingStore.isEditingGroups, newTab != previousTab {
            selectedTab = previousTab
            return
        }
        if privacy.isAmountHidden, newTab != AppTab.home.rawValue {
            privacyBlockedTab = newTab
            isRevertingTabForPrivacy = true
            selectedTab = AppTab.home.rawValue
            showsPrivacyModeTabAlert = true
            return
        }
        NotificationCenter.default.post(
            name: .tabResigned,
            object: nil,
            userInfo: [TabResignUserInfoKey.tabIndex: previousTab]
        )
    }
}

private struct DemoModeFloatingBadge: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 17, weight: .bold))
                
                Text("示範模式")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.lossRed.opacity(0.96))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color.lossRed.opacity(0.35), radius: 10, x: 0, y: 4)
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("示範模式")
        .accessibilityHint("點一下可結束示範模式")
    }
}

#Preview {
    ContentView()
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
        .environmentObject(ThemeManager.shared)
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(LaunchSessionState.shared)
        .environmentObject(DataFreshnessStore.shared)
}
