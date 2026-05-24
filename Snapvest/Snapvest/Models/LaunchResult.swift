//
//  LaunchResult.swift
//  Snapvest
//
//  冷啟動結果（Phase 3）。
//

import Foundation

enum LaunchResult: Equatable {
    case success
    /// 雲端同步失敗或略過，但本機 B 可用
    case degraded(notice: String)
    /// 無法取得雲端資料且本機 B 不足
    case blocked(message: String, allowsRetry: Bool)
}
