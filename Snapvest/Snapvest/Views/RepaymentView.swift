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
    let repaymentType: RepaymentType  // 還款類型（提前還款或定期還款）
    let editingTransaction: Transaction? // 編輯模式：如果提供，則為編輯模式
    let preloadedAccounts: [Account]?
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountsViewModel = AccountsViewModel()
    
    @State private var deductFromTWDAccount = false
    @State private var selectedSourceAccount: Account?
    @State private var debtAccount: Account?
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var userId: String = AppUser.id
    @State private var showingAccountPicker = false
    @State private var errorMessage: String? = nil
    @State private var sourceAccountCashBalance: Decimal = 0
    @State private var showFullRepayment: Bool = false  // 全額還款選項
    @State private var editBaseline: RepaymentEditBaseline?
    @State private var isDeductInfoAlertPresented = false
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    private var themeColor: Color {
        .appPrimary
    }

    private var deductInfoMessage: String {
        "還款會記錄到債務帳戶。勾選此選項時，系統會同時扣除還款金額；未勾選則僅記錄還款，不影響帳戶餘額。債務帳戶只能從同幣別帳戶扣款。"
    }
    
    init(
        liability: Liability,
        repaymentType: RepaymentType = .regular,
        editingTransaction: Transaction? = nil,
        preloadedAccounts: [Account]? = nil
    ) {
        self.liability = liability
        self.repaymentType = repaymentType
        self.editingTransaction = editingTransaction
        self.preloadedAccounts = preloadedAccounts
        
        if editingTransaction == nil {
            switch repaymentType {
            case .regular:
                _amount = State(initialValue: Self.prefilledRegularAmount(for: liability))
            case .prepayment:
                _amount = State(initialValue: "")
            }
            _notes = State(initialValue: Self.prefilledNotes(for: repaymentType))
        }
        
        if let accounts = preloadedAccounts, !accounts.isEmpty {
            _debtAccount = State(initialValue: Self.debtAccount(in: accounts, liability: liability))
        }
    }
    
    private static let integerRounding = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    private static func prefilledRegularAmount(for liability: Liability) -> String {
        let monthlyRate = liability.monthlyRate
        let currentMonthInterest = liability.remainingBalance * monthlyRate
        let remainingTotal = liability.remainingBalance + currentMonthInterest
        
        let amount: Decimal
        if remainingTotal < liability.monthlyPayment {
            amount = (remainingTotal as NSDecimalNumber)
                .rounding(accordingToBehavior: integerRounding).decimalValue
        } else {
            amount = (liability.monthlyPayment as NSDecimalNumber)
                .rounding(accordingToBehavior: integerRounding).decimalValue
        }
        return amount.formatted(fractionDigits: 0)
    }
    
    private static func prefilledNotes(for repaymentType: RepaymentType) -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        if repaymentType == .prepayment {
            return "\(year)/\(String(format: "%02d", month))提前還款"
        }
        return "\(year)/\(String(format: "%02d", month))還款"
    }
    
    private static func debtAccount(in accounts: [Account], liability: Liability) -> Account? {
        accounts.first { $0.accountType == .debt && $0.name == liability.name }
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: repaymentType == .prepayment ? "arrow.down.circle.fill" : "creditcard.fill")
                        .font(.system(size: 24))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(repaymentType == .prepayment ? "提前還款" : "定期還款")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                    Text(repaymentType == .prepayment
                         ? "提前償還部分本金，保持月還款額不變，縮短還款期限。"
                         : "記錄本期還款，可選擇是否從同幣別帳戶扣款。")
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
    
    private var deductFromAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeColor)
                Text("從同幣別帳戶扣款")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                Button {
                    isDeductInfoAlertPresented = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeColor.opacity(0.9))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("從同幣別帳戶扣款說明")
            }

            Toggle(isOn: $deductFromTWDAccount) {
                Text("從同幣別帳戶中扣除此筆款項")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            .tint(themeColor)
            .onChange(of: deductFromTWDAccount) { _, enabled in
                if !enabled {
                    selectedSourceAccount = nil
                }
            }
            
            if deductFromTWDAccount {
                AccountPickerTriggerField(
                    placeholder: "選擇 \(liability.currency.rawValue) 帳戶",
                    selectedAccount: selectedSourceAccount,
                    subtitle: sourceAccountPickerSubtitle,
                    tint: themeColor,
                    action: { showingAccountPicker = true }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var debtAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("債務帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack(spacing: 12) {
                    if let debtAccount = debtAccount {
                        CurrencyIconBadge(currency: debtAccount.currency, tint: debtAccount.accountType.color)

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

                    Spacer(minLength: 0)
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
                Text("還款金額 (\(liability.currency.rawValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            // 提前還款時顯示全額還款選項
            if repaymentType == .prepayment {
                VStack(alignment: .leading, spacing: 8) {
                    // 計算全額還款（剩餘本金 + 當月利息）
                    let monthlyRate = liability.monthlyRate
                    let currentMonthInterest = liability.remainingBalance * monthlyRate
                    let fullAmount = liability.remainingBalance + currentMonthInterest
                    
                    Button(action: {
                        let roundedAmount = (fullAmount as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                            roundingMode: .plain,
                            scale: 0,
                            raiseOnExactness: false,
                            raiseOnOverflow: false,
                            raiseOnUnderflow: false,
                            raiseOnDivideByZero: false
                        ))
                        amount = roundedAmount.decimalValue.formatted(fractionDigits: 0)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("全額還款")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(themeColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(themeColor.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // 顯示剩餘本金和當月利息的金額
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("剩餘本金：")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(liability.remainingBalance.formatted(currency: liability.currency))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                        
                        HStack(spacing: 4) {
                            Text("當月利息：")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(currentMonthInterest.formatted(currency: liability.currency))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 4)
            }
            
            CardView {
                HStack {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.headline)
                        .disabled(repaymentType == .regular && editingTransaction == nil)
                        .onChange(of: amount) { oldValue, newValue in
                            handleAmountChange(oldValue: oldValue, newValue: newValue)
                        }
                }
            }
            
            // 提前還款時顯示預估結果
            if repaymentType == .prepayment, let amountValue = Decimal(string: amount), amountValue > 0 {
                prepaymentPreviewSection(amountValue: amountValue)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - 提前還款預估結果
    @ViewBuilder
    private func prepaymentPreviewSection(amountValue: Decimal) -> some View {
        if let preview = calculatePrepaymentPreview(amountValue: amountValue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeColor)
                    Text("預估結果")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "還款後剩餘本金", 
                               value: preview.newRemainingBalance.formatted(currency: liability.currency))
                        
                        if preview.newRemainingPeriods > 0 {
                            InfoRow(label: "還款後剩餘期數", 
                                   value: "\(preview.newRemainingPeriods) 期")
                        } else {
                            InfoRow(label: "還款狀態", 
                                   value: "債務已全部還清",
                                   valueColor: .profitGreen)
                        }
                        
                        // 當次提前還款所付的利息
                        let currentMonthInterest = liability.remainingBalance * liability.monthlyRate
                        if currentMonthInterest > 0 {
                            InfoRow(label: "當次提前還款所付的利息", 
                                   value: currentMonthInterest.formatted(currency: liability.currency),
                                   valueColor: .primaryText)
                        }
                        
                        // 剩餘利息（提前還款後，後續需要支付的利息）
                        if preview.remainingInterest > 0 {
                            InfoRow(label: "剩餘利息", 
                                   value: preview.remainingInterest.formatted(currency: liability.currency),
                                   valueColor: .primaryText)
                        }
                        
                        // 預估節省利息
                        if preview.savedInterest > 0 {
                            InfoRow(label: "預估節省利息", 
                                   value: preview.savedInterest.formatted(currency: liability.currency),
                                   valueColor: .profitGreen)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 資訊行組件
    private struct InfoRow: View {
        let label: String
        let value: String
        var valueColor: Color = .primaryText
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
        }
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
                SnapTappableDateField(
                    date: $transactionDate,
                    sheetTitle: "日期",
                    showsLeadingIcon: false
                )
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    debtAccountSection
                    amountSection
                    if editingTransaction == nil {
                        deductFromAccountSection
                    }
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .snapFormScrollDismissesKeyboard()
            .background(Color.mainBackground)
            .navigationTitle(editingTransaction != nil ? "編輯還款" : (repaymentType == .prepayment ? "提前還款" : "定期還款"))
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
                    saveRepayment()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                        Text(editingTransaction != nil ? "確認修改" : "確認還款")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? themeColor : AppColors.disabledBackground)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountSelectionSheet(
                    title: "選擇扣款帳戶",
                    accounts: availableSourceAccounts,
                    selectedAccount: $selectedSourceAccount,
                    subtitle: accountSelectionSubtitle,
                    tint: themeColor
                )
                .snapFormSheetChrome()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    loadSourceAccountCashBalance(
                        accountId: account.id,
                        accounts: accountsViewModel.accounts
                    )
                }
            }
            .alert("從同幣別帳戶扣款說明", isPresented: $isDeductInfoAlertPresented) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(deductInfoMessage)
            }
        }
        .snapFormSheetChrome()
    }
    
    // MARK: - Computed Properties
    private var sourceAccountPickerSubtitle: String? {
        guard let account = selectedSourceAccount else { return nil }
        return accountSelectionSubtitle(account)
    }

    private func accountSelectionSubtitle(_ account: Account) -> String {
        if let balance = accountsViewModel.balancesByAccountId[account.id] {
            return "現金餘額：\(balance.cashBalance.formatted(currency: account.currency))"
        }
        if account.id == selectedSourceAccount?.id, sourceAccountCashBalance > 0 {
            return "現金餘額：\(sourceAccountCashBalance.formatted(currency: account.currency))"
        }
        return account.accountType.displayName
    }

    private var availableSourceAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            guard account.currency == liability.currency else { return false }
            return account.accountType == .twdDeposit || account.accountType == .twdSecurities
        }
    }
    
    private var hasEditChanges: Bool {
        guard editingTransaction != nil, let editBaseline else { return true }
        return !EditFormChangeTracking.decimalStringsEqual(amount, editBaseline.amountText)
            || EditFormChangeTracking.normalizedNote(notes) != EditFormChangeTracking.normalizedNote(editBaseline.notes)
            || !EditFormChangeTracking.datesEqual(transactionDate, editBaseline.date)
            || deductFromTWDAccount != editBaseline.deductFromTWDAccount
            || selectedSourceAccount?.id != editBaseline.sourceAccountId
    }

    private var isValid: Bool {
        guard debtAccount != nil,
              let amountValue = Decimal(string: amount),
              amountValue > 0 else {
            return false
        }

        if editingTransaction != nil, !hasEditChanges {
            return false
        }

        if repaymentType == .regular, liability.remainingBalance <= 0 {
            return false
        }
        
        if deductFromTWDAccount {
            guard selectedSourceAccount != nil else { return false }
            if amountValue > sourceAccountCashBalance { return false }
        }
        
        let receivedAmount = amountValue
        let tolerance: Decimal = 1
        let roundHandler = NSDecimalNumberHandler(
            roundingMode: .plain, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        
        if repaymentType == .prepayment {
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            let fullAmount = liability.remainingBalance + currentMonthInterest
            let maxRepaymentRounded = (fullAmount as NSDecimalNumber).rounding(accordingToBehavior: roundHandler).decimalValue
            let minRepaymentRounded = (currentMonthInterest as NSDecimalNumber).rounding(accordingToBehavior: roundHandler).decimalValue
            if receivedAmount > maxRepaymentRounded + tolerance { return false }
            if receivedAmount < minRepaymentRounded - tolerance { return false }
        } else if repaymentType == .regular {
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            let remainingTotal = liability.remainingBalance + currentMonthInterest
            if remainingTotal < liability.monthlyPayment {
                let finalAmountRounded = (remainingTotal as NSDecimalNumber).rounding(accordingToBehavior: roundHandler).decimalValue
                if abs(receivedAmount - finalAmountRounded) > tolerance { return false }
            } else {
                let monthlyPaymentRounded = (liability.monthlyPayment as NSDecimalNumber).rounding(accordingToBehavior: roundHandler).decimalValue
                if abs(receivedAmount - monthlyPaymentRounded) > tolerance { return false }
            }
        }
        
        return true
    }
    
    // MARK: - Functions
    private func loadInitialData() async {
        if let preloadedAccounts, !preloadedAccounts.isEmpty {
            accountsViewModel.accounts = preloadedAccounts
        } else if accountsViewModel.accounts.isEmpty {
            await accountsViewModel.loadAccounts(userId: userId)
        }
        
        if debtAccount == nil {
            debtAccount = Self.debtAccount(in: accountsViewModel.accounts, liability: liability)
        }
        
        if let sourceAccount = selectedSourceAccount, deductFromTWDAccount {
            loadSourceAccountCashBalance(
                accountId: sourceAccount.id,
                accounts: accountsViewModel.accounts
            )
        }
    }
    
    private func loadEditingData(transaction: Transaction) async {
        amount = transaction.quantity.formatted(fractionDigits: 0)
        transactionDate = transaction.transactionDate
        debtAccount = accountsViewModel.accounts.first { $0.id == transaction.accountId }
        
        if let notesText = transaction.notes {
            let parts = notesText.components(separatedBy: " - ")
            if let first = parts.first,
               first == "提前還款" || first == "定期還款" {
                if parts.count > 2,
                   !parts[1].contains("本金償還"),
                   !parts[1].contains("利息償還") {
                    notes = parts[1]
                } else {
                    notes = ""
                }
            } else {
                notes = notesText
            }
        }
        captureEditBaseline()
    }

    private func captureEditBaseline() {
        guard editingTransaction != nil else {
            editBaseline = nil
            return
        }
        editBaseline = RepaymentEditBaseline(
            amountText: amount,
            notes: notes,
            date: transactionDate,
            deductFromTWDAccount: deductFromTWDAccount,
            sourceAccountId: selectedSourceAccount?.id
        )
    }

    private func loadSourceAccountCashBalance(accountId: String, accounts: [Account]) {
        Task {
            do {
                let transactions = try await dataService.fetchTransactions(accountId: accountId)
                
                let accountList: [Account]
                if accounts.isEmpty {
                    accountList = try await dataService.fetchAccounts(userId: userId)
                } else {
                    accountList = accounts
                }
                
                await MainActor.run {
                    sourceAccountCashBalance = CashCalculator.calculateCash(
                        accountId: accountId,
                        transactions: transactions,
                        accounts: accountList
                    )
                }
            } catch {
                await MainActor.run {
                    sourceAccountCashBalance = 0
                }
            }
        }
    }
    
    private func handleAmountChange(oldValue: String, newValue: String) {
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            amount = filtered
        }
    }
    
    // MARK: - 提前還款計算邏輯（方案A：保持月還款額不變，縮短期限）
    struct PrepaymentPreview {
        let newRemainingBalance: Decimal
        let newRemainingPeriods: Int
        let savedInterest: Decimal  // 預估節省利息
        let remainingInterest: Decimal  // 剩餘利息（提前還款後，後續需要支付的利息）
    }
    
    private func calculatePrepaymentPreview(amountValue: Decimal) -> PrepaymentPreview? {
        guard repaymentType == .prepayment, debtAccount != nil else {
            return nil
        }
        
        let receivedAmount = amountValue
        
        // 檢查金額是否有效
        let monthlyRate = liability.monthlyRate
        let currentMonthInterest = liability.remainingBalance * monthlyRate
        let maxRepayment = liability.remainingBalance + currentMonthInterest
        
        // 如果金額小於當月利息或大於最大還款額，返回 nil
        if receivedAmount < currentMonthInterest || receivedAmount > maxRepayment {
            return nil
        }
        
        // 1. 計算提前還款本金部分
        let prepaymentPrincipal = receivedAmount - currentMonthInterest
        
        // 2. 計算新的剩餘本金
        let newRemainingBalance = max(0, liability.remainingBalance - prepaymentPrincipal)
        
        // 3. 如果還清了，返回結果
        let monthlyPayment = liability.monthlyPayment
        if newRemainingBalance <= 0 {
            // 計算節省的利息：還款前的剩餘利息 - 當次提前還款所付的利息
            // 還款前的剩餘利息 = 還款前的 remainingTotalAmount - 還款前的剩餘本金
            let beforeRemainingTotalAmount = liability.remainingTotalAmount
            let beforeRemainingInterest = beforeRemainingTotalAmount - liability.remainingBalance
            
            // 如果還清了，剩餘利息為0，節省的利息 = 還款前的剩餘利息 - 當次提前還款所付的利息
            let savedInterest = beforeRemainingInterest - currentMonthInterest
            
            return PrepaymentPreview(
                newRemainingBalance: 0,
                newRemainingPeriods: 0,
                savedInterest: max(0, savedInterest),
                remainingInterest: 0
            )
        }
        
        // 4. 保持月還款額不變，重新計算剩餘期數
        let newRemainingPeriods = calculateRemainingPeriods(
            remainingBalance: newRemainingBalance,
            monthlyPayment: monthlyPayment,
            monthlyRate: monthlyRate
        )
        
        // 5. 計算利息（確保：預估節省利息 + 當次提前還款所付的利息 + 剩餘利息 = 原計劃剩餘期數的總利息）
        // 使用 remainingTotalAmount 來計算剩餘利息，而不是使用 calculateTotalInterest
        
        // 還款前的剩餘利息 = 還款前的 remainingTotalAmount - 還款前的剩餘本金
        let beforeRemainingTotalAmount = liability.remainingTotalAmount
        let beforeRemainingInterest = beforeRemainingTotalAmount - liability.remainingBalance
        
        // 創建臨時的 Liability 對象來計算還款後的 remainingTotalAmount
        var tempLiability = liability
        tempLiability.remainingBalance = newRemainingBalance
        
        // 計算還款後的 paidPeriods（使用 newRemainingPeriods）
        if newRemainingBalance <= 0 {
            tempLiability.paidPeriods = liability.totalPeriods
        } else {
            // 使用 newRemainingPeriods 來計算新的 paidPeriods
            let newPaidPeriods = liability.totalPeriods - newRemainingPeriods
            tempLiability.paidPeriods = max(0, min(newPaidPeriods, liability.totalPeriods))
        }
        
        // 還款後的剩餘利息 = 還款後的 remainingTotalAmount - 還款後的剩餘本金
        let afterRemainingTotalAmount = tempLiability.remainingTotalAmount
        let remainingInterest = afterRemainingTotalAmount - newRemainingBalance
        
        // 當次提前還款所付的利息 = currentMonthInterest
        // 預估節省利息 = 還款前的剩餘利息 - 當次提前還款所付的利息 - 還款後的剩餘利息
        let savedInterest = beforeRemainingInterest - currentMonthInterest - remainingInterest
        
        return PrepaymentPreview(
            newRemainingBalance: newRemainingBalance,
            newRemainingPeriods: newRemainingPeriods,
            savedInterest: max(0, savedInterest),
            remainingInterest: remainingInterest
        )
    }
    
    // 根據剩餘本金和月還款額計算剩餘期數
    private func calculateRemainingPeriods(
        remainingBalance: Decimal,
        monthlyPayment: Decimal,
        monthlyRate: Decimal
    ) -> Int {
        // 如果無息或利率接近0
        guard monthlyRate > 0.0001 else {
            let periods = Double(truncating: (remainingBalance / monthlyPayment) as NSDecimalNumber)
            return Int(ceil(periods))
        }
        
        // 使用等額本息公式反向計算期數
        // 從公式：每月還款額 = 本金 × [月利率 × (1+月利率)^n] / [(1+月利率)^n - 1]
        // 推導出：n = log(1 + 本金×月利率/每月還款額) / log(1 + 月利率)
        
        let balanceNS = NSDecimalNumber(decimal: remainingBalance)
        let paymentNS = NSDecimalNumber(decimal: monthlyPayment)
        let rateNS = NSDecimalNumber(decimal: monthlyRate)
        
        let numerator = balanceNS.multiplying(by: rateNS).dividing(by: paymentNS)
        let onePlusRate = NSDecimalNumber.one.adding(rateNS)
        
        let periods = log(1 + numerator.doubleValue) / log(onePlusRate.doubleValue)
        return Int(ceil(periods))
    }
    
    // 計算總利息
    private func calculateTotalInterest(
        remainingBalance: Decimal,
        monthlyPayment: Decimal,
        periods: Int,
        monthlyRate: Decimal
    ) -> Decimal {
        // 總利息 = 每月還款額 × 期數 - 剩餘本金
        return monthlyPayment * Decimal(periods) - remainingBalance
    }
    
    private func saveRepayment() {
        guard let debtAccount = debtAccount,
              let amountValue = Decimal(string: amount),
              amountValue > 0 else {
            errorMessage = "請檢查輸入的金額是否有效"
            return
        }
        
        if deductFromTWDAccount {
            guard selectedSourceAccount != nil else {
                errorMessage = "請選擇扣款帳戶"
                return
            }
            if amountValue > sourceAccountCashBalance {
                errorMessage = "扣款金額不能超過帳戶現金餘額"
                return
            }
        }
        
        let receivedAmount = amountValue
        
        // 提前還款：檢查邊界情況
        if repaymentType == .prepayment {
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            let fullAmount = liability.remainingBalance + currentMonthInterest
            
            // 計算最大還款金額（與全額還款按鈕的計算保持一致，四捨五入到整數）
            let maxRepaymentRounded = (fullAmount as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )).decimalValue
            
            // 計算最小還款金額（當月利息，四捨五入到整數）
            let minRepaymentRounded = (currentMonthInterest as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )).decimalValue
            
            // 允許小的精度誤差（1），因為格式化可能導致微小差異
            let tolerance: Decimal = 1
            
            // 檢查金額是否至少覆蓋當月利息（允許容錯範圍）
            if receivedAmount < minRepaymentRounded - tolerance {
                errorMessage = "還款金額至少需要覆蓋當月利息 \(minRepaymentRounded.formatted(currency: liability.currency))"
                return
            }
            
            // 檢查金額是否超過最大還款額（剩餘本金 + 當月利息，允許容錯範圍）
            if receivedAmount > maxRepaymentRounded + tolerance {
                errorMessage = "還款金額不能超過剩餘本金加上當月利息 \(maxRepaymentRounded.formatted(currency: liability.currency))"
                return
            }
        }
        
        errorMessage = nil
        
        Task {
            await saveRepaymentAsync(
                debtAccount: debtAccount,
                amountValue: amountValue,
                deductFromAccount: deductFromTWDAccount ? selectedSourceAccount : nil
            )
        }
    }
    
    private func saveRepaymentAsync(
        debtAccount: Account,
        amountValue: Decimal,
        deductFromAccount: Account?
    ) async {
        let transactionsViewModel = TransactionsViewModel()
        do {
            let receivedAmount = amountValue
            
            // ===== 記錄還款前的狀態（用於刪除時恢復） =====
            let beforeRepaymentBalance = liability.remainingBalance
            let beforeRepaymentInterest = liability.remainingTotalAmount - liability.remainingBalance
            let beforeRepaymentPaidPeriods = liability.paidPeriods
            let beforeRepaymentTotalPeriods = liability.totalPeriods  // 還款前的總期數（提前還款時總期數永遠不變）
            
            // ===== 計算本金和利息部分（提前還款和定期還款統一邏輯） =====
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            
            let principalAmount: Decimal
            let interestAmount: Decimal
            var actualRepaymentAmount = receivedAmount
            
            if repaymentType == .prepayment {
                // 提前還款：實際還款金額扣除當月利息後為本金部分
                // 如果金額小於當月利息，則全部為利息，本金為0
                if receivedAmount <= currentMonthInterest {
                    interestAmount = receivedAmount
                    principalAmount = 0
                } else {
                    interestAmount = currentMonthInterest
                    principalAmount = receivedAmount - currentMonthInterest
                }
            } else {
                // 定期還款：檢查是否為最後一期（剩餘本金+利息 < 每月還款金額）
                let remainingTotal = liability.remainingBalance + currentMonthInterest
                
                if remainingTotal < liability.monthlyPayment {
                    // 最後一期：調整還款金額為剩餘本金+利息（確保賬戶歸0）
                    actualRepaymentAmount = remainingTotal
                    interestAmount = currentMonthInterest
                    principalAmount = liability.remainingBalance
                } else {
                    // 正常期數：使用等額本息公式計算本金和利息
                    // 當月應還利息 = 剩餘本金 × 月利率
                    interestAmount = min(currentMonthInterest, receivedAmount)
                    // 當月應還本金 = 還款金額 - 當月利息
                    principalAmount = receivedAmount - interestAmount
                }
            }
            
            let repaymentTypePrefix = repaymentType == .prepayment ? "提前還款" : "定期還款"
            var transactionNotes = repaymentTypePrefix
            let noteText = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !noteText.isEmpty {
                transactionNotes += " - \(noteText)"
            }
            let principalNote = "本金償還 \(principalAmount.formatted(currency: liability.currency))"
            let interestNote = "利息償還 \(interestAmount.formatted(currency: liability.currency))"
            transactionNotes += " - \(principalNote), \(interestNote)"
            
            // ===== 計算節省利息（如果是提前還款） =====
            // 需要在創建交易前計算，因為需要存儲在 Transaction 中
            let calculatedSavedInterest: Decimal
            if repaymentType == .prepayment {
                // 使用正確的邏輯計算節省利息：基於 remainingTotalAmount
                // 還款前的剩餘總利息 = 還款前的 remainingTotalAmount - 還款前的剩餘本金
                // 創建臨時的 Liability 對象來計算還款前的 remainingTotalAmount
                var beforeRepaymentLiability = liability
                beforeRepaymentLiability.remainingBalance = beforeRepaymentBalance
                beforeRepaymentLiability.paidPeriods = beforeRepaymentPaidPeriods
                
                let beforeRemainingTotalAmount = beforeRepaymentLiability.remainingTotalAmount
                let beforeRemainingInterest = beforeRemainingTotalAmount - beforeRepaymentBalance
                
                // 計算還款後的狀態（臨時計算，用於計算節省利息）
                let tempRemainingBalance = max(0, beforeRepaymentBalance - principalAmount)
                
                // 創建臨時的 Liability 對象來計算還款後的 remainingTotalAmount
                // 需要先計算還款後的 paidPeriods（使用與更新 liability 相同的邏輯）
                var tempLiability = liability
                tempLiability.remainingBalance = tempRemainingBalance
                
                if tempRemainingBalance <= 0 {
                    tempLiability.paidPeriods = liability.totalPeriods
                } else {
                    // 使用迭代方法計算剩餘期數（與更新 liability 時的邏輯相同）
                    let originalRemainingPeriods = liability.totalPeriods - beforeRepaymentPaidPeriods
                    var estimatedPeriods = originalRemainingPeriods
                    var finalPeriods = estimatedPeriods
                    var iterations = 10
                    
                    while iterations > 0 {
                        let remainingTotalAmount: Decimal
                        if estimatedPeriods <= 0 {
                            remainingTotalAmount = 0
                        } else if monthlyRate <= 0.0001 {
                            remainingTotalAmount = tempRemainingBalance
                        } else {
                            let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
                            let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
                            let power = onePlusRate.raising(toPower: estimatedPeriods)
                            let balanceNS = NSDecimalNumber(decimal: tempRemainingBalance)
                            let numerator = balanceNS.multiplying(by: monthlyRateNS).multiplying(by: power)
                            let denominator = power.subtracting(NSDecimalNumber.one)
                            let adjustedMonthlyPayment = numerator.dividing(by: denominator).decimalValue
                            remainingTotalAmount = adjustedMonthlyPayment * Decimal(estimatedPeriods)
                        }
                        
                        if liability.monthlyPayment > 0 && remainingTotalAmount > 0 {
                            let quotient = remainingTotalAmount / liability.monthlyPayment
                            let quotientNSDecimal = NSDecimalNumber(decimal: quotient)
                            let roundUp = NSDecimalNumberHandler(
                                roundingMode: .up, scale: 0,
                                raiseOnExactness: false, raiseOnOverflow: false,
                                raiseOnUnderflow: false, raiseOnDivideByZero: false
                            )
                            finalPeriods = Int(truncating: quotientNSDecimal.rounding(accordingToBehavior: roundUp))
                        } else {
                            finalPeriods = 0
                        }
                        
                        if finalPeriods == estimatedPeriods { break }
                        estimatedPeriods = finalPeriods
                        iterations -= 1
                    }
                    
                    let newPaidPeriods = liability.totalPeriods - finalPeriods
                    tempLiability.paidPeriods = max(0, min(newPaidPeriods, liability.totalPeriods))
                }
                
                let afterRemainingTotalAmount = tempLiability.remainingTotalAmount
                let afterRemainingInterest = afterRemainingTotalAmount - tempRemainingBalance
                
                // 節省利息 = 還款前的剩餘利息 - 當次提前還款所付的利息 - 還款後的剩餘利息
                calculatedSavedInterest = beforeRemainingInterest - interestAmount - afterRemainingInterest
            } else {
                // 定期還款沒有節省利息
                calculatedSavedInterest = 0
            }
            
            // ===== 創建單一 .repayment 交易（存儲總還款金額） =====
            // 提前計算 savedInterest（如果是提前還款），用於存儲在交易中
            let savedInterestForTransaction: Decimal? = (repaymentType == .prepayment) ? max(0, calculatedSavedInterest) : nil
            
            let repaymentQuantity = (actualRepaymentAmount as NSDecimalNumber).rounding(
                accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain, scale: 0,
                    raiseOnExactness: false, raiseOnOverflow: false,
                    raiseOnUnderflow: false, raiseOnDivideByZero: false
                )
            ).decimalValue
            
            let repaymentTransaction: Transaction
            if let editingTransaction = editingTransaction {
                repaymentTransaction = Transaction(
                    id: editingTransaction.id,
                    accountId: debtAccount.id,
                    type: .repayment,
                    assetType: .cash,
                    symbol: "REPAY",
                    quantity: repaymentQuantity,
                    price: 1,
                    currency: liability.currency,
                    fee: 0,
                    notes: transactionNotes,
                    transactionDate: transactionDate,
                    createdAt: editingTransaction.createdAt,
                    updatedAt: Date(),
                    beforeRepaymentBalance: beforeRepaymentBalance,
                    beforeRepaymentInterest: beforeRepaymentInterest,
                    beforeRepaymentPaidPeriods: beforeRepaymentPaidPeriods,
                    beforeRepaymentTotalPeriods: beforeRepaymentTotalPeriods,
                    principalAmount: principalAmount,
                    interestAmount: interestAmount,
                    savedInterest: savedInterestForTransaction
                )
                await transactionsViewModel.updateTransaction(repaymentTransaction)
            } else {
                repaymentTransaction = Transaction(
                    accountId: debtAccount.id,
                    type: .repayment,
                    assetType: .cash,
                    symbol: "REPAY",
                    quantity: repaymentQuantity,
                    price: 1,
                    currency: liability.currency,
                    fee: 0,
                    notes: transactionNotes,
                    transactionDate: transactionDate,
                    beforeRepaymentBalance: beforeRepaymentBalance,
                    beforeRepaymentInterest: beforeRepaymentInterest,
                    beforeRepaymentPaidPeriods: beforeRepaymentPaidPeriods,
                    beforeRepaymentTotalPeriods: beforeRepaymentTotalPeriods,
                    principalAmount: principalAmount,
                    interestAmount: interestAmount,
                    savedInterest: savedInterestForTransaction
                )
                await transactionsViewModel.createTransaction(repaymentTransaction)
                
                if let deductAccount = deductFromAccount {
                    let deductAmount = repaymentType == .regular ? repaymentQuantity : repaymentQuantity
                    var withdrawNotes = "還款扣款：\(debtAccount.name)"
                    if !noteText.isEmpty {
                        withdrawNotes += " - \(noteText)"
                    }
                    let withdrawTransaction = Transaction(
                        accountId: deductAccount.id,
                        type: .withdraw,
                        assetType: .cash,
                        symbol: "CASH",
                        quantity: deductAmount,
                        price: 1,
                        currency: deductAccount.currency,
                        fee: 0,
                        notes: withdrawNotes,
                        transactionDate: transactionDate
                    )
                    await transactionsViewModel.createTransaction(withdrawTransaction)
                }
            }
            
            // ===== 根據還款類型更新債務（方案A：固定月還款額，縮短期限） =====
            var updatedLiability = liability
            
            if repaymentType == .prepayment {
                // 提前還款邏輯（基於剩餘本息總額計算剩餘期數）：
                // 1. 總期數不變（保持原始 totalPeriods，不修改）
                // 2. 更新剩餘本金（直接減去本金部分）
                // 3. 計算剩餘總額（剩餘本金 + 剩餘利息），剩餘利息由等額本息公式自動計算
                // 4. 剩餘期數 = 向上取整(剩餘總額 / 每月應繳金額)
                // 5. 已還期數 = 總期數 - 剩餘期數
                // 例如：提前還款 50,000 後，剩餘本金 50,192，剩餘利息 386，剩餘總額 50,578
                //       剩餘期數 = 向上取整(50,578 / 8,438) = 向上取整(5.99408) = 6期
                //       已還期數 = 12 - 6 = 6期
                
                // 先更新剩餘本金（直接減去本金部分）
                // principalAmount 已經計算好了（receivedAmount - currentMonthInterest），直接減去即可
                let previousPaidPeriods = updatedLiability.paidPeriods
                updatedLiability.remainingBalance -= principalAmount
                
                if updatedLiability.remainingBalance < 0 {
                    updatedLiability.remainingBalance = 0
                }
                
                // 如果剩餘本金 <= 0，已還期數 = 總期數（例如：12/12）
                if updatedLiability.remainingBalance <= 0 {
                    updatedLiability.paidPeriods = updatedLiability.totalPeriods
                } else {
                    // 計算剩餘期數（基於剩餘本息總額，使用迭代方法解決循環依賴）
                    // 邏輯：
                    // 1. 使用迭代方法，先假設剩餘期數 = totalPeriods - previousPaidPeriods
                    // 2. 根據剩餘本金和假設的剩餘期數，計算 remainingTotalAmount
                    // 3. 根據 remainingTotalAmount 和每月應繳金額，計算實際剩餘期數
                    // 4. 如果實際剩餘期數和假設的不同，重複步驟2-3，直到收斂
                    
                    let monthlyRate = updatedLiability.monthlyRate
                    var estimatedRemainingPeriods = updatedLiability.totalPeriods - previousPaidPeriods
                    var remainingPeriods = estimatedRemainingPeriods
                    var maxIterations = 10  // 最大迭代次數，防止無限循環
                    
                    while maxIterations > 0 {
                        // 根據假設的剩餘期數，計算剩餘總額（使用等額本息公式）
                        let remainingTotalAmount: Decimal
                        
                        if estimatedRemainingPeriods <= 0 {
                            remainingTotalAmount = 0
                        } else if monthlyRate <= 0.0001 {
                            // 無息貸款：剩餘總額 = 剩餘本金
                            remainingTotalAmount = updatedLiability.remainingBalance
                        } else {
                            // 使用等額本息公式計算剩餘總額
                            let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
                            let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
                            let power = onePlusRate.raising(toPower: estimatedRemainingPeriods)
                            let balanceNS = NSDecimalNumber(decimal: updatedLiability.remainingBalance)
                            
                            // 使用等額本息公式計算：每月還款額 = 剩餘本金 * (月利率 * (1+月利率)^n) / ((1+月利率)^n - 1)
                            let numerator = balanceNS.multiplying(by: monthlyRateNS).multiplying(by: power)
                            let denominator = power.subtracting(NSDecimalNumber.one)
                            let adjustedMonthlyPayment = numerator.dividing(by: denominator).decimalValue
                            
                            // 剩餘總額 = 調整後的每月還款額 × 剩餘期數
                            remainingTotalAmount = adjustedMonthlyPayment * Decimal(estimatedRemainingPeriods)
                        }
                        
                        // 計算實際剩餘期數 = 向上取整(剩餘總額 / 每月應繳金額)
                        if updatedLiability.monthlyPayment > 0 && remainingTotalAmount > 0 {
                            let quotient = remainingTotalAmount / updatedLiability.monthlyPayment
                            let quotientNSDecimal = NSDecimalNumber(decimal: quotient)
                            let roundUp = NSDecimalNumberHandler(
                                roundingMode: .up,
                                scale: 0,
                                raiseOnExactness: false,
                                raiseOnOverflow: false,
                                raiseOnUnderflow: false,
                                raiseOnDivideByZero: false
                            )
                            let roundedQuotient = quotientNSDecimal.rounding(accordingToBehavior: roundUp)
                            remainingPeriods = Int(truncating: roundedQuotient)
                        } else {
                            remainingPeriods = 0
                        }
                        
                        // 如果計算出的剩餘期數和假設的相同，收斂完成
                        if remainingPeriods == estimatedRemainingPeriods {
                            break
                        }
                        
                        // 使用計算出的剩餘期數作為下一次迭代的假設值
                        estimatedRemainingPeriods = remainingPeriods
                        maxIterations -= 1
                    }
                    
                    // 計算已還期數 = 總期數 - 剩餘期數
                    let newPaidPeriods = updatedLiability.totalPeriods - remainingPeriods
                    updatedLiability.paidPeriods = max(0, min(newPaidPeriods, updatedLiability.totalPeriods))
                }
                
                // 提前還款：使用已計算的節省利息（在創建交易前已計算）
                let savedInterest = savedInterestForTransaction ?? 0
                
                // 更新已還款本金、已支出利息、節省利息
                updatedLiability.totalPaidPrincipal += principalAmount
                updatedLiability.totalPaidInterest += interestAmount
                updatedLiability.totalSavedInterest += savedInterest
                
                // 注意：totalPeriods 永遠不變（這是方案A的要求：固定月還款額，縮短期限，但總期數記錄保持不變）
            } else {
                // 定期還款：只減去本金部分，遞增已還期數（如果還沒還清）
                updatedLiability.remainingBalance -= principalAmount
                if updatedLiability.remainingBalance < 0 {
                    updatedLiability.remainingBalance = 0
                }
                
                // 定期還款：遞增已還期數（如果還沒還清）
                if updatedLiability.remainingBalance > 0 && updatedLiability.paidPeriods < updatedLiability.totalPeriods {
                    updatedLiability.paidPeriods += 1
                }
                
                // 如果還清了，已還期數 = 總期數（但總期數保持不變）
                if updatedLiability.remainingBalance <= 0 {
                    updatedLiability.paidPeriods = updatedLiability.totalPeriods
                }
                
                // 定期還款：更新已還款本金和已支出利息（不節省利息）
                updatedLiability.totalPaidPrincipal += principalAmount
                updatedLiability.totalPaidInterest += interestAmount
                // 注意：totalPeriods 永遠不變（這是方案A的要求：固定月還款額，縮短期限，但總期數記錄保持不變）
            }
            
            updatedLiability.accountId = debtAccount.id
            updatedLiability.updatedAt = Date()
            
            try await MockDataService.shared.updateLiability(updatedLiability)

            await MainActor.run {
                dismiss()
            }
            } catch {
            await MainActor.run {
                errorMessage = "還款失敗：\(error.localizedDescription)"
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
