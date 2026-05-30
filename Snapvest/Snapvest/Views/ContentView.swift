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
    @State private var selectedTab = 0
    @State private var privacyBlockedTab: Int?
    @State private var showsPrivacyModeTabAlert = false
    @State private var isRevertingTabForPrivacy = false
    @State private var isSettingsPresented = false
    @State private var showsExitDemoModeAlert = false
    @State private var isPortfolioMutationRefreshing = false
    @State private var portfolioMutationRefreshDepth = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab) {
                isSettingsPresented = true
            }
                .tabItem {
                    Label("首頁", systemImage: "house.fill")
                }
                .tag(AppTab.home.rawValue)
            
            AccountsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem {
                    Label("帳戶", systemImage: "building.columns.fill")
                }
                .tag(AppTab.accounts.rawValue)
            
            AssetsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem {
                    Label("資產", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.assets.rawValue)
            
            TransactionsView(selectedTab: $selectedTab)
                .environment(\.openSettings, { isSettingsPresented = true })
                .tabItem {
                    Label("紀錄", systemImage: "clock.fill")
                }
                .tag(AppTab.transactions.rawValue)
        }
        .background(Color.mainBackground)
        .tint(.appPrimary)
        .toolbarBackground(Color.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .id(themeManager.appearanceRefreshToken)
        .transaction { transaction in
            transaction.animation = nil
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = launchSessionState.startupNotice {
                StartupNoticeBanner(message: notice) {
                    launchSessionState.clearStartupNotice()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if demoMode.isEnabled {
                DemoModeFloatingBadge {
                    showsExitDemoModeAlert = true
                }
                    .padding(.trailing, 14)
                    .padding(.bottom, 58)
            }
        }
        .overlay {
            if isPortfolioMutationRefreshing {
                PortfolioMutationLoadingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPortfolioMutationRefreshing)
        .onReceive(NotificationCenter.default.publisher(for: .portfolioMutationRefreshBegan)) { _ in
            beginPortfolioMutationRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portfolioMutationRefreshEnded)) { _ in
            finishPortfolioMutationRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { notification in
            let shouldShowOverlay = notification.userInfo?[PortfolioMutationUserInfoKey.showsLoadingOverlay] as? Bool == true
            let affectedAccountIds = notification.userInfo?[PortfolioMutationUserInfoKey.affectedAccountIds] as? [String]
            let affectedAccountIdSet = affectedAccountIds.map { Set($0) }
            if shouldShowOverlay {
                beginPortfolioMutationRefresh()
            }
            Task {
                let perfFlow = "transactionsDidChange UI apply overlay=\(shouldShowOverlay)"
                let perfStart = DebugPerformanceLog.now()
                var perfLast = perfStart
                DebugPerformanceLog.start(perfFlow)
                await LaunchCoordinator.applyPersistedState(
                    userId: AppUser.id,
                    portfolioViewModel: portfolioViewModel,
                    accountsViewModel: accountsViewModel,
                    assetsViewModel: assetsViewModel,
                    dataService: MockDataService.shared,
                    accountDetailCacheAccountIds: affectedAccountIdSet
                )
                DebugPerformanceLog.lap("apply persisted state", flow: perfFlow, start: perfStart, last: &perfLast)
                await MainActor.run {
                    if shouldShowOverlay {
                        finishPortfolioMutationRefresh()
                    }
                }
                DebugPerformanceLog.lap("finish overlay", flow: perfFlow, start: perfStart, last: &perfLast)
                DebugPerformanceLog.end(perfFlow, start: perfStart)
            }
        }
        .onChange(of: selectedTab) { previousTab, newTab in
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
        .onChange(of: privacy.isAmountHidden) { _, isHidden in
            guard isHidden, selectedTab != AppTab.home.rawValue else { return }
            privacyBlockedTab = selectedTab
            isRevertingTabForPrivacy = true
            selectedTab = AppTab.home.rawValue
            showsPrivacyModeTabAlert = true
        }
        .alert("目前為隱藏金額模式", isPresented: $showsPrivacyModeTabAlert) {
            Button("繼續隱藏", role: .cancel) {
                privacyBlockedTab = nil
            }
            Button("關閉隱藏金額") {
                let targetTab = privacyBlockedTab
                privacyBlockedTab = nil
                privacy.setAmountHidden(false)
                if let targetTab {
                    selectedTab = targetTab
                }
            }
        } message: {
            Text("為了避免顯示帳戶明細、持股成本與交易紀錄，隱藏金額模式下只能瀏覽首頁。若要查看其他頁面，請先關閉隱藏金額。")
        }
        .alert("結束示範模式？", isPresented: $showsExitDemoModeAlert) {
            Button("取消", role: .cancel) {}
            Button("結束示範模式", role: .destructive) {
                Task { await demoMode.exitDemoMode() }
            }
        } message: {
            Text("結束後會回到你的真實資料，沙盒中的操作不會保留。")
        }
        .onAppear {
            dataFreshness.refresh()
        }
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
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    private func beginPortfolioMutationRefresh() {
        portfolioMutationRefreshDepth += 1
        isPortfolioMutationRefreshing = true
    }

    private func finishPortfolioMutationRefresh() {
        portfolioMutationRefreshDepth = max(0, portfolioMutationRefreshDepth - 1)
        if portfolioMutationRefreshDepth == 0 {
            isPortfolioMutationRefreshing = false
        }
    }
}

private struct DemoModeFloatingBadge: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 12, weight: .bold))
                
                Text("示範模式")
                    .font(.caption.weight(.bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.lossRed.opacity(0.94))
            .clipShape(Capsule())
            .shadow(color: AppColors.shadowLow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct PortfolioMutationLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.appPrimary)
                Text("正在更新資料…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                Text("交易完成後會自動顯示最新結果")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
        .environmentObject(LaunchSessionState.shared)
        .environmentObject(DataFreshnessStore.shared)
}
