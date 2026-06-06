//
//  AppTabTopChrome.swift
//  Snapvest
//
//  Tab 頂部：啟動提示／合規橫幅 + 自訂 header（避免與內容重疊）
//

import SwiftUI

struct AppTabTopChrome<Header: View>: View {
    @ViewBuilder var header: () -> Header

    @EnvironmentObject private var launchSessionState: LaunchSessionState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @Environment(\.openPlusPaywall) private var openPlusPaywall

    private var complianceSnapshot: PortfolioLimitSnapshot {
        SubscriptionComplianceState.snapshot(
            accounts: accountsViewModel.accounts,
            holdings: assetsViewModel.aggregatedHoldings
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header()

            if let notice = launchSessionState.startupNotice {
                StartupNoticeBanner(message: notice) {
                    launchSessionState.clearStartupNotice()
                }
            }

            if !PlusFeatureGate.shouldBypassLimits(isPlusActive: subscriptionManager.isPlusActive),
               complianceSnapshot.isOverFreeHoldingLimits {
                SubscriptionComplianceBanner(snapshot: complianceSnapshot, onShowPaywall: openPlusPaywall)
            }
        }
        .background(Color.mainBackground)
    }
}
