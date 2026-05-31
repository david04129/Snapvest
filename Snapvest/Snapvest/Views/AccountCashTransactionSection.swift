//
//  AccountCashTransactionSection.swift
//  Snapvest
//
//  帳戶詳情：內嵌交易紀錄預覽與編輯流程（現金／投資／負債帳戶共用）。
//

import SwiftUI

struct AccountTransactionHistorySection: View {
    let account: Account
    @Binding var showFullTransactionHistory: Bool
    let onDataChanged: () async -> Void

    @StateObject private var historyViewModel = TransactionHistoryViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()

    @State private var showingEditIncome = false
    @State private var showingEditExpense = false
    @State private var showingEditRepayment = false
    @State private var showingEditTransaction: Transaction?
    @State private var editingIncomeTransaction: Transaction?
    @State private var editingExpenseTransaction: Transaction?
    @State private var editingRepaymentTransaction: Transaction?
    @State private var buyTradeEditItem: BuyTradeEditItem?
    @State private var sellTradeEditItem: SellTradeEditItem?
    @State private var showingRepaymentEditBlockedAlert = false
    @State private var transactionPendingDelete: Transaction?
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        TransactionHistoryPreviewSection(
            account: account,
            transactions: historyViewModel.transactions,
            isLoading: historyViewModel.isLoading,
            accentColor: account.accountType.color,
            balanceAfter: { historyViewModel.getBalance(after: $0, accountId: account.id, accountCurrency: account.currency) },
            onRowTap: { attemptEditTransaction($0) },
            onDelete: { transactionPendingDelete = $0; showingDeleteConfirmation = true },
            onViewAll: { showFullTransactionHistory = true }
        )
        .task {
            await reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            Task { await reload() }
        }
        .sheet(isPresented: $showingEditIncome) {
            if let transaction = editingIncomeTransaction {
                IncomeView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                    .onAppear {
                        Task { await editingAccountViewModel.loadAccountData(accountId: account.id) }
                    }
                    .onDisappear { Task { await reloadAndNotify() } }
            }
        }
        .sheet(isPresented: $showingEditExpense) {
            if let transaction = editingExpenseTransaction {
                ExpenseView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                    .onAppear {
                        Task { await editingAccountViewModel.loadAccountData(accountId: account.id) }
                    }
                    .onDisappear { Task { await reloadAndNotify() } }
            }
        }
        .sheet(isPresented: $showingEditRepayment) {
            if let transaction = editingRepaymentTransaction {
                RepaymentEditWrapperView(
                    transaction: transaction,
                    viewModel: transactionsViewModel,
                    portfolioViewModel: PortfolioViewModel(),
                    userId: account.userId,
                    onDismiss: { Task { await reloadAndNotify() } }
                )
            }
        }
        .sheet(item: $showingEditTransaction) { transaction in
            EditTransactionView(transaction: transaction, viewModel: transactionsViewModel)
                .onDisappear { Task { await reloadAndNotify() } }
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
        .alert("無法編輯", isPresented: $showingRepaymentEditBlockedAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(TransactionsViewModel.repaymentNotEditableMessage)
        }
    }

    @MainActor
    private func reload() async {
        await historyViewModel.loadTransactions(accountId: account.id, userId: account.userId)
        await transactionsViewModel.loadTransactions(userId: account.userId)
    }

    @MainActor
    private func reloadAndNotify() async {
        await reload()
        await onDataChanged()
    }

    private func attemptEditTransaction(_ transaction: Transaction) {
        if transaction.type == .liability { return }
        if transaction.type == .repayment,
           account.accountType == .debt,
           !transactionsViewModel.canEditRepaymentTransaction(transaction) {
            showingRepaymentEditBlockedAlert = true
            return
        }
        handleEditTransaction(transaction)
    }

    private func handleEditTransaction(_ transaction: Transaction) {
        if transaction.type == .repayment, account.accountType == .debt {
            editingRepaymentTransaction = transaction
            showingEditRepayment = true
            return
        }
        if transaction.type == .withdraw,
           transaction.notes?.contains("還款扣款：") == true {
            editingExpenseTransaction = transaction
            showingEditExpense = true
            return
        }
        if transaction.type == .deposit {
            editingIncomeTransaction = transaction
            showingEditIncome = true
        } else if transaction.type == .withdraw {
            editingExpenseTransaction = transaction
            showingEditExpense = true
        } else if transaction.type == .buy || transaction.type == .sell,
                  let market = TradeMarket(assetType: transaction.assetType) {
            if transaction.type == .buy {
                buyTradeEditItem = BuyTradeEditItem(transaction: transaction, market: market)
            } else {
                sellTradeEditItem = SellTradeEditItem(transaction: transaction, market: market)
            }
        } else {
            showingEditTransaction = transaction
        }
    }

    private func editBuyTradeSheet(item: BuyTradeEditItem) -> some View {
        NavigationStack {
            BuyTradeFormView(market: item.market, editingTransaction: item.transaction, onSubmit: {
                buyTradeEditItem = nil
                Task { await reloadAndNotify() }
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
                Task { await reloadAndNotify() }
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
    private func handleDeleteTransaction(_ transaction: Transaction) async {
        if transaction.type == .repayment {
            let (canDelete, errorMessage) = await transactionsViewModel.canDeleteRepaymentTransaction(
                transaction,
                userId: account.userId
            )
            if !canDelete, let errorMessage {
                deleteErrorMessage = errorMessage
                showingDeleteError = true
                return
            }
        }
        await transactionsViewModel.deleteTransaction(transaction.id)
        if let error = transactionsViewModel.errorMessage {
            deleteErrorMessage = error
            showingDeleteError = true
            return
        }
        await reloadAndNotify()
    }
}
