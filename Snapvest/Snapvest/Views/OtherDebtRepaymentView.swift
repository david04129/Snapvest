//
//  OtherDebtRepaymentView.swift
//  Snapvest
//
//  其他債務還款（整筆扣減欠款，UI 與 RepaymentView 一致）
//

import SwiftUI

struct OtherDebtRepaymentView: View {
    let debtAccount: Account
    let prefilledAccounts: [Account]
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountsViewModel = AccountsViewModel()
    
    @State private var selectedSourceAccount: Account?
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showingAccountPicker = false
    @State private var sourceAccountCashBalance: Decimal = 0
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    private let themeColor: Color = .appPrimary
    
    private var remainingBalance: Decimal {
        OtherDebtCalculator.remainingBalance(
            accountId: debtAccount.id,
            transactions: cachedTransactions,
            accounts: accountsViewModel.accounts
        )
    }
    
    @State private var cachedTransactions: [Transaction] = []
    
    private var availableSourceAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            account.id != debtAccount.id
                && !account.accountType.isLiabilityAccount
                && account.currency == debtAccount.currency
                && (account.accountType == .twdDeposit
                    || account.accountType == .twdSecurities
                    || account.accountType == .usdAccount)
        }
    }
    
    private var isValid: Bool {
        guard let value = Decimal(string: amount.trimmingCharacters(in: .whitespaces)),
              value > 0,
              selectedSourceAccount != nil else { return false }
        return value <= remainingBalance
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    sourceAccountSection
                    targetAccountSection
                    amountSection
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .background(Color.mainBackground)
            .navigationTitle("還款")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await save() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                        Text("確認還款")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid && !isSaving ? themeColor : AppColors.disabledBackground)
                    .cornerRadius(12)
                }
                .disabled(!isValid || isSaving)
                .padding(.horizontal)
                .padding(.vertical, 16)
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
            }
            .onChange(of: selectedSourceAccount) { _, newValue in
                if let account = newValue {
                    loadSourceAccountCashBalance(accountId: account.id)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 24))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("其他債務還款")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("從存款帳戶扣款，直接減少目前欠款。")
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
                    .foregroundColor(themeColor)
                Text("轉出帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            Button { showingAccountPicker = true } label: {
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
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var targetAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.left.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("其他債務")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    Image(systemName: debtAccount.accountType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(debtAccount.accountType.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(debtAccount.name)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Text("目前欠款：\(remainingBalance.formatted(currency: debtAccount.currency))")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
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
                    .foregroundColor(themeColor)
                Text("還款金額 (\(debtAccount.currency.rawValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.headline)
                    .onChange(of: amount) { oldValue, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if filtered != newValue { amount = filtered }
                        if let value = Decimal(string: filtered), value < 0 {
                            amount = oldValue
                        }
                    }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("日期")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                DatePicker("", selection: $transactionDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
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
                    TextField("例如：還朋友五月份款項", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var errorMessageSection: some View {
        if let errorMessage {
            CardView {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.lossRed)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Data
    
    @MainActor
    private func loadInitialData() async {
        if !prefilledAccounts.isEmpty {
            accountsViewModel.accounts = prefilledAccounts
        } else {
            await accountsViewModel.loadAccounts(userId: debtAccount.userId)
        }
        
        do {
            cachedTransactions = try await dataService.fetchAllTransactions(userId: debtAccount.userId)
        } catch {
            cachedTransactions = []
        }
        
        if selectedSourceAccount == nil {
            selectedSourceAccount = availableSourceAccounts.first
        }
        if let source = selectedSourceAccount {
            loadSourceAccountCashBalance(accountId: source.id)
        }
        
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        notes = "\(year)/\(String(format: "%02d", month))還款"
    }
    
    private func loadSourceAccountCashBalance(accountId: String) {
        Task {
            do {
                async let localTransactions = dataService.fetchTransactions(accountId: accountId)
                async let allTransactions = dataService.fetchAllTransactions(userId: debtAccount.userId)
                var transactions = try await localTransactions
                let allTx = try await allTransactions
                let incoming = allTx.filter {
                    ($0.type == .transfer || $0.type == .repayment)
                        && $0.targetAccountId == accountId
                        && $0.accountId != accountId
                }
                transactions.append(contentsOf: incoming)
                let accountList = accountsViewModel.accounts
                await MainActor.run {
                    sourceAccountCashBalance = CashCalculator.calculateCash(
                        accountId: accountId,
                        transactions: transactions,
                        accounts: accountList
                    )
                }
            } catch {
                await MainActor.run { sourceAccountCashBalance = 0 }
            }
        }
    }
    
    @MainActor
    private func save() async {
        errorMessage = nil
        guard let amountValue = Decimal(string: amount.trimmingCharacters(in: .whitespaces)),
              amountValue > 0 else {
            errorMessage = "請輸入有效的還款金額"
            return
        }
        guard let source = selectedSourceAccount else {
            errorMessage = "請選擇扣款帳戶"
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let allTransactions = try await dataService.fetchAllTransactions(userId: debtAccount.userId)
            let allAccounts = try await dataService.fetchAccounts(userId: debtAccount.userId)
            let beforeBalance = OtherDebtCalculator.remainingBalance(
                accountId: debtAccount.id,
                transactions: allTransactions,
                accounts: allAccounts
            )
            guard amountValue <= beforeBalance else {
                errorMessage = "還款金額不能超過目前欠款 \(beforeBalance.formatted(currency: debtAccount.currency))"
                return
            }
            
            let noteText = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            var transactionNotes = "還款至 \(debtAccount.name)"
            if !noteText.isEmpty {
                transactionNotes += " - \(noteText)"
            }
            
            let transaction = Transaction(
                accountId: source.id,
                type: .repayment,
                assetType: .cash,
                symbol: "REPAY",
                quantity: 1,
                price: amountValue,
                currency: debtAccount.currency,
                notes: transactionNotes,
                transactionDate: transactionDate,
                targetAccountId: debtAccount.id,
                beforeRepaymentBalance: beforeBalance,
                principalAmount: amountValue,
                interestAmount: 0
            )
            
            try await dataService.createTransaction(transaction)
            
            let priceService = PriceService(dataService: dataService)
            await PortfolioStateSync.sync(
                userId: debtAccount.userId,
                dataService: dataService,
                priceService: priceService
            )
            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
            dismiss()
        } catch {
            errorMessage = "還款失敗：\(error.localizedDescription)"
        }
    }
}
