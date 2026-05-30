//
//  AppNotifications.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

extension Notification.Name {
    static let snapshotsDidUpdate = Notification.Name("snapshotsDidUpdate")
    /// 交易新增／更新／刪除後（首頁已實現損益明細等需重讀交易列表）
    static let transactionsDidChange = Notification.Name("transactionsDidChange")
    /// 交易 mutation 後正在重建快照與套用畫面資料。
    static let portfolioMutationRefreshBegan = Notification.Name("portfolioMutationRefreshBegan")
    static let portfolioMutationRefreshEnded = Notification.Name("portfolioMutationRefreshEnded")
    /// 使用者切換到其他 Tab 時發送；userInfo["tabIndex"] = Int
    static let tabResigned = Notification.Name("tabResigned")
}

enum TabResignUserInfoKey {
    static let tabIndex = "tabIndex"
}

enum PortfolioMutationUserInfoKey {
    static let showsLoadingOverlay = "showsLoadingOverlay"
    static let affectedAccountIds = "affectedAccountIds"
}

enum AppTab: Int {
    case home = 0
    case accounts = 1
    case assets = 2
    case transactions = 3
}

enum DebugPerformanceLog {
    #if DEBUG
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "PerfLogsEnabled")
    }
    #else
    static var isEnabled: Bool { false }
    #endif

    static func now() -> TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }

    static func start(_ flow: String) {
        #if DEBUG
        guard isEnabled else { return }
        print("[Perf][\(flow)] start")
        #endif
    }

    static func lap(_ label: String, flow: String, start: TimeInterval, last: inout TimeInterval) {
        let current = now()
        #if DEBUG
        guard isEnabled else {
            last = current
            return
        }
        let delta = Int((current - last) * 1000)
        let total = Int((current - start) * 1000)
        print("[Perf][\(flow)] \(label): +\(delta)ms total=\(total)ms")
        #endif
        last = current
    }

    static func end(_ flow: String, start: TimeInterval) {
        #if DEBUG
        guard isEnabled else { return }
        let total = Int((now() - start) * 1000)
        print("[Perf][\(flow)] end total=\(total)ms")
        #endif
    }
}
