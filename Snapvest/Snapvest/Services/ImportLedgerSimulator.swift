//
//  ImportLedgerSimulator.swift
//  Snapvest
//
//  匯入預覽：依日期重播帳本，驗證 sell 可賣量並推算匯入後持股。
//

import Foundation

struct ImportProjectedHolding: Identifiable, Equatable {
    let assetType: AssetType
    let symbol: String
    let quantity: Decimal
    
    var id: String { "\(assetType.rawValue)_\(symbol)" }
    
    var displayKey: String { id }
}

struct ImportLedgerSimulationResult: Equatable {
    let rowErrors: [Int: String]
    let projectedHoldings: [ImportProjectedHolding]
}

enum ImportLedgerSimulator {
    private struct Lot {
        var quantity: Decimal
        var costPerUnit: Decimal
    }
    
    /// 模擬「既有交易 + 本批將匯入的 buy/sell」，依 `transactionDate` 升序重播。
    static func simulate(
        account: Account,
        existingTransactions: [Transaction],
        scheduledImports: [(lineNumber: Int, transaction: Transaction)]
    ) -> ImportLedgerSimulationResult {
        var lots: [String: [Lot]] = [:]
        var rowErrors: [Int: String] = [:]
        
        let existing = existingTransactions
            .filter { $0.accountId == account.id && ($0.type == .buy || $0.type == .sell) }
            .sorted { $0.transactionDate < $1.transactionDate }
        
        var importItems = scheduledImports
        importItems.sort { lhs, rhs in
            lhs.transaction.transactionDate < rhs.transaction.transactionDate
        }
        
        var timeline: [(lineNumber: Int?, transaction: Transaction)] = existing.map { (lineNumber: nil, transaction: $0) }
        timeline.append(contentsOf: importItems.map { (lineNumber: $0.lineNumber, transaction: $0.transaction) })
        timeline.sort { lhs, rhs in
            lhs.transaction.transactionDate < rhs.transaction.transactionDate
        }
        
        for item in timeline {
            let transaction = item.transaction
            let key = lotKey(assetType: transaction.assetType, symbol: transaction.symbol)
            
            switch transaction.type {
            case .buy:
                applyBuy(transaction, key: key, lots: &lots)
            case .sell:
                let available = totalQuantity(lots[key])
                let resolvedRate = SellTransactionValidator.resolvedExchangeRate(
                    account: account,
                    assetType: transaction.assetType,
                    exchangeRate: transaction.exchangeRate
                )
                if let message = SellTransactionValidator.validate(
                    account: account,
                    assetType: transaction.assetType,
                    symbol: transaction.symbol,
                    quantity: transaction.quantity,
                    exchangeRate: resolvedRate,
                    maxSellQuantity: available
                ), let lineNumber = item.lineNumber {
                    rowErrors[lineNumber] = message
                    continue
                }
                if transaction.quantity > available {
                    let digits = transaction.assetType == .crypto ? 8 : 4
                    let maxLabel = available.formattedQuantityInput(maxFractionDigits: digits)
                    let message = "數量不可超過可賣數量（\(maxLabel)）"
                    if let lineNumber = item.lineNumber {
                        rowErrors[lineNumber] = message
                    }
                    continue
                }
                applySell(transaction, key: key, lots: &lots)
            default:
                break
            }
        }
        
        let projected = buildProjectedHoldings(from: lots)
        return ImportLedgerSimulationResult(rowErrors: rowErrors, projectedHoldings: projected)
    }
    
    private static func lotKey(assetType: AssetType, symbol: String) -> String {
        let normalized = normalizedSymbol(assetType: assetType, symbol: symbol)
        return "\(assetType.rawValue)_\(normalized)"
    }
    
    private static func normalizedSymbol(assetType: AssetType, symbol: String) -> String {
        switch assetType {
        case .crypto:
            return SymbolListService.normalizedCryptoSymbol(symbol)
        case .stockTW, .stockUS:
            return symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        default:
            return symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private static func totalQuantity(_ lots: [Lot]?) -> Decimal {
        (lots ?? []).reduce(0) { $0 + $1.quantity }
    }
    
    private static func applyBuy(_ transaction: Transaction, key: String, lots: inout [String: [Lot]]) {
        guard transaction.quantity > 0 else { return }
        let costPerUnit = transaction.totalAmountWithFee / transaction.quantity
        var bucket = lots[key] ?? []
        bucket.append(Lot(quantity: transaction.quantity, costPerUnit: costPerUnit))
        lots[key] = bucket
    }
    
    private static func applySell(_ transaction: Transaction, key: String, lots: inout [String: [Lot]]) {
        guard var bucket = lots[key], !bucket.isEmpty else {
            lots[key] = nil
            return
        }
        var remaining = transaction.quantity
        while remaining > 0, !bucket.isEmpty {
            let oldest = bucket[0]
            if oldest.quantity <= remaining {
                remaining -= oldest.quantity
                bucket.removeFirst()
            } else {
                bucket[0].quantity -= remaining
                remaining = 0
            }
        }
        lots[key] = bucket.isEmpty ? nil : bucket
    }
    
    private static func buildProjectedHoldings(from lots: [String: [Lot]]) -> [ImportProjectedHolding] {
        var result: [ImportProjectedHolding] = []
        for (key, bucket) in lots {
            let qty = bucket.reduce(0) { $0 + $1.quantity }
            guard qty > 0 else { continue }
            guard let parsed = parseLotKey(key) else { continue }
            result.append(ImportProjectedHolding(assetType: parsed.0, symbol: parsed.1, quantity: qty))
        }
        return result.sorted {
            $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending
        }
    }
    
    /// `lotKey` 為 `\(assetType.rawValue)_\(symbol)`；台美股 rawValue 含 `_`，不可用第一個 `_` 切分。
    private static func parseLotKey(_ key: String) -> (AssetType, String)? {
        let orderedTypes = AssetType.allCases.sorted { $0.rawValue.count > $1.rawValue.count }
        for assetType in orderedTypes {
            let prefix = "\(assetType.rawValue)_"
            guard key.hasPrefix(prefix) else { continue }
            let symbol = String(key.dropFirst(prefix.count))
            guard !symbol.isEmpty else { return nil }
            return (assetType, symbol)
        }
        return nil
    }
}
