//
//  EditFormChangeTracking.swift
//  Snapvest
//
//  編輯表單：比對進場快照，僅在有改動時允許「確認修改」。
//

import Foundation

enum EditFormChangeTracking {
    static func normalizedNote(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func datesEqual(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .minute)
    }

    static func decimalStringsEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let l = Decimal(string: left), let r = Decimal(string: right) else {
            return left == right
        }
        return l == r
    }
}

struct CashTransactionEditBaseline: Equatable {
    let amountText: String
    let notes: String
    let date: Date
}

struct BuyTradeEditBaseline: Equatable {
    let accountId: String
    let symbol: String
    let quantityText: String
    let priceText: String
    let exchangeRateText: String
    let date: Date
    let deductFromAccount: Bool
}

struct SellTradeEditBaseline: Equatable {
    let accountId: String
    let quantityText: String
    let priceText: String
    let exchangeRateText: String
    let date: Date
}

struct RepaymentEditBaseline: Equatable {
    let amountText: String
    let notes: String
    let date: Date
    let deductFromTWDAccount: Bool
    let sourceAccountId: String?
}

struct GenericTransactionEditBaseline: Equatable {
    let amountText: String
    let quantityText: String
    let priceText: String
    let feeText: String
    let notes: String
    let date: Date
}

struct ManualAssetValueEditBaseline: Equatable {
    let valueText: String
    let notes: String
    let date: Date
}
