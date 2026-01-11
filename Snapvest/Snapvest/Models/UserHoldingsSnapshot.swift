//
//  UserHoldingsSnapshot.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

/// 使用者持股快照 - 用於快速知道使用者需要哪些股票價格
struct UserHoldingsSnapshot: Identifiable, Codable, Equatable {
    let userId: String            // 使用者ID（主鍵）
    var symbols: [SymbolInfo]     // 使用者持有的所有股票（唯一列表）
    var lastUpdated: Date         // 快照最後更新時間
    
    var id: String {
        userId
    }
    
    init(
        userId: String,
        symbols: [SymbolInfo] = [],
        lastUpdated: Date = Date()
    ) {
        self.userId = userId
        self.symbols = symbols
        self.lastUpdated = lastUpdated
    }
    
    /// 添加股票符號（自動去重）
    mutating func addSymbol(_ symbol: SymbolInfo) {
        if !symbols.contains(symbol) {
            symbols.append(symbol)
        }
    }
    
    /// 移除股票符號
    mutating func removeSymbol(_ symbol: SymbolInfo) {
        symbols.removeAll { $0 == symbol }
    }
    
    /// 更新符號列表（自動去重）
    mutating func updateSymbols(_ newSymbols: [SymbolInfo]) {
        // 使用 Set 去重
        let uniqueSymbols = Array(Set(newSymbols))
        symbols = uniqueSymbols
    }
}
