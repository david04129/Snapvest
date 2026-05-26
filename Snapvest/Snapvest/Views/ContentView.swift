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
    @EnvironmentObject private var launchSessionState: LaunchSessionState
    @EnvironmentObject private var dataFreshness: DataFreshnessStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("首頁", systemImage: "house.fill")
                }
                .tag(AppTab.home.rawValue)
            
            AccountsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("帳戶", systemImage: "building.columns.fill")
                }
                .tag(AppTab.accounts.rawValue)
            
            AssetsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("資產", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.assets.rawValue)
            
            TransactionsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("紀錄", systemImage: "clock.fill")
                }
                .tag(AppTab.transactions.rawValue)
        }
        .background(Color.mainBackground)
        .tint(.appPrimary)
        .toolbarBackground(Color.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = launchSessionState.startupNotice {
                StartupNoticeBanner(message: notice) {
                    launchSessionState.clearStartupNotice()
                }
            }
        }
        .id(themeManager.appearanceRefreshToken)
        .onChange(of: selectedTab) { previousTab, newTab in
            if pieGroupingStore.isEditingGroups, newTab != previousTab {
                selectedTab = previousTab
                return
            }
            NotificationCenter.default.post(
                name: .tabResigned,
                object: nil,
                userInfo: [TabResignUserInfoKey.tabIndex: previousTab]
            )
        }
        .onAppear {
            dataFreshness.refresh()
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
