//
//  ContentView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var accountsViewId = UUID()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首頁", systemImage: "house.fill")
                }
                .tag(0)
            
            AccountsView()
                .id(accountsViewId)
                .tabItem {
                    Label("帳戶", systemImage: "building.columns.fill")
                }
                .tag(1)
                .onAppear {
                    // 當切換到帳戶 Tab 時，重置視圖 ID 以清除導航狀態
                    accountsViewId = UUID()
                }
            
            AssetsView()
                .tabItem {
                    Label("資產", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            TransactionsView()
                .tabItem {
                    Label("紀錄", systemImage: "clock.fill")
                }
                .tag(3)
        }
        .background(Color.mainBackground)
        .tint(.appPrimary)
    }
}

#Preview {
    ContentView()
}

