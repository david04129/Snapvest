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
    @Environment(\.dismiss) var dismiss
    @State private var expandedTransactionId: String? = nil
    @State private var showingEditIncome = false
    @State private var showingEditExpense = false
    @State private var showingEditTransfer = false
    @State private var showingEditTransaction: Transaction?
    @State private var editingIncomeTransaction: Transaction?
    @State private var editingExpenseTransaction: Transaction?
    @State private var editingTransferTransaction: Transaction?
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // 標題（置頂）
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(account.name) - 交易紀錄")
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text("此處顯示所有影響此帳戶餘額的交易。")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 交易列表
                if viewModel.transactions.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondaryText)
                        Text("尚無交易紀錄")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                } else {
                    VStack(spacing: 0) {
                        // 固定表頭
                        HStack(alignment: .top, spacing: 8) {
                                Text("日期")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondaryText)
                                .frame(width: 60, alignment: .leading)
                                
                                Text("摘要")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("餘額變化")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondaryText)
                                .frame(width: 80, alignment: .leading)
                                
                                Text("餘額")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondaryText)
                                .frame(width: 90, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.secondaryBackground)
                            
                        // 可滾動的交易列表
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.transactions) { transaction in
                                TransactionHistoryRowView(
                                    transaction: transaction,
                                        accountId: account.id,
                                        accountCurrency: account.currency,
                                        balance: viewModel.getBalance(after: transaction, accountId: account.id, accountCurrency: account.currency),
                                        isExpanded: expandedTransactionId == transaction.id,
                                        onTap: {
                                            withAnimation {
                                                if expandedTransactionId == transaction.id {
                                                    expandedTransactionId = nil
                                                } else {
                                                    expandedTransactionId = transaction.id
                                                }
                                            }
                                        },
                                        onEdit: {
                                            handleEditTransaction(transaction)
                                        },
                                        onDelete: { transaction in
                                            Task {
                                                await handleDeleteTransaction(transaction)
                                            }
                                        }
                                    )
                                
                                Divider()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .task {
                await viewModel.loadTransactions(accountId: account.id, userId: account.userId)
                await transactionsViewModel.loadTransactions(userId: account.userId)
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
            .sheet(isPresented: $showingEditTransfer) {
                if let transaction = editingTransferTransaction {
                    TransferView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
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
            .sheet(item: $showingEditTransaction) { transaction in
                EditTransactionView(
                    transaction: transaction,
                    viewModel: transactionsViewModel
                )
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
        }
    }
    
    private func handleEditTransaction(_ transaction: Transaction) {
        // 還款和債務交易不能編輯，只能刪除
        if transaction.type == .repayment || transaction.type == .liability {
            return
        }
        
        // 檢查是否為轉帳交易（使用新的類型）
        if transaction.type == .transfer {
            // 轉帳交易：直接編輯
            editingTransferTransaction = transaction
            showingEditTransfer = true
            return
        }
        
        // 舊的轉帳交易格式（兼容舊數據）
        let isTransfer = (transaction.notes?.contains("轉帳至") ?? false) || 
                        (transaction.notes?.contains("轉帳自") ?? false)
        
        if isTransfer {
            // 轉帳交易：如果是轉入交易（deposit），需要找到對應的轉出交易
            if transaction.type == .deposit && transaction.notes?.contains("轉帳自") == true {
                // 這是轉入交易，需要找到對應的轉出交易來編輯
                // 解析轉出帳戶名稱
                if let notes = transaction.notes {
                    let accountName = extractAccountNameFromTransferNotes(notes, isFrom: false)
                    // 如果轉出帳戶就是當前帳戶，直接使用當前交易
                    if accountName == account.name {
                        editingTransferTransaction = transaction
                        showingEditTransfer = true
                    } else {
                        // 找到對應的轉出交易
                        if let fromTransaction = viewModel.transactions.first(where: { trans in
                            trans.accountId == account.id &&
                            trans.type == .withdraw &&
                            abs(trans.transactionDate.timeIntervalSince(transaction.transactionDate)) < 1.0 &&
                            (trans.notes?.contains("轉帳至") ?? false)
                        }) {
                            editingTransferTransaction = fromTransaction
                            showingEditTransfer = true
                        }
                    }
                }
            } else {
                // 轉出交易（withdraw），直接使用
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
    let accountId: String  // 當前帳戶ID，用於判斷轉帳/還款是轉出還是轉入
    let accountCurrency: Currency  // 當前帳戶的幣別，用於顯示正確的金額
    let balance: Decimal
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: ((Transaction) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要交易行
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 8) {
            // 日期
            Text(formatDate(transaction.transactionDate))
                .font(.caption)
                .foregroundColor(.primaryText)
                        .frame(width: 60, alignment: .leading)
                    
                    // 摘要
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            // 顯示統一的圖標
                            let iconInfo = getTransactionIcon(transaction)
                            Image(systemName: iconInfo.icon)
                            .font(.caption2)
                                .foregroundColor(iconInfo.color)
                    
                    Text(getTransactionSummary(transaction))
                        .font(.caption)
                        .foregroundColor(.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(1)
                }
                
                if transaction.type == .buy || transaction.type == .sell {
                    Text("\(transaction.symbol) × \(transaction.quantity.formatted(fractionDigits: 0))")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
                    .frame(maxWidth: .infinity, alignment: .leading)
            
            // 餘額變化
                    let change = getBalanceChange(transaction, accountId: accountId, accountCurrency: accountCurrency)
                    Text(formatBalanceChange(change, currency: accountCurrency))
                .font(.caption)
                .foregroundColor(change >= 0 ? .profitGreen : .lossRed)
                        .frame(width: 80, alignment: .leading)
            
            // 餘額
                    Text(balance.formatted(currency: accountCurrency))
                .font(.caption)
                .foregroundColor(.primaryText)
                        .frame(width: 90, alignment: .leading)
                    
                    // 展開/收起圖標
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .frame(width: 20)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // 刪除按鈕（所有交易都可以刪除）
                if let onDelete = onDelete {
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
                    }
                    .tint(.red)
                }
                
                // 編輯按鈕（還款和債務交易不能編輯）
                if transaction.type != .repayment && transaction.type != .liability {
                    Button {
                        onEdit()
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
                    }
                    .tint(.blue)
                }
            }
            
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
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        return formatter.string(from: date)
    }
    
    private func isTransferTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為轉帳類型
        return transaction.type == .transfer
    }
    
    private func isRepaymentTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為還款類型
        return transaction.type == .repayment
    }
    
    private func getTransactionSummary(_ transaction: Transaction) -> String {
        // 統一的簡化標題顯示，與 TransactionsView 保持一致
        switch transaction.type {
        case .transfer:
            return "轉帳"
        case .repayment:
            return "還款"
        case .deposit:
            return "收入"
        case .withdraw:
            return "支出"
        case .buy, .sell:
            // 買賣股票：顯示股票代碼（symbol）
            return transaction.symbol
        case .dividend:
            return "股利"
        case .fee:
            return "手續費"
        case .liability:
            return "債務"
        }
    }
    
    private func getTransactionIcon(_ transaction: Transaction) -> (icon: String, color: Color) {
        // 統一的圖標和顏色邏輯，與 TransactionsView 保持一致
        switch transaction.type {
        case .transfer:
            return ("arrow.left.arrow.right", .appPrimary)
        case .repayment:
            return ("creditcard.fill", .lossRed)
        case .deposit, .dividend:
            return ("arrow.up", .profitGreen)  // 收入、股利：向上箭頭，綠色（收入）
        case .withdraw, .fee:
            return ("arrow.down", .lossRed)  // 支出、手續費：向下箭頭，紅色（支出）
        case .liability:
            return ("creditcard", .lossRed)
        case .buy:
            return ("arrow.down", .lossRed)  // 買入：向下箭頭，紅色（支出）
        case .sell:
            return ("arrow.up", .profitGreen)  // 賣出：向上箭頭，綠色（收入）
        }
    }
    
    private func getBalanceChange(_ transaction: Transaction, accountId: String, accountCurrency: Currency) -> Decimal {
        switch transaction.type {
        case .deposit, .dividend:
            return transaction.totalAmount
        case .sell:
            return transaction.totalAmountWithFee
        case .withdraw, .buy, .fee, .liability:
            return -transaction.totalAmountWithFee
        case .transfer:
            // 轉帳：判斷是轉出還是轉入
            if transaction.accountId == accountId {
                // 這是轉出帳戶：減少（使用轉出金額）
                return -transaction.totalAmount
            } else if transaction.targetAccountId == accountId {
                // 這是轉入帳戶：增加（需要計算轉入金額）
                if transaction.currency != accountCurrency {
                    // 跨幣別轉帳：從備註中解析匯率並計算轉入金額
                    var receivedAmount = transaction.totalAmount
                    if let notes = transaction.notes,
                       let rateRange = notes.range(of: "匯率: ") {
                        let rateString = String(notes[rateRange.upperBound...])
                        if let rateEnd = rateString.firstIndex(of: ")") {
                            let rateValue = String(rateString[..<rateEnd]).trimmingCharacters(in: .whitespaces)
                            if let rate = Decimal(string: rateValue), rate > 0 {
                                // 匯率是 1 USD = rate TWD
                                if transaction.currency == .TWD && accountCurrency == .USD {
                                    receivedAmount = transaction.totalAmount / rate
                                } else if transaction.currency == .USD && accountCurrency == .TWD {
                                    receivedAmount = transaction.totalAmount * rate
                                }
                            }
                        }
                    }
                    return receivedAmount
                } else {
                    // 同幣別轉帳：直接使用交易金額
                    return transaction.totalAmount
                }
            }
            return 0
        case .repayment:
            // 還款：判斷是還款帳戶（轉出）還是債務帳戶（轉入）
            if transaction.accountId == accountId {
                // 這是還款帳戶（源帳戶）：減少總還款金額（本金+利息）
                // 還款帳戶顯示的是總還款金額
                return -transaction.totalAmount
            } else if transaction.targetAccountId == accountId {
                // 這是債務帳戶（目標帳戶）：只增加本金部分（直接從 transaction.principalAmount 讀取）
                // 債務帳戶的餘額就是剩餘本金，所以餘額變化只計算本金部分
                if let principalAmount = transaction.principalAmount {
                    return principalAmount
                }
                // 如果沒有本金數據，返回0（這種情況不應該發生）
                return 0
            }
            return 0
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
            // 獲取該帳戶的交易（包括轉出交易）
            var fetchedTransactions = try await dataService.fetchTransactions(accountId: accountId)
            
            // 同時獲取所有交易，找出以該帳戶為目標帳戶的轉帳/還款交易
            // 這樣轉入帳戶也能看到轉入的轉帳/還款交易
            if let userId = userId, let allTransactions = try? await dataService.fetchAllTransactions(userId: userId) {
                let incomingTransactions = allTransactions.filter { transaction in
                    (transaction.type == .transfer || transaction.type == .repayment) &&
                    transaction.targetAccountId == accountId &&
                    transaction.accountId != accountId
                }
                fetchedTransactions.append(contentsOf: incomingTransactions)
            }
            
            // 按日期排序（最新的在前）
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
                balance += t.totalAmountWithFee
            case .withdraw, .buy, .fee, .liability:
                balance -= t.totalAmountWithFee
            case .transfer:
                // 轉帳：判斷是轉出還是轉入
                if t.accountId == accountId {
                    // 這是轉出帳戶：減少（使用轉出金額）
                    balance -= t.totalAmount
                } else if t.targetAccountId == accountId {
                    // 這是轉入帳戶：增加（需要計算轉入金額）
                    if t.currency != accountCurrency {
                        // 跨幣別轉帳：從備註中解析匯率並計算轉入金額
                        var receivedAmount = t.totalAmount
                        if let notes = t.notes,
                           let rateRange = notes.range(of: "匯率: ") {
                            let rateString = String(notes[rateRange.upperBound...])
                            if let rateEnd = rateString.firstIndex(of: ")") {
                                let rateValue = String(rateString[..<rateEnd]).trimmingCharacters(in: .whitespaces)
                                if let rate = Decimal(string: rateValue), rate > 0 {
                                    // 匯率是 1 USD = rate TWD
                                    if t.currency == .TWD && accountCurrency == .USD {
                                        receivedAmount = t.totalAmount / rate
                                    } else if t.currency == .USD && accountCurrency == .TWD {
                                        receivedAmount = t.totalAmount * rate
                                    }
                                }
                            }
                        }
                        balance += receivedAmount
                    } else {
                        // 同幣別轉帳：直接使用交易金額
                        balance += t.totalAmount
                    }
                }
            case .repayment:
                // 還款：判斷是還款帳戶（轉出）還是債務帳戶（轉入）
                if t.accountId == accountId {
                    // 這是還款帳戶（源帳戶）：減少總還款金額（本金+利息）
                    // 還款帳戶顯示的是總還款金額
                    balance -= t.totalAmount
                } else if t.targetAccountId == accountId {
                    // 這是債務帳戶（目標帳戶）：只增加本金部分（直接從 transaction.principalAmount 讀取）
                    // 債務帳戶的餘額就是剩餘本金，所以餘額變化只計算本金部分
                    if let principalAmount = t.principalAmount {
                        balance += principalAmount
                    }
                    // 如果沒有本金數據，不增加餘額（這種情況不應該發生）
                }
            }
        }
        
        return balance
    }
}

#Preview {
    TransactionHistoryView(
        account: Account(userId: "test", name: "國泰證券", type: .stockTW, currency: .TWD)
    )
}

