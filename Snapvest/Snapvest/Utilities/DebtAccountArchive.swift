//
//  DebtAccountArchive.swift
//  Snapvest
//
//  已還清債務帳戶封存（保留交易紀錄，自列表隱藏）
//

import Foundation

enum DebtAccountArchive {
    /// 剩餘本金低於此值視為已還清（TWD / 原幣同值）
    static let balanceTolerance: Decimal = 1
    
    static func canArchive(debtAccount: Account, liability: Liability?) -> (allowed: Bool, reason: String?) {
        guard debtAccount.accountType == .debt else {
            return (false, "僅債務帳戶可封存")
        }
        guard !debtAccount.isArchived else {
            return (false, "此帳戶已封存")
        }
        guard let liability else {
            return (false, "找不到對應的債務資料")
        }
        guard liability.remainingBalance <= balanceTolerance else {
            return (false, "剩餘本金須歸零後才能封存")
        }
        return (true, nil)
    }
    
    static func liability(forDebtAccount debtAccount: Account, in liabilities: [Liability]) -> Liability? {
        liabilities.first { $0.name == debtAccount.name }
    }
    
    static func isDebtAccountArchived(named liabilityName: String, accounts: [Account]) -> Bool {
        accounts.contains {
            $0.accountType == .debt && $0.name == liabilityName && $0.isArchived
        }
    }
}

extension Account {
    var isActiveForListing: Bool {
        if accountType.isLiabilityAccount {
            return !isArchived
        }
        return true
    }
}

extension Array where Element == Account {
    func activeAccounts(ofType type: AccountType) -> [Account] {
        filter { $0.accountType == type && $0.isActiveForListing }
    }
    
    var archivedDebtAccounts: [Account] {
        filter { $0.accountType.isLiabilityAccount && $0.isArchived }
    }
}
