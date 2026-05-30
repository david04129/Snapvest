//
//  Price.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct Price: Identifiable, Codable {
    let id: String
    var assetType: AssetType
    var symbol: String
    var price: Decimal
    var currency: Currency
    var priceDate: Date
    var source: String?
    var createdAt: Date
    
    nonisolated init(id: String = UUID().uuidString,
                     assetType: AssetType,
                     symbol: String,
                     price: Decimal,
                     currency: Currency,
                     priceDate: Date,
                     source: String? = nil,
                     createdAt: Date = Date()) {
        self.id = id
        self.assetType = assetType
        self.symbol = symbol
        self.price = price
        self.currency = currency
        self.priceDate = priceDate
        self.source = source
        self.createdAt = createdAt
    }
}

