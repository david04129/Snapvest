//
//  TransferView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import Foundation

struct TransferView: View {
    let account: Account
    @ObservedObject var viewModel: AccountDetailViewModel
    @StateObject private var accountsViewModel = AccountsViewModel()
    @Environment(\.dismiss) var dismiss
    
    // 編輯模式：如果提供，則為編輯模式（提供轉出交易）
    let editingTransaction: Transaction?
    
    // 是否允許選擇轉出帳戶（還款模式使用）
    let allowSourceAccountSelection: Bool
    
    @State private var selectedSourceAccount: Account? // 選擇的轉出帳戶（還款模式）
    @State private var selectedTargetAccount: Account?
    @State private var amount: String = ""
    @State private var exchangeRate: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var userId: String = "test-user-id"
    @State private var showingAccountPicker = false
    @State private var showingSourceAccountPicker = false // 轉出帳戶選擇器
    @State private var errorMessage: String? = nil
    @State private var sourceAccountCashBalance: Decimal = 0 // 轉出帳戶現金餘額（還款模式）
    @State private var targetAccountCashBalance: Decimal = 0
    
    // 還款模式：預填的債務帳戶和金額
    let prepopulatedTargetAccount: Account?
    let prepopulatedAmount: Decimal?
    let prepopulatedNotes: String?
    let allowAmountEdit: Bool  // 是否允許編輯金額
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    // 計算實際使用的轉出帳戶
    private var actualSourceAccount: Account {
        if allowSourceAccountSelection, let selected = selectedSourceAccount {
            return selected
        }
        return account
    }
    
    // 計算實際使用的現金餘額
    private var actualSourceCashBalance: Decimal {
        if allowSourceAccountSelection {
            return sourceAccountCashBalance
        }
        return viewModel.cashBalance
    }
    
    // 判斷是否為還款模式
    private var isRepaymentMode: Bool {
        prepopulatedTargetAccount?.accountType == .debt
    }
    
