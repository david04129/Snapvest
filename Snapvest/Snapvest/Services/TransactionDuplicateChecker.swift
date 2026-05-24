//
//  TransactionDuplicateChecker.swift
//  Snapvest
//
//  比對 buy/sell 是否與既有或同批匯入交易重複（指紋相同；symbol 字面一致，FI ≠ FISV）。
//

import Foundation

struct TransactionDuplicateMatch: Equatable {
    enum Source: Equatable {
        case existing
        case importBatch(lineNumber: Int)
    }
    
    let source: Source
    let referenceTransaction: Transaction
    
    var detailMessage: String {
        switch source {
        case .existing:
            return "與帳戶中既有交易相同"
        case .importBatch(let lineNumber):
            return "與本次 CSV 第 \(lineNumber) 列相同"
        }
    }
}

struct TransactionFingerprint: Hashable {
    let accountId: String
    let type: TransactionType
    let assetType: AssetType
    let symbol: String
    let day: Date
    let quantityKey: String
    let priceKey: String
}

enum TransactionDuplicateChecker {
    private static let quantityScale = 8
    private static let priceScale = 6
    
    static func needsDuplicateCheck(_ type: TransactionType) -> Bool {
        type == .buy || type == .sell
    }
    
    static func fingerprint(for transaction: Transaction) -> TransactionFingerprint? {
        guard needsDuplicateCheck(transaction.type) else { return nil }
        
        let symbol = SupabasePriceService.normalizeSymbol(
            assetType: transaction.assetType,
            symbol: transaction.symbol
        )
        guard !symbol.isEmpty else { return nil }
        
        return TransactionFingerprint(
            accountId: transaction.accountId,
            type: transaction.type,
            assetType: transaction.assetType,
            symbol: symbol,
            day: Calendar.current.startOfDay(for: transaction.transactionDate),
            quantityKey: decimalKey(transaction.quantity, scale: quantityScale),
            priceKey: decimalKey(transaction.price, scale: priceScale)
        )
    }
    
    static func matches(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        guard let left = fingerprint(for: lhs), let right = fingerprint(for: rhs) else {
            return false
        }
        return left == right
    }
    
    static func findDuplicate(
        for transaction: Transaction,
        in existing: [Transaction],
        excludingTransactionId: String? = nil
    ) -> Transaction? {
        guard fingerprint(for: transaction) != nil else { return nil }
        
        return existing.first { candidate in
            if let excludingTransactionId, candidate.id == excludingTransactionId {
                return false
            }
            return matches(transaction, candidate)
        }
    }
    
    /// 僅對已通過格式／股價驗證的列比對；回傳 lineNumber → 重複資訊。
    static func duplicateMatches(
        for rows: [TransactionImportValidatedRow],
        existingTransactions: [Transaction]
    ) -> [Int: TransactionDuplicateMatch] {
        var matches: [Int: TransactionDuplicateMatch] = [:]
        var seenInBatch: [TransactionFingerprint: (lineNumber: Int, transaction: Transaction)] = [:]
        
        let candidates = rows
            .filter { $0.isValid }
            .sorted { $0.lineNumber < $1.lineNumber }
        
        for row in candidates {
            guard let transaction = row.transaction,
                  needsDuplicateCheck(transaction.type) else { continue }
            
            if let existing = findDuplicate(for: transaction, in: existingTransactions) {
                matches[row.lineNumber] = TransactionDuplicateMatch(
                    source: .existing,
                    referenceTransaction: existing
                )
                continue
            }
            
            guard let fingerprint = fingerprint(for: transaction) else { continue }
            if let earlier = seenInBatch[fingerprint] {
                matches[row.lineNumber] = TransactionDuplicateMatch(
                    source: .importBatch(lineNumber: earlier.lineNumber),
                    referenceTransaction: earlier.transaction
                )
            } else {
                seenInBatch[fingerprint] = (row.lineNumber, transaction)
            }
        }
        
        return matches
    }
    
    static func summary(for transaction: Transaction) -> String {
        let display = TransactionDisplayFormatter(transaction: transaction)
        let dateText = transaction.transactionDate.formatted(date: .numeric, time: .omitted)
        if let detail = display.tradeDetailLine {
            return "\(dateText) · \(display.primaryTitle) · \(detail)"
        }
        return "\(dateText) · \(display.primaryTitle)"
    }
    
    static func alertMessage(
        for transaction: Transaction,
        existing: Transaction
    ) -> String {
        """
        此交易與帳戶中既有紀錄相同：
        \(summary(for: existing))
        
        是否仍要建立一筆相同的交易？
        """
    }
    
    private static func decimalKey(_ value: Decimal, scale: Int) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, scale, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
