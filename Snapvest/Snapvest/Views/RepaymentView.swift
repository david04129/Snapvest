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
    @State private var showFullRepayment: Bool = false  // 全額還款選項
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    // 債務主題顏色（預設）
    private var debtThemeColorBase: Color {
        Color.lossRed
    }
    
    // 提前還款主題顏色（紅色）
    private var prepaymentColor: Color {
        Color(red: 0.85, green: 0.15, blue: 0.15)
    }
    
    // 定期還款主題顏色（橘色）
    private var regularRepaymentColor: Color {
        Color(red: 1.0, green: 0.55, blue: 0.0)
    }
    
    // 根據還款類型返回對應的主題顏色
    private var debtThemeColor: Color {
        repaymentType == .prepayment ? prepaymentColor : regularRepaymentColor
    }
    
    // 提前還款主題漸層（紅色漸層）
    private var prepaymentGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color(red: 0.85, green: 0.15, blue: 0.15), Color(red: 0.95, green: 0.3, blue: 0.3)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // 定期還款主題漸層（橘色漸層）
    private var regularRepaymentGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.0), Color(red: 1.0, green: 0.7, blue: 0.2)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // 根據還款類型返回對應的漸層
    private var debtThemeGradient: LinearGradient {
        repaymentType == .prepayment ? prepaymentGradient : regularRepaymentGradient
    }
    
    init(liability: Liability, repaymentType: RepaymentType = .regular, editingTransaction: Transaction? = nil) {
        self.liability = liability
        self.repaymentType = repaymentType
        self.editingTransaction = editingTransaction
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 圖標（債務風格：紅色）
                ZStack {
                    Circle()
                        .fill(debtThemeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: repaymentType == .prepayment ? "arrow.down.circle.fill" : "creditcard.fill")
                        .font(.system(size: 24))
                        .foregroundColor(debtThemeColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(repaymentType == .prepayment ? "提前還款" : "定期還款")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                    Text(repaymentType == .prepayment 
                         ? "提前償還部分本金，保持月還款額不變，縮短還款期限。"
                         : "從還款帳戶轉帳至債務帳戶。")
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
                    .foregroundColor(debtThemeColor)
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
                    .foregroundColor(debtThemeColor)
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
                    .foregroundColor(debtThemeColor)
                Text("還款金額 (\(selectedSourceAccount?.currency.rawValue ?? liability.currency.rawValue))")
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
                        // 全額還款金額：四捨五入到整數（而不是向下取整）
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
                    .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.15), Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.15)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    }
                    
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
                        .foregroundColor(debtThemeColor)
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
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        if let sourceAccount = selectedSourceAccount,
           let debtAccount = debtAccount,
           sourceAccount.currency != debtAccount.currency {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(debtThemeColor)
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
                    .foregroundColor(debtThemeColor)
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
                    .foregroundColor(debtThemeColor)
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
            .navigationTitle(editingTransaction != nil ? "編輯還款" : (repaymentType == .prepayment ? "提前還款" : "定期還款"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(debtThemeColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(debtThemeColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    saveRepayment()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: repaymentType == .prepayment ? "arrow.down.circle.fill" : "creditcard.fill")
                            .font(.system(size: 18))
                        Text(editingTransaction != nil ? "確認修改" : "確認還款")
                            .font(.headline)
                    }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    .background(isValid ? debtThemeGradient : LinearGradient(gradient: Gradient(colors: [Color.gray, Color.gray]), startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                }
                .disabled(!isValid)
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
            account.accountType != .debt && // 不能選擇債務帳戶
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
        
        // 定期還款：如果剩餘本金已經為0，禁止還款
        if repaymentType == .regular {
            if liability.remainingBalance <= 0 {
                return false
            }
        }
        
        // 檢查轉帳金額不能超過轉出帳戶的現金餘額
        if amountValue > sourceAccountCashBalance {
            return false
        }
        
        // 提前還款：檢查金額是否至少覆蓋當月利息
        if repaymentType == .prepayment {
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            
            // 計算實際收到的金額（跨幣別需要轉換）
            let receivedAmount: Decimal
            if sourceAccount.currency != debtAccount.currency {
                guard let rateValue = Decimal(string: exchangeRate),
                      rateValue > 0 else {
                    return false
                }
                receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
            } else {
                receivedAmount = amountValue
            }
            
            // 提前還款金額不能超過剩餘本金 + 當月利息（全額還款的上限）
            // 計算最大還款金額（與全額還款按鈕的計算保持一致）
            let fullAmount = liability.remainingBalance + currentMonthInterest
            // 將最大還款金額四捨五入到整數（與全額還款按鈕的格式化保持一致）
            let maxRepaymentRounded = (fullAmount as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )).decimalValue
            
            // 允許小的精度誤差（1），因為格式化可能導致微小差異
            let tolerance: Decimal = 1
            if receivedAmount > maxRepaymentRounded + tolerance {
                return false
            }
            
            // 提前還款金額至少需要覆蓋當月利息（允許小的精度誤差）
            // 將當月利息也四捨五入到整數進行比較
            let currentMonthInterestRounded = (currentMonthInterest as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )).decimalValue
            
            if receivedAmount < currentMonthInterestRounded - tolerance {
                return false
            }
        } else if repaymentType == .regular {
            // 定期還款：檢查是否為最後一期，如果是，允許還款金額等於剩餘本金+利息（考慮小數點誤差）
            let monthlyRate = liability.monthlyRate
            let currentMonthInterest = liability.remainingBalance * monthlyRate
            let remainingTotal = liability.remainingBalance + currentMonthInterest
            
            // 計算實際收到的金額（跨幣別需要轉換）
            let receivedAmount: Decimal
            if sourceAccount.currency != debtAccount.currency {
                guard let rateValue = Decimal(string: exchangeRate),
                      rateValue > 0 else {
                    return false
                }
                receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
            } else {
                receivedAmount = amountValue
            }
            
            // 如果剩餘本金+利息 < 每月還款金額，則為最後一期
            if remainingTotal < liability.monthlyPayment {
                // 最後一期：還款金額應該等於剩餘本金+利息（允許小數點誤差）
                let finalAmountRounded = (remainingTotal as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )).decimalValue
                
                // 允許小的精度誤差（1），因為格式化可能導致微小差異
                let tolerance: Decimal = 1
                if abs(receivedAmount - finalAmountRounded) > tolerance {
                    return false
                }
            } else {
                // 正常期數：還款金額應該等於每月還款金額（允許小數點誤差）
                let monthlyPaymentRounded = (liability.monthlyPayment as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )).decimalValue
                
                // 允許小的精度誤差（1），因為格式化可能導致微小差異
                let tolerance: Decimal = 1
                if abs(receivedAmount - monthlyPaymentRounded) > tolerance {
                    return false
                }
            }
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
            // 定期還款：預填轉出帳戶為還款帳戶
            // 提前還款：允許從任何帳戶轉帳（不預填，讓用戶選擇）
            if repaymentType == .regular {
                if let repaymentAccount = accountsViewModel.accounts.first(where: { $0.id == liability.accountId }) {
                    selectedSourceAccount = repaymentAccount
                    loadSourceAccountCashBalance(accountId: repaymentAccount.id)
                }
            }
            
            // 預填還款金額
            if repaymentType == .regular {
                // 定期還款：檢查是否為最後一期（剩餘本金+利息 < 每月還款金額）
                let monthlyRate = liability.monthlyRate
                let currentMonthInterest = liability.remainingBalance * monthlyRate
                let remainingTotal = liability.remainingBalance + currentMonthInterest
                
                // 如果剩餘本金+利息 < 每月還款金額，則為最後一期，使用剩餘本金+利息作為還款金額
                if remainingTotal < liability.monthlyPayment {
                    // 最後一期：使用剩餘本金+利息（四捨五入到整數）
                    let finalAmountRounded = (remainingTotal as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
                    amount = finalAmountRounded.decimalValue.formatted(fractionDigits: 0)
                } else {
                    // 正常期數：預填每月還款金額（整數，四捨五入）
                    let monthlyPaymentRounded = (liability.monthlyPayment as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
                    amount = monthlyPaymentRounded.decimalValue.formatted(fractionDigits: 0)
                }
            } else {
                // 提前還款：預填空白，讓用戶輸入任意金額
                amount = ""
            }
            
            // 預填備註
            let calendar = Calendar.current
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            
            if repaymentType == .prepayment {
                notes = "\(year)/\(String(format: "%02d", month))提前還款"
            } else {
                notes = "\(year)/\(String(format: "%02d", month))還款"
            }
            
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
    
    // MARK: - 提前還款計算邏輯（方案A：保持月還款額不變，縮短期限）
    struct PrepaymentPreview {
        let newRemainingBalance: Decimal
        let newRemainingPeriods: Int
        let savedInterest: Decimal  // 預估節省利息
        let remainingInterest: Decimal  // 剩餘利息（提前還款後，後續需要支付的利息）
    }
    
    private func calculatePrepaymentPreview(amountValue: Decimal) -> PrepaymentPreview? {
        guard repaymentType == .prepayment,
              let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount else {
            return nil
        }
        
        // 計算實際收到的金額（跨幣別需要轉換）
        let receivedAmount: Decimal
        if sourceAccount.currency != debtAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate),
                  rateValue > 0 else {
                return nil
            }
            receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
        } else {
            receivedAmount = amountValue
        }
        
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
        guard let sourceAccount = selectedSourceAccount,
              let debtAccount = debtAccount,
              let amountValue = Decimal(string: amount),
              amountValue > 0,
              amountValue <= sourceAccountCashBalance else {
            errorMessage = "請檢查輸入的金額是否有效"
            return
        }
        
        // 計算實際收到的金額（跨幣別需要轉換）
        let receivedAmount: Decimal
        if sourceAccount.currency != debtAccount.currency {
            guard let rateValue = Decimal(string: exchangeRate),
                  rateValue > 0 else {
                errorMessage = "請輸入有效的匯率"
                return
            }
            receivedAmount = calculateReceivedAmount(amount: amountValue, rate: rateValue)
        } else {
            receivedAmount = amountValue
        }
        
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
            var actualRepaymentAmount = receivedAmount  // 實際還款金額（可能被調整）
            var actualSourceAmount = amountValue  // 源賬戶實際扣除金額（可能被調整）
            
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
                    
                    // 如果跨幣種，需要將調整後的還款金額轉換回源賬戶的貨幣
                    if sourceAccount.currency != debtAccount.currency {
                        guard let rateValue = Decimal(string: exchangeRate),
                              rateValue > 0 else {
                            errorMessage = "請輸入有效的匯率"
                            return
                        }
                        // 源賬戶扣除金額 = 債務賬戶收到的金額 / 匯率
                        actualSourceAmount = actualRepaymentAmount / rateValue
                    } else {
                        // 同幣種：源賬戶扣除金額 = 債務賬戶收到的金額
                        actualSourceAmount = actualRepaymentAmount
                    }
                } else {
                    // 正常期數：使用等額本息公式計算本金和利息
                    // 當月應還利息 = 剩餘本金 × 月利率
                    interestAmount = min(currentMonthInterest, receivedAmount)
                    // 當月應還本金 = 還款金額 - 當月利息
                    principalAmount = receivedAmount - interestAmount
                }
            }
            
            // ===== 構建備註（統一格式，包含匯率顯示） =====
            let repaymentTypePrefix = repaymentType == .prepayment ? "提前還款" : "定期還款"
            var transactionNotes = "\(repaymentTypePrefix)自 \(sourceAccount.name) 還款到 \(debtAccount.name)"
            
            // 計算匯率值（如果有跨幣別，用於設置 Transaction.exchangeRate 和 notes 中的顯示）
            let exchangeRateValue: Decimal? = sourceAccount.currency != debtAccount.currency ? Decimal(string: exchangeRate) : nil
            
            // 如果有跨幣別，在備註中顯示匯率（使用與 Transaction.exchangeRate 相同的值）
            if let rateValue = exchangeRateValue {
                transactionNotes += " (匯率: \(rateValue.formatted(fractionDigits: 2)))"
            }
            
            // 先添加自定義備註（如果有）
            if !notes.isEmpty {
                transactionNotes += " - \(notes)"
            }
            
            // 在備註中標明本金償還和利息償還部分
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
            
            let repaymentTransaction: Transaction
            if let editingTransaction = editingTransaction {
                // 編輯模式：更新現有交易（但債務不允許編輯，這裡不會執行）
                repaymentTransaction = Transaction(
                    id: editingTransaction.id,
                    accountId: sourceAccount.id,
                    type: .repayment,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: actualSourceAmount,  // 使用調整後的源賬戶扣除金額
                    price: 1,
                    currency: sourceAccount.currency,
                    fee: 0,
                    notes: transactionNotes,
                    transactionDate: transactionDate,
                    createdAt: editingTransaction.createdAt,
                    updatedAt: Date(),
                    targetAccountId: debtAccount.id,
                    exchangeRate: exchangeRateValue,
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
                // 新增模式：創建單一交易
                repaymentTransaction = Transaction(
                    accountId: sourceAccount.id,
                    type: .repayment,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: actualSourceAmount,  // 使用調整後的源賬戶扣除金額
                    price: 1,
                    currency: sourceAccount.currency,
                    fee: 0,
                    notes: transactionNotes,
                    transactionDate: transactionDate,
                    targetAccountId: debtAccount.id,
                    exchangeRate: exchangeRateValue,
                    beforeRepaymentBalance: beforeRepaymentBalance,
                    beforeRepaymentInterest: beforeRepaymentInterest,
                    beforeRepaymentPaidPeriods: beforeRepaymentPaidPeriods,
                    beforeRepaymentTotalPeriods: beforeRepaymentTotalPeriods,
                    principalAmount: principalAmount,
                    interestAmount: interestAmount,
                    savedInterest: savedInterestForTransaction
                )
                await transactionsViewModel.createTransaction(repaymentTransaction)
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
