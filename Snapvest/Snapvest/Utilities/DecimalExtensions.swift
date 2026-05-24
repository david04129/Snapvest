//
//  DecimalExtensions.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

extension Decimal {
    /// 格式化為貨幣字串
    /// - Parameters:
    ///   - currency: 貨幣類型
    ///   - fractionDigits: 小數位數（台幣預設為0＝整數現金；>0 時用於股價等，截斷不四捨五入、去尾 0）
    ///   - showSymbol: 是否顯示貨幣符號（台幣不顯示NT，美金顯示$）
    func formatted(currency: Currency, fractionDigits: Int? = nil, showSymbol: Bool = true) -> String {
        if currency == .TWD {
            let digits = fractionDigits ?? 0
            if digits > 0 {
                return formattedFlexibleDecimal(maxFractionDigits: digits, showGrouping: true)
            }
            return formattedTWInteger(showGrouping: true)
        }
        
        let formatter = NumberFormatter()
        let number = NSDecimalNumber(decimal: self)
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency == .USD ? "$" : currency.symbol
        let digits = fractionDigits ?? 2
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: number) ?? "$0.00"
    }
    
    /// 股價／成交價：保留有效小數、截斷不四捨五入、去掉尾端 0
    func formattedTradePrice(currency: Currency, maxFractionDigits: Int = 4) -> String {
        switch currency {
        case .TWD:
            return formattedFlexibleDecimal(maxFractionDigits: maxFractionDigits, showGrouping: true)
        case .USD:
            if maxFractionDigits > 0 {
                return formattedFlexibleDecimal(maxFractionDigits: maxFractionDigits, showGrouping: true, currencySymbol: "$")
            }
            return formatted(currency: .USD, fractionDigits: 2, showSymbol: true)
        case .EUR, .JPY, .CNY:
            return formatted(currency: currency, fractionDigits: maxFractionDigits, showSymbol: true)
        }
    }
    
    /// 成交金額（與股價相同規則）
    func formattedTradeAmount(currency: Currency, maxFractionDigits: Int = 4) -> String {
        formattedTradePrice(currency: currency, maxFractionDigits: maxFractionDigits)
    }
    
    /// 台幣整數（現金餘額等）
    private func formattedTWInteger(showGrouping: Bool) -> String {
        let formatter = NumberFormatter()
        let number = NSDecimalNumber(decimal: self)
        let isNegative = number.compare(NSDecimalNumber.zero) == .orderedAscending
        let absoluteNumber = isNegative ? number.multiplying(by: NSDecimalNumber(value: -1)) : number
        
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = showGrouping
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "zh_TW")
        
        let formattedValue = formatter.string(from: absoluteNumber) ?? "0"
        return isNegative ? "-\(formattedValue)" : formattedValue
    }
    
    /// 最多 maxFractionDigits 位小數；截斷（不四捨五入）；去掉尾端 0
    private func formattedFlexibleDecimal(
        maxFractionDigits: Int,
        showGrouping: Bool,
        currencySymbol: String? = nil
    ) -> String {
        var value = self
        var truncated = Decimal()
        NSDecimalRound(&truncated, &value, maxFractionDigits, .down)
        
        let formatter = NumberFormatter()
        let number = NSDecimalNumber(decimal: truncated)
        let isNegative = number.compare(NSDecimalNumber.zero) == .orderedAscending
        let absoluteNumber = isNegative ? number.multiplying(by: NSDecimalNumber(value: -1)) : number
        
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = showGrouping
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.roundingMode = .down
        formatter.locale = Locale(identifier: "zh_TW")
        
        let formattedValue = formatter.string(from: absoluteNumber) ?? "0"
        let signed = isNegative ? "-\(formattedValue)" : formattedValue
        guard let currencySymbol, !currencySymbol.isEmpty else { return signed }
        return isNegative ? "-\(currencySymbol)\(formattedValue)" : "\(currencySymbol)\(formattedValue)"
    }
    
    /// 格式化為百分比字串
    func formattedPercent(fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: (self / 100) as NSDecimalNumber) ?? "\(self)%"
    }
    
    /// 格式化為數字字串
    func formatted(fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
    
    /// 表單數量預填：整數不帶小數；有小數則保留（最多 maxFractionDigits 位，去掉尾端 0）
    func formattedQuantityInput(maxFractionDigits: Int = 8) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

