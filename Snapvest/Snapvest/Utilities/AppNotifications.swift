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
