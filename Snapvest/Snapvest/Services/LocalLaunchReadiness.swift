//
//  LocalLaunchReadiness.swift
//  Snapvest
//
//  判斷冷啟動是否可僅靠本機 B 進入 App。
//

import Foundation

enum LocalLaunchReadiness {
    /// 全新使用者或已有可用估值快照 → 可進 App
    static func canEnterApp(userId: String) -> Bool {
        guard let saved = LocalUserDataStore.load(userId: userId) else {
            return true
        }
        
        let accounts = saved.structure.accounts.filter { !$0.isArchived }
        if accounts.isEmpty {
            return true
        }
        
        return hasValuationSnapshot(saved.valuation)
    }
    
    static func hasValuationSnapshot(userId: String) -> Bool {
        guard let saved = LocalUserDataStore.load(userId: userId) else {
            return false
        }
        return hasValuationSnapshot(saved.valuation)
    }
    
    private static func hasValuationSnapshot(_ valuation: LocalUserValuationStore) -> Bool {
        if valuation.homeDashboardSnapshot != nil {
            return true
        }
        if !valuation.accountSnapshotsByAccountId.isEmpty {
            return true
        }
        return !valuation.aggregatedHoldingSnapshots.isEmpty
    }
}
