//
//  TransactionsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct TransactionsView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingAddTransaction = false
    @State private var showingEditTransaction: Transaction?
    @State private var showingEditLiability = false
    @State private var editingLiability: Liability?
    @State private var showingEditIncome = false
    @State private var showingEditExpense = false
    @State private var showingEditTransfer = false
    @State private var showingEditRepayment = false
    @State private var editingIncomeTransaction: Transaction?
    @State private var editingExpenseTransaction: Transaction?
    @State private var editingTransferTransaction: Transaction?
    @State private var editingRepaymentTransaction: Transaction?
    @State private var editingAccount: Account?
    @State private var userId: String = "test-user-id"
    @State private var selectedFilter: FilterOption = .all
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()
    
    enum FilterOption: String, CaseIterable {
        case all = "全部"
        case stock = "股票交易"
        case cashFlow = "現金流"
    }
    
    // MARK: - View Components
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("篩選條件")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            Picker("篩選", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .background(Color.secondaryBackground)
        .padding(.bottom, 8)
    }
    
    private var filterTitleSection: some View {
        HStack {
            if !viewModel.isLoading {
                Text("\(selectedFilter.rawValue) - 共 \(filteredTransactions.count) 筆")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            } else {
                Text("載入中...")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.cardBackground)
    }
    
    @ViewBuilder
    private var transactionsListSection: some View {
        if viewModel.isLoading {
            loadingView
        } else if filteredTransactions.isEmpty {
            emptyStateView
        } else {
            transactionsListView
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
    
    private var transactionsListView: some View {
        List {
            ForEach(filteredTransactions, id: \.id) { transaction in
                TransactionRowView(
                    transaction: transaction,
                    accountName: getAccountName(for: transaction),
                    onEdit: { transaction in
                        handleEditTransaction(transaction)
                    },
                    onDelete: { transaction in
                        Task {
                            await viewModel.deleteTransaction(transaction.id)
                            // 如果是債務交易，重新載入帳戶列表（因為刪除了債務帳戶）
                            if transaction.type == .liability {
                                await accountsViewModel.loadAccounts(userId: userId)
                            }
                            await viewModel.loadTransactions(userId: userId)
                            await portfolioViewModel.loadData(userId: userId)
                        }
                    }
                )
            }
            .onDelete(perform: deleteTransactions)
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadTransactions(userId: userId)
        }
    }
    
    var filteredTransactions: [Transaction] {
        // 如果正在載入，返回空數組
        guard !viewModel.isLoading else {
            return []
        }
        
        // 確保 transactions 數組已初始化
        let allTransactions = viewModel.transactions
        
        switch selectedFilter {
        case .all:
            return allTransactions
        case .stock:
            return allTransactions.filter { transaction in
                transaction.type == .buy || transaction.type == .sell
            }
        case .cashFlow:
            return allTransactions.filter { transaction in
                transaction.type == .deposit || 
                transaction.type == .withdraw || 
                transaction.type == .dividend || 
                transaction.type == .fee ||
                transaction.type == .transfer ||
                transaction.type == .repayment
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection
                filterTitleSection
                transactionsListSection
            }
            .navigationTitle("所有紀錄")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .refreshable {
                await viewModel.loadTransactions(userId: userId)
            }
            .task {
                await viewModel.loadTransactions(userId: userId)
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(viewModel: viewModel)
            }
            .sheet(item: $showingEditTransaction) { transaction in
                editTransactionSheet(transaction: transaction)
            }
            .sheet(isPresented: $showingEditLiability) {
                editLiabilitySheet
            }
            .sheet(isPresented: $showingEditIncome) {
                editIncomeSheet
            }
            .sheet(isPresented: $showingEditExpense) {
                editExpenseSheet
            }
            .sheet(isPresented: $showingEditTransfer) {
                editTransferSheet
            }
            .sheet(isPresented: $showingEditRepayment) {
                editRepaymentSheet
            }
            .onChange(of: showingEditIncome) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditExpense) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditTransfer) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditRepayment) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditTransaction) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: {
                    showingAddTransaction = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增交易")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.appPrimary)
                            .font(.caption)
                    }
            }
        }
    }
    
    // MARK: - Sheet Views
    
    @ViewBuilder
    private func editTransactionSheet(transaction: Transaction) -> some View {
        EditTransactionView(
            transaction: transaction,
            viewModel: viewModel,
            onEditLiability: { liability in
                editingLiability = liability
                showingEditLiability = true
            }
        )
        .onDisappear {
            Task {
                await viewModel.loadTransactions(userId: userId)
            }
        }
    }
    
    @ViewBuilder
    private var editLiabilitySheet: some View {
        if let liability = editingLiability {
            AddLiabilityView(portfolioViewModel: portfolioViewModel, userId: userId, editingLiability: liability)
        }
    }
    
    @ViewBuilder
    private var editIncomeSheet: some View {
        if let account = editingAccount, let transaction = editingIncomeTransaction {
            IncomeView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editExpenseSheet: some View {
        if let account = editingAccount, let transaction = editingExpenseTransaction {
            ExpenseView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editTransferSheet: some View {
        if let account = editingAccount, let transaction = editingTransferTransaction {
            TransferView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editRepaymentSheet: some View {
        if let transaction = editingRepaymentTransaction {
            RepaymentEditWrapperView(
                transaction: transaction,
                viewModel: viewModel,
                portfolioViewModel: portfolioViewModel,
                userId: userId,
                onDismiss: {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleEditSheetChange(oldValue: Bool, newValue: Bool) {
        if oldValue == true && newValue == false {
            Task {
                await viewModel.loadTransactions(userId: userId)
            }
        }
    }
    
    private func handleEditTransaction(_ transaction: Transaction) {
        // 還款和債務交易不能編輯，只能刪除
        if transaction.type == .repayment || transaction.type == .liability {
            return
        }
        
        // 獲取帳戶資訊
        guard let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) else {
            return
        }
        
        editingAccount = account
        
        // 檢查是否為轉帳交易（使用新的類型）
        if transaction.type == .transfer {
            // 轉帳交易：直接編輯
            editingTransferTransaction = transaction
            showingEditTransfer = true
            return
        }
        
        // 舊的轉帳/還款交易格式（兼容舊數據）
        let isRepayment = (transaction.notes?.contains("還款至") ?? false) || 
                         (transaction.notes?.contains("還款自") ?? false)
        let isTransfer = (transaction.notes?.contains("轉帳至") ?? false) || 
                        (transaction.notes?.contains("轉帳自") ?? false)
        
        // 還款和轉帳使用相同的編輯邏輯
        if isTransfer || isRepayment {
            // 轉帳或還款交易：如果是轉入交易（deposit），需要找到對應的轉出交易
            if transaction.type == .deposit && (transaction.notes?.contains("轉帳自") == true || transaction.notes?.contains("還款自") == true) {
                // 這是轉入交易，需要找到對應的轉出交易來編輯
                // 解析轉出帳戶名稱
                if let notes = transaction.notes {
                    let accountName = extractAccountNameFromTransferNotes(notes, isFrom: false)
                    if let sourceAccount = viewModel.accounts.first(where: { $0.name == accountName }) {
                        // 找到對應的轉出交易
                        let isRepaymentNote = transaction.notes?.contains("還款自") ?? false
                        if let fromTransaction = viewModel.transactions.first(where: { trans in
                            trans.accountId == sourceAccount.id &&
                            trans.type == .withdraw &&
                            abs(trans.transactionDate.timeIntervalSince(transaction.transactionDate)) < 1.0 &&
                            (isRepaymentNote ? (trans.notes?.contains("還款至") ?? false) : (trans.notes?.contains("轉帳至") ?? false))
                        }) {
                            editingAccount = sourceAccount
                            if isRepaymentNote {
                                editingTransferTransaction = fromTransaction // 還款也用轉帳的編輯
                                showingEditTransfer = true
                            } else {
                                editingTransferTransaction = fromTransaction
                                showingEditTransfer = true
                            }
                            return
                        }
                    }
                }
            } else {
                // 轉出交易（withdraw），直接使用（轉帳和還款都用這個）
                editingTransferTransaction = transaction
                showingEditTransfer = true
            }
        } else if transaction.type == .deposit {
            // 收入交易
            editingIncomeTransaction = transaction
            showingEditIncome = true
        } else if transaction.type == .withdraw {
            // 支出交易
            editingExpenseTransaction = transaction
            showingEditExpense = true
        } else {
            // 其他交易類型（buy, sell等）使用原有的EditTransactionView
            showingEditTransaction = transaction
        }
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
    
    /// 從還款交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromRepaymentNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "還款至 " : "還款自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱在備註之前）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        let transactionsToDelete = offsets.map { filteredTransactions[$0] }
        Task {
            // 逐一刪除，確保每個刪除操作完成後再進行下一個
            for transaction in transactionsToDelete {
                await viewModel.deleteTransaction(transaction.id)
            }
            // 刪除完成後，刷新所有相關的 ViewModel
            await refreshAllData()
        }
    }
    
    private func refreshAllData() async {
        // 使用 Task 確保異步操作不會阻塞
        await portfolioViewModel.loadData(userId: userId)
        await accountsViewModel.loadAccounts(userId: userId)
        // 重新載入交易以確保數據一致性
        await viewModel.loadTransactions(userId: userId)
    }
    
    private func getAccountName(for transaction: Transaction) -> String {
        // 確保 accounts 已載入
        if viewModel.accounts.isEmpty {
            return "未知帳戶"
        }
        
        // 如果是轉帳或還款交易，顯示「A到B」格式
        if transaction.type == .transfer || transaction.type == .repayment {
            // 從 notes 中解析帳戶名稱
            if let notes = transaction.notes {
                var sourceAccountName: String?
                var targetAccountName: String?
                
                if transaction.type == .transfer {
                    // 轉帳格式：「自 美股帳戶 轉帳到 台幣帳戶」或「備註 - 自 美股帳戶 轉帳到 台幣帳戶 (匯率: 32.00)」
                    if let transferRange = notes.range(of: "自 ") {
                        var transferText = String(notes[transferRange.upperBound...])
                        // 移除匯率部分
                        if let rateRange = transferText.range(of: " (匯率:") {
                            transferText = String(transferText[..<rateRange.lowerBound])
                        }
                        // 移除可能的備註部分
                        if let dashRange = transferText.range(of: " - ") {
                            let afterDash = String(transferText[dashRange.upperBound...])
                            if afterDash.contains("自 ") {
                                transferText = afterDash
                                if let rateRange = transferText.range(of: " (匯率:") {
                                    transferText = String(transferText[..<rateRange.lowerBound])
                                }
                            }
                        }
                        // 解析「自 A 轉帳到 B」
                        if let toRange = transferText.range(of: "轉帳到 ") {
                            sourceAccountName = String(transferText[..<toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            let afterTo = String(transferText[toRange.upperBound...])
                            // 移除可能的匯率部分
                            if let rateRange = afterTo.range(of: " (匯率:") {
                                targetAccountName = String(afterTo[..<rateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            } else {
                                targetAccountName = afterTo.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                } else if transaction.type == .repayment {
                    // 還款格式：「自 台幣帳戶 還款到 債務帳戶」或「備註 - 自 台幣帳戶 還款到 債務帳戶 (匯率: 32.00) 本金償還$1000，利息償還$125」
                    if let repaymentRange = notes.range(of: "自 ") {
                        var repaymentText = String(notes[repaymentRange.upperBound...])
                        // 移除本金和利息部分
                        if let principalRange = repaymentText.range(of: " 本金償還") {
                            repaymentText = String(repaymentText[..<principalRange.lowerBound])
                        }
                        // 移除匯率部分
                        if let rateRange = repaymentText.range(of: " (匯率:") {
                            repaymentText = String(repaymentText[..<rateRange.lowerBound])
                        }
                        // 移除可能的備註部分
                        if let dashRange = repaymentText.range(of: " - ") {
                            let afterDash = String(repaymentText[dashRange.upperBound...])
                            if afterDash.contains("自 ") {
                                repaymentText = afterDash
                                if let principalRange = repaymentText.range(of: " 本金償還") {
                                    repaymentText = String(repaymentText[..<principalRange.lowerBound])
                                }
                                if let rateRange = repaymentText.range(of: " (匯率:") {
                                    repaymentText = String(repaymentText[..<rateRange.lowerBound])
                                }
                            }
                        }
                        // 解析「自 A 還款到 B」
                        if let toRange = repaymentText.range(of: "還款到 ") {
                            sourceAccountName = String(repaymentText[..<toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            let afterTo = String(repaymentText[toRange.upperBound...])
                            // 移除可能的匯率部分
                            if let rateRange = afterTo.range(of: " (匯率:") {
                                targetAccountName = String(afterTo[..<rateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            } else {
                                targetAccountName = afterTo.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
                
                // 如果成功解析，返回「A到B」格式
                if let source = sourceAccountName, let target = targetAccountName {
                    return "\(source)到\(target)"
                }
            }
            
            // 如果無法從 notes 解析，嘗試從帳戶列表中查找
            if let sourceAccount = viewModel.accounts.first(where: { $0.id == transaction.accountId }),
               let targetAccountId = transaction.targetAccountId,
               let targetAccount = viewModel.accounts.first(where: { $0.id == targetAccountId }) {
                return "\(sourceAccount.name)到\(targetAccount.name)"
            }
            
            // 如果都無法獲取，返回預設值
            if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
                return account.name
            }
            return "未知帳戶"
        }
        
        // 非轉帳/還款交易，返回帳戶名稱
        if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
            return account.name
        }
        return "未知帳戶"
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let accountName: String
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要交易行
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 圖示
                    Circle()
                        .fill(typeColor(for: transaction.type).opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: typeIcon(for: transaction.type))
                                .foregroundColor(typeColor(for: transaction.type))
                                .font(.system(size: 16))
                        }
                    
                    // 資訊
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transactionDescription)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Text(accountName)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    // 金額和日期
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(transactionAmount)
                            .font(.headline)
                            .foregroundColor(transaction.type == .repayment ? .lossRed : typeColor(for: transaction.type))
                        
                        Text(transaction.transactionDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    // 展開/收起圖標
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .frame(width: 20)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展開的備註區域
            if isExpanded, let notes = transaction.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("備註")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.secondaryBackground.opacity(0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("刪除")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(Color.red)
                .cornerRadius(0)
            }
            .tint(.red)
            
            // 還款和債務交易只能刪除，不能編輯
            if transaction.type != .repayment && transaction.type != .liability {
                Button {
                    onEdit(transaction)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                        Text("編輯")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.blue)
                    .cornerRadius(0)
                }
                .tint(.blue)
            }
        }
    }
    
    private var transactionDescription: String {
        // 統一的簡化標題顯示
        switch transaction.type {
        case .buy, .sell:
            return transaction.symbol
        case .transfer:
            return "轉帳"
        case .repayment:
            return "還款"
        case .deposit:
            return "收入"
        case .withdraw:
            return "支出"
        case .dividend:
            return "股利"
        case .fee:
            return "手續費"
        case .liability:
            return "債務"
        }
    }
    
    
    private var transactionAmount: String {
        // 安全地計算金額
        let amount = transaction.totalAmountWithFee
        let absAmount = abs(amount)
        let sign: String
        
        switch transaction.type {
        case .liability:
            // 債務總是顯示為負數
            sign = "-"
        case .deposit, .dividend:
            sign = "+"
        case .sell:
            sign = amount > 0 ? "+" : "-"
        case .transfer:
            // 轉帳：不顯示負號，因為對用戶來說沒有損失
            sign = ""
        case .repayment:
            // 還款：顯示負號
            sign = "-"
        default:
            sign = "-"
        }
        
        // 安全地格式化金額
        let formattedAmount = absAmount.formatted(currency: transaction.currency)
        // 如果 sign 為空，直接返回金額，否則返回帶符號的金額
        return sign.isEmpty ? formattedAmount : "\(sign) \(formattedAmount)"
    }
    
    private func isTransferTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為轉帳類型
        return transaction.type == .transfer
    }
    
    private func isRepaymentTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為還款類型
        return transaction.type == .repayment
    }
    
    private func typeIcon(for type: TransactionType) -> String {
        // 統一的圖標邏輯，與 TransactionHistoryView 保持一致
        switch type {
        case .transfer:
            return "arrow.left.arrow.right"
        case .repayment:
            return "creditcard.fill"
        case .buy:
            return "arrow.down"  // 買入：向下箭頭（支出）
        case .sell:
            return "arrow.up"  // 賣出：向上箭頭（收入）
        case .deposit:
            return "arrow.up"  // 收入：向上箭頭
        case .withdraw:
            return "arrow.down"  // 支出：向下箭頭
        case .dividend:
            return "arrow.up"  // 股利：向上箭頭（收入）
        case .fee:
            return "arrow.down"  // 手續費：向下箭頭（支出）
        case .liability:
            return "creditcard"
        }
    }
    
    private func typeColor(for type: TransactionType) -> Color {
        // 統一的顏色邏輯，與 TransactionHistoryView 保持一致
        switch type {
        case .transfer:
            return .appPrimary
        case .repayment:
            return .lossRed
        case .buy:
            return .lossRed  // 買入：紅色（支出）
        case .sell:
            return .profitGreen  // 賣出：綠色（收入）
        case .deposit, .dividend:
            return .profitGreen  // 收入、股利：綠色（收入）
        case .withdraw, .fee, .liability:
            return .lossRed  // 支出、手續費、債務：紅色（支出）
        }
    }
}

// MARK: - 還款編輯包裝視圖
struct RepaymentEditWrapperView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: TransactionsViewModel
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    let userId: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var liability: Liability?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中...")
            } else if let liability = liability {
                RepaymentView(liability: liability, editingTransaction: transaction)
                    .onDisappear {
                        onDismiss()
                    }
            } else {
                Text("無法找到對應的債務")
                    .foregroundColor(.secondaryText)
            }
        }
        .task {
            await loadLiability()
        }
    }
    
    private func loadLiability() async {
        // 從交易 notes 中提取債務帳戶名稱（參考轉帳的邏輯）
        guard let notes = transaction.notes else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        var debtAccountName: String?
        
        if notes.contains("還款至 ") {
            // 轉出交易：直接從 notes 中提取債務帳戶名稱
            debtAccountName = extractAccountNameFromRepaymentNotes(notes, isFrom: true)
        } else if notes.contains("還款自 ") {
            // 轉入交易：當前交易的帳戶就是債務帳戶
            if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId && $0.accountType == .debt }) {
                debtAccountName = account.name
            } else {
                // 如果當前帳戶不是債務帳戶，從轉出交易中提取
                let sourceAccountName = extractAccountNameFromRepaymentNotes(notes, isFrom: false)
                if let sourceAccount = viewModel.accounts.first(where: { $0.name == sourceAccountName }) {
                    do {
                        let allTransactions = try await MockDataService.shared.fetchAllTransactions(userId: userId)
                        if let fromTransaction = allTransactions.first(where: { trans in
                            trans.accountId == sourceAccount.id &&
                            trans.type == .withdraw &&
                            abs(trans.transactionDate.timeIntervalSince(transaction.transactionDate)) < 1.0 &&
                            (trans.notes?.contains("還款至") ?? false)
                        }) {
                            debtAccountName = extractAccountNameFromRepaymentNotes(fromTransaction.notes ?? "", isFrom: true)
                        }
                    } catch {
                        await MainActor.run {
                            isLoading = false
                        }
                        return
                    }
                }
            }
        }
        
        guard let debtAccountName = debtAccountName,
              let debtAccount = viewModel.accounts.first(where: { $0.name == debtAccountName && $0.accountType == .debt }) else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // 找到對應的債務記錄
        do {
            let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: debtAccount.id)
            await MainActor.run {
                liability = liabilities.first(where: { $0.name == debtAccountName })
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func extractAccountNameFromRepaymentNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "還款至 " : "還款自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱在備註之前）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
}

#Preview {
    TransactionsView()
}

