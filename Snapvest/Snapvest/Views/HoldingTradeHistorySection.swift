//
//  HoldingTradeHistorySection.swift
//  Snapvest
//
//  個股詳情：依帳戶顯示此標的買賣交易（僅 UI／載入，不變更 FIFO 計算）。
//

import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class HoldingTradeHistoryViewModel: ObservableObject {
    struct AccountGroup: Identifiable {
        let account: Account
        /// 此帳戶、此標的的 buy / sell（日期新→舊，由 section 依排序狀態重排）
        var trades: [Transaction]
        /// 該帳戶全部交易（供餘額計算）
        let allAccountTransactions: [Transaction]

        var id: String { account.id }
    }

    @Published private(set) var groups: [AccountGroup] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }

    private static func normalizedSymbol(assetType: AssetType, symbol: String) -> String {
        switch assetType {
        case .crypto:
            return SymbolListService.normalizedCryptoSymbol(symbol)
        default:
            return symbol
        }
    }

    private static func matchesHolding(_ transaction: Transaction, holding: AggregatedHoldingSnapshot) -> Bool {
        guard transaction.assetType == holding.assetType else { return false }
        guard transaction.type == .buy || transaction.type == .sell else { return false }
        let target = normalizedSymbol(assetType: holding.assetType, symbol: holding.symbol)
        let candidate = normalizedSymbol(assetType: transaction.assetType, symbol: transaction.symbol)
        return target.caseInsensitiveCompare(candidate) == .orderedSame
    }

    func load(holding: AggregatedHoldingSnapshot) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let accounts = try await dataService.fetchAccounts(userId: holding.userId)
            let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })

            var accountIds = Set(holding.sourceAccountIds)
            for group in holding.fifoLotsByAccount {
                accountIds.insert(group.accountId)
            }
            if accountIds.isEmpty {
                accountIds = Set(
                    accounts
                        .filter { $0.accountType.supportsStockTrading && !$0.isArchived }
                        .map(\.id)
                )
            }

            var built: [AccountGroup] = []
            for accountId in accountIds {
                guard let account = accountMap[accountId] else { continue }
                let all = try await dataService.fetchTransactions(accountId: accountId)
                let sortedAll = all.sorted { $0.transactionDate > $1.transactionDate }
                let trades = sortedAll.filter { Self.matchesHolding($0, holding: holding) }
                guard !trades.isEmpty else { continue }
                built.append(
                    AccountGroup(
                        account: account,
                        trades: trades,
                        allAccountTransactions: sortedAll
                    )
                )
            }

            groups = built.sorted {
                $0.account.name.localizedStandardCompare($1.account.name) == .orderedAscending
            }
        } catch {
            errorMessage = "載入交易紀錄失敗：\(error.localizedDescription)"
            groups = []
        }
    }

    func balance(
        after transaction: Transaction,
        accountId: String,
        accountCurrency: Currency,
        in group: AccountGroup
    ) -> Decimal {
        guard let index = group.allAccountTransactions.firstIndex(where: { $0.id == transaction.id }) else {
            return 0
        }

        var balance: Decimal = 0
        for i in (index..<group.allAccountTransactions.count).reversed() {
            let t = group.allAccountTransactions[i]
            switch t.type {
            case .deposit, .dividend:
                balance += t.totalAmount
            case .sell:
                balance += CashCalculator.buySellAmountInAccountCurrency(
                    transaction: t,
                    accountCurrency: accountCurrency
                )
            case .withdraw, .fee, .liability:
                balance -= t.totalAmountWithFee
            case .buy:
                if t.deductFromAccount == true {
                    balance -= CashCalculator.buySellAmountInAccountCurrency(
                        transaction: t,
                        accountCurrency: accountCurrency
                    )
                }
            case .repayment:
                if t.accountId == accountId {
                    let principal = t.principalAmount ?? t.totalAmount
                    balance -= principal
                }
            }
        }
        return balance
    }
}

// MARK: - Section

struct HoldingTradeHistorySection: View {
    let aggregatedHolding: AggregatedHoldingSnapshot
    let currentPrice: Decimal?
    let usdToTwdRate: Decimal

    @StateObject private var historyViewModel = HoldingTradeHistoryViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @State private var dateSort: HoldingsMarketValueSort = .descending
    @State private var buyTradeEditItem: BuyTradeEditItem?
    @State private var sellTradeEditItem: SellTradeEditItem?
    @State private var transactionPendingDelete: Transaction?
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String?

    private var holdingAccentColor: Color {
        HoldingColorPreferences.getColor(
            for: aggregatedHolding.symbol,
            assetType: aggregatedHolding.assetType
        )
    }

    private var totalTradeCount: Int {
        historyViewModel.groups.reduce(0) { $0 + $1.trades.count }
    }

