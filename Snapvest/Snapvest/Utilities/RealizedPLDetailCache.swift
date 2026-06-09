//
//  RealizedPLDetailCache.swift
//  Snapvest
//
//  已實現損益明細：展開時才載入，避免首頁每次 appear 全量拉交易。
//

import Foundation

@MainActor
enum RealizedPLDetailCache {
    private(set) static var sellTransactions: [Transaction] = []
    private static var cachedUserId: String?

    static func isLoaded(for userId: String) -> Bool {
        cachedUserId == userId
    }

    static func apply(userId: String, transactions: [Transaction]) {
        cachedUserId = userId
        sellTransactions = transactions.filter { $0.type == .sell }
    }

    static func invalidate() {
        cachedUserId = nil
        sellTransactions = []
        SymbolRealizedPLCache.invalidate()
    }
}

struct SymbolRealizedPL: Equatable {
    var amountByCurrency: [Currency: Decimal]
    
    static let zero = SymbolRealizedPL(amountByCurrency: [:])
    
    func amount(in currency: Currency) -> Decimal {
        amountByCurrency[currency] ?? 0
    }
    
    func amountInTWD(usdToTwdRate: Decimal) -> Decimal {
        amountByCurrency.reduce(Decimal.zero) { partial, entry in
            let (currency, amount) = entry
            switch currency {
            case .TWD:
                return partial + amount
            case .USD:
                guard usdToTwdRate > 0 else { return partial }
                return partial + amount * usdToTwdRate
            default:
                return partial
            }
        }
    }
}

@MainActor
enum SymbolRealizedPLCache {
    private static var cachedUserId: String?
    private static var amountBySymbolKey: [String: SymbolRealizedPL] = [:]
    
    static func value(
        userId: String,
        assetType: AssetType,
        symbol: String
    ) -> SymbolRealizedPL {
        guard cachedUserId == userId else { return .zero }
        return amountBySymbolKey[key(assetType: assetType, symbol: symbol)] ?? .zero
    }
    
    static func loadIfNeeded(
        userId: String,
        dataService: DataServiceProtocol
    ) async throws {
        guard cachedUserId != userId else { return }
        
        let transactions = try await dataService.fetchAllTransactions(userId: userId)
        var grouped: [String: [Currency: Decimal]] = [:]
        
        for transaction in transactions where transaction.type == .sell {
            guard let realizedGainLoss = transaction.realizedGainLoss else { continue }
            let key = key(assetType: transaction.assetType, symbol: transaction.symbol)
            grouped[key, default: [:]][transaction.currency, default: 0] += realizedGainLoss
        }
        
        amountBySymbolKey = grouped.mapValues { SymbolRealizedPL(amountByCurrency: $0) }
        cachedUserId = userId
    }
    
    static func invalidate() {
        cachedUserId = nil
        amountBySymbolKey = [:]
    }
    
    private static func key(assetType: AssetType, symbol: String) -> String {
        "\(assetType.rawValue)_\(normalizedSymbol(assetType: assetType, symbol: symbol))"
    }
    
    private static func normalizedSymbol(assetType: AssetType, symbol: String) -> String {
        switch assetType {
        case .crypto:
            return SymbolListService.normalizedCryptoSymbol(symbol)
        default:
            return symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
    }
}
