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
    /// 使用者切換到其他 Tab 時發送；userInfo["tabIndex"] = Int
    static let tabResigned = Notification.Name("tabResigned")
}

enum TabResignUserInfoKey {
    static let tabIndex = "tabIndex"
}

enum AppTab: Int {
    case home = 0
    case accounts = 1
    case assets = 2
    case transactions = 3
}
