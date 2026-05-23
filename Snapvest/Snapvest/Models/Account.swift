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
    /// 債務帳戶還清後封存：自列表隱藏，交易紀錄保留
    var isArchived: Bool
    var archivedAt: Date?
    
    // 為了向後兼容，保留 type 屬性（從 accountType 計算）
    var type: AssetType {
        accountType.assetType
    }
    
    enum CodingKeys: String, CodingKey {
        case id, userId, name, accountType, currency, createdAt, updatedAt
        case isArchived, archivedAt
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         accountType: AccountType,
         currency: Currency? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         isArchived: Bool = false,
         archivedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.accountType = accountType
        self.currency = currency ?? accountType.defaultCurrency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        currency = try container.decode(Currency.self, forKey: .currency)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
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
        self.isArchived = false
        self.archivedAt = nil
    }
}
