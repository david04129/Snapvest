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
    @State private var isLaunchComplete = false
    @State private var networkErrorMessage: String?
    @State private var blockedLaunchMessage: String?
    @State private var blockedLaunchAllowsRetry = false
    @State private var launchAttempt = 0
    
    private let userId = AppUser.id
    
    var body: some View {
        Group {
            if !isLaunchComplete {
                LaunchSplashView(
                    networkErrorMessage: networkErrorMessage,
                    blockedMessage: blockedLaunchMessage,
                    blockedAllowsRetry: blockedLaunchAllowsRetry,
                    onRetryLaunch: retryLaunch,
                    onExitApp: exitApplication
                )
                .id(launchAttempt)
            } else if privacyLock.isLocked {
                PrivacyLockView()
            } else {
                ContentView()
                    .environmentObject(portfolioViewModel)
                    .environmentObject(accountsViewModel)
                    .environmentObject(assetsViewModel)
                    .environmentObject(themeManager)
                    .environmentObject(LaunchSessionState.shared)
                    .environmentObject(DataFreshnessStore.shared)
                    .snapDismissKeyboardOnTap()
                    .fullScreenCover(isPresented: $onboardingManager.isPresented) {
                        OnboardingView(
                            onFinish: { onboardingManager.complete() },
                            onDemoMode: {
                                await DemoModeManager.shared.enterDemoMode()
                                onboardingManager.complete()
                            }
                        )
                    }
            }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .dynamicTypeSize(.medium)
        .task(id: launchAttempt) {
            await runLaunchSequence()
        }
        .onChange(of: scenePhase) { _, newPhase in
            privacyLock.handleScenePhase(newPhase, launchComplete: isLaunchComplete)
        }
        .onChange(of: isLaunchComplete) { _, launchComplete in
            guard launchComplete else { return }
            privacyLock.handleLaunchComplete()
            presentOnboardingIfAppropriate()
        }
        .onChange(of: privacyLock.isLocked) { wasLocked, isLocked in
            if wasLocked && !isLocked {
                presentOnboardingIfAppropriate()
            }
        }
    }

    private func presentOnboardingIfAppropriate() {
        guard isLaunchComplete, !privacyLock.isLocked else { return }
        onboardingManager.presentIfNeeded()
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
        privacyLock.prepareForProtectedPresentation()
        isLaunchComplete = true
    }
    
    private func retryLaunch() {
        isLaunchComplete = false
        launchAttempt += 1
    }
    
    private func exitApplication() {
        exit(0)
    }
}
