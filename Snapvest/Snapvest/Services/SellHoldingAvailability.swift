//
//  SellHoldingAvailability.swift
//  Snapvest
//
//  賣出／編輯賣出：哪些帳戶持有該標的、最多可賣幾股。
//

import Foundation

struct SellAccountOption: Identifiable, Equatable {
    let account: Account
    let maxSellQuantity: Decimal

    var id: String { account.id }
}

enum SellHoldingAvailability {
    static func accountsWithSellCapacity(
        symbol: String,
        assetType: AssetType,
        candidateAccounts: [Account],
        dataService: DataServiceProtocol,
        editingTransaction: Transaction?
    ) async -> [SellAccountOption] {
        let normalizedSymbol = assetType == .crypto
            ? SymbolListService.normalizedCryptoSymbol(symbol)
            : symbol

        var options: [SellAccountOption] = []
        for account in candidateAccounts {
            guard let transactions = try? await dataService.fetchTransactions(accountId: account.id) else {
                continue
            }
            let holdings = HoldingCalculator.calculateHoldings(from: transactions)
            let holdingQty = holdings.first(where: {
                $0.assetType == assetType && symbolsMatch($0.symbol, normalizedSymbol)
            })?.quantity ?? 0

            var maxQty = holdingQty
            if let editing = editingTransaction,
               editing.accountId == account.id,
               editing.assetType == assetType,
               symbolsMatch(editing.symbol, normalizedSymbol) {
                maxQty += editing.quantity
            }

            guard maxQty > 0 else { continue }
            options.append(SellAccountOption(account: account, maxSellQuantity: maxQty))
        }

        return options.sorted { $0.account.name.localizedStandardCompare($1.account.name) == .orderedAscending }
    }

    private static func symbolsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs
    }
}
