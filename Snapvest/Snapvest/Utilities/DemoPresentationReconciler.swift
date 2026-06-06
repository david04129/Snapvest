//
//  DemoPresentationReconciler.swift
//  Snapvest
//
//  示範模式：離線走勢模板 × rebuild 首頁快照（不拉歷史股價）。
//

import Foundation

enum DemoPresentationReconciler {
    @MainActor
    static func reconcile(userId: String, dataService: MockDataService) async {
        guard dataService.isDemoModeActive,
              let home = try? await dataService.fetchHomeDashboardSnapshot(userId: userId),
              home.netWorth > 0,
              home.totalAssets > 0 else {
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        let unrealized = home.totalInvestments - home.totalInvestmentsCost
        let shape = DemoTrendTemplate.shapePoints()

        for (index, point) in shape.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: index - (DemoTrendTemplate.dayCount - 1), to: today) else {
                continue
            }

            let netWorth = home.netWorth * decimalRatio(point.netWorthRatio)
            let liabilities = home.totalLiabilities * decimalRatio(point.liabilityRatio)
            // 總資產 = 淨資產 + 負債，與首頁卡片一致，避免今日點與昨日脫鉤。
            let totalAssets = netWorth + liabilities

            let snap = LocalDailyTrendSnapshot(
                userId: userId,
                date: date,
                totalAssets: totalAssets,
                netWorth: netWorth,
                unrealizedGainLoss: unrealized * decimalRatio(point.unrealizedRatio),
                sourceHomeSnapshotUpdatedAt: home.lastUpdated,
                recordedAt: now
            )
            try? await dataService.upsertLocalDailyTrendSnapshot(snap)
        }
    }

    private static func decimalRatio(_ value: Double) -> Decimal {
        Decimal(string: String(format: "%.8f", value), locale: Locale(identifier: "en_US_POSIX")) ?? 1
    }
}
