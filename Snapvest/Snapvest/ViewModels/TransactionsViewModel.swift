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
    private var isBatchImporting = false
    
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
    
    func findDuplicateMatch(
        for transaction: Transaction,
        excludingTransactionId: String? = nil
    ) async -> Transaction? {
        do {
            let existing = try await dataService.fetchTransactions(accountId: transaction.accountId)
            return TransactionDuplicateChecker.findDuplicate(
                for: transaction,
                in: existing,
                excludingTransactionId: excludingTransactionId
            )
        } catch {
            return nil
        }
    }
    
    func createTransaction(_ transaction: Transaction, allowDuplicate: Bool = false) async {
        if let priceError = await SymbolPriceValidator.validatePriceAvailable(
            assetType: transaction.assetType,
            symbol: transaction.symbol,
            transactionType: transaction.type
        ) {
            errorMessage = priceError
            return
        }
        
        if !allowDuplicate,
           let duplicate = await findDuplicateMatch(for: transaction) {
            errorMessage = TransactionDuplicateChecker.alertMessage(
                for: transaction,
                existing: duplicate
            )
            return
        }
        
        do {
            try await dataService.createTransaction(transaction)
            if !isBatchImporting {
                await updateSnapshotsIfNeeded(for: transaction.accountId)
                await updateHoldings(accountId: transaction.accountId)
            }
            if !isBatchImporting {
                await loadTransactions(userId: accounts.first?.userId ?? "")
                notifyTransactionsDidChange()
            }
        } catch {
            errorMessage = "建立交易失敗：\(error.localizedDescription)"
        }
    }
    
    /// 批次匯入 CSV 交易（依日期升序寫入，逐筆記錄失敗，結束後重建快照）
    func importValidatedTransactions(
        userId: String,
        validation: TransactionImportValidationResult
    ) async -> TransactionImportBatchResult {
        guard validation.canImport else {
            let failures = validation.rows
                .filter { $0.errorMessage != nil }
                .map {
                    TransactionImportBatchFailure(
                        lineNumber: $0.lineNumber,
                        summary: $0.summary,
                        errorMessage: $0.errorMessage ?? "資料不完整"
                    )
                }
            return TransactionImportBatchResult(imported: 0, failures: failures)
        }
        
        isBatchImporting = true
        defer { isBatchImporting = false }
        
        errorMessage = nil
        let sortedRows = validation.rows
            .filter(\.isValid)
            .sorted {
                ($0.transaction?.transactionDate ?? .distantPast) < ($1.transaction?.transactionDate ?? .distantPast)
            }
        var imported = 0
        var failures: [TransactionImportBatchFailure] = []
        
        do {
            if accounts.isEmpty {
                accounts = try await dataService.fetchAccounts(userId: userId)
            }
            
            for row in sortedRows {
                guard let draft = row.transaction else { continue }
                do {
                    try await SymbolPriceValidator.validatePriceAvailableOrThrow(
                        assetType: draft.assetType,
                        symbol: draft.symbol,
                        transactionType: draft.type
                    )
                    if draft.type == .sell {
                        try await importSellTransactionDuringBatch(draft)
                    } else {
                        try await dataService.createTransaction(draft)
                    }
                    imported += 1
                } catch {
                    failures.append(
                        TransactionImportBatchFailure(
                            lineNumber: row.lineNumber,
                            summary: row.summary,
                            errorMessage: error.localizedDescription
                        )
                    )
                }
            }
            
            if imported > 0, let accountId = sortedRows.compactMap({ $0.transaction?.accountId }).first {
                await updateSnapshotsIfNeeded(for: accountId)
            }
            await loadTransactions(userId: userId)
            
            if !failures.isEmpty {
                errorMessage = TransactionImportBatchResult(imported: imported, failures: failures).alertMessage
            }
            return TransactionImportBatchResult(imported: imported, failures: failures)
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            await loadTransactions(userId: userId)
            return TransactionImportBatchResult(
                imported: imported,
                failures: [
                    TransactionImportBatchFailure(
                        lineNumber: 0,
                        summary: "匯入程序",
                        errorMessage: message
                    )
                ]
            )
        }
    }
    
    private func importSellTransactionDuringBatch(_ draft: Transaction) async throws {
        guard let account = accounts.first(where: { $0.id == draft.accountId }) else {
            throw TransactionImportError.missingAccount
        }
        
        let costBasis = try await calculateCostBasis(
            userId: account.userId,
            accountId: account.id,
            assetType: draft.assetType,
            symbol: draft.symbol,
            quantity: draft.quantity,
            averageCostFallback: draft.price
        )
        let proceeds = draft.quantity * draft.price
        let realizedGainLoss = proceeds - costBasis
        let realizedGainLossPercent = costBasis > 0 ? (realizedGainLoss / costBasis) * 100 : nil
        let realizedCostPerUnit = draft.quantity > 0 ? costBasis / draft.quantity : nil
        
        let sell = Transaction(
            id: draft.id,
            accountId: draft.accountId,
            type: .sell,
            assetType: draft.assetType,
            symbol: draft.symbol,
            quantity: draft.quantity,
            price: draft.price,
            currency: draft.currency,
            fee: draft.fee,
            notes: draft.notes,
            transactionDate: draft.transactionDate,
            exchangeRate: draft.exchangeRate,
            realizedGainLoss: realizedGainLoss,
            realizedGainLossPercent: realizedGainLossPercent,
            realizedCostBasis: costBasis,
            realizedCostPerUnit: realizedCostPerUnit
        )
        try await dataService.createTransaction(sell)
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
        averageCostFallback: Decimal,
        allowDuplicate: Bool = false
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
            
            await createTransaction(transaction, allowDuplicate: allowDuplicate)
        } catch {
            errorMessage = "建立賣出交易失敗：\(error.localizedDescription)"
        }
    }
    
    private func validateBuyMutation(
        account: Account,
        assetType: AssetType,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        fee: Decimal,
        exchangeRate: Decimal?,
        deductFromAccount: Bool,
        existingTransaction: Transaction?
    ) async -> Bool {
        do {
            let accountTransactions = try await dataService.fetchTransactions(accountId: account.id)
            let allAccounts = accounts.isEmpty
                ? try await dataService.fetchAccounts(userId: account.userId)
                : accounts
            let resolvedRate = BuyTransactionValidator.resolvedExchangeRate(
                account: account,
                assetType: assetType,
                exchangeRate: exchangeRate
            )
            if let message = BuyTransactionValidator.validate(
                account: account,
                assetType: assetType,
                quantity: quantity,
                price: price,
                currency: currency,
                fee: fee,
                exchangeRate: resolvedRate,
                deductFromAccount: deductFromAccount,
                accountTransactions: accountTransactions,
                allAccounts: allAccounts,
                existingTransaction: existingTransaction
            ) {
                errorMessage = message
                return false
            }
            return true
        } catch {
            errorMessage = "無法驗證帳戶餘額：\(error.localizedDescription)"
            return false
        }
    }
    
    func createBuyTransaction(
        account: Account,
        assetType: AssetType,
        symbol: String,
        symbolName: String?,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        fee: Decimal,
        exchangeRate: Decimal?,
        deductFromAccount: Bool,
        transactionDate: Date,
        allowDuplicate: Bool = false
    ) async {
        errorMessage = nil
        let resolvedRate = BuyTransactionValidator.resolvedExchangeRate(
            account: account,
            assetType: assetType,
            exchangeRate: exchangeRate
        )
        guard await validateBuyMutation(
            account: account,
            assetType: assetType,
            quantity: quantity,
            price: price,
            currency: currency,
            fee: fee,
            exchangeRate: resolvedRate,
            deductFromAccount: deductFromAccount,
            existingTransaction: nil
        ) else { return }
        
        let resolvedSymbol = assetType == .crypto
            ? SymbolListService.normalizedCryptoSymbol(symbol)
            : symbol
        let notes: String? = {
            guard let symbolName, !symbolName.isEmpty, assetType != .crypto else {
                return assetType == .crypto ? "買入 \(resolvedSymbol)" : nil
            }
            return "買入 \(resolvedSymbol) - \(symbolName)"
        }()
        let transaction = Transaction(
            accountId: account.id,
            type: .buy,
            assetType: assetType,
            symbol: resolvedSymbol,
            quantity: quantity,
            price: price,
            currency: currency,
            fee: fee,
            notes: notes,
            transactionDate: transactionDate,
            exchangeRate: resolvedRate,
            deductFromAccount: deductFromAccount
        )
        
        await createTransaction(transaction, allowDuplicate: allowDuplicate)
    }
    
    func updateTransaction(_ transaction: Transaction, previousAccountId: String? = nil, allowDuplicate: Bool = false) async {
        if !allowDuplicate,
           let duplicate = await findDuplicateMatch(
            for: transaction,
            excludingTransactionId: transaction.id
           ) {
            errorMessage = TransactionDuplicateChecker.alertMessage(
                for: transaction,
                existing: duplicate
            )
            return
        }
        
        do {
            try await dataService.updateTransaction(transaction)
            await updateSnapshotsIfNeeded(for: transaction.accountId)
            await updateHoldings(accountId: transaction.accountId)
            if let previousAccountId, previousAccountId != transaction.accountId {
                await updateSnapshotsIfNeeded(for: previousAccountId)
                await updateHoldings(accountId: previousAccountId)
            }
            let userId = await resolveUserId(for: transaction.accountId) ?? AppUser.id
            await loadTransactions(userId: userId)
            notifyTransactionsDidChange()
        } catch {
            errorMessage = "更新交易失敗：\(error.localizedDescription)"
        }
    }
    
    func updateBuyTransaction(
        existing: Transaction,
        account: Account,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        fee: Decimal,
        exchangeRate: Decimal?,
        deductFromAccount: Bool,
        transactionDate: Date,
        symbolName: String?,
        allowDuplicate: Bool = false
    ) async {
        errorMessage = nil
        let resolvedRate = BuyTransactionValidator.resolvedExchangeRate(
            account: account,
            assetType: existing.assetType,
            exchangeRate: exchangeRate
        )
        guard await validateBuyMutation(
            account: account,
            assetType: existing.assetType,
            quantity: quantity,
            price: price,
            currency: currency,
            fee: fee,
            exchangeRate: resolvedRate,
            deductFromAccount: deductFromAccount,
            existingTransaction: existing
        ) else { return }
        
        let notes: String? = {
            if let symbolName, !symbolName.isEmpty {
                return "買入 \(existing.symbol) - \(symbolName)"
            }
            return existing.notes
        }()
        let updated = Transaction(
            id: existing.id,
            accountId: account.id,
            type: .buy,
            assetType: existing.assetType,
            symbol: existing.symbol,
            quantity: quantity,
            price: price,
            currency: currency,
            fee: fee,
            notes: notes,
            transactionDate: transactionDate,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            exchangeRate: resolvedRate,
            deductFromAccount: deductFromAccount
        )
        await updateTransaction(updated, previousAccountId: existing.accountId, allowDuplicate: allowDuplicate)
    }
    
    func updateSellTransaction(
        existing: Transaction,
        account: Account,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        exchangeRate: Decimal?,
        transactionDate: Date,
        averageCostFallback: Decimal,
        allowDuplicate: Bool = false
    ) async {
        errorMessage = nil
        let resolvedRate = SellTransactionValidator.resolvedExchangeRate(
            account: account,
            assetType: existing.assetType,
            exchangeRate: exchangeRate
        )
        let maxSellQuantity = await resolveMaxSellQuantity(
            account: account,
            assetType: existing.assetType,
            symbol: existing.symbol,
            editingTransaction: existing
        )
        if let message = SellTransactionValidator.validate(
            account: account,
            assetType: existing.assetType,
            symbol: existing.symbol,
            quantity: quantity,
            exchangeRate: resolvedRate,
            maxSellQuantity: maxSellQuantity
        ) {
            errorMessage = message
            return
        }

        do {
            let costBasis = try await calculateCostBasis(
                userId: account.userId,
                accountId: account.id,
                assetType: existing.assetType,
                symbol: existing.symbol,
                quantity: quantity,
                averageCostFallback: averageCostFallback
            )
            let proceeds = quantity * price
            let realizedGainLoss = proceeds - costBasis
            let realizedGainLossPercent = costBasis > 0 ? (realizedGainLoss / costBasis) * 100 : nil
            let realizedCostPerUnit = quantity > 0 ? costBasis / quantity : nil
            
            let updated = Transaction(
                id: existing.id,
                accountId: account.id,
                type: .sell,
                assetType: existing.assetType,
                symbol: existing.symbol,
                quantity: quantity,
                price: price,
                currency: currency,
                fee: existing.fee,
                notes: existing.notes,
                transactionDate: transactionDate,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                exchangeRate: resolvedRate,
                realizedGainLoss: realizedGainLoss,
                realizedGainLossPercent: realizedGainLossPercent,
                realizedCostBasis: costBasis,
                realizedCostPerUnit: realizedCostPerUnit
            )
            await updateTransaction(updated, previousAccountId: existing.accountId, allowDuplicate: allowDuplicate)
        } catch {
            errorMessage = "更新賣出交易失敗：\(error.localizedDescription)"
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
        
        do {
            guard transaction.type == .repayment else {
                return (true, nil)
            }
            
            let allAccounts = try await dataService.fetchAccounts(userId: userId)
            guard let debtAccount = allAccounts.first(where: { $0.id == transaction.accountId }),
                  debtAccount.accountType == .debt else {
                return (true, nil)
            }
            
            let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
            let repaymentTransactions = allTransactions
                .filter { $0.type == .repayment && $0.accountId == debtAccount.id }
                .sorted { $0.transactionDate > $1.transactionDate }
            
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
            
            let userId = accounts.first?.userId ?? AppUser.id
            
            if transaction.type == .repayment {
                let allAccounts = try await dataService.fetchAccounts(userId: userId)
                if let debtAccount = allAccounts.first(where: { $0.id == transaction.accountId }),
                   debtAccount.accountType == .debt {
                    let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
                    let repaymentTransactions = allTransactions
                        .filter { $0.type == .repayment && $0.accountId == debtAccount.id }
                        .sorted { $0.transactionDate > $1.transactionDate }
                    
                    guard let latestRepayment = repaymentTransactions.first,
                          latestRepayment.id == transaction.id else {
                        await MainActor.run {
                            errorMessage = "只能刪除最新的還款紀錄。請先刪除較新的還款紀錄。"
                        }
                        return
                    }
                    
                    let accountLiabilities = try await dataService.fetchLiabilities(accountId: debtAccount.id)
                    guard var liability = accountLiabilities.first(where: { $0.name == debtAccount.name }) ?? accountLiabilities.first else {
                        await MainActor.run {
                            errorMessage = "找不到對應的債務記錄：\(debtAccount.name)"
                        }
                        return
                    }
                    
                    if debtAccount.accountType == .debt {
                        guard let beforeBalance = transaction.beforeRepaymentBalance,
                              let beforePaidPeriods = transaction.beforeRepaymentPaidPeriods else {
                            await MainActor.run {
                                errorMessage = "無法恢復還款前狀態：交易記錄中缺少還款前狀態資訊。"
                            }
                            return
                        }
                        
                        liability.remainingBalance = beforeBalance
                        liability.paidPeriods = beforePaidPeriods
                        if let beforeTotalPeriods = transaction.beforeRepaymentTotalPeriods {
                            liability.totalPeriods = beforeTotalPeriods
                        }
                        if let principalAmount = transaction.principalAmount {
                            liability.totalPaidPrincipal -= principalAmount
                        }
                        if let interestAmount = transaction.interestAmount {
                            liability.totalPaidInterest -= interestAmount
                        }
                        if let savedInterest = transaction.savedInterest, savedInterest > 0 {
                            liability.totalSavedInterest -= savedInterest
                        }
                        liability.totalPaidPrincipal = max(0, liability.totalPaidPrincipal)
                        liability.totalPaidInterest = max(0, liability.totalPaidInterest)
                        liability.totalSavedInterest = max(0, liability.totalSavedInterest)
                        liability.updatedAt = Date()
                        try await dataService.updateLiability(liability)
                    }
                }
                
                try await dataService.deleteTransaction(transactionId)
                await updateHoldings(accountId: transaction.accountId)
            }
            else if transaction.type == .liability {
                let allAccounts = try await dataService.fetchAccounts(userId: userId)
                if let liabilityAccount = allAccounts.first(where: { $0.id == transaction.accountId }) {
                    switch liabilityAccount.accountType {
                    case .otherDebt:
                        // 其他債務：僅刪除該筆欠款紀錄，保留帳戶
                        try await dataService.deleteTransaction(transactionId)
                    case .debt:
                        let debtAccountId = liabilityAccount.id
                        let liabilityName = liabilityAccount.name
                        let accountLiabilities = try await dataService.fetchLiabilities(accountId: debtAccountId)
                        let foundLiability = accountLiabilities.first(where: { $0.name == liabilityName }) ?? accountLiabilities.first
                        
                        try await dataService.deleteTransaction(transactionId)
                        if let liability = foundLiability {
                            try await dataService.deleteLiability(liability.id)
                        }
                        try await dataService.deleteAccount(debtAccountId)
                    default:
                        try await dataService.deleteTransaction(transactionId)
                        await updateHoldings(accountId: transaction.accountId)
                    }
                } else {
                    try await dataService.deleteTransaction(transactionId)
                }
            } else {
                try await dataService.deleteTransaction(transactionId)
                await updateHoldings(accountId: transaction.accountId)
            }
            
            await loadTransactions(userId: userId)
            await refreshPortfolioSnapshots(userId: userId)
            notifyTransactionsDidChange()
            // 清除錯誤訊息（如果刪除成功）
            await MainActor.run {
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "刪除交易失敗：\(error.localizedDescription)"
            }
            // 如果刪除失敗，重新載入數據以恢復狀態
            await loadTransactions(userId: accounts.first?.userId ?? AppUser.id)
        }
    }

    private func refreshPortfolioSnapshots(userId: String) async {
        await SnapshotRefreshCoordinator.rebuildAndNotify(
            userId: userId,
            dataService: dataService
        )
    }
    
    private func updateSnapshotsIfNeeded(for accountId: String) async {
        let userId = await resolveUserId(for: accountId) ?? AppUser.id
        await refreshPortfolioSnapshots(userId: userId)
    }

    private func notifyTransactionsDidChange() {
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }

    private func resolveMaxSellQuantity(
        account: Account,
        assetType: AssetType,
        symbol: String,
        editingTransaction: Transaction
    ) async -> Decimal {
        let options = await SellHoldingAvailability.accountsWithSellCapacity(
            symbol: symbol,
            assetType: assetType,
            candidateAccounts: [account],
            dataService: dataService,
            editingTransaction: editingTransaction
        )
        return options.first?.maxSellQuantity ?? editingTransaction.quantity
    }

    private func resolveUserId(for accountId: String) async -> String? {
        if let account = accounts.first(where: { $0.id == accountId }) {
            return account.userId
        }
        if let fetchedAccounts = try? await dataService.fetchAccounts(userId: AppUser.id),
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

