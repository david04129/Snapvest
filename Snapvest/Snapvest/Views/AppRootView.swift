//
//  AppRootView.swift
//  Snapvest
//
//  開機 Splash → 有網路才灌資料 → 進入主畫面。
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var assetsViewModel = AssetsViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var privacyLock = PrivacyLockManager.shared
    @ObservedObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isLaunchComplete = false
    @State private var showSplashOverlay = true
    @State private var networkErrorMessage: String?
    @State private var blockedLaunchMessage: String?
    @State private var blockedLaunchAllowsRetry = false
    @State private var launchAttempt = 0
    
    private let userId = AppUser.id
    
    var body: some View {
        ZStack {
            postLaunchRootView

            LaunchSplashView(
                networkErrorMessage: networkErrorMessage,
                blockedMessage: blockedLaunchMessage,
                blockedAllowsRetry: blockedLaunchAllowsRetry,
                onRetryLaunch: retryLaunch,
                onExitApp: exitApplication
            )
            .opacity(showSplashOverlay ? 1 : 0)
            .animation(LaunchSplashTiming.fadeOutAnimation, value: showSplashOverlay)
            .allowsHitTesting(showSplashOverlay)
            .zIndex(1)
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .dynamicTypeSize(.medium)
        .task(id: launchAttempt) {
            await runLaunchSequence()
        }
        .onChange(of: scenePhase) { _, newPhase in
            privacyLock.handleScenePhase(newPhase, launchComplete: isLaunchComplete && !showSplashOverlay)
        }
        .onChange(of: isLaunchComplete) { _, launchComplete in
            guard launchComplete else { return }
            privacyLock.handleLaunchComplete()
        }
    }

    @ViewBuilder
    private var postLaunchRootView: some View {
        if isLaunchComplete {
            if privacyLock.isLocked {
                PrivacyLockView()
            } else if !onboardingManager.hasCompletedOnboarding {
                onboardingRootView
            } else {
                mainAppView
            }
        } else {
            launchUnderlayBackground
        }
    }

    private var launchUnderlayBackground: some View {
        (themeManager.isDarkMode ? Color.mainBackground : Color(hex: "#F7FAF5"))
            .ignoresSafeArea()
    }

    private var onboardingRootView: some View {
        OnboardingView(
            onFinish: { onboardingManager.complete() },
            onDemoMode: { await enterDemoModeFromOnboarding() }
        )
    }

    private var mainAppView: some View {
        ContentView()
            .environmentObject(portfolioViewModel)
            .environmentObject(accountsViewModel)
            .environmentObject(assetsViewModel)
            .environmentObject(themeManager)
            .environmentObject(subscriptionManager)
            .environmentObject(LaunchSessionState.shared)
            .environmentObject(DataFreshnessStore.shared)
            .snapDismissKeyboardOnTap()
            .fullScreenCover(isPresented: $onboardingManager.isPresented) {
                OnboardingView(
                    onFinish: { onboardingManager.complete() },
                    onDemoMode: { await enterDemoModeFromOnboarding() }
                )
            }
    }

    /// 新手教學進示範：先 rebuild 再灌入 ViewModel，避免 ContentView 首次掛載時 onChange 不觸發而顯示 0。
    private func enterDemoModeFromOnboarding() async {
        await DemoModeManager.shared.enterDemoMode(userId: userId)
        await LaunchCoordinator.applyPersistedState(
            userId: userId,
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: accountsViewModel,
            assetsViewModel: assetsViewModel,
            dataService: MockDataService.shared
        )
        DataFreshnessStore.shared.refresh(userId: userId)
        onboardingManager.complete()
    }
    
    private func runLaunchSequence() async {
        networkErrorMessage = nil
        blockedLaunchMessage = nil
        blockedLaunchAllowsRetry = false
        LaunchSessionState.shared.clearStartupNotice()
        
        let splashStarted = ContinuousClock.now
        
        guard await NetworkConnectivity.isConnected() else {
            networkErrorMessage = """
            Walleaf 需要網路才能同步股價與資料。
            請檢查 Wi‑Fi 或行動數據後重新開啟 App。
            """
            return
        }
        
        let result = await LaunchCoordinator.run(
            userId: userId,
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: accountsViewModel,
            assetsViewModel: assetsViewModel
        )
        
        switch result {
        case .success:
            break
        case .degraded(let notice):
            LaunchSessionState.shared.startupNotice = notice
        case .blocked(let message, let allowsRetry):
            blockedLaunchMessage = message
            blockedLaunchAllowsRetry = allowsRetry
            return
        }
        
        DataFreshnessStore.shared.refresh(userId: userId)
        
        let elapsed = ContinuousClock.now - splashStarted
        if elapsed < LaunchSplashTiming.minimumDuration {
            try? await Task.sleep(for: LaunchSplashTiming.minimumDuration - elapsed)
        }
        
        try? await Task.sleep(for: LaunchSplashTiming.preTransitionHold)

        if privacyLock.isEnabled {
            let unlocked = await privacyLock.authenticateForLaunch()
            if !unlocked {
                blockedLaunchMessage = privacyLock.errorMessage ?? "無法完成驗證，請再試一次。"
                blockedLaunchAllowsRetry = true
                return
            }
        }

        isLaunchComplete = true
        await Task.yield()
        try? await Task.sleep(for: LaunchSplashTiming.contentLayoutHold)

        showSplashOverlay = false
    }
    
    private func retryLaunch() {
        showSplashOverlay = true
        isLaunchComplete = false
        launchAttempt += 1
    }
    
    private func exitApplication() {
        exit(0)
    }
}
