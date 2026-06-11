//
//  TransactionImportService.swift
//  Snapvest
//
//  驗證 CSV 列並轉成 Transaction
//

import Foundation

struct TransactionImportValidatedRow: Identifiable, Equatable {
    let id: Int
    let lineNumber: Int
    let summary: String
    let transaction: Transaction?
    let errorMessage: String?
    /// 非錯誤、但不會寫入（例如存入／提取）
    let skipReason: String?
    
    var isSkipped: Bool { skipReason != nil }
    var isValid: Bool { errorMessage == nil && transaction != nil && !isSkipped }
}

struct TransactionImportValidationResult: Equatable {
    let rows: [TransactionImportValidatedRow]
    
    var validTransactions: [Transaction] {
        rows.filter(\.isValid).compactMap(\.transaction)
    }
    
    var importableCount: Int {
        rows.filter(\.isValid).count
    }
    
    var skippedRows: [TransactionImportValidatedRow] {
        rows.filter(\.isSkipped)
    }
    
    var errorCount: Int {
        rows.filter { $0.errorMessage != nil }.count
    }
    
    var canImport: Bool {
        importableCount > 0 && errorCount == 0
    }
}

struct TransactionImportBatchFailure: Identifiable, Equatable {
    let lineNumber: Int
    let summary: String
    let errorMessage: String
    
    var id: Int { lineNumber }
}

struct TransactionImportBatchResult: Equatable {
    let imported: Int
    let failures: [TransactionImportBatchFailure]
    
    var isFullSuccess: Bool { imported > 0 && failures.isEmpty }
    
    var alertTitle: String {
        if failures.isEmpty { return "匯入成功" }
        return imported > 0 ? "匯入完成" : "匯入失敗"
    }
    
