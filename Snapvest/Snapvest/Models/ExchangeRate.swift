//
//  ExchangeRate.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct ExchangeRate: Identifiable, Codable {
    let id: String
    var fromCurrency: Currency
    var toCurrency: Currency
    var rate: Decimal
    var rateDate: Date
    var source: String?
    var createdAt: Date
    
    init(id: String = UUID().uuidString,
         fromCurrency: Currency,
         toCurrency: Currency,
         rate: Decimal,
         rateDate: Date,
         source: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
        self.rateDate = rateDate
        self.source = source
        self.createdAt = createdAt
    }
}

