//
//  TransactionsViewModel.swift
//  Snapvest
//
//  Created on 2024
//

import Foundation
import Combine

@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }
    
    func loadTransactions(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var allTransactions = try await dataService.fetchAllTransactions(userId: userId)
            // 按日期排序，最新的在最上面
            allTransactions.sort { $0.transactionDate > $1.transactionDate }
            transactions = allTransactions
            accounts = try await dataService.fetchAccounts(userId: userId)
        } catch {
            errorMessage = "載入交易失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createTransaction(_ transaction: Transaction) async {
        do {
            try await dataService.createTransaction(transaction)
            // 重新計算持股
            await updateHoldings(accountId: transaction.accountId)
            await loadTransactions(userId: accounts.first?.userId ?? "")
        } catch {
            errorMessage = "建立交易失敗：\(error.localizedDescription)"
        }
    }
    
    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await dataService.updateTransaction(transaction)
            await updateHoldings(accountId: transaction.accountId)
            await loadTransactions(userId: accounts.first?.userId ?? "")
        } catch {
            errorMessage = "更新交易失敗：\(error.localizedDescription)"
        }
    }
    
    func deleteTransaction(_ transactionId: String) async {
        do {
            // 先獲取交易資訊以找到 accountId
            guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
                return
            }
            
            let userId = accounts.first?.userId ?? "test-user-id"
            
            // 檢查是否為還款或轉帳交易（還款使用轉帳的邏輯）
            let isRepayment = (transaction.notes?.contains("還款至") ?? false) || 
                             (transaction.notes?.contains("還款自") ?? false)
            
            // 如果是轉帳或還款交易，使用相同的邏輯處理
            if transaction.type == .transfer || transaction.type == .repayment || isTransferTransaction(transaction) || isRepayment {
                // 現在轉帳/還款只記錄在一筆交易中，只需要刪除這筆交易
                // 但如果是還款交易，需要恢復債務的剩餘本金
                if transaction.type == .repayment || isRepayment {
                    // 如果是還款交易，需要恢復債務的剩餘本金
                    if let targetAccountId = transaction.targetAccountId,
                       let targetAccount = try? await dataService.fetchAccounts(userId: userId).first(where: { $0.id == targetAccountId }),
                       targetAccount.accountType == .debt {
                        // 找到對應的債務
                        let repaymentAccountId = transaction.accountId // 還款帳戶的 ID
                        let liabilities = try await dataService.fetchLiabilities(accountId: repaymentAccountId)
                        
                        if let liability = liabilities.first(where: { $0.name == targetAccount.name }) {
                            // 從交易的備註中提取本金和利息
                            var principalPortion: Decimal = 0
                            var interestPortion: Decimal = 0
                            var receivedAmount: Decimal = 0
                            
                            if let notes = transaction.notes {
                                // 備註格式：自A還款到B 本金償還$31.25，利息償還$1.25
                                // 或者：備註 - 自A還款到B (匯率: 32.00) 本金償還$31.25，利息償還$1.25
                                
                                // 提取本金
                                if let principalRange = notes.range(of: "本金償還") {
                                    let principalString = String(notes[principalRange.upperBound...])
                                    var endIndex = principalString.endIndex
                                    if let commaRange = principalString.range(of: "，") {
                                        endIndex = commaRange.lowerBound
                                    }
                                    let principalValue = String(principalString[..<endIndex])
                                        .replacingOccurrences(of: ",", with: "")
                                        .replacingOccurrences(of: targetAccount.currency.symbol, with: "")
                                        .replacingOccurrences(of: "$", with: "")
                                        .replacingOccurrences(of: "NT$", with: "")
                                        .replacingOccurrences(of: "TWD", with: "")
                                        .replacingOccurrences(of: "USD", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                    if let principal = Decimal(string: principalValue) {
                                        principalPortion = principal
                                    }
                                }
                                
                                // 提取利息
                                if let interestRange = notes.range(of: "利息償還") {
                                    let interestString = String(notes[interestRange.upperBound...])
                                    let interestValue = interestString
                                        .replacingOccurrences(of: ",", with: "")
                                        .replacingOccurrences(of: targetAccount.currency.symbol, with: "")
                                        .replacingOccurrences(of: "$", with: "")
                                        .replacingOccurrences(of: "NT$", with: "")
                                        .replacingOccurrences(of: "TWD", with: "")
                                        .replacingOccurrences(of: "USD", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                    if let interest = Decimal(string: interestValue) {
                                        interestPortion = interest
                                    }
                                }
                                
                                // 計算總還款金額（本金 + 利息）
                                receivedAmount = principalPortion + interestPortion
                            }
                            
                            // 如果無法從備註中提取，則使用交易金額（可能不準確，因為跨幣別轉帳）
                            if receivedAmount == 0 {
                                // 嘗試從備註中解析匯率並計算
                                if let notes = transaction.notes,
                                   let rateRange = notes.range(of: "匯率: ") {
                                    let rateString = String(notes[rateRange.upperBound...])
                                    if let rateEnd = rateString.firstIndex(of: ")") {
                                        let rateValue = String(rateString[..<rateEnd]).trimmingCharacters(in: .whitespaces)
                                        if let rate = Decimal(string: rateValue), rate > 0 {
                                            // 匯率是 1 USD = rate TWD
                                            // transaction.currency 是源帳戶貨幣，targetAccount.currency 是目標帳戶貨幣
                                            if transaction.currency == .TWD && targetAccount.currency == .USD {
                                                receivedAmount = transaction.totalAmount / rate
                                            } else if transaction.currency == .USD && targetAccount.currency == .TWD {
                                                receivedAmount = transaction.totalAmount * rate
                                            } else {
                                                receivedAmount = transaction.totalAmount
                                            }
                                        }
                                    }
                                }
                                
                                // 如果還是無法獲取，使用交易金額（同幣別情況）
                                if receivedAmount == 0 {
                                    receivedAmount = transaction.totalAmount
                                }
                                
                                // 如果無法提取本金，使用計算方法
                                if principalPortion == 0 {
                                    // 計算利息：當月利息 = 剩餘本金 × 月利率
                                    // 但由於我們已經恢復了本金，我們需要使用恢復前的剩餘本金
                                    // 實際上，我們可以使用當前的剩餘本金 + 本金部分來計算
                                    let monthlyRate = liability.monthlyRate
                                    // 恢復前的剩餘本金 = 當前剩餘本金 + 本金部分
                                    // 但我們還沒有恢復，所以使用當前剩餘本金
                                    // 這可能不準確，但比沒有恢復好
                                    if interestPortion == 0 {
                                        interestPortion = liability.remainingBalance * monthlyRate
                                    }
                                    principalPortion = receivedAmount - interestPortion
                                    if principalPortion < 0 {
                                        principalPortion = receivedAmount
                                        interestPortion = 0
                                    }
                                }
                            }
                            
                            // 恢復債務的剩餘本金和已還期數
                            var updatedLiability = liability
                            updatedLiability.remainingBalance += principalPortion
                            
                            // 恢復已還期數：如果還款金額 >= 每月應繳金額，則減少1期
                            // 注意：我們需要檢查恢復前的還款金額（receivedAmount），而不是本金部分
                            if receivedAmount >= liability.monthlyPayment && updatedLiability.paidPeriods > 0 {
                                updatedLiability.paidPeriods -= 1
                            }
                            
                            updatedLiability.updatedAt = Date()
                            try await dataService.updateLiability(updatedLiability)
                        }
                    }
                }
                
                // 刪除交易
                try await dataService.deleteTransaction(transactionId)
                
                // 更新兩個帳戶的持股
                await updateHoldings(accountId: transaction.accountId)
                if let targetAccountId = transaction.targetAccountId {
                    await updateHoldings(accountId: targetAccountId)
                }
            }
            // 如果是債務交易，需要同時刪除對應的債務、債務帳戶和交易記錄
            else if transaction.type == .liability {
                // transaction.accountId 是債務帳戶的 ID
                let debtAccountId = transaction.accountId
                
                // 1. 先找到債務帳戶，獲取債務名稱
                let allAccounts = try await dataService.fetchAccounts(userId: userId)
                guard let debtAccount = allAccounts.first(where: { $0.id == debtAccountId && $0.accountType == .debt }) else {
                    // 如果找不到債務帳戶，只刪除交易記錄
                    try await dataService.deleteTransaction(transactionId)
                    await loadTransactions(userId: userId)
                    return
                }
                
                let liabilityName = debtAccount.name
                
                // 2. 找到對應的 Liability 記錄（需要遍歷所有還款帳戶的 Liability 記錄）
                // Liability 的 accountId 是還款帳戶的 ID，name 是債務名稱
                var foundLiability: Liability? = nil
                for account in allAccounts {
                    if account.accountType != .debt {
                        let accountLiabilities = try await dataService.fetchLiabilities(accountId: account.id)
                        if let liability = accountLiabilities.first(where: { $0.name == liabilityName }) {
                            foundLiability = liability
                            break
                        }
                    }
                }
                
                // 3. 先刪除交易記錄（在刪除帳戶之前）
                try await dataService.deleteTransaction(transactionId)
                
                // 4. 如果找到 Liability 記錄，刪除它
                if let liability = foundLiability {
                    try await dataService.deleteLiability(liability.id)
                }
                
                // 5. 最後刪除債務帳戶（這會自動刪除該帳戶的所有交易和持股）
                // 注意：雖然我們已經手動刪除了交易記錄，但 deleteAccount 也會刪除該帳戶的所有交易
                // 這樣可以確保數據一致性，即使某些交易沒有被手動刪除
                try await dataService.deleteAccount(debtAccountId)
            } else {
                // 普通交易：只刪除一筆
                try await dataService.deleteTransaction(transactionId)
                await updateHoldings(accountId: transaction.accountId)
            }
            
            // 重新載入交易以確保數據一致性（這會更新本地數組）
            await loadTransactions(userId: userId)
        } catch {
            errorMessage = "刪除交易失敗：\(error.localizedDescription)"
            // 如果刪除失敗，重新載入數據以恢復狀態
            await loadTransactions(userId: accounts.first?.userId ?? "test-user-id")
        }
    }
    
    /// 檢查是否為轉帳交易
    private func isTransferTransaction(_ transaction: Transaction) -> Bool {
        if let notes = transaction.notes {
            return notes.contains("轉帳至") || notes.contains("轉帳自")
        }
        return false
    }
    
    /// 從轉帳交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromTransferNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "轉帳至 " : "轉帳自 "
        
        if let range = notes.range(of: prefix) {
            let afterPrefix = String(notes[range.upperBound...])
            // 移除可能的匯率部分和備註部分
            var accountName = afterPrefix
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取後面的部分
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[dashRange.upperBound...])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    /// 從還款交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromRepaymentNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "還款至 " : "還款自 "
        
        if let range = notes.range(of: prefix) {
            let afterPrefix = String(notes[range.upperBound...])
            // 移除可能的匯率部分和備註部分
            var accountName = afterPrefix
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱在備註之前）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    /// 更新持股（根據交易記錄重播）
    private func updateHoldings(accountId: String) async {
        do {
            // 1. 獲取該帳戶的所有交易
            let accountTransactions = try await dataService.fetchTransactions(accountId: accountId)
            
            // 2. 計算新的持股
            let calculatedHoldings = HoldingCalculator.calculateHoldings(from: accountTransactions)
            
            // 3. 更新或建立持股
            let existingHoldings = try await dataService.fetchHoldings(accountId: accountId)
            
            // 刪除不存在的持股
            for existing in existingHoldings {
                let stillExists = calculatedHoldings.contains { $0.symbol == existing.symbol && $0.assetType == existing.assetType }
                if !stillExists {
                    try await dataService.deleteHolding(existing.id)
                }
            }
            
            // 更新或建立持股
            for calculated in calculatedHoldings {
                if let existing = existingHoldings.first(where: { $0.symbol == calculated.symbol && $0.assetType == calculated.assetType }) {
                    var updated = existing
                    updated.quantity = calculated.quantity
                    updated.averageCost = calculated.averageCost
                    try await dataService.updateHolding(updated)
                } else {
                    try await dataService.updateHolding(calculated)
                }
            }
        } catch {
            errorMessage = "更新持股失敗：\(error.localizedDescription)"
        }
    }
}

