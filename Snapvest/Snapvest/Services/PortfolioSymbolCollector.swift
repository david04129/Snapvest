//
//  PortfolioSymbolCollector.swift
//  Snapvest
//

import Foundation

enum PortfolioSymbolCollector {
    static func holdingSymbols(
        userId: String,
        dataService: DataServiceProtocol
    ) async -> [SymbolInfo] {
        let accounts = (try? await dataService.fetchAccounts(userId: userId)) ?? []
        var symbols: [SymbolInfo] = []
        var seen = Set<String>()

        for account in accounts where !account.accountType.isLiabilityAccount && !account.isArchived {
            guard let snapshot = try? await dataService.fetchAccountSnapshot(accountId: account.id),
                  let holdings = snapshot.holdings else {
                continue
            }
            for holding in holdings where holding.assetType != .cash {
                let normalized = SupabasePriceService.normalizeSymbol(
                    assetType: holding.assetType,
                    symbol: holding.symbol
                )
                let key = "\(holding.assetType.rawValue)_\(normalized)"
                guard seen.insert(key).inserted else { continue }
                symbols.append(SymbolInfo(assetType: holding.assetType, symbol: holding.symbol))
            }
        }

        return symbols
    }
}
