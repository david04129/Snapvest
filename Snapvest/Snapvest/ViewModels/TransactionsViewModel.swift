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
            await updateSnapshotsIfNeeded(for: transaction.accountId)
            // 重新計算持股
            await updateHoldings(accountId: transaction.accountId)
            await loadTransactions(userId: accounts.first?.userId ?? "")
        } catch {
            errorMessage = "建立交易失敗：\(error.localizedDescription)"
        }
    }

    func createSellTransaction(
        account: Account,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        exchangeRate: Decimal?,
        transactionDate: Date,
        averageCostFallback: Decimal
    ) async {
        do {
            let costBasis = try await calculateCostBasis(
                userId: account.userId,
                accountId: account.id,
                assetType: assetType,
                symbol: symbol,
                quantity: quantity,
                averageCostFallback: averageCostFallback
            )
            let proceeds = quantity * price
            let realizedGainLoss = proceeds - costBasis
            let realizedGainLossPercent = costBasis > 0 ? (realizedGainLoss / costBasis) * 100 : nil
            let realizedCostPerUnit = quantity > 0 ? costBasis / quantity : nil

            let transaction = Transaction(
                accountId: account.id,
                type: .sell,
                assetType: assetType,
                symbol: symbol,
                quantity: quantity,
                price: price,
                currency: currency,
                fee: 0,
                notes: nil,
                transactionDate: transactionDate,
                exchangeRate: exchangeRate,
                realizedGainLoss: realizedGainLoss,
                realizedGainLossPercent: realizedGainLossPercent,
                realizedCostBasis: costBasis,
                realizedCostPerUnit: realizedCostPerUnit
            )
            
            await createTransaction(transaction)
        } catch {
            errorMessage = "建立賣出交易失敗：\(error.localizedDescription)"
        }
    }
    
    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await dataService.updateTransaction(transaction)
            await updateSnapshotsIfNeeded(for: transaction.accountId)
            await updateHoldings(accountId: transaction.accountId)
            await loadTransactions(userId: accounts.first?.userId ?? "")
        } catch {
            errorMessage = "更新交易失敗：\(error.localizedDescription)"
        }
    }
    
    /// 驗證是否可以刪除還款交易（異步檢查，用於 UI 層面的驗證）
    func canDeleteRepaymentTransaction(_ transaction: Transaction, userId: String) async -> (canDelete: Bool, errorMessage: String?) {
        // 檢查是否為還款交易
        let isRepayment = transaction.type == .repayment || 
                         (transaction.notes?.contains("還款至") == true) ||
                         (transaction.notes?.contains("還款自") == true) ||
                         (transaction.notes?.contains("還款到") == true)
        
        guard isRepayment else {
            // 不是還款交易，可以刪除
            return (true, nil)
        }
        
        // 如果是還款交易，需要檢查是否為最新紀錄
        do {
            guard let targetAccountId = transaction.targetAccountId,
                  let targetAccount = try? await dataService.fetchAccounts(userId: userId).first(where: { $0.id == targetAccountId }),
                  targetAccount.accountType == .debt else {
                // 不是債務帳戶的還款交易，可以刪除
                return (true, nil)
            }
            
            // 獲取所有還款交易，檢查是否為最新紀錄
            let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
            let repaymentTransactions = allTransactions
                .filter { ($0.type == .repayment || $0.notes?.contains("還款") == true) && $0.targetAccountId == targetAccountId }
                .sorted { $0.transactionDate > $1.transactionDate }  // 按日期降序排序
            
            // 檢查當前交易是否為最新還款紀錄（第一個）
            if let latestRepayment = repaymentTransactions.first,
               latestRepayment.id == transaction.id {
                // 是最新還款紀錄，可以刪除
                return (true, nil)
            } else {
                // 不是最新還款紀錄，不允許刪除
                return (false, "只能刪除最新的還款紀錄。請先刪除較新的還款紀錄。")
            }
        } catch {
            // 如果檢查失敗，允許刪除（讓實際刪除時再驗證）
            return (true, nil)
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
                             (transaction.notes?.contains("還款自") ?? false) ||
                             (transaction.notes?.contains("還款到") ?? false)
            
            // 如果是轉帳或還款交易，使用相同的邏輯處理
            if transaction.type == .transfer || transaction.type == .repayment || isTransferTransaction(transaction) || isRepayment {
                // 現在轉帳/還款只記錄在一筆交易中，只需要刪除這筆交易
                // 但如果是還款交易，需要恢復債務的剩餘本金
                if transaction.type == .repayment || isRepayment {
                    // ===== 還款交易：檢查是否為最新還款紀錄，並恢復還款前狀態 =====
                    if let targetAccountId = transaction.targetAccountId,
                       let targetAccount = try? await dataService.fetchAccounts(userId: userId).first(where: { $0.id == targetAccountId }),
                       targetAccount.accountType == .debt {
                        
                        // 1. 檢查是否為最新還款紀錄（只能刪除最新的一筆）
                        let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
                        let repaymentTransactions = allTransactions
                            .filter { ($0.type == .repayment || $0.notes?.contains("還款") == true) && $0.targetAccountId == targetAccountId }
                            .sorted { $0.transactionDate > $1.transactionDate }  // 按日期降序排序
                        
                        // 檢查當前交易是否為最新還款紀錄（第一個）
                        guard let latestRepayment = repaymentTransactions.first,
                              latestRepayment.id == transaction.id else {
                            // 不是最新還款紀錄，不允許刪除
                            await MainActor.run {
                                errorMessage = "只能刪除最新的還款紀錄。請先刪除較新的還款紀錄。"
                            }
                            return
                        }
                        
                        // 2. 找到對應的債務並使用存儲的還款前狀態直接恢復
                        // 注意：Liability 的 accountId 是還款帳戶的 ID（不是債務帳戶的 ID），name 是債務名稱
                        let allAccounts = try await dataService.fetchAccounts(userId: userId)
                        let debtAccountName = targetAccount.name  // 債務名稱
                        
                        // 在所有非債務帳戶中查找對應的 Liability（通過 name 匹配）
                        // 因為一個債務名稱應該只對應一個 Liability，所以找到第一個匹配的就夠了
                        var foundLiability: Liability? = nil
                        for account in allAccounts {
                            if account.accountType != .debt {
                                // Liability 的 accountId 是還款帳戶的 ID，name 是債務名稱
                                let accountLiabilities = try await dataService.fetchLiabilities(accountId: account.id)
                                if let liability = accountLiabilities.first(where: { $0.name == debtAccountName }) {
                                    foundLiability = liability
                                    break
                                }
                            }
                        }
                        
                        guard var liability = foundLiability else {
                            await MainActor.run {
                                errorMessage = "找不到對應的債務記錄：\(debtAccountName)"
                            }
                            return
                        }
                        
                        // 使用存儲的還款前狀態直接恢復（不需要重新計算）
                        guard let beforeBalance = transaction.beforeRepaymentBalance,
                              let beforePaidPeriods = transaction.beforeRepaymentPaidPeriods else {
                            // 如果交易中沒有存儲還款前狀態（舊數據），則不允許刪除
                            await MainActor.run {
                                errorMessage = "無法恢復還款前狀態：交易記錄中缺少還款前狀態資訊。這可能是舊版本的交易記錄，無法安全刪除。"
                            }
                            return
                        }
                        
                        // 直接恢復還款前的狀態
                        liability.remainingBalance = beforeBalance
                        liability.paidPeriods = beforePaidPeriods
                        
                        // 如果存儲了還款前的總期數，恢復總期數（提前還款時總期數應該不變，但為了安全起見還是恢復）
                        if let beforeTotalPeriods = transaction.beforeRepaymentTotalPeriods {
                            liability.totalPeriods = beforeTotalPeriods
                        }
                        // 注意：如果沒有存儲還款前的總期數（舊數據），總期數保持當前值不變
                        
                        // 恢復已還款本金、已支出利息、節省利息
                        // 直接從交易記錄中讀取 principalAmount 和 interestAmount（不使用字符串解析）
                        if let principalAmount = transaction.principalAmount {
                            liability.totalPaidPrincipal -= principalAmount
                        }
                        if let interestAmount = transaction.interestAmount {
                            liability.totalPaidInterest -= interestAmount
                        }
                        
                        // 如果是提前還款，需要恢復節省利息
                        // 直接從交易記錄中讀取 savedInterest（不使用字符串解析）
                        if let savedInterest = transaction.savedInterest, savedInterest > 0 {
                            liability.totalSavedInterest -= savedInterest
                        }
                        
                        // 確保不會出現負數
                        if liability.totalPaidPrincipal < 0 {
                            liability.totalPaidPrincipal = 0
                        }
                        if liability.totalPaidInterest < 0 {
                            liability.totalPaidInterest = 0
                        }
                        if liability.totalSavedInterest < 0 {
                            liability.totalSavedInterest = 0
                        }
                        
                        liability.updatedAt = Date()
                        try await dataService.updateLiability(liability)
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
            await updateSnapshotsIfNeeded(for: transaction.accountId)
            await loadTransactions(userId: userId)
            // 清除錯誤訊息（如果刪除成功）
            await MainActor.run {
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "刪除交易失敗：\(error.localizedDescription)"
            }
            // 如果刪除失敗，重新載入數據以恢復狀態
            await loadTransactions(userId: accounts.first?.userId ?? "test-user-id")
        }
    }

    private func updateSnapshotsIfNeeded(for accountId: String) async {
        if let userId = await resolveUserId(for: accountId) {
            do {
                let priceService = PriceService(dataService: dataService)
                _ = try await SnapshotUpdater.rebuildSnapshots(
                    userId: userId,
                    dataService: dataService,
                    priceService: priceService
                )
                await MainActor.run {
                    NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
                }
            } catch {
                // 快照更新失敗不影響交易流程
            }
        }
    }

    private func resolveUserId(for accountId: String) async -> String? {
        if let account = accounts.first(where: { $0.id == accountId }) {
            return account.userId
        }
        if let fetchedAccounts = try? await dataService.fetchAccounts(userId: "test-user-id"),
           let account = fetchedAccounts.first(where: { $0.id == accountId }) {
            return account.userId
        }
        return nil
    }

    private func calculateCostBasis(
        userId: String,
        accountId: String,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        averageCostFallback: Decimal
    ) async throws -> Decimal {
        if let snapshot = try await dataService.fetchAggregatedHoldingSnapshot(userId: userId, assetType: assetType, symbol: symbol),
           let accountLots = snapshot.fifoLotsByAccount.first(where: { $0.accountId == accountId }) {
            var remaining = quantity
            var costBasis: Decimal = 0
            for lot in accountLots.lots {
                if remaining <= 0 { break }
                let used = min(remaining, lot.remainingQuantity)
                costBasis += used * lot.costPerUnit
                remaining -= used
            }
            if costBasis > 0 {
                return costBasis
            }
        }
        return averageCostFallback * quantity
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

