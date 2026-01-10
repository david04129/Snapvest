//
//  Account.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    var name: String
    var accountType: AccountType  // 使用新的 AccountType
    var currency: Currency
    var createdAt: Date
    var updatedAt: Date
    
    // 為了向後兼容，保留 type 屬性（從 accountType 計算）
    var type: AssetType {
        accountType.assetType
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         accountType: AccountType,
         currency: Currency? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        self.accountType = accountType
        self.currency = currency ?? accountType.defaultCurrency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 為了向後兼容，保留舊的初始化方法
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         type: AssetType,
         currency: Currency = .TWD,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        // 根據 AssetType 推斷 AccountType
        switch type {
        case .cash:
            self.accountType = .twdDeposit
        case .stockTW:
            self.accountType = .twdSecurities
        case .stockUS:
            self.accountType = .usdAccount
        case .crypto:
            self.accountType = .cryptoWallet
        }
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

