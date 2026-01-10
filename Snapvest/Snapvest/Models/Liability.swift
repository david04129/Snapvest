//
//  Liability.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation

struct Liability: Identifiable, Codable {
    let id: String
    var accountId: String
    var name: String
    var principal: Decimal
    var interestRate: Decimal
    var monthlyPayment: Decimal
    var remainingBalance: Decimal
    var currency: Currency
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var totalPeriods: Int  // 總期數
    var paidPeriods: Int  // 已還期數
    var totalPaidPrincipal: Decimal  // 已還款本金（累加所有還款交易的本金部分）
    var totalPaidInterest: Decimal  // 已支出利息（累加所有還款交易的利息部分）
    var totalSavedInterest: Decimal  // 總共節省利息（累加所有提前還款的節省利息）
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String = UUID().uuidString,
         accountId: String,
         name: String,
         principal: Decimal,
         interestRate: Decimal,
         monthlyPayment: Decimal,
         remainingBalance: Decimal,
         currency: Currency,
         startDate: Date,
         endDate: Date? = nil,
         notes: String? = nil,
         totalPeriods: Int = 0,
         paidPeriods: Int = 0,
         totalPaidPrincipal: Decimal = 0,
         totalPaidInterest: Decimal = 0,
         totalSavedInterest: Decimal = 0,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.principal = principal
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.remainingBalance = remainingBalance
        self.currency = currency
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.totalPeriods = totalPeriods
        self.paidPeriods = paidPeriods
        self.totalPaidPrincipal = totalPaidPrincipal
        self.totalPaidInterest = totalPaidInterest
        self.totalSavedInterest = totalSavedInterest
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - 計算屬性
    
    /// 計算總還款金額（含利息）
    var totalAmount: Decimal {
        monthlyPayment * Decimal(totalPeriods)
    }
    
    /// 計算總利息
    var totalInterest: Decimal {
        totalAmount - principal
    }
    
    /// 計算剩餘應還總額（剩餘本息總額）
    /// 根據實際剩餘本金和等額本息還款公式計算未來應還總額
    var remainingTotalAmount: Decimal {
        // 如果剩餘本金為0，返回0
        guard remainingBalance > 0 else { return 0 }
        
        // 如果沒有設定每月還款額，返回剩餘本金
        guard monthlyPayment > 0 else {
            return remainingBalance
        }
        
        // 計算剩餘期數
        let remainingPeriods = totalPeriods - paidPeriods
        
        // 如果剩餘期數為0，返回0
        guard remainingPeriods > 0 else { return 0 }
        
        // 如果剩餘期數等於總期數且剩餘本金等於原始本金（初始狀態，還沒還款）
        // 則剩餘應還總額 = 總還款金額（使用總還款金額）
        if remainingPeriods == totalPeriods && remainingBalance == principal {
            return totalAmount
        }
        
        // 如果月利率為0或接近0，無息貸款
        let monthlyRateValue = monthlyRate
        guard monthlyRateValue > 0.0001 else {
            // 無息：剩餘應還總額 = 每月還款額 × 剩餘期數
            return monthlyPayment * Decimal(remainingPeriods)
        }
        
        // 如果剩餘本金小於每月還款額，只需要還一期（加上利息）
        if remainingBalance <= monthlyPayment {
            return remainingBalance * (1 + monthlyRateValue)
        }
        
        // 對於提前還款的情況，使用等額本息還款公式重新計算剩餘應還總額
        // 根據剩餘本金和剩餘期數，重新計算每月還款額，然後乘以剩餘期數
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRateValue)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        let power = onePlusRate.raising(toPower: remainingPeriods)
        let balanceNS = NSDecimalNumber(decimal: remainingBalance)
        
        // 使用等額本息公式計算：每月還款額 = 剩餘本金 * (月利率 * (1+月利率)^n) / ((1+月利率)^n - 1)
        let numerator = balanceNS.multiplying(by: monthlyRateNS).multiplying(by: power)
        let denominator = power.subtracting(NSDecimalNumber.one)
        let adjustedMonthlyPayment = numerator.dividing(by: denominator).decimalValue
        
        // 剩餘應還總額 = 調整後的每月還款額 × 剩餘期數
        return adjustedMonthlyPayment * Decimal(remainingPeriods)
    }
    
    /// 計算月利率
    var monthlyRate: Decimal {
        interestRate / 100 / 12
    }
}