    var alertMessage: String {
        var lines: [String] = []
        if imported > 0 {
            lines.append("成功 \(imported) 筆")
        }
        if !failures.isEmpty {
            lines.append("失敗 \(failures.count) 筆：")
            for failure in failures {
                if failure.lineNumber > 0 {
                    lines.append("· 第 \(failure.lineNumber) 列 \(failure.summary)：\(failure.errorMessage)")
                } else {
                    lines.append("· \(failure.summary)：\(failure.errorMessage)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

enum TransactionImportError: LocalizedError {
    case missingAccount
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAccount: return "找不到交易所屬帳戶"
        case .validationFailed(let message): return message
        }
    }
}

enum TransactionImportService {
    static let supportedTypes: Set<TransactionType> = [
        .buy, .sell, .deposit, .withdraw, .dividend
    ]
    
    /// 帳戶詳情 CSV 匯入僅接受股票買賣
    static func importableTypes(for account: Account) -> Set<TransactionType> {
        if account.accountType.supportsTransactionImport {
            return [.buy, .sell]
        }
        return supportedTypes
    }
    
    static func skippedTypeReason(for type: TransactionType, account: Account) -> String? {
        guard account.accountType.supportsTransactionImport else { return nil }
        guard !importableTypes(for: account).contains(type) else { return nil }
        return "非股票交易（\(type.displayName)），已略過"
    }
    
    /// 此帳戶 CSV 匯入允許的 asset_type
    static func allowedAssetTypes(for account: Account) -> Set<AssetType> {
        switch account.accountType {
        case .usdAccount:
            return [.stockUS]
        case .twdSecurities:
            return [.stockTW]
        case .cryptoWallet:
            return [.crypto]
        default:
            return []
        }
    }
    
    static func assetTypeAccountMismatchMessage(assetType: AssetType, account: Account) -> String? {
        guard account.accountType.supportsTransactionImport else { return nil }
        guard !allowedAssetTypes(for: account).contains(assetType) else { return nil }
        switch account.accountType {
        case .usdAccount:
            switch assetType {
            case .stockTW:
                return "此為美股證券帳戶，不可匯入台股（請改在台股證券匯入）"
            case .crypto:
                return "此為美股證券帳戶，不可匯入加密貨幣"
            default:
                return "此帳戶不支援 asset_type「\(assetType.rawValue)」"
            }
        case .twdSecurities:
            switch assetType {
            case .stockUS:
                return "此為台股證券帳戶，不可匯入美股（請改在美股證券匯入）"
            case .crypto:
                return "此為台股證券帳戶，不可匯入加密貨幣"
            default:
                return "此帳戶不支援 asset_type「\(assetType.rawValue)」"
            }
        case .cryptoWallet:
            switch assetType {
            case .stockTW:
                return "此為加密貨幣帳戶，不可匯入台股"
            case .stockUS:
                return "此為加密貨幣帳戶，不可匯入美股"
            default:
                return "此帳戶不支援 asset_type「\(assetType.rawValue)」"
            }
        default:
            return "此帳戶不支援 asset_type「\(assetType.rawValue)」"
        }
    }
    
    static func validate(
        parsedRows: [TransactionImportParsedRow],
        account: Account
    ) -> TransactionImportValidationResult {
        let validated = parsedRows.map { row in
            validateRow(row, account: account)
        }
        
        return TransactionImportValidationResult(rows: validated)
    }
    
    /// 匯入預覽：使用者於買賣表單編輯後更新草稿列
    static func validatedRow(
        from draft: Transaction,
        lineNumber: Int,
        account: Account
    ) -> TransactionImportValidatedRow {
        var normalized = draft
        normalized.accountId = account.id
        
        var errors: [String] = []
        if normalized.quantity <= 0 {
            errors.append("quantity 必須大於 0")
        }
        if normalized.type == .buy || normalized.type == .sell {
            if normalized.price <= 0 {
                errors.append("price 必填且須大於 0")
            }
        } else if normalized.price < 0 {
            errors.append("price 無效")
        }
        if normalized.type == .buy || normalized.type == .sell {
            if normalized.symbol.isEmpty {
                errors.append("需填 symbol")
            }
            if let message = assetTypeAccountMismatchMessage(
                assetType: normalized.assetType,
                account: account
            ) {
                errors.append(message)
            }
        }
        
        if !errors.isEmpty {
            return TransactionImportValidatedRow(
                id: lineNumber,
                lineNumber: lineNumber,
                summary: "",
                transaction: nil,
                errorMessage: errors.joined(separator: "；"),
                skipReason: nil
            )
        }
        
        return TransactionImportValidatedRow(
            id: lineNumber,
            lineNumber: lineNumber,
            summary: "",
            transaction: normalized,
            errorMessage: nil,
            skipReason: nil
        )
    }
    
    static func validationResult(from rows: [TransactionImportValidatedRow]) -> TransactionImportValidationResult {
        TransactionImportValidationResult(rows: rows)
    }
    
    /// 合併帳本模擬錯誤（例如 sell 超過可賣量）至預覽列。
    static func applyLedgerSimulation(
        rows: [TransactionImportValidatedRow],
        simulation: ImportLedgerSimulationResult
    ) -> [TransactionImportValidatedRow] {
        rows.map { row in
            guard let message = simulation.rowErrors[row.lineNumber] else { return row }
            if let existing = row.errorMessage, !existing.isEmpty {
                return row
            }
            return TransactionImportValidatedRow(
                id: row.id,
                lineNumber: row.lineNumber,
                summary: row.summary,
                transaction: row.transaction,
                errorMessage: message,
                skipReason: row.skipReason
            )
        }
    }
    
    /// 對已通過格式驗證的 buy/sell 列，向 Supabase 確認可取得有效報價（方案 A）。
    static func applyPriceValidation(
        to result: TransactionImportValidationResult
    ) async -> TransactionImportValidationResult {
        var uniqueSymbols: [String: (AssetType, String)] = [:]
        for row in result.rows {
            guard row.errorMessage == nil, !row.isSkipped,
                  let transaction = row.transaction,
                  SymbolPriceValidator.needsValidation(
                    assetType: transaction.assetType,
                    transactionType: transaction.type
                  ) else { continue }
            let key = SymbolPriceValidator.priceValidationKey(
                assetType: transaction.assetType,
                symbol: transaction.symbol
            )
            if uniqueSymbols[key] == nil {
                uniqueSymbols[key] = (transaction.assetType, transaction.symbol)
            }
        }
        
        let symbolInfos = uniqueSymbols.values.map {
            SymbolInfo(assetType: $0.0, symbol: $0.1)
        }
        let priceFailures = await SymbolPriceValidator.validatePricesAvailable(symbols: symbolInfos)
        
        let updatedRows = result.rows.map { row in
            rowWithPriceValidation(row, priceFailures: priceFailures)
        }
        return TransactionImportValidationResult(rows: updatedRows)
    }
    
    private static func rowWithPriceValidation(
        _ row: TransactionImportValidatedRow,
        priceFailures: [String: String]
    ) -> TransactionImportValidatedRow {
        guard row.errorMessage == nil, !row.isSkipped,
              let transaction = row.transaction,
              SymbolPriceValidator.needsValidation(
                assetType: transaction.assetType,
                transactionType: transaction.type
              ) else {
            return row
        }
        
        let key = SymbolPriceValidator.priceValidationKey(
            assetType: transaction.assetType,
            symbol: transaction.symbol
        )
        guard let priceError = priceFailures[key] else { return row }
        
        return TransactionImportValidatedRow(
            id: row.id,
            lineNumber: row.lineNumber,
            summary: row.summary,
            transaction: transaction,
            errorMessage: priceError,
            skipReason: nil
        )
    }
    
    static func tradeCurrency(assetType: AssetType, account: Account, explicit: Currency?) -> Currency {
        if let explicit { return explicit }
        switch assetType {
        case .stockUS, .crypto:
            return .USD
        case .stockTW:
            return .TWD
        case .cash:
            return account.currency
        }
    }
    
    private static func validateRow(
        _ row: TransactionImportParsedRow,
        account: Account
    ) -> TransactionImportValidatedRow {
        var errors: [String] = []
        
        let type = row.type
        if type == nil {
            errors.append("type 無效")
        } else if let type, !supportedTypes.contains(type) {
            errors.append("type「\(type.rawValue)」尚不支援匯入")
        } else if let type, account.accountType == .twdDeposit, type == .buy || type == .sell {
            errors.append("台幣存款帳戶不支援 buy/sell")
        }
        
        let date = row.date
        if date == nil {
            errors.append("date 格式錯誤")
        }
        
        let quantity = row.quantity
        if quantity == nil || (quantity ?? 0) <= 0 {
            errors.append("quantity 必須大於 0")
        }
        
        let price = row.price
        if let type, type == .buy || type == .sell {
            if price == nil || (price ?? 0) <= 0 {
                errors.append("price 必填且須大於 0")
            }
        } else if price == nil || (price ?? -1) < 0 {
            errors.append("price 無效")
        }
        
        if let type, type == .deposit || type == .withdraw {
            if row.currency != nil, row.currency != account.currency {
                errors.append("currency 須與此帳戶 \(account.currency.rawValue) 一致，或留空使用帳戶幣別")
            }
        }
        
        var assetType = resolveAssetType(row: row, account: account)
        var symbol = normalizedSymbol(row.symbol, assetType: assetType)
        
        switch row.type {
        case .buy, .sell, .dividend:
            if assetType == nil {
                errors.append("buy/sell/dividend 需填 asset_type")
            }
            if symbol.isEmpty {
                errors.append("buy/sell/dividend 需填 symbol")
            }
            if let assetType {
                if let message = assetTypeAccountMismatchMessage(assetType: assetType, account: account) {
                    errors.append(message)
                }
                if let message = symbolAccountMismatchMessage(
                    symbol: symbol,
                    assetType: assetType,
                    account: account
                ) {
                    errors.append(message)
                }
            }
        case .deposit, .withdraw:
            assetType = .cash
            symbol = "CASH"
        default:
            break
        }
        
        if !errors.isEmpty {
            return TransactionImportValidatedRow(
                id: row.id,
                lineNumber: row.lineNumber,
                summary: previewSummary(row, account: account),
                transaction: nil,
                errorMessage: errors.joined(separator: "；"),
                skipReason: nil
            )
        }
        
        guard
            let type,
            let date,
            let quantity,
            let price,
            let assetType
        else {
            return TransactionImportValidatedRow(
                id: row.id,
                lineNumber: row.lineNumber,
                summary: previewSummary(row, account: account),
                transaction: nil,
                errorMessage: "資料不完整",
                skipReason: nil
            )
        }
        
        let currency = tradeCurrency(assetType: assetType, account: account, explicit: row.currency)
        
        let transaction = buildTransaction(
            row: row,
            type: type,
            date: date,
            quantity: quantity,
            price: price,
            currency: currency,
            account: account,
            assetType: assetType,
            symbol: symbol
        )
        
        let summary = previewSummary(row, account: account, type: type, symbol: symbol)
        if let skipReason = skippedTypeReason(for: type, account: account) {
            return TransactionImportValidatedRow(
                id: row.id,
                lineNumber: row.lineNumber,
                summary: summary,
                transaction: transaction,
                errorMessage: nil,
                skipReason: skipReason
            )
        }
        
        return TransactionImportValidatedRow(
            id: row.id,
            lineNumber: row.lineNumber,
            summary: summary,
            transaction: transaction,
            errorMessage: nil,
            skipReason: nil
        )
    }
    
    private static func buildTransaction(
        row: TransactionImportParsedRow,
        type: TransactionType,
        date: Date,
        quantity: Decimal,
        price: Decimal,
        currency: Currency,
        account: Account,
        assetType: AssetType,
        symbol: String
    ) -> Transaction {
        var notes = row.notes
        
        if type == .buy || type == .sell {
            notes = tradeNotes(
                type: type,
                assetType: assetType,
                symbol: symbol,
                existingNotes: notes
            )
        }
        
        if type == .deposit || type == .withdraw {
            notes = notes ?? (type == .deposit ? "CSV 匯入存入" : "CSV 匯入提取")
        }
        
        return Transaction(
            accountId: account.id,
            type: type,
            assetType: assetType,
            symbol: symbol,
            quantity: quantity,
            price: price,
            currency: currency,
            fee: row.fee,
            notes: notes,
            transactionDate: date,
            exchangeRate: row.exchangeRate,
            deductFromAccount: type == .buy ? row.deductFromAccount : nil
        )
    }
    
    private static func tradeNotes(
        type: TransactionType,
        assetType: AssetType,
        symbol: String,
        existingNotes: String?
    ) -> String? {
        if let existingNotes, !existingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existingNotes
        }
        let action = type == .buy ? "買入" : "賣出"
        if assetType == .stockTW, let displayName = SymbolListService.twDisplayName(for: symbol) {
            return "\(action) \(symbol) - \(displayName)"
        }
        return "\(action) \(symbol)"
    }
    
    private static func resolveAssetType(row: TransactionImportParsedRow, account: Account) -> AssetType? {
        if let explicit = row.assetType {
            return explicit
        }
        guard row.type == .buy || row.type == .sell || row.type == .dividend else {
            return inferredAssetType(for: account, type: row.type)
        }
        switch account.accountType {
        case .usdAccount:
            return .stockUS
        case .twdSecurities:
            let sym = row.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sym.isEmpty, sym.allSatisfy(\.isNumber) {
                return .stockTW
            }
            return .stockUS
        default:
            return inferredAssetType(for: account, type: row.type)
        }
    }
    
    /// 美金戶若出現純數字代號（像台股），或台幣戶標成美股卻像台股代號
    private static func symbolAccountMismatchMessage(
        symbol: String,
        assetType: AssetType,
        account: Account
    ) -> String? {
        let sym = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sym.isEmpty else { return nil }
        let looksLikeTW = sym.allSatisfy(\.isNumber)
        
        switch account.accountType {
        case .usdAccount:
            if assetType == .stockTW || looksLikeTW {
                return "代號「\(sym)」為台股格式，請在台股證券匯入"
            }
        case .twdSecurities:
            if assetType == .stockUS, looksLikeTW {
                return "代號「\(sym)」像台股，請將 asset_type 改為 stock_tw"
            }
        default:
            break
        }
        return nil
    }
    
    private static func inferredAssetType(for account: Account, type: TransactionType?) -> AssetType? {
        switch account.accountType {
        case .twdSecurities: return .stockTW
        case .usdAccount: return .stockUS
        case .cryptoWallet: return .crypto
        case .twdDeposit: return type == .deposit || type == .withdraw ? .cash : nil
        default: return nil
        }
    }
    
    private static func previewSummary(
        _ row: TransactionImportParsedRow,
        account: Account? = nil,
        type: TransactionType? = nil,
        symbol: String? = nil
    ) -> String {
        let typeText = (type ?? row.type)?.displayName ?? row.rawFields["type"] ?? "?"
        let accountText = account?.name ?? "—"
        let symbolText = symbol ?? row.symbol
        let dateText = row.date.map { formatDate($0) } ?? row.rawFields["date"] ?? "?"
        return "第 \(row.lineNumber) 列 · \(dateText) · \(typeText) · \(accountText) · \(symbolText)"
    }
    
    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }
    
    private static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private static func normalizedSymbol(_ symbol: String, assetType: AssetType?) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        guard let assetType else { return trimmed }
        switch assetType {
        case .stockTW, .stockUS, .crypto:
            return trimmed.uppercased()
        default:
            return trimmed
        }
    }
}
