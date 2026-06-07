//
//  TransactionHistoryView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import Combine

struct TransactionHistoryView: View {
    let account: Account
    @StateObject private var viewModel = TransactionHistoryViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @State private var showingRepaymentEditBlockedAlert = false
    @State private var showingEditIncome = false
    @State private var showingEditExpense = false
    @State private var showingEditRepayment = false
    @State private var showingEditTransaction: Transaction?
    @State private var editingIncomeTransaction: Transaction?
    @State private var editingExpenseTransaction: Transaction?
    @State private var editingRepaymentTransaction: Transaction?
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String? = nil
    @State private var transactionPendingDelete: Transaction?
    @State private var showingDeleteConfirmation = false
    @State private var buyTradeEditItem: BuyTradeEditItem?
    @State private var sellTradeEditItem: SellTradeEditItem?
    
    private struct TransactionDayGroup: Identifiable {
        let day: Date
        let transactions: [Transaction]
        
        var id: Date { day }
    }
    
    private var transactionDayGroups: [TransactionDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.transactions) {
            calendar.startOfDay(for: $0.transactionDate)
        }
        return grouped.keys.sorted(by: >).map { day in
            TransactionDayGroup(
                day: day,
                transactions: grouped[day]!.sorted { $0.transactionDate > $1.transactionDate }
            )
        }
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                loadingView
            } else if viewModel.transactions.isEmpty {
                emptyStateView
            } else {
                transactionsListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.mainBackground)
        .navigationTitle("交易紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .task {
            await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
            await transactionsViewModel.loadTransactions(userId: account.userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            Task {
                await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
                await transactionsViewModel.loadTransactions(userId: account.userId)
            }
        }
        .sheet(isPresented: $showingEditIncome) {
                if let transaction = editingIncomeTransaction {
                    IncomeView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                        .onAppear {
                            Task {
                                await editingAccountViewModel.loadAccountData(accountId: account.id)
                            }
                        }
                        .onDisappear {
                            // 編輯完成後刷新交易紀錄
                            Task {
                                await viewModel.loadTransactions(accountId: account.id)
                            }
                        }
                }
            }
            .sheet(isPresented: $showingEditExpense) {
                if let transaction = editingExpenseTransaction {
                    ExpenseView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                        .onAppear {
                            Task {
                                await editingAccountViewModel.loadAccountData(accountId: account.id)
                            }
                        }
                        .onDisappear {
                            // 編輯完成後刷新交易紀錄
                            Task {
                                await viewModel.loadTransactions(accountId: account.id)
                            }
                        }
                }
            }
            .sheet(isPresented: $showingEditRepayment) {
                if let transaction = editingRepaymentTransaction {
                    RepaymentEditWrapperView(
                        transaction: transaction,
                        viewModel: transactionsViewModel,
                        portfolioViewModel: PortfolioViewModel(),
                        userId: account.userId,
                        onDismiss: {
                            Task {
                                await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
                                await transactionsViewModel.loadTransactions(userId: account.userId)
                            }
                        }
                    )
                }
            }
            .sheet(item: $showingEditTransaction) { transaction in
                EditTransactionView(
                    transaction: transaction,
                    viewModel: transactionsViewModel
                )
            }
            .sheet(item: $buyTradeEditItem) { item in
                editBuyTradeSheet(item: item)
            }
            .sheet(item: $sellTradeEditItem) { item in
                editSellTradeSheet(item: item)
            }
            .alert("刪除這筆紀錄？", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    transactionPendingDelete = nil
                }
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
                Button("確定", role: .cancel) {
                    deleteErrorMessage = nil
                }
            } message: {
                if let errorMessage = deleteErrorMessage {
                    Text(errorMessage)
                }
            }
            .alert("無法編輯", isPresented: $showingRepaymentEditBlockedAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(TransactionsViewModel.repaymentNotEditableMessage)
            }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入中...")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.secondaryText)
            Text("尚無交易紀錄")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var accountSummaryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            CurrencyIconBadge(
                currency: account.currency,
                tint: account.accountType.color
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                Text(account.accountType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer(minLength: 8)
            Text("\(viewModel.transactions.count) 筆")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(account.accountType.color)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
    
    private var transactionsListView: some View {
        List {
            Section {
                accountSummaryHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            
            ForEach(transactionDayGroups) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        TransactionHistoryRowView(
                            transaction: transaction,
                            accountId: account.id,
                            accountCurrency: account.currency,
                            balance: viewModel.getBalance(
                                after: transaction,
                                accountId: account.id,
                                accountCurrency: account.currency
                            ),
                            onRowTap: { attemptEditTransaction(transaction) },
                            onDelete: { transaction in
                                transactionPendingDelete = transaction
                                showingDeleteConfirmation = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    TransactionDateSectionHeader(
                        date: group.day,
                        count: group.transactions.count
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.mainBackground)
    }
    
    private func attemptEditTransaction(_ transaction: Transaction) {
        if transaction.type == .liability {
            return
        }
        if transaction.type == .repayment,
           account.accountType == .debt,
           !transactionsViewModel.canEditRepaymentTransaction(transaction) {
            showingRepaymentEditBlockedAlert = true
            return
        }
        handleEditTransaction(transaction)
    }

    private func handleEditTransaction(_ transaction: Transaction) {
        if transaction.type == .liability {
            return
        }
        
        if transaction.type == .repayment,
           account.accountType == .debt {
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
            // 收入交易
            editingIncomeTransaction = transaction
            showingEditIncome = true
        } else if transaction.type == .withdraw {
            // 支出交易
            editingExpenseTransaction = transaction
            showingEditExpense = true
        } else if transaction.type == .buy || transaction.type == .sell {
            guard let market = TradeMarket(assetType: transaction.assetType) else {
                showingEditTransaction = transaction
                return
            }
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
                Task {
                    await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
                    await transactionsViewModel.loadTransactions(userId: account.userId)
                }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        buyTradeEditItem = nil
                    } label: {
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
                Task {
                    await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
                    await transactionsViewModel.loadTransactions(userId: account.userId)
                }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        sellTradeEditItem = nil
                    } label: {
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
    
    /// 從轉帳交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromTransferNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "轉帳至 " : "轉帳自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取後面的部分
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[dashRange.upperBound...])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    /// 處理刪除交易
    private func handleDeleteTransaction(_ transaction: Transaction) async {
        // 如果是還款交易，先驗證是否為最新紀錄
        if transaction.type == .repayment || 
           (transaction.notes?.contains("還款") == true) {
            let (canDelete, errorMessage) = await transactionsViewModel.canDeleteRepaymentTransaction(transaction, userId: account.userId)
            
            if !canDelete, let error = errorMessage {
                // 驗證失敗，顯示錯誤訊息，不執行刪除
                await MainActor.run {
                    self.deleteErrorMessage = error
                    self.showingDeleteError = true
                }
                return
            }
        }
        
        // 清除之前的錯誤訊息
        await MainActor.run {
            transactionsViewModel.errorMessage = nil
            deleteErrorMessage = nil
        }
        
        // 執行刪除
        await transactionsViewModel.deleteTransaction(transaction.id)
        
        // 再次檢查是否有錯誤訊息（防止其他錯誤）
        await MainActor.run {
            if let error = transactionsViewModel.errorMessage {
                deleteErrorMessage = error
                showingDeleteError = true
                return
            }
        }
        
        // 如果沒有錯誤，重新載入交易紀錄
        await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
        await transactionsViewModel.loadTransactions(userId: account.userId)
    }
}

// MARK: - 交易行視圖（交易紀錄專用）

struct TransactionHistoryRowView: View {
    let transaction: Transaction
    let accountId: String
    let accountCurrency: Currency
    let balance: Decimal
    let onRowTap: () -> Void
    let onDelete: ((Transaction) -> Void)?
    
    private var display: TransactionDisplayFormatter {
        TransactionDisplayFormatter(transaction: transaction)
    }
    
    private var accentColor: Color {
        display.typeAccentColor
    }
    
    private var balanceChange: Decimal {
        getBalanceChange(transaction, accountId: accountId, accountCurrency: accountCurrency)
    }
    
    var body: some View {
        Button(action: onRowTap) {
            cardContent {
                rowHeader()
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button {
                    onDelete(transaction)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("刪除")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(width: 70, height: 70)
                    .background(AppColors.actionDestructiveBackground)
                }
                .tint(AppColors.actionDestructiveBackground)
            }
        }
    }
    
    @ViewBuilder
    private func cardContent<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
    
    private func rowHeader() -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(display.primaryTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                if !display.accountHistorySubtitle.isEmpty {
                    Text(display.accountHistorySubtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBalanceChange(balanceChange, currency: accountCurrency))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(balanceChange >= 0 ? .marketUp : .marketDown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text("餘額 \(balance.formatted(currency: accountCurrency))")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .contentShape(Rectangle())
    }
    
    private func getBalanceChange(_ transaction: Transaction, accountId: String, accountCurrency: Currency) -> Decimal {
        switch transaction.type {
        case .deposit, .dividend:
            return transaction.totalAmount
        case .sell:
            return CashCalculator.buySellAmountInAccountCurrency(transaction: transaction, accountCurrency: accountCurrency)
        case .withdraw, .fee, .liability:
            return -transaction.totalAmountWithFee
        case .buy:
            if transaction.deductFromAccount == true {
                return -CashCalculator.buySellAmountInAccountCurrency(transaction: transaction, accountCurrency: accountCurrency)
            }
            return 0
        case .repayment:
            guard transaction.accountId == accountId else { return 0 }
            let principal = transaction.principalAmount ?? transaction.totalAmount
            return -principal
        }
    }
    
    private func formatBalanceChange(_ change: Decimal, currency: Currency) -> String {
        let absChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        // 使用當前帳戶的幣別來格式化金額
        let formattedAmount = absChange.formatted(currency: currency).trimmingCharacters(in: .whitespaces)
        // 返回格式：符號 + 空格 + 數字（無前導空格）
        return "\(sign) \(formattedAmount)"
    }
}

// MARK: - 交易紀錄 ViewModel
@MainActor
class TransactionHistoryViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol? = nil) {
        self.dataService = dataService ?? MockDataService.shared
    }
    
    func loadTransactions(accountId: String, userId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTransactions = try await dataService.fetchTransactions(accountId: accountId)
            transactions = fetchedTransactions.sorted { $0.transactionDate > $1.transactionDate }
        } catch {
            errorMessage = "載入交易紀錄失敗：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 計算交易後的餘額
    func getBalance(after transaction: Transaction, accountId: String, accountCurrency: Currency) -> Decimal {
        // 找到該交易在列表中的位置
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            return 0
        }
        
        // 因為列表是按日期倒序排列的（最新的在前），所以需要從最早的交易開始累積
        // 我們需要從列表末尾（最早的交易）開始，累積到當前交易
        var balance: Decimal = 0
        
        // 從最早的交易（列表末尾）開始，累積到當前交易（包含）
        for i in (index..<transactions.count).reversed() {
            let t = transactions[i]
            switch t.type {
            case .deposit, .dividend:
                balance += t.totalAmount
            case .sell:
                balance += CashCalculator.buySellAmountInAccountCurrency(transaction: t, accountCurrency: accountCurrency)
            case .withdraw, .fee, .liability:
                balance -= t.totalAmountWithFee
            case .buy:
                if t.deductFromAccount == true {
                    balance -= CashCalculator.buySellAmountInAccountCurrency(transaction: t, accountCurrency: accountCurrency)
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

#Preview {
    NavigationStack {
        TransactionHistoryView(
            account: Account(userId: "test", name: "國泰證券", type: .stockTW, currency: .TWD)
        )
    }
}

