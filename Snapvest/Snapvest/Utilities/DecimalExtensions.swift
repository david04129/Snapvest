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
    ///   - fractionDigits: 小數位數（台幣預設為0，其他貨幣預設為2）
    ///   - showSymbol: 是否顯示貨幣符號（台幣不顯示NT，美金顯示$）
    func formatted(currency: Currency, fractionDigits: Int? = nil, showSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        let number = NSDecimalNumber(decimal: self)
        
        if currency == .TWD {
            // 台幣：只顯示整數，不顯示NT
            // 使用絕對值格式化，確保負數正確顯示
            let isNegative = number.compare(NSDecimalNumber.zero) == .orderedAscending
            let absoluteNumber = isNegative ? number.multiplying(by: NSDecimalNumber(value: -1)) : number
            
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.usesGroupingSeparator = true
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            formatter.locale = Locale(identifier: "zh_TW")
            
            let formattedValue = formatter.string(from: absoluteNumber) ?? "0"
            // 如果是負數，手動添加負號
            return isNegative ? "-\(formattedValue)" : formattedValue
        } else {
            // 美金或其他貨幣：顯示符號
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.rawValue
            formatter.currencySymbol = currency == .USD ? "$" : currency.symbol
            let digits = fractionDigits ?? 2
            formatter.minimumFractionDigits = digits
            formatter.maximumFractionDigits = digits
            return formatter.string(from: number) ?? "$0.00"
        }
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