    var body: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                if historyViewModel.isLoading && historyViewModel.groups.isEmpty {
                    loadingPlaceholder
                } else if let errorMessage = historyViewModel.errorMessage,
                          historyViewModel.groups.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                        .fixedSize(horizontal: false, vertical: true)
                } else if historyViewModel.groups.isEmpty {
                    Text("尚無買賣紀錄")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    tradeList
                }
            }
        }
        .task(id: aggregatedHolding.id) {
            await historyViewModel.load(holding: aggregatedHolding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            Task { await historyViewModel.load(holding: aggregatedHolding) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
            Task { await historyViewModel.load(holding: aggregatedHolding) }
        }
        .sheet(item: $buyTradeEditItem) { item in
            editBuyTradeSheet(item: item)
        }
        .sheet(item: $sellTradeEditItem) { item in
            editSellTradeSheet(item: item)
        }
        .alert("刪除這筆紀錄？", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { transactionPendingDelete = nil }
            Button("刪除", role: .destructive) {
                guard let transaction = transactionPendingDelete else { return }
                transactionPendingDelete = nil
                Task { await handleDeleteTransaction(transaction) }
            }
        } message: {
            if let transaction = transactionPendingDelete {
                Text(transaction.deleteConfirmationMessage)
            }
        }
        .alert("無法刪除", isPresented: $showingDeleteError) {
            Button("好", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("交易紀錄")
                .font(.headline)
                .foregroundColor(.primaryText)

            Spacer(minLength: 8)

            if totalTradeCount > 0 {
                Text("共 \(totalTradeCount) 筆")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
            }

            AssetsFilterChipButton(
                title: "日期",
                icon: dateSort.iconName,
                isActive: true
            ) {
                withAnimation(ChartMotion.switchSpring) {
                    dateSort.cycle()
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("載入中…")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var tradeList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(historyViewModel.groups) { group in
                accountTradeGroupSection(group)
            }
        }
        .animation(ChartMotion.switchSpring, value: dateSort)
    }

    @ViewBuilder
    private func accountTradeGroupSection(_ group: HoldingTradeHistoryViewModel.AccountGroup) -> some View {
        let trades = sortedTrades(in: group)
        VStack(alignment: .leading, spacing: 8) {
            accountSectionHeader(group.account)

            DetailPreviewMeasuredList(rowIDs: trades.map(\.id)) {
                ForEach(trades) { transaction in
                    HoldingTradeHistoryRowView(
                        transaction: transaction,
                        aggregatedHolding: aggregatedHolding,
                        currentPrice: currentPrice,
                        usdToTwdRate: usdToTwdRate,
                        accountCurrency: group.account.currency,
                        onRowTap: { handleEditTransaction(transaction) },
                        onDelete: { _ in
                            transactionPendingDelete = transaction
                            showingDeleteConfirmation = true
                        }
                    )
                    .detailPreviewListRowStyle()
                    .detailPreviewMeasureRowHeight(id: transaction.id)
                }
            }
        }
    }

    private func sortedTrades(in group: HoldingTradeHistoryViewModel.AccountGroup) -> [Transaction] {
        switch dateSort {
        case .descending:
            return group.trades.sorted { $0.transactionDate > $1.transactionDate }
        case .ascending:
            return group.trades.sorted { $0.transactionDate < $1.transactionDate }
        }
    }

    private func accountSectionHeader(_ account: Account) -> some View {
        HStack(spacing: 8) {
            Text(account.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)
            CurrencyCodeChip(currency: account.currency, tint: holdingAccentColor)
            Spacer(minLength: 0)
        }
        .textCase(nil)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func handleEditTransaction(_ transaction: Transaction) {
        guard let market = TradeMarket(assetType: transaction.assetType) else { return }
        if transaction.type == .buy {
            buyTradeEditItem = BuyTradeEditItem(transaction: transaction, market: market)
        } else if transaction.type == .sell {
            sellTradeEditItem = SellTradeEditItem(transaction: transaction, market: market)
        }
    }

    private func editBuyTradeSheet(item: BuyTradeEditItem) -> some View {
        NavigationStack {
            BuyTradeFormView(market: item.market, editingTransaction: item.transaction, onSubmit: {
                buyTradeEditItem = nil
                Task { await reloadAfterMutation() }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { buyTradeEditItem = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .snapFormSheetChrome()
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }

    private func editSellTradeSheet(item: SellTradeEditItem) -> some View {
        NavigationStack {
            SellTradeFormView(market: item.market, editingTransaction: item.transaction, onSubmit: { _ in
                sellTradeEditItem = nil
                Task { await reloadAfterMutation() }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { sellTradeEditItem = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .snapFormSheetChrome()
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }

    @MainActor
    private func reloadAfterMutation() async {
        await historyViewModel.load(holding: aggregatedHolding)
        await transactionsViewModel.loadTransactions(userId: aggregatedHolding.userId)
    }

    @MainActor
    private func handleDeleteTransaction(_ transaction: Transaction) async {
        await transactionsViewModel.loadTransactions(userId: aggregatedHolding.userId)
        await transactionsViewModel.deleteTransaction(transaction.id)
        if let error = transactionsViewModel.errorMessage {
            deleteErrorMessage = error
            showingDeleteError = true
            return
        }
        await reloadAfterMutation()
    }
}
