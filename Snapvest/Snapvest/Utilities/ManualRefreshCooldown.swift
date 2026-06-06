//
//  ManualRefreshCooldown.swift
//  Snapvest
//
//  下拉刷新最短間隔（僅 App 端，不取代 server 限流）。
//

import Foundation
import Combine

@MainActor
final class ManualRefreshCooldown: ObservableObject {
    static let shared = ManualRefreshCooldown()

    /// 兩次手動刷新之間最短間隔
    static let minimumInterval: TimeInterval = 60

    @Published private(set) var alertMessage: String?

    private var lastRefreshStartedAt: Date?

    private init() {}

    /// 允許時執行 `action` 並記錄開始時間；否則設定 `alertMessage` 且不執行。
    func performIfAllowed(_ action: () async -> Void) async {
        if let seconds = secondsUntilAllowed() {
            alertMessage = "請 \(seconds) 秒後再試"
            return
        }
        lastRefreshStartedAt = Date()
        alertMessage = nil
        await action()
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func showRateLimited(retryAfterSeconds: Int? = nil) {
        if let retryAfterSeconds, retryAfterSeconds > 0 {
            alertMessage = "雲端忙碌，請 \(retryAfterSeconds) 秒後再試"
        } else {
            alertMessage = "雲端忙碌，請稍後再試"
        }
    }

    private func secondsUntilAllowed() -> Int? {
        guard let last = lastRefreshStartedAt else { return nil }
        let remaining = Self.minimumInterval - Date().timeIntervalSince(last)
        guard remaining > 0 else { return nil }
        return Int(ceil(remaining))
    }
}
