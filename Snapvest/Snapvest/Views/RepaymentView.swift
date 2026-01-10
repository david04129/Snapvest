//
//  RepaymentView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import Foundation

struct RepaymentView: View {
    let liability: Liability
    let editingTransaction: Transaction? // 編輯模式：如果提供，則為編輯模式
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    
    @State private var selectedSourceAccount: Account? // 轉出帳戶（還款帳戶）
    @State private var debtAccount: Account? // 債務帳戶（轉入帳戶，固定）
    @State private var amount: String = ""
    @State private var exchangeRate: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var userId: String = "test-user-id"
    @State private var showingAccountPicker = false
    @State private var errorMessage: String? = nil
    @State private var sourceAccountCashBalance: Decimal = 0
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    init(liability: Liability, editingTransaction: Transaction? = nil) {
        self.liability = liability
        self.editingTransaction = editingTransaction
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
                    Text("進行還款")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("從還款帳戶轉帳至債務帳戶。")
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
            
            Button(action: {
                showingAccountPicker = true
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
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var targetAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.left.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                Text("轉入帳戶（債務帳戶）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    if let debtAccount = debtAccount {
                        Image(systemName: debtAccount.accountType.icon)
                            .font(.system(size: 20))
                            .foregroundColor(debtAccount.accountType.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(debtAccount.name)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            Text("剩餘本金：\(liability.remainingBalance.formatted(currency: liability.currency))")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text(liability.name)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                    }
                    
                    Spacer()
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
                Text("還款金額 (\(selectedSourceAccount?.currency.rawValue ?? liability.currency.rawValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.headline)
                        .onChange(of: amount) { oldValue, newValue in
                            handleAmountChange(oldValue: oldValue, newValue: newValue)
                        }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        if let sourceAccount = selectedSourceAccount,
           let debtAccount = debtAccount,
           sourceAccount.currency != debtAccount.currency {
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
                        Text(calculateReceivedAmount(amount: amountValue, rate: rateValue).formatted(currency: debtAccount.currency))
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
            .navigationTitle(editingTransaction != nil ? "編輯還款" : "進行還款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確認還款") {
                        saveRepayment()
                    }
                    .disabled(!isValid)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    saveRepayment()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("確認還款")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? Color.lossRed : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding()
                .background(Color.cardBackground)
            }
            .sheet(isPresented: $showingAccountPicker) {
                RepaymentAccountPickerSheet(
                    accounts: availableSourceAccounts,
                    selectedAccount: $selectedSourceAccount
                )
            }
            .task {
                await loadInitialData()
                // 如果是編輯模式，載入編輯數據
                if let transaction = editingTransaction {
                    await loadEditingData(transaction: transaction)
                }
            }
            .onChange(of: selectedSourceAccount) { oldValue, newValue in
                if let account = newValue {
                    loadSourceAccountCashBalance(accountId: account.id)
                    loadExchangeRate()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var availableSourceAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            account.id != debtAccount?.id && // 不能選擇債務帳戶本身
            (account.accountType == .twdDeposit || account.accountType == .twdSecurities) // 只能選擇台幣帳戶
        }
    }
    
    private var isValid: Bool {
        guard let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount,
              let amountValue = Decimal(string: amount),
              amountValue > 0 else {
            return false
        }
        
        // 檢查轉帳金額不能超過轉出帳戶的現金餘額
        if amountValue > sourceAccountCashBalance {
            return false
        }
        
        // 如果是跨幣別轉帳，需要匯率
        if sourceAccount.currency != debtAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate),
                  rateValue > 0 else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Functions
    private func loadInitialData() async {
        await accountsViewModel.loadAccounts(userId: userId)
        
        // 找到債務帳戶（AccountType.debt）
        debtAccount = accountsViewModel.accounts.first { account in
            account.accountType == .debt && account.name == liability.name
        }
        
        // 如果不是編輯模式，才預填默認值
        if editingTransaction == nil {
            // 預填轉出帳戶為還款帳戶
            if let repaymentAccount = accountsViewModel.accounts.first(where: { $0.id == liability.accountId }) {
                selectedSourceAccount = repaymentAccount
                loadSourceAccountCashBalance(accountId: repaymentAccount.id)
            }
            
            // 預填還款金額為每月還款金額（整數，四捨五入）
            let monthlyPaymentRounded = (liability.monthlyPayment as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
            amount = monthlyPaymentRounded.decimalValue.formatted(fractionDigits: 0)
            
            // 預填備註為當前年月格式
            let calendar = Calendar.current
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            notes = "\(year)/\(String(format: "%02d", month))還款"
            
            // 如果是跨幣別，載入匯率
            if let sourceAccount = selectedSourceAccount,
               let debtAccount = debtAccount,
               sourceAccount.currency != debtAccount.currency {
                loadExchangeRate()
            }
        }
    }
    
    private func loadEditingData(transaction: Transaction) async {
        // 預填金額和日期
        amount = transaction.quantity.formatted(fractionDigits: 0) // 還款金額是整數
        transactionDate = transaction.transactionDate
        
        if let notesText = transaction.notes {
            // 解析備註，提取原始備註和匯率
            let pattern = "還款至 (.+?)(?: \\(匯率:.*?\\))?(?: - (.+))?$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: notesText, options: [], range: NSRange(notesText.startIndex..., in: notesText)) {
                
                if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: notesText) {
                    notes = String(notesText[range])
                } else {
                    notes = ""
                }
            } else {
                // 嘗試簡單的字符串處理
                if notesText.contains("還款至 ") {
                    let parts = notesText.components(separatedBy: "還款至 ")
                    if parts.count > 1 {
                        let accountPart = parts[1]
                        // 移除匯率部分
                        let accountName = accountPart.components(separatedBy: " (匯率:")[0].trimmingCharacters(in: .whitespaces)
                        // 如果有 " - " 分隔符，提取備註
                        if let dashRange = accountName.range(of: " - ") {
                            notes = String(accountName[dashRange.upperBound...])
                        } else {
                            notes = ""
                        }
                    }
                } else if notesText.contains("還款自 ") {
                    let parts = notesText.components(separatedBy: "還款自 ")
                    if parts.count > 1 {
                        let accountPart = parts[1]
                        // 移除匯率部分
                        let accountName = accountPart.components(separatedBy: " (匯率:")[0].trimmingCharacters(in: .whitespaces)
                        // 如果有 " - " 分隔符，提取備註
                        if let dashRange = accountName.range(of: " - ") {
                            notes = String(accountName[dashRange.upperBound...])
                        } else {
                            notes = ""
                        }
                    }
                } else {
                    notes = ""
                }
            }
            
            // 解析匯率
            if let rateRange = notesText.range(of: "匯率: ") {
                let rateString = String(notesText[rateRange.upperBound...])
                if let rateEnd = rateString.firstIndex(of: ")") {
                    let rateValue = String(rateString[..<rateEnd])
                    exchangeRate = rateValue.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // 找到轉出帳戶
        if let notesText = transaction.notes {
            var sourceAccountName: String?
            if notesText.contains("還款至 ") {
                // 這是轉出交易，轉出帳戶就是當前交易的帳戶
                sourceAccountName = accountsViewModel.accounts.first(where: { $0.id == transaction.accountId })?.name
            } else if notesText.contains("還款自 ") {
                // 這是轉入交易，需要從 notes 中提取轉出帳戶名稱
                sourceAccountName = extractAccountNameFromRepaymentNotes(notesText, isFrom: false)
            }
            
            if let accountName = sourceAccountName {
                selectedSourceAccount = accountsViewModel.accounts.first { $0.name == accountName }
                if let sourceAccount = selectedSourceAccount {
                    loadSourceAccountCashBalance(accountId: sourceAccount.id)
                }
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
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    private func loadSourceAccountCashBalance(accountId: String) {
        Task {
            do {
                var transactions = try await dataService.fetchTransactions(accountId: accountId)
                
                // 獲取所有交易，以便找到以該帳戶為目標帳戶的轉帳/還款交易
                var allAccountsList: [Account] = []
                do {
                    allAccountsList = try await dataService.fetchAccounts(userId: userId)
                    if let sourceAccount = allAccountsList.first(where: { $0.id == accountId }) {
                        let allTransactions = try await dataService.fetchAllTransactions(userId: sourceAccount.userId)
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
                
                sourceAccountCashBalance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccountsList.isEmpty ? accountsViewModel.accounts : allAccountsList)
            } catch {
                sourceAccountCashBalance = 0
            }
        }
    }
    
    private func loadExchangeRate() {
        guard let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount,
              sourceAccount.currency != debtAccount.currency else {
            return
        }
        
        Task {
            do {
                if let exchangeRateData = try await dataService.fetchExchangeRate(
                    from: sourceAccount.currency,
                    to: debtAccount.currency,
                    date: nil
                ) {
                    await MainActor.run {
                        exchangeRate = exchangeRateData.rate.formatted(fractionDigits: 2)
                    }
                }
            } catch {
                // 如果獲取匯率失敗，使用默認值
                if sourceAccount.currency == .USD && debtAccount.currency == .TWD {
                    await MainActor.run {
                        exchangeRate = "32.00"
                    }
                }
            }
        }
    }
    
    private func handleAmountChange(oldValue: String, newValue: String) {
        // 過濾非數字字符（保留小數點）
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            amount = filtered
        }
        
        // 如果是跨幣別，重新計算預計收到金額
        if let sourceAccount = selectedSourceAccount,
           let debtAccount = debtAccount,
           sourceAccount.currency != debtAccount.currency {
            loadExchangeRate()
        }
    }
    
    private func handleExchangeRateChange(oldValue: String, newValue: String) {
        // 過濾非數字字符（保留小數點）
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            exchangeRate = filtered
        }
    }
    
    private func calculateReceivedAmount(amount: Decimal, rate: Decimal) -> Decimal {
        guard let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount else {
            return 0
        }
        
        if sourceAccount.currency == .USD && debtAccount.currency == .TWD {
            return amount * rate
        } else if sourceAccount.currency == .TWD && debtAccount.currency == .USD {
            return amount / rate
        }
        return amount
    }
    
    private func saveRepayment() {
        guard let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount,
              let amountValue = Decimal(string: amount),
              amountValue > 0,
              amountValue <= sourceAccountCashBalance else {
            errorMessage = "請檢查輸入的金額是否有效"
            return
        }
        
        errorMessage = nil
        
        Task {
            await saveRepaymentAsync(
                sourceAccount: sourceAccount,
                debtAccount: debtAccount,
                amountValue: amountValue
            )
        }
    }
    
    private func saveRepaymentAsync(
        sourceAccount: Account,
        debtAccount: Account,
        amountValue: Decimal
    ) async {
        do {
            // 計算轉入金額（如果是跨幣別，需要轉換）
            let receivedAmount: Decimal
            if sourceAccount.currency != debtAccount.currency {
                guard let rateValue = Decimal(string: exchangeRate),
                      rateValue > 0 else {
                    await MainActor.run {
                        errorMessage = "請輸入有效的匯率"
                    }
                    return
                }
                receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
            } else {
                receivedAmount = amountValue
            }
            
            // 構建備註
            var fromNotes = "還款至 \(debtAccount.name)"
            var toNotes = "還款自 \(sourceAccount.name)"
            
            if sourceAccount.currency != debtAccount.currency {
                fromNotes += " (匯率: \(exchangeRate))"
                toNotes += " (匯率: \(exchangeRate))"
            }
            
            if !notes.isEmpty {
                fromNotes += " - \(notes)"
                toNotes += " - \(notes)"
            }
            
            // 創建轉出交易（從還款帳戶扣款）
            let fromTransaction = Transaction(
                accountId: sourceAccount.id,
                type: .withdraw,
                assetType: .cash,
                symbol: "CASH",
                quantity: amountValue,
                price: 1,
                currency: sourceAccount.currency,
                fee: 0,
                notes: fromNotes,
                transactionDate: transactionDate
            )
            
            // 創建轉入交易（轉入債務帳戶）
            let toTransaction = Transaction(
                accountId: debtAccount.id,
                type: .deposit,
                assetType: .cash,
                symbol: "CASH",
                quantity: receivedAmount,
                price: 1,
                currency: debtAccount.currency,
                fee: 0,
                notes: toNotes,
                transactionDate: transactionDate
            )
            
            // 更新債務的剩餘本金
            var updatedLiability = liability
            if let editingTransaction = editingTransaction {
                // 編輯模式：先恢復原來的還款金額，再減去新的還款金額
                // 找到對應的轉入交易來獲取原來的還款金額
                do {
                    let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
                    let originalDate = editingTransaction.transactionDate
                    let sourceAccountName = selectedSourceAccount?.name ?? ""
                    let targetAccountId = debtAccount.id
                    
                    if let originalToTransaction = allTransactions.first(where: { trans in
                        trans.accountId == targetAccountId &&
                        trans.type == .deposit &&
                        abs(trans.transactionDate.timeIntervalSince(originalDate)) < 1.0 &&
                        (trans.notes?.contains("還款自 \(sourceAccountName)") ?? false)
                    }) {
                        // 恢復原來的還款金額
                        updatedLiability.remainingBalance += originalToTransaction.quantity
                    }
                } catch {
                    // 如果無法獲取原來的金額，跳過恢復步驟
                }
                
                // 更新兩筆交易
                await updateRepaymentTransactions(
                    editingTransaction: editingTransaction,
                    amountValue: amountValue,
                    receivedAmount: receivedAmount,
                    fromNotes: fromNotes,
                    toNotes: toNotes,
                    targetAccount: debtAccount,
                    transactionsViewModel: transactionsViewModel
                )
            } else {
                // 新增模式：創建兩筆交易
                await transactionsViewModel.createTransaction(fromTransaction)
                await transactionsViewModel.createTransaction(toTransaction)
            }
            
            // 減去新的還款金額
            updatedLiability.remainingBalance -= receivedAmount
            if updatedLiability.remainingBalance < 0 {
                updatedLiability.remainingBalance = 0
            }
            updatedLiability.updatedAt = Date()
            
            try await MockDataService.shared.updateLiability(updatedLiability)
            
            // 刷新數據
            await portfolioViewModel.loadData(userId: userId)
            await accountsViewModel.loadAccounts(userId: userId)
            
            // 通知父視圖刷新（通過重新載入債務數據）
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "還款失敗：\(error.localizedDescription)"
            }
        }
    }
    
    private func updateRepaymentTransactions(
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
        do {
            let allTransactions = try await dataService.fetchAllTransactions(userId: userId)
            
            let originalDate = editingTransaction.transactionDate
            let sourceAccountName = selectedSourceAccount?.name ?? ""
            let targetAccountId = targetAccount.id
            
            let toTransaction = allTransactions.first(where: { trans in
                let isSameAccount = trans.accountId == targetAccountId
                let isDeposit = trans.type == .deposit
                let isSameDate = abs(trans.transactionDate.timeIntervalSince(originalDate)) < 1.0
                let hasRepaymentNote = trans.notes?.contains("還款自 \(sourceAccountName)") ?? false
                return isSameAccount && isDeposit && isSameDate && hasRepaymentNote
            })
            
            if let toTransaction = toTransaction {
                var updatedToTransaction = toTransaction
                updatedToTransaction.quantity = receivedAmount
                updatedToTransaction.price = 1
                updatedToTransaction.notes = toNotes
                updatedToTransaction.transactionDate = transactionDate
                await transactionsViewModel.updateTransaction(updatedToTransaction)
            }
        } catch {
            // Handle error if fetching all transactions fails
            await MainActor.run {
                errorMessage = "更新轉入交易失敗：\(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 還款帳戶選擇器 Sheet
struct RepaymentAccountPickerSheet: View {
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button(action: {
                        selectedAccount = account
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: account.accountType.icon)
                                .font(.system(size: 24))
                                .frame(width: 32, height: 32)
                                .foregroundColor(account.accountType.color)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                Text(account.accountType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
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
            .navigationTitle("選擇還款帳戶")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RepaymentView(
        liability: Liability(
            accountId: "test",
            name: "信貸 (富邦)",
            principal: 2300000,
            interestRate: 2.3,
            monthlyPayment: 29671,
            remainingBalance: 2270329,
            currency: .TWD,
            startDate: Date()
        )
    )
}
