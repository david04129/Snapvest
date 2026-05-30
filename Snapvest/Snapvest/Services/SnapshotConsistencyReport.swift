//
//  SnapshotConsistencyReport.swift
//  Snapvest
//
//  DEBUG-only helper models for comparing persisted snapshots with a full rebuild.
//

import Foundation

struct SnapshotConsistencyReport: Equatable {
    let checkedAt: Date
    let mismatches: [SnapshotConsistencyMismatch]

    var isConsistent: Bool {
        mismatches.isEmpty
    }

    var summary: String {
        if isConsistent {
            return "快照一致：局部更新結果與全量重算一致。"
        }
        return "發現 \(mismatches.count) 個差異，請查看 Xcode Console 的 [SnapshotConsistency] 明細。"
    }
}

struct SnapshotConsistencyMismatch: Equatable {
    let scope: String
    let field: String
    let current: String
    let rebuilt: String

    var description: String {
        "[\(scope)] \(field): current=\(current), rebuilt=\(rebuilt)"
    }
}
