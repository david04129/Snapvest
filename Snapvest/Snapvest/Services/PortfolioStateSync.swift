//
//  PortfolioStateSync.swift
//  Snapvest
//
//  交易完成後，將現金 / 持股 / 負債狀態同步至後端
//

import Foundation

enum PortfolioStateSync {
    /// 重建快照後同步（或沿用既有 bundle）
    static func sync(
        userId: String,
        dataService: DataServiceProtocol,
        priceService: PriceServiceProtocol,
        bundle: SnapshotBundle? = nil
    ) async {
        do {
            let resolvedBundle: SnapshotBundle
            if let bundle {
                resolvedBundle = bundle
            } else {
                resolvedBundle = try await SnapshotUpdater.rebuildSnapshots(
                    userId: userId,
                    dataService: dataService,
                    priceService: priceService
                )
            }
            
            let accounts = try await dataService.fetchAccounts(userId: userId)
            let transactions = try await dataService.fetchAllTransactions(userId: userId)
            let liabilities = try await loadAllLiabilities(
                userId: userId,
                accounts: accounts,
                dataService: dataService
            )
            
            let payload = PortfolioStateSyncBuilder.build(
                userId: userId,
                accounts: accounts,
                accountSnapshots: resolvedBundle.accountSnapshots,
                aggregatedHoldings: resolvedBundle.aggregatedHoldings,
                liabilities: liabilities,
                transactions: transactions
            )
            
            try await dataService.syncPortfolioState(payload)
        } catch {
            #if DEBUG
            print("[PortfolioStateSync] failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    private static func loadAllLiabilities(
        userId: String,
        accounts: [Account],
        dataService: DataServiceProtocol
    ) async throws -> [Liability] {
        var all: [Liability] = []
        for account in accounts {
            let batch = try await dataService.fetchLiabilities(accountId: account.id)
            all.append(contentsOf: batch)
        }
        return all
    }
}
