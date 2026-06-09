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
    @Published var manualAssets: [ManualAsset] = []
    @Published var manualAssetValuationsByAssetId: [String: [ManualAssetValuation]] = [:]
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
            manualAssets = try await dataService.fetchManualAssets(userId: userId)
            var valuationsByAssetId: [String: [ManualAssetValuation]] = [:]
            for asset in manualAssets {
                valuationsByAssetId[asset.id] = try await dataService.fetchManualAssetValuations(assetId: asset.id)
            }
            manualAssetValuationsByAssetId = valuationsByAssetId
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
    
    func createTransaction(
        _ transaction: Transaction,
        allowDuplicate: Bool = false,
        skipPriceValidation: Bool = false,
        showsLoadingOverlay: Bool = true
    ) async {
        if !skipPriceValidation,
           let priceError = await SymbolPriceValidator.validatePriceAvailable(
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
            let userId = await resolveUserId(for: transaction.accountId) ?? accounts.first?.userId ?? AppUser.id
            if !isBatchImporting {
                let affectedAccountIds: Set<String> = [transaction.accountId]
                let affectedSymbols = impactedSymbols(for: [transaction])
                let forceFullRebuild = await requiresFullSnapshotRebuild(
                    changedTransactions: [transaction],
                    affectedAccountIds: affectedAccountIds,
                    affectedSymbols: affectedSymbols
                )
                await loadTransactions(userId: userId)
                schedulePortfolioRefresh(
                    userId: userId,
                    affectedAccountIds: affectedAccountIds,
                    affectedSymbols: affectedSymbols,
                    realizedGainLossDeltaByCurrency: realizedGainLossDeltaByCurrency(newTransaction: transaction),
                    forceFullRebuild: forceFullRebuild,
                    showsLoadingOverlay: showsLoadingOverlay
                )
            }
        } catch {
            errorMessage = "建立交易失敗：\(error.localizedDescription)"
        }
    }
    
    /// 批次匯入 CSV 交易（依日期升序寫入，逐筆記錄失敗，結束後重建快照）
    func importValidatedTransactions(
        userId: String,
        validation: TransactionImportValidationResult,
        assumePricesValidated: Bool = false
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
        let validRows = validation.rows.filter(\.isValid)
        let sortedBuys = validRows
            .filter { $0.transaction?.type == .buy }
            .sorted {
                ($0.transaction?.transactionDate ?? .distantPast) < ($1.transaction?.transactionDate ?? .distantPast)
            }
        let sortedSells = validRows
            .filter { $0.transaction?.type == .sell }
            .sorted {
                ($0.transaction?.transactionDate ?? .distantPast) < ($1.transaction?.transactionDate ?? .distantPast)
            }
        var imported = 0
        var failures: [TransactionImportBatchFailure] = []
        
        do {
            if accounts.isEmpty {
                accounts = try await dataService.fetchAccounts(userId: userId)
            }
            
            func importRow(_ row: TransactionImportValidatedRow) async {
                guard let draft = row.transaction else { return }
                do {
                    if !assumePricesValidated {
                        try await SymbolPriceValidator.validatePriceAvailableOrThrow(
                            assetType: draft.assetType,
                            symbol: draft.symbol,
                            transactionType: draft.type
                        )
                    }
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
            
            for row in sortedBuys {
                await importRow(row)
            }
            
            for row in sortedSells {
                await importRow(row)
            }
            
            await loadTransactions(userId: userId)

            if imported > 0 {
                let importedTransactions = validRows.compactMap(\.transaction)
                schedulePortfolioRefresh(
                    userId: userId,
                    affectedAccountIds: Set(importedTransactions.map(\.accountId)),
                    affectedSymbols: impactedSymbols(for: importedTransactions),
                    forceFullRebuild: true,
                    showsLoadingOverlay: true,
                    loadingTitle: "正在更新持倉…",
                    loadingMessage: "重新計算帳戶餘額與投資總覽"
                )
            }
            
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
        
        let resolvedRate = SellTransactionValidator.resolvedExchangeRate(
            account: account,
            assetType: draft.assetType,
            exchangeRate: draft.exchangeRate
        )
        let maxSellQuantity = await resolveMaxSellQuantity(
            account: account,
            assetType: draft.assetType,
            symbol: draft.symbol,
            editingTransaction: nil
        )
        if let message = SellTransactionValidator.validate(
            account: account,
            assetType: draft.assetType,
            symbol: draft.symbol,
            quantity: draft.quantity,
            exchangeRate: resolvedRate,
            maxSellQuantity: maxSellQuantity
        ) {
            throw TransactionImportError.validationFailed(message)
        }
        
        let costBasis = try await calculateCostBasis(
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
        allowDuplicate: Bool = false,
        skipPriceValidation: Bool = false
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
        
        await createTransaction(
            transaction,
            allowDuplicate: allowDuplicate,
            skipPriceValidation: skipPriceValidation
        )
    }
    
    func updateTransaction(_ transaction: Transaction, previousAccountId: String? = nil, allowDuplicate: Bool = false) async {
        let previousTransaction = await persistedTransaction(
            id: transaction.id,
            candidateAccountIds: [transaction.accountId, previousAccountId].compactMap { $0 }
        )

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
            let affectedAccountIds = Set([transaction.accountId, previousAccountId, previousTransaction?.accountId].compactMap { $0 })
            let affectedSymbols = impactedSymbols(for: [transaction, previousTransaction].compactMap { $0 })
            let forceFullRebuild = await requiresFullSnapshotRebuild(
                changedTransactions: [transaction, previousTransaction].compactMap { $0 },
                affectedAccountIds: affectedAccountIds,
                affectedSymbols: affectedSymbols
            )
            let userId = await resolveUserId(for: transaction.accountId) ?? AppUser.id
            await loadTransactions(userId: userId)
            schedulePortfolioRefresh(
                userId: userId,
                affectedAccountIds: affectedAccountIds,
                affectedSymbols: affectedSymbols,
                realizedGainLossDeltaByCurrency: realizedGainLossDeltaByCurrency(
                    newTransaction: transaction,
                    previousTransaction: previousTransaction
                ),
                forceFullRebuild: forceFullRebuild,
                showsLoadingOverlay: true
            )
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
                accountId: account.id,
                assetType: existing.assetType,
                symbol: existing.symbol,
                quantity: quantity,
                averageCostFallback: averageCostFallback,
                excludingTransactionId: existing.id
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
    
    static let repaymentNotEditableMessage = "此筆紀錄無法編輯 請編輯最新的紀錄"

    /// 債務帳戶還款僅最新一筆可編輯（與刪除規則一致，使用已載入的 `transactions`）。
    func canEditRepaymentTransaction(_ transaction: Transaction) -> Bool {
        guard transaction.type == .repayment else { return true }
        guard let debtAccount = accounts.first(where: { $0.id == transaction.accountId }),
              debtAccount.accountType == .debt else {
            return true
        }
        let latest = transactions
            .filter { $0.type == .repayment && $0.accountId == debtAccount.id }
            .max(by: { $0.transactionDate < $1.transactionDate })
        return latest?.id == transaction.id
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
            let affectedAccountIds: Set<String> = [transaction.accountId]
            let affectedSymbols = impactedSymbols(for: [transaction])
            
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
                    }
                } else {
                    try await dataService.deleteTransaction(transactionId)
                }
            } else {
                try await dataService.deleteTransaction(transactionId)
            }
            
            await loadTransactions(userId: userId)
            let forceFullRebuild = await requiresFullSnapshotRebuild(
                changedTransactions: [transaction],
                affectedAccountIds: affectedAccountIds,
                affectedSymbols: affectedSymbols
            )
            schedulePortfolioRefresh(
                userId: userId,
                affectedAccountIds: affectedAccountIds,
                affectedSymbols: affectedSymbols,
                realizedGainLossDeltaByCurrency: realizedGainLossDeltaByCurrency(deletedTransaction: transaction),
                forceFullRebuild: forceFullRebuild,
                showsLoadingOverlay: true,
                loadingTitle: "正在更新資料…",
                loadingMessage: "重新計算帳戶、持股與總資產"
            )
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

    private func updateSnapshotsIfNeeded(for accountId: String) async {
        let userId = await resolveUserId(for: accountId) ?? AppUser.id
        schedulePortfolioRefresh(
            userId: userId,
            affectedAccountIds: [accountId],
            showsLoadingOverlay: false
        )
    }

    private func impactedSymbols(for transactions: [Transaction]) -> [SymbolInfo] {
        var symbols: [SymbolInfo] = []
        for transaction in transactions {
            guard transaction.type == .buy || transaction.type == .sell else { continue }
            let symbol = normalizedSnapshotSymbol(assetType: transaction.assetType, symbol: transaction.symbol)
            guard !symbol.isEmpty else { continue }
            let symbolInfo = SymbolInfo(assetType: transaction.assetType, symbol: symbol)
            if !symbols.contains(symbolInfo) {
                symbols.append(symbolInfo)
            }
        }
        return symbols
    }

    private func requiresFullSnapshotRebuild(
        changedTransactions: [Transaction],
        affectedAccountIds: Set<String>,
        affectedSymbols: [SymbolInfo]
    ) async -> Bool {
        if changedTransactions.contains(where: { transaction in
            transaction.type == .liability || transaction.type == .repayment
        }) {
            return true
        }
        guard !affectedSymbols.isEmpty else { return false }
        let changedTransactionIds = Set(changedTransactions.map(\.id))

        for accountId in affectedAccountIds {
            guard let accountTransactions = try? await dataService.fetchTransactions(accountId: accountId) else {
                return true
            }
            for symbolInfo in affectedSymbols {
                if accountTransactions.contains(where: { transaction in
                    transaction.type == .sell &&
                    !changedTransactionIds.contains(transaction.id) &&
                    transaction.assetType == symbolInfo.assetType &&
                    normalizedSnapshotSymbol(assetType: transaction.assetType, symbol: transaction.symbol) == symbolInfo.symbol
                }) {
                    return true
                }
            }
        }
        return false
    }

    private func normalizedSnapshotSymbol(assetType: AssetType, symbol: String) -> String {
        SupabasePriceService.normalizeSymbol(assetType: assetType, symbol: symbol)
    }

    private func realizedGainLossDeltaByCurrency(
        newTransaction: Transaction? = nil,
        previousTransaction: Transaction? = nil,
        deletedTransaction: Transaction? = nil
    ) -> [Currency: Decimal] {
        var deltas: [Currency: Decimal] = [:]
        if let previousTransaction, previousTransaction.type == .sell {
            deltas[previousTransaction.currency, default: 0] -= previousTransaction.realizedGainLoss ?? 0
        }
        if let deletedTransaction, deletedTransaction.type == .sell {
            deltas[deletedTransaction.currency, default: 0] -= deletedTransaction.realizedGainLoss ?? 0
        }
        if let newTransaction, newTransaction.type == .sell {
            deltas[newTransaction.currency, default: 0] += newTransaction.realizedGainLoss ?? 0
        }
        return deltas
    }

    private func schedulePortfolioRefresh(
        userId: String,
        affectedAccountIds: Set<String>,
        affectedSymbols: [SymbolInfo] = [],
        realizedGainLossDeltaByCurrency: [Currency: Decimal] = [:],
        forceFullRebuild: Bool = false,
        showsLoadingOverlay: Bool = true,
        loadingTitle: String = "正在更新資料…",
        loadingMessage: String = "重新計算帳戶、持股與總資產"
    ) {
        let request = PortfolioMutationRefreshRequest(
            userId: userId,
            affectedAccountIds: affectedAccountIds,
            affectedSymbols: affectedSymbols,
            forceFullRebuild: forceFullRebuild,
            realizedGainLossDeltaByCurrency: realizedGainLossDeltaByCurrency,
            showsLoadingOverlay: showsLoadingOverlay,
            loadingTitle: loadingTitle,
            loadingMessage: loadingMessage
        )
        RealizedPLDetailCache.invalidate()
        NotificationCenter.default.post(
            name: .transactionsDidChange,
            object: request,
            userInfo: [
                PortfolioMutationUserInfoKey.affectedAccountIds: Array(affectedAccountIds)
            ]
        )
    }

    private func resolveMaxSellQuantity(
        account: Account,
        assetType: AssetType,
        symbol: String,
        editingTransaction: Transaction?
    ) async -> Decimal {
        let options = await SellHoldingAvailability.accountsWithSellCapacity(
            symbol: symbol,
            assetType: assetType,
            candidateAccounts: [account],
            dataService: dataService,
            editingTransaction: editingTransaction
        )
        return options.first?.maxSellQuantity ?? editingTransaction?.quantity ?? 0
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

    private func persistedTransaction(id: String, candidateAccountIds: [String]) async -> Transaction? {
        var checkedAccountIds: [String] = []
        for accountId in candidateAccountIds where !checkedAccountIds.contains(accountId) {
            checkedAccountIds.append(accountId)
            if let transaction = try? await dataService.fetchTransactions(accountId: accountId).first(where: { $0.id == id }) {
                return transaction
            }
        }

        if let transaction = transactions.first(where: { $0.id == id }) {
            return transaction
        }

        return try? await dataService.fetchAllTransactions(userId: AppUser.id).first(where: { $0.id == id })
    }

    private func calculateCostBasis(
        accountId: String,
        assetType: AssetType,
        symbol: String,
        quantity: Decimal,
        averageCostFallback: Decimal,
        excludingTransactionId: String? = nil
    ) async throws -> Decimal {
        let accountTransactions = try await dataService.fetchTransactions(accountId: accountId)
        let costBasis = HoldingCalculator.fifoCostBasis(
            accountId: accountId,
            assetType: assetType,
            symbol: symbol,
            sellQuantity: quantity,
            transactions: accountTransactions,
            excludingTransactionId: excludingTransactionId
        )
        if costBasis > 0 {
            return costBasis
        }
        return averageCostFallback * quantity
    }
}

