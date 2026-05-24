//
//  AppRootView.swift
//  Snapvest
//
//  開機 Splash → 有網路才灌資料 → 進入主畫面。
//

import SwiftUI

struct AppRootView: View {
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var assetsViewModel = AssetsViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isLaunchComplete = false
    @State private var networkErrorMessage: String?
    @State private var blockedLaunchMessage: String?
    @State private var blockedLaunchAllowsRetry = false
    @State private var launchAttempt = 0
    
    private let userId = AppUser.id
    
    var body: some View {
        Group {
            if isLaunchComplete {
                ContentView()
                    .environmentObject(portfolioViewModel)
                    .environmentObject(accountsViewModel)
                    .environmentObject(assetsViewModel)
                    .environmentObject(themeManager)
                    .environmentObject(LaunchSessionState.shared)
                    .transition(.opacity)
            } else {
                LaunchSplashView(
                    networkErrorMessage: networkErrorMessage,
                    blockedMessage: blockedLaunchMessage,
                    blockedAllowsRetry: blockedLaunchAllowsRetry,
                    onRetryLaunch: retryLaunch,
                    onExitApp: exitApplication
                )
                .id(launchAttempt)
                .transition(.opacity)
            }
        }
        .id(themeManager.appearanceRefreshToken)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.35), value: isLaunchComplete)
        .animation(.easeInOut(duration: 0.28), value: themeManager.isDarkMode)
        .animation(.easeInOut(duration: 0.22), value: themeManager.isRedUpGreenDown)
        .task(id: launchAttempt) {
            await runLaunchSequence()
        }
    }
    
    private func runLaunchSequence() async {
        networkErrorMessage = nil
        blockedLaunchMessage = nil
        blockedLaunchAllowsRetry = false
        LaunchSessionState.shared.clearStartupNotice()
        
        let splashStarted = ContinuousClock.now
        
        guard await NetworkConnectivity.isConnected() else {
            networkErrorMessage = """
            Snapvest 需要網路才能同步股價與資料。
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
        
        let elapsed = ContinuousClock.now - splashStarted
        if elapsed < LaunchSplashTiming.minimumDuration {
            try? await Task.sleep(for: LaunchSplashTiming.minimumDuration - elapsed)
        }
        
        try? await Task.sleep(for: LaunchSplashTiming.preTransitionHold)
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