    init(account: Account, viewModel: AccountDetailViewModel, editingTransaction: Transaction? = nil, allowSourceAccountSelection: Bool = false, prepopulatedTargetAccount: Account? = nil, prepopulatedAmount: Decimal? = nil, prepopulatedNotes: String? = nil, allowAmountEdit: Bool = false) {
        self.account = account
        self.viewModel = viewModel
        self.editingTransaction = editingTransaction
        self.allowSourceAccountSelection = allowSourceAccountSelection
        self.prepopulatedTargetAccount = prepopulatedTargetAccount
        self.prepopulatedAmount = prepopulatedAmount
        self.prepopulatedNotes = prepopulatedNotes
        self.allowAmountEdit = allowAmountEdit
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("帳戶轉帳")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("在您的帳戶之間轉移資金。")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 8)
    }
    
    private var sourceAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("轉出帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            if allowSourceAccountSelection {
                // 還款模式：可以選擇轉出帳戶
                Button(action: {
                    showingSourceAccountPicker = true
                }) {
                    CardView {
                        HStack {
                            if let sourceAccount = selectedSourceAccount {
                                Image(systemName: sourceAccount.accountType.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(sourceAccount.accountType.color)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sourceAccount.name)
                                        .font(.headline)
                                        .foregroundColor(.primaryText)
                                    Text("現金餘額：\(sourceAccountCashBalance.formatted(currency: sourceAccount.currency))")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            } else {
                                Image(systemName: account.accountType.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(account.accountType.color)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.name)
                                        .font(.headline)
                                        .foregroundColor(.primaryText)
                                    Text("現金餘額：\(actualSourceCashBalance.formatted(currency: account.currency))")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            } else {
                // 轉帳模式：固定轉出帳戶
                CardView {
                    HStack {
                        Image(systemName: account.accountType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(account.accountType.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            Text("現金餘額：\(viewModel.cashBalance.formatted(currency: account.currency))")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var targetAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.left.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text(isRepaymentMode ? "債務帳戶" : "轉入帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            if isRepaymentMode {
                // 還款模式：轉入帳戶固定，不顯示餘額
                CardView {
                    HStack {
                        if let targetAccount = selectedTargetAccount {
                            Image(systemName: targetAccount.accountType.icon)
                                .font(.system(size: 20))
                                .foregroundColor(targetAccount.accountType.color)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(targetAccount.name)
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                            }
                        } else {
                            Text("選擇一個帳戶")
                                .font(.headline)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                    }
                }
            } else {
                // 轉帳模式：可以選擇轉入帳戶，顯示餘額
                Button(action: {
                    showingAccountPicker = true
                }) {
                    CardView {
                        HStack {
                            if let targetAccount = selectedTargetAccount {
                                Image(systemName: targetAccount.accountType.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(targetAccount.accountType.color)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(targetAccount.name)
                                        .font(.headline)
                                        .foregroundColor(.primaryText)
                                    Text("現金餘額：\(targetAccountCashBalance.formatted(currency: targetAccount.currency))")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            } else {
                                Text("選擇一個帳戶")
                                    .font(.headline)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("轉帳金額 (\(actualSourceAccount.currency.rawValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    if allowAmountEdit || prepopulatedAmount == nil {
                        // 允許編輯或沒有預填金額：使用 TextField
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.headline)
                            .onChange(of: amount) { oldValue, newValue in
                                handleAmountChange(oldValue: oldValue, newValue: newValue)
                            }
                    } else {
                        // 定期還款且不允許編輯：顯示為只讀
                        if amount.isEmpty {
                            Text("請輸入金額")
                                .font(.headline)
                                .foregroundColor(.secondaryText)
                        } else {
                            Text(amount)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        if let targetAccount = selectedTargetAccount, targetAccount.currency != actualSourceAccount.currency {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(.appPrimary)
                    Text("美金對台幣匯率")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                CardView {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18))
                            .foregroundColor(.secondaryText)
                        
                        TextField("0", text: $exchangeRate)
                            .keyboardType(.decimalPad)
                            .font(.headline)
                            .onChange(of: exchangeRate) { oldValue, newValue in
                                handleExchangeRateChange(oldValue: oldValue, newValue: newValue)
                            }
                    }
                }
                
                if let amountValue = Decimal(string: amount), !amount.isEmpty,
                   let rateValue = Decimal(string: exchangeRate), !exchangeRate.isEmpty {
                    HStack {
                        Text("預計收到：")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text(calculateReceivedAmount(amount: amountValue, rate: rateValue).formatted(currency: targetAccount.currency))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("日期")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18))
                        .foregroundColor(.secondaryText)
                    
                    DatePicker("", selection: $transactionDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("備註 (選填)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.secondaryText)
                        .padding(.top, 2)
                    
                    TextField("例如:房屋貸款五月款項", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var errorMessageSection: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.lossRed)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    sourceAccountSection
                    targetAccountSection
                    amountSection
                    exchangeRateSection
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .navigationTitle(editingTransaction != nil ? "編輯轉帳" : "帳戶轉帳")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    saveTransfer()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 18))
                        Text(editingTransaction != nil ? "確認修改" : "確認轉帳")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? Color.appPrimary : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
            .sheet(isPresented: $showingAccountPicker) {
                TransferAccountPickerSheet(
                    accounts: accountsViewModel.accounts.filter { 
                        // 不能選擇自己
                        $0.id != actualSourceAccount.id &&
                        // 轉帳模式：不能選擇債務帳戶；還款模式：可以選擇債務帳戶
                        (isRepaymentMode || $0.accountType != .debt)
                    },
                    selectedAccount: $selectedTargetAccount
                )
            }
            .sheet(isPresented: $showingSourceAccountPicker) {
                TransferAccountPickerSheet(
                    accounts: accountsViewModel.accounts.filter { 
                        // 還款模式：只能選擇台幣帳戶，不能選擇債務帳戶
                        ($0.accountType == .twdDeposit || $0.accountType == .twdSecurities) &&
                        $0.id != prepopulatedTargetAccount?.id
                    },
                    selectedAccount: $selectedSourceAccount
                )
            }
            .task {
                await accountsViewModel.loadAccounts(userId: userId)
                
                // 如果是編輯模式，預填資料
                if let transaction = editingTransaction {
                    await loadEditingData(transaction: transaction)
                } else if let targetAccount = prepopulatedTargetAccount {
                    // 還款模式：預填轉入帳戶、金額和備註
                    selectedTargetAccount = targetAccount
                    loadTargetAccountCashBalance(accountId: targetAccount.id)
                    loadExchangeRate()
                    
                    // 預填金額和備註（定期還款）
                    if let prepopulatedAmount = prepopulatedAmount {
                        amount = prepopulatedAmount.formatted(fractionDigits: 0)
                    }
                    
                    if let prepopulatedNotes = prepopulatedNotes {
                        notes = prepopulatedNotes
                    }
                    
                    // 還款模式：預設轉出帳戶為還款帳戶，並載入其現金餘額
                    if allowSourceAccountSelection {
                        selectedSourceAccount = account
                        // 載入初始帳戶的數據
                        await viewModel.loadAccountData(accountId: account.id)
                        loadSourceAccountCashBalance(accountId: account.id)
                    }
                } else {
                    // 轉帳模式：載入初始帳戶的數據
                    await viewModel.loadAccountData(accountId: account.id)
                }
            }
            .onChange(of: selectedTargetAccount) { oldValue, newValue in
                if let newAccount = newValue {
                    loadTargetAccountCashBalance(accountId: newAccount.id)
                    // 載入匯率
                    loadExchangeRate()
                } else {
                    targetAccountCashBalance = 0
                    exchangeRate = ""
                }
                // 只有在金額不為空時才驗證
                if !amount.isEmpty {
                    validateInput()
                }
            }
            .onChange(of: selectedSourceAccount) { oldValue, newValue in
                if let newAccount = newValue {
                    // 先重置餘額，避免使用舊值
                    sourceAccountCashBalance = 0
                    loadSourceAccountCashBalance(accountId: newAccount.id)
                    loadExchangeRate()
                    // 驗證會在 loadSourceAccountCashBalance 完成後自動觸發
                } else {
                    sourceAccountCashBalance = 0
                    // 如果金額不為空，清除錯誤訊息（因為已經沒有選擇帳戶了）
                    if !amount.isEmpty {
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard selectedTargetAccount != nil,
              let amountValue = Decimal(string: amount),
              !amount.isEmpty,
              amountValue > 0 else {
            return false
        }
        
        // 檢查轉帳金額不能大於現金餘額（使用實際的轉出帳戶餘額）
        if amountValue > actualSourceCashBalance {
            return false
        }
        
        // 如果幣別不同，需要匯率
        if let targetAccount = selectedTargetAccount, targetAccount.currency != actualSourceAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate),
                  !exchangeRate.isEmpty,
                  rateValue > 0 else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    private func handleAmountChange(oldValue: String, newValue: String) {
        // 過濾非數字字符
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            amount = filtered
        }
        // 驗證不能為負數
        if let value = Decimal(string: filtered), value <= 0, !filtered.isEmpty {
            amount = oldValue.isEmpty ? "" : oldValue
        }
        // 只有在金額不為空時才驗證
        if !amount.isEmpty {
            validateInput()
        } else {
            // 如果金額為空，清除錯誤訊息
            errorMessage = nil
        }
    }
    
    private func handleExchangeRateChange(oldValue: String, newValue: String) {
        // 過濾非數字字符
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            exchangeRate = filtered
        }
        // 驗證不能為負數或零
        if let value = Decimal(string: filtered), value <= 0 {
            exchangeRate = oldValue.isEmpty ? "" : oldValue
        }
    }
    
    private func validateInput() {
        errorMessage = nil
        
        guard let amountValue = Decimal(string: amount), !amount.isEmpty else {
            return
        }
        
        if amountValue <= 0 {
            errorMessage = "轉帳金額必須大於 0"
            return
        }
        
        if amountValue > actualSourceCashBalance {
            errorMessage = "轉帳金額不能大於現金餘額 \(actualSourceCashBalance.formatted(currency: actualSourceAccount.currency))"
            return
        }
        
        if let targetAccount = selectedTargetAccount, targetAccount.currency != actualSourceAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate), !exchangeRate.isEmpty, rateValue > 0 else {
                errorMessage = "請輸入有效的匯率"
                return
            }
        }
    }
    
    private func loadTargetAccountCashBalance(accountId: String) {
        Task {
            do {
                var transactions = try await dataService.fetchTransactions(accountId: accountId)
                
                // 獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
                var allAccountsList: [Account] = []
                do {
                    // 先獲取該帳戶以獲取 userId（使用已知的 userId，因為這是 mock data）
                    allAccountsList = try await dataService.fetchAccounts(userId: userId)
                    if let targetAccount = allAccountsList.first(where: { $0.id == accountId }) {
                        let allTransactions = try await dataService.fetchAllTransactions(userId: targetAccount.userId)
                        // 找到以該帳戶為目標帳戶的轉帳/還款交易
                        let incomingTransferTransactions = allTransactions.filter { transaction in
                            (transaction.type == .transfer || transaction.type == .repayment) &&
                            transaction.targetAccountId == accountId &&
                            transaction.accountId != accountId
                        }
                        transactions.append(contentsOf: incomingTransferTransactions)
                    }
                } catch {
                    // 如果獲取所有交易失敗，繼續使用該帳戶自己的交易
                }
                
                targetAccountCashBalance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccountsList)
            } catch {
                targetAccountCashBalance = 0
            }
        }
    }
    
    private func loadSourceAccountCashBalance(accountId: String) {
        Task {
            do {
                var transactions = try await dataService.fetchTransactions(accountId: accountId)
                
                // 獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
                var allAccountsList: [Account] = []
                do {
                    // 先獲取該帳戶以獲取 userId（使用已知的 userId，因為這是 mock data）
                    allAccountsList = try await dataService.fetchAccounts(userId: userId)
                    if let sourceAccount = allAccountsList.first(where: { $0.id == accountId }) {
                        let allTransactions = try await dataService.fetchAllTransactions(userId: sourceAccount.userId)
                        // 找到以該帳戶為目標帳戶的轉帳/還款交易
                        let incomingTransferTransactions = allTransactions.filter { transaction in
                            (transaction.type == .transfer || transaction.type == .repayment) &&
                            transaction.targetAccountId == accountId &&
                            transaction.accountId != accountId
                        }
                        transactions.append(contentsOf: incomingTransferTransactions)
                    }
                } catch {
                    // 如果獲取所有交易失敗，繼續使用該帳戶自己的交易
                }
                
                let balance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccountsList)
                await MainActor.run {
                    sourceAccountCashBalance = balance
                    // 載入完成後，如果金額不為空，重新驗證
                    if !amount.isEmpty {
                        validateInput()
                    }
                }
            } catch {
                await MainActor.run {
                    sourceAccountCashBalance = 0
                    // 載入失敗後，如果金額不為空，重新驗證
                    if !amount.isEmpty {
                        validateInput()
                    }
                }
            }
        }
    }
    
    private func loadExchangeRate() {
        guard selectedTargetAccount != nil else { return }
        
        Task {
            do {
                // 統一使用美金對台幣匯率（1 USD = X TWD）
                if let exchangeRateData = try await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil) {
                    await MainActor.run {
                        exchangeRate = exchangeRateData.rate.formatted(fractionDigits: 2)
                    }
                }
            } catch {
                // 如果載入失敗，使用預設值（1 USD = 32 TWD）
                await MainActor.run {
                    exchangeRate = "32.00"
                }
            }
        }
    }
    
    private func loadEditingData(transaction: Transaction) async {
        // 預填金額和日期
        amount = transaction.quantity.formatted(fractionDigits: 2)
        transactionDate = transaction.transactionDate
        
        // 優先從 targetAccountId 查找轉入帳戶
        if let targetAccountId = transaction.targetAccountId {
            selectedTargetAccount = accountsViewModel.accounts.first { $0.id == targetAccountId }
            if let targetAccount = selectedTargetAccount {
                loadTargetAccountCashBalance(accountId: targetAccount.id)
                loadExchangeRate()
            }
        }
        
        // 從notes中解析轉入帳戶名稱和備註（如果 targetAccountId 找不到）
        var extractedNotes: String?
        if let notesText = transaction.notes {
            // 解析新格式："自 A帳戶 轉帳到 B帳戶" 或 "備註 - 自 A帳戶 轉帳到 B帳戶 (匯率: 32.00)"
            var targetAccountName: String?
            
            // 先嘗試新格式：「自 A 轉帳到 B」
            if let transferToRange = notesText.range(of: "轉帳到 ") {
                let afterTo = String(notesText[transferToRange.upperBound...])
                // 移除匯率部分
                if let rateRange = afterTo.range(of: " (匯率:") {
                    targetAccountName = String(afterTo[..<rateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    targetAccountName = afterTo.trimmingCharacters(in: .whitespaces)
                }
            }
            
            // 如果沒有匹配到新格式，嘗試舊格式
            if targetAccountName == nil {
                // 解析舊格式："轉帳至 帳戶名稱" 或 "備註 - 轉帳至 帳戶名稱" 或 "轉帳至 帳戶名稱 (匯率: 32.00)"
                if notesText.contains("轉帳至 ") {
                    let parts = notesText.components(separatedBy: "轉帳至 ")
                    if parts.count > 1 {
                        let accountPart = parts[1]
                        targetAccountName = accountPart.components(separatedBy: " (匯率:")[0].trimmingCharacters(in: .whitespaces)
                    }
                } else if notesText.contains("轉帳自 ") {
                    let parts = notesText.components(separatedBy: "轉帳自 ")
                    if parts.count > 1 {
                        let accountPart = parts[1]
                        targetAccountName = accountPart.components(separatedBy: " (匯率:")[0].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            // 提取備註（如果有「 - 」分隔符，且備註在「 - 」之前）
            if let dashRange = notesText.range(of: " - ") {
                let beforeDash = String(notesText[..<dashRange.lowerBound])
                // 檢查是否包含「自」或「轉帳」或「還款」，如果不包含則為備註
                if !beforeDash.contains("自") && !beforeDash.contains("轉帳") && !beforeDash.contains("還款") {
                    extractedNotes = beforeDash.trimmingCharacters(in: .whitespaces)
                }
            }
            
            // 如果還沒有找到轉入帳戶，嘗試從解析出的名稱查找
            if selectedTargetAccount == nil, let accountName = targetAccountName {
                selectedTargetAccount = accountsViewModel.accounts.first { $0.name == accountName }
                if let targetAccount = selectedTargetAccount {
                    loadTargetAccountCashBalance(accountId: targetAccount.id)
                    loadExchangeRate()
                }
            }
            
            // 設置備註
            notes = extractedNotes ?? ""
            
            // 從 transaction.exchangeRate 讀取匯率（如果有的話，用於向後兼容，也嘗試從 notes 解析）
            if let rate = transaction.exchangeRate {
                exchangeRate = rate.formatted(fractionDigits: 2)
            } else {
                // 向後兼容：嘗試從 notes 解析匯率（僅用於舊數據）
                if let rateRange = notesText.range(of: "匯率: ") {
                    let rateString = String(notesText[rateRange.upperBound...])
                    if let rateEnd = rateString.firstIndex(of: ")") {
                        let rateValue = String(rateString[..<rateEnd])
                        exchangeRate = rateValue.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
    }
    
    private func saveTransferAsync(
        transferTransaction: Transaction,
        receivedAmount: Decimal
    ) async {
        let transactionsViewModel = TransactionsViewModel()
        
        if let editingTransaction = editingTransaction {
            // 編輯模式：更新現有交易
            // 創建一個新的交易對象，使用原交易的 id 和 createdAt
            let updatedTransaction = Transaction(
                id: editingTransaction.id,
                accountId: transferTransaction.accountId,
                type: transferTransaction.type,
                assetType: transferTransaction.assetType,
                symbol: transferTransaction.symbol,
                quantity: transferTransaction.quantity,
                price: transferTransaction.price,
                currency: transferTransaction.currency,
                fee: transferTransaction.fee,
                notes: transferTransaction.notes,
                transactionDate: transferTransaction.transactionDate,
                createdAt: editingTransaction.createdAt,
                updatedAt: Date(),
                targetAccountId: transferTransaction.targetAccountId,
                exchangeRate: transferTransaction.exchangeRate
            )
            await transactionsViewModel.updateTransaction(updatedTransaction)
        } else {
            // 新增模式：建立一筆新交易
            await transactionsViewModel.createTransaction(transferTransaction)
        }
        
        // 更新兩個帳戶的資料
        if allowSourceAccountSelection, let sourceAccount = selectedSourceAccount {
            // 還款模式：更新選擇的轉出帳戶
            let sourceAccountViewModel = AccountDetailViewModel()
            await sourceAccountViewModel.refresh(accountId: sourceAccount.id)
        } else {
            // 轉帳模式：更新原始帳戶
            await viewModel.refresh(accountId: account.id)
        }
        if let targetAccount = selectedTargetAccount {
            let targetAccountViewModel = AccountDetailViewModel()
            await targetAccountViewModel.refresh(accountId: targetAccount.id)
        }
        await MainActor.run {
            dismiss()
        }
    }
    
    private func updateTransferTransactions(
        editingTransaction: Transaction,
        amountValue: Decimal,
        receivedAmount: Decimal,
        fromNotes: String,
        toNotes: String,
        targetAccount: Account,
        transactionsViewModel: TransactionsViewModel
    ) async {
        // 更新轉出交易
        var updatedFromTransaction = editingTransaction
        updatedFromTransaction.quantity = amountValue
        updatedFromTransaction.price = 1
        updatedFromTransaction.notes = fromNotes
        updatedFromTransaction.transactionDate = transactionDate
        await transactionsViewModel.updateTransaction(updatedFromTransaction)
        
        // 找到並更新轉入交易
        let allTransactions: [Transaction]
        do {
            allTransactions = try await dataService.fetchAllTransactions(userId: userId)
        } catch {
            await MainActor.run {
                errorMessage = "載入交易失敗：\(error.localizedDescription)"
            }
            return
        }
        
        // 更精確的匹配：通過日期和帳戶名稱匹配
        let originalDate = editingTransaction.transactionDate
        let accountName = actualSourceAccount.name
        let targetAccountId = targetAccount.id
        
        // 判斷是否為還款模式（轉入帳戶是債務帳戶）
        let isRepayment = targetAccount.accountType == .debt
        
        let toTransaction = allTransactions.first(where: { trans in
            let isSameAccount = trans.accountId == targetAccountId
            let isDeposit = trans.type == .deposit
            let isSameDate = abs(trans.transactionDate.timeIntervalSince(originalDate)) < 1.0
            // 還款模式：匹配 "自" 或 "定期還款自" 開頭的備註；轉帳模式：匹配 "轉帳自" 開頭的備註
            let hasMatchingNote: Bool
            if isRepayment {
                hasMatchingNote = trans.notes?.contains("自 \(accountName)") ?? false || 
                                 trans.notes?.contains("定期還款自 \(accountName)") ?? false
            } else {
                hasMatchingNote = trans.notes?.contains("轉帳自 \(accountName)") ?? false
            }
            return isSameAccount && isDeposit && isSameDate && hasMatchingNote
        })
        
        if let toTransaction = toTransaction {
            var updatedToTransaction = toTransaction
            updatedToTransaction.quantity = receivedAmount
            updatedToTransaction.price = 1
            updatedToTransaction.notes = toNotes
            updatedToTransaction.transactionDate = transactionDate
            await transactionsViewModel.updateTransaction(updatedToTransaction)
            
            // 同時更新目標帳戶的持股
            let targetAccountViewModel = AccountDetailViewModel()
            await targetAccountViewModel.refresh(accountId: targetAccount.id)
        }
    }
    
    private func calculateReceivedAmount(amount: Decimal, rate: Decimal) -> Decimal {
        // rate 是美金對台幣匯率（1 USD = rate TWD）
        if actualSourceAccount.currency == .USD && selectedTargetAccount?.currency == .TWD {
            // USD to TWD: amount * rate
            return amount * rate
        } else if actualSourceAccount.currency == .TWD && selectedTargetAccount?.currency == .USD {
            // TWD to USD: amount / rate
            return amount / rate
        }
        return amount
    }
    
    
    private func saveTransfer() {
        guard let targetAccount = selectedTargetAccount,
              let amountValue = Decimal(string: amount),
              amountValue > 0,
              amountValue <= actualSourceCashBalance else {
            return
        }
        
        var receivedAmount = amountValue
        var exchangeRateValue: Decimal? = nil
        
        // 如果幣別不同，計算轉入金額並記錄匯率
        if targetAccount.currency != actualSourceAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate), rateValue > 0 else {
                return
            }
            // rateValue 是美金對台幣匯率（1 USD = rateValue TWD）
            receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
            exchangeRateValue = rateValue
        }
        
        // 判斷是否為還款模式（轉入帳戶是債務帳戶）
        let isRepayment = targetAccount.accountType == .debt
        
        Task {
            // 生成單一交易的備註（格式：自A轉帳到B 或 自A還款到B，包含匯率顯示）
            var transactionNotes: String
            var exchangeRateText = ""
            
            // 如果有跨幣別，在備註中顯示匯率（用於查看，但計算使用 exchangeRate 欄位）
            if let rateValue = exchangeRateValue {
                exchangeRateText = " (匯率: \(rateValue.formatted(fractionDigits: 2)))"
            }
            
            if isRepayment {
                // 還款模式：先計算本金和利息，然後生成備註
                var baseNotes: String
                if notes.isEmpty {
                    baseNotes = "自 \(actualSourceAccount.name) 還款到 \(targetAccount.name)\(exchangeRateText)"
                } else {
                    baseNotes = "\(notes) - 自 \(actualSourceAccount.name) 還款到 \(targetAccount.name)\(exchangeRateText)"
                }
                
                // 計算本金和利息
                if let (principalPortion, interestPortion) = await calculatePrincipalAndInterest(
                    receivedAmount: receivedAmount,
                    debtAccount: targetAccount
                ) {
                    // 生成本金和利息的文字
                    let principalText = principalPortion.formatted(currency: targetAccount.currency)
                    let interestText = interestPortion.formatted(currency: targetAccount.currency)
                    transactionNotes = "\(baseNotes) 本金償還\(principalText)，利息償還\(interestText)"
                } else {
                    // 如果計算失敗，使用基本備註
                    transactionNotes = baseNotes
                }
            } else {
                // 轉帳模式：格式為「自A轉帳到B」
                if notes.isEmpty {
                    transactionNotes = "自 \(actualSourceAccount.name) 轉帳到 \(targetAccount.name)\(exchangeRateText)"
                } else {
                    transactionNotes = "\(notes) - 自 \(actualSourceAccount.name) 轉帳到 \(targetAccount.name)\(exchangeRateText)"
                }
            }
            
            // 只創建一筆交易，記錄在轉出帳戶
            let transferTransaction = Transaction(
                accountId: actualSourceAccount.id,
                type: isRepayment ? .repayment : .transfer,
                assetType: .cash,
                symbol: "CASH",
                quantity: amountValue,
                price: 1,
                currency: actualSourceAccount.currency,
                fee: 0,
                notes: transactionNotes,
                transactionDate: transactionDate,
                targetAccountId: targetAccount.id,
                exchangeRate: exchangeRateValue
            )
            
            await saveTransferAsync(
                transferTransaction: transferTransaction,
                receivedAmount: receivedAmount
            )
            
            // 如果是還款模式，更新債務的剩餘本金
            if isRepayment {
                await updateLiabilityAfterRepayment(receivedAmount: receivedAmount, debtAccount: targetAccount)
            }
        }
    }
    
    // 還款模式：計算本金和利息
    private func calculatePrincipalAndInterest(receivedAmount: Decimal, debtAccount: Account) async -> (principal: Decimal, interest: Decimal)? {
        do {
            // 債務記錄是根據原始還款帳戶 ID（account.id）存儲的
            let repaymentAccountId = account.id
            
            // 從原始還款帳戶查找債務
            let liabilities = try await dataService.fetchLiabilities(accountId: repaymentAccountId)
            
            // 通過債務帳戶名稱匹配找到對應的債務
            if let liability = liabilities.first(where: { $0.name == debtAccount.name }) {
                // 計算月利率
                let monthlyRate = liability.monthlyRate
                
                // 計算當月還款中的本金和利息
                // 當月利息 = 剩餘本金 × 月利率
                let interestPortion = liability.remainingBalance * monthlyRate
                
                // 當月本金 = 還款金額 - 當月利息
                // 如果還款金額不等於每月應繳金額，則按比例計算
                let principalPortion: Decimal
                if receivedAmount >= liability.monthlyPayment {
                    // 正常還款或提前還款：本金 = 還款金額 - 利息
                    principalPortion = receivedAmount - interestPortion
                } else {
                    // 部分還款：按比例計算本金
                    let ratio = receivedAmount / liability.monthlyPayment
                    principalPortion = (liability.monthlyPayment - interestPortion) * ratio
                }
                
                return (principalPortion, interestPortion)
            }
        } catch {
            // 如果計算失敗，返回 nil
            print("計算本金和利息失敗：\(error.localizedDescription)")
        }
        return nil
    }
    
    // 還款模式：更新債務的剩餘本金
    private func updateLiabilityAfterRepayment(receivedAmount: Decimal, debtAccount: Account) async {
        do {
            // 債務記錄是根據原始還款帳戶 ID（account.id）存儲的
            // 即使用戶選擇了其他帳戶來還款，債務記錄仍然在原始還款帳戶下
            let repaymentAccountId = account.id
            
            // 從原始還款帳戶查找債務
            let liabilities = try await dataService.fetchLiabilities(accountId: repaymentAccountId)
            
            // 通過債務帳戶名稱匹配找到對應的債務
            if let liability = liabilities.first(where: { $0.name == debtAccount.name }) {
                var updatedLiability = liability
                
                // 計算月利率
                let monthlyRate = updatedLiability.monthlyRate
                
                // 計算當月還款中的本金和利息
                // 當月利息 = 剩餘本金 × 月利率
                let interestPortion = updatedLiability.remainingBalance * monthlyRate
                
                // 當月本金 = 還款金額 - 當月利息
                // 如果還款金額不等於每月應繳金額，則按比例計算
                let principalPortion: Decimal
                if receivedAmount >= updatedLiability.monthlyPayment {
                    // 正常還款或提前還款：本金 = 還款金額 - 利息
                    principalPortion = receivedAmount - interestPortion
                } else {
                    // 部分還款：按比例計算本金
                    let ratio = receivedAmount / updatedLiability.monthlyPayment
                    principalPortion = (updatedLiability.monthlyPayment - interestPortion) * ratio
                }
                
                // 只從剩餘本金減去本金部分
                updatedLiability.remainingBalance -= principalPortion
                if updatedLiability.remainingBalance < 0 {
                    updatedLiability.remainingBalance = 0
                }
                
                // 更新已還期數（如果還款金額 >= 每月應繳金額）
                if receivedAmount >= updatedLiability.monthlyPayment {
                    updatedLiability.paidPeriods += 1
                }
                
                updatedLiability.updatedAt = Date()
                try await dataService.updateLiability(updatedLiability)
            }
        } catch {
            // 如果更新失敗，記錄錯誤但不阻止交易
            print("更新債務剩餘本金失敗：\(error.localizedDescription)")
        }
    }
}

// MARK: - 轉帳帳戶選擇器 Sheet
struct TransferAccountPickerSheet: View {
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    @Environment(\.dismiss) var dismiss
    private let dataService: DataServiceProtocol = MockDataService.shared
    @State private var accountBalances: [String: Decimal] = [:]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button(action: {
                        selectedAccount = account
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: account.accountType.icon)
                                .font(.system(size: 24))
                                .foregroundColor(account.accountType.color)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                Text(account.accountType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                if let balance = accountBalances[account.id] {
                                    Text("現金餘額：\(balance.formatted(currency: account.currency))")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("選擇轉入帳戶")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadAccountBalances()
            }
        }
    }
    
    private func loadAccountBalances() async {
        for account in accounts {
            do {
                var transactions = try await dataService.fetchTransactions(accountId: account.id)
                
                // 獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
                var allAccountsList: [Account] = []
                do {
                    // 使用帳戶的 userId 來獲取所有帳戶
                    allAccountsList = try await dataService.fetchAccounts(userId: account.userId)
                    if let targetAccount = allAccountsList.first(where: { $0.id == account.id }) {
                        let allTransactions = try await dataService.fetchAllTransactions(userId: targetAccount.userId)
                        let incomingTransferTransactions = allTransactions.filter { transaction in
                            (transaction.type == .transfer || transaction.type == .repayment) &&
                            transaction.targetAccountId == account.id &&
                            transaction.accountId != account.id
                        }
                        transactions.append(contentsOf: incomingTransferTransactions)
                    }
                } catch {
                    // 如果獲取所有交易失敗，繼續使用該帳戶自己的交易
                }
                
                let balance = CashCalculator.calculateCash(accountId: account.id, transactions: transactions, accounts: allAccountsList.isEmpty ? accounts : allAccountsList)
                await MainActor.run {
                    accountBalances[account.id] = balance
                }
            } catch {
                await MainActor.run {
                    accountBalances[account.id] = 0
                }
            }
        }
    }
}

#Preview {
    TransferView(
        account: Account(userId: "test", name: "國泰證券", accountType: .twdSecurities, currency: .TWD),
        viewModel: AccountDetailViewModel()
    )
}

