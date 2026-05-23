//
//  SnapvestTests.swift
//  SnapvestTests
//

import Foundation
import Testing
@testable import Snapvest

struct OtherDebtCalculatorTests {
    
    private let cashAccountId = "cash-1"
    private let otherDebtAccountId = "other-debt-1"
    private let userId = "user-1"
    
    private var cashAccount: Account {
        Account(id: cashAccountId, userId: userId, name: "台幣活存", accountType: .twdDeposit)
    }
    
    private var otherDebtAccount: Account {
        Account(id: otherDebtAccountId, userId: userId, name: "欠朋友", accountType: .otherDebt)
    }
    
    @Test func remainingBalance_initialLiabilityOnly() {
        let accounts = [cashAccount, otherDebtAccount]
        let transactions = [
            makeLiability(accountId: otherDebtAccountId, amount: 30_000)
        ]
        
        let remaining = OtherDebtCalculator.remainingBalance(
            accountId: otherDebtAccountId,
            transactions: transactions,
            accounts: accounts
        )
        
        #expect(remaining == 30_000)
    }
    
    @Test func remainingBalance_afterRepayment() {
        let accounts = [cashAccount, otherDebtAccount]
        let transactions = [
            makeLiability(accountId: otherDebtAccountId, amount: 30_000),
            makeRepayment(from: cashAccountId, to: otherDebtAccountId, amount: 10_000)
        ]
        
        let remaining = OtherDebtCalculator.remainingBalance(
            accountId: otherDebtAccountId,
            transactions: transactions,
            accounts: accounts
        )
        
        #expect(remaining == 20_000)
    }
    
    @Test func totalDebtCalculator_sumsLiabilityAndOtherDebt() {
        let debtAccount = Account(id: "debt-1", userId: userId, name: "房貸", accountType: .debt)
        let accounts = [cashAccount, debtAccount, otherDebtAccount]
        
        let liability = Liability(
            accountId: cashAccountId,
            name: "房貸",
            principal: 50_000,
            interestRate: 2,
            monthlyPayment: 1_000,
            remainingBalance: 50_000,
            currency: .TWD,
            startDate: Date(),
            totalPeriods: 60
        )
        
        let transactions = [
            makeLiability(accountId: otherDebtAccountId, amount: 30_000)
        ]
        
        let total = TotalDebtCalculator.totalLiabilitiesTWD(
            accounts: accounts,
            liabilities: [liability],
            transactions: transactions,
            usdToTwdRate: 32
        )
        
        #expect(total == 80_000)
    }
    
    @Test func totalDebtCalculator_excludesArchivedOtherDebt() {
        var archived = otherDebtAccount
        archived.isArchived = true
        
        let accounts = [cashAccount, archived]
        let transactions = [
            makeLiability(accountId: otherDebtAccountId, amount: 30_000)
        ]
        
        let total = TotalDebtCalculator.totalLiabilitiesTWD(
            accounts: accounts,
            liabilities: [],
            transactions: transactions,
            usdToTwdRate: 32
        )
        
        #expect(total == 0)
    }
    
    private func makeLiability(accountId: String, amount: Decimal) -> Transaction {
        Transaction(
            accountId: accountId,
            type: .liability,
            assetType: .cash,
            symbol: "DEBT",
            quantity: 1,
            price: amount,
            currency: .TWD,
            notes: "新增其他債務"
        )
    }
    
    private func makeRepayment(from sourceId: String, to targetId: String, amount: Decimal) -> Transaction {
        Transaction(
            accountId: sourceId,
            type: .repayment,
            assetType: .cash,
            symbol: "REPAY",
            quantity: 1,
            price: amount,
            currency: .TWD,
            notes: "還款至 欠朋友",
            targetAccountId: targetId,
            principalAmount: amount
        )
    }
}
