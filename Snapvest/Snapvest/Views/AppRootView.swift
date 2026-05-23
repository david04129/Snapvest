//
//  AppRootView.swift
//  Snapvest
//
//  開機只顯示 Logo；首頁資料 ready 後才建立主畫面（避免半成品首頁閃現）
//

import SwiftUI

struct AppRootView: View {
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isLaunchComplete = false
    
    private let userId = "test-user-id"
    
    var body: some View {
        Group {
            if isLaunchComplete {
                ContentView()
                    .environmentObject(portfolioViewModel)
                    .environmentObject(themeManager)
                    .transition(.opacity)
            } else {
                LaunchSplashView()
                    .transition(.opacity)
            }
        }
        .id(themeManager.appearanceRefreshToken)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.35), value: isLaunchComplete)
        .animation(.easeInOut(duration: 0.28), value: themeManager.isDarkMode)
        .animation(.easeInOut(duration: 0.22), value: themeManager.isRedUpGreenDown)
        .task(id: userId) {
            await runLaunchSequence()
        }
    }
    
    private func runLaunchSequence() async {
        await portfolioViewModel.ensureHomeSnapshot(userId: userId)
        isLaunchComplete = true
    }
}
