//
//  DemoModeManager.swift
//  Snapvest
//
//  記憶體示範模式：計算與一般模式相同（雲端現價、同一 UID），僅不寫入本機；
//  走勢圖用離線模板對齊 rebuild，history 只拉最近 2 天。
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var isSwitching = false

    private init() {}

    func enterDemoMode(userId: String? = nil) async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }

        let resolvedUserId = userId ?? AppUser.id
        let seed = DemoSeedData.make(userId: resolvedUserId)
        MockDataService.shared.beginDemoMode(seed: seed)
        ExchangeRateSessionCache.clear()
        PieChartGroupingStore.shared.applyDemoDefaults()
        DailyPriceHistoryCache.invalidate()

        await SupabaseAuthService.shared.warmUp()

        let holdingSymbols = await PortfolioSymbolCollector.holdingSymbols(
            userId: resolvedUserId,
            dataService: MockDataService.shared
        )
        await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: resolvedUserId,
            dataService: MockDataService.shared,
            trackSymbols: holdingSymbols,
            syncPortfolioPreviousCloses: true,
            updatePriceMetadata: false,
            postsUpdateNotification: false
        )
        await DemoPresentationReconciler.reconcile(
            userId: resolvedUserId,
            dataService: MockDataService.shared
        )

        isEnabled = true
    }

    func exitDemoMode(userId: String? = nil) async {
        guard !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }

        let resolvedUserId = userId ?? AppUser.id
        MockDataService.shared.endDemoMode()
        PieChartGroupingStore.shared.reload(for: resolvedUserId)
        DailyPriceHistoryCache.invalidate()
        ExchangeRateSessionCache.clear()
        isEnabled = false
    }
}
