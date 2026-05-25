//
//  AccountDeletionSummaryBuilder.swift
//  Snapvest
//
//  刪除帳戶前的警告內容（列出將一併移除的資產與紀錄）
//

import Foundation

enum AccountDeletionSummaryBuilder {
    /// 帳戶列表左滑刪除：自行載入持股與餘額。
    static func buildForAccountList(
        account: Account,
        dataService: DataServiceProtocol,
        balancesByAccountId: [String: AccountBalanceDisplay],
        liabilities: [Liability],
        accounts: [Account]
    ) async -> String {
        let cashBalance = balancesByAccountId[account.id]?.cashBalance ?? 0
        let holdings = await loadHoldingsForPreview(accountId: account.id, dataService: dataService)
        let liability = liabilities.first { $0.accountId == account.id }
        var otherDebtRemaining: Decimal?
        if account.accountType == .otherDebt,
           let transactions = try? await dataService.fetchAllTransactions(userId: account.userId) {
            otherDebtRemaining = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: transactions,
                accounts: accounts
            )
        }
        return await build(
            account: account,
            dataService: dataService,
            cashBalance: cashBalance,
            holdings: holdings,
            liability: liability,
            otherDebtRemaining: otherDebtRemaining
        )
    }

    static func build(
        account: Account,
        dataService: DataServiceProtocol,
        cashBalance: Decimal,
        holdings: [HoldingSnapshot],
        liability: Liability?,
        otherDebtRemaining: Decimal?
    ) async -> String {
        let accountTransactions: [Transaction]
        if let fetched = try? await dataService.fetchTransactions(accountId: account.id) {
            accountTransactions = fetched
        } else {
            accountTransactions = []
        }

        var lines: [String] = []
        lines.append("將永久刪除「\(account.name)」，無法復原。")
        lines.append("")
        lines.append("將一併移除：")
        lines.append("· \(accountTransactions.count) 筆交易紀錄")

        switch account.accountType {
        case .debt:
            appendDebtLines(to: &lines, liability: liability)
        case .otherDebt:
            appendOtherDebtLines(to: &lines, remaining: otherDebtRemaining, currency: account.currency)
        default:
            appendAssetLines(
                to: &lines,
                account: account,
                cashBalance: cashBalance,
                holdings: holdings
            )
        }

        if account.accountType.isLiabilityAccount {
            lines.append("")
            lines.append("其他帳戶上的「還款扣款」紀錄不會自動刪除。")
        }

        return lines.joined(separator: "\n")
    }

    private static func loadHoldingsForPreview(
        accountId: String,
        dataService: DataServiceProtocol
    ) async -> [HoldingSnapshot] {
        if let cached = AccountDetailPresentationStore.holdings(for: accountId), !cached.isEmpty {
            return cached
        }
        guard let snapshot = try? await dataService.fetchAccountSnapshot(accountId: accountId),
              let items = snapshot.holdings else {
            return []
        }
        return items.map { item in
            HoldingSnapshot(
                id: item.id,
                holding: Holding(
                    id: item.id,
                    accountId: accountId,
                    assetType: item.assetType,
                    symbol: item.symbol,
                    name: item.name,
                    quantity: item.quantity,
                    averageCost: item.averageCost,
                    currency: item.currency,
                    lastUpdated: item.lastUpdated
                )
            )
        }
    }

    private static func appendAssetLines(
        to lines: inout [String],
        account: Account,
        cashBalance: Decimal,
        holdings: [HoldingSnapshot]
    ) {
        lines.append("· 現金餘額 \(cashBalance.formatted(currency: account.currency))")

        if holdings.isEmpty {
            lines.append("· 持股：無")
        } else {
            lines.append("· 持股：")
            for item in holdings {
                let holding = item.holding
                let qty = holding.quantity.formattedQuantityInput(
                    maxFractionDigits: holding.assetType == .crypto ? 8 : 4
                )
                lines.append("  \(holding.symbol) × \(qty)")
            }
        }
    }

    private static func appendDebtLines(to lines: inout [String], liability: Liability?) {
        guard let liability else {
            lines.append("· 貸款資訊（若曾建立）")
            return
        }
        lines.append("· 剩餘本金 \(liability.remainingBalance.formatted(currency: liability.currency))")
        lines.append("· 貸款本金 \(liability.principal.formatted(currency: liability.currency))")
        if liability.totalPeriods > 0 {
            lines.append("· 還款進度 \(liability.paidPeriods) / \(liability.totalPeriods) 期")
        }
    }

    private static func appendOtherDebtLines(
        to lines: inout [String],
        remaining: Decimal?,
        currency: Currency
    ) {
        let balance = remaining ?? 0
        lines.append("· 目前欠款 \(balance.formatted(currency: currency))")
    }
}
