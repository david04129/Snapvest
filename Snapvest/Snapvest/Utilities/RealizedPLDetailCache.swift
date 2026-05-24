//
//  RealizedPLDetailCache.swift
//  Snapvest
//
//  已實現損益明細：展開時才載入，避免首頁每次 appear 全量拉交易。
//

import Foundation

@MainActor
enum RealizedPLDetailCache {
    private(set) static var sellTransactions: [Transaction] = []
    private static var cachedUserId: String?

    static func isLoaded(for userId: String) -> Bool {
        cachedUserId == userId
    }

    static func apply(userId: String, transactions: [Transaction]) {
        cachedUserId = userId
        sellTransactions = transactions.filter { $0.type == .sell }
    }

    static func invalidate() {
        cachedUserId = nil
        sellTransactions = []
    }
}
