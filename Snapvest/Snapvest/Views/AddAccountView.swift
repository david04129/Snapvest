//
//  AddAccountView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AddAccountView: View {
    @ObservedObject var viewModel: AccountsViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    
    @State private var selectedAccountType: AccountType?
    @State private var selectedCurrency: Currency = .TWD
    @State private var showingAccountDetails = false
    @State private var name: String = ""
    @State private var initialBalance: String = ""
    // 債務相關欄位
    @State private var principal: String = ""
    @State private var totalPeriods: String = ""
    @State private var paidPeriods: String = "0"  // 已還期數
    @State private var interestRate: String = ""
    @State private var monthlyPayment: Decimal = 0
    @State private var repaymentDay: String = "1"
    @State private var startDate: Date = Date()  // 開始日期
    @State private var otherDebtAmount: String = ""
    @State private var otherDebtNotes: String = ""
    @State private var userId: String = AppUser.id
    @State private var duplicateNameError: String? = nil
    
    // 重置所有輸入欄位
    private func resetForm() {
        name = ""
        initialBalance = ""
        principal = ""
        totalPeriods = ""
        paidPeriods = "0"
        interestRate = ""
        monthlyPayment = 0
        repaymentDay = "1"
        startDate = Date()
        otherDebtAmount = ""
        otherDebtNotes = ""
        selectedCurrency = preferredDefaultCurrency(for: selectedAccountType)
        duplicateNameError = nil
    }
    
    private func preferredDefaultCurrency(for accountType: AccountType?) -> Currency {
        guard let accountType else { return .TWD }
        switch accountType {
        case .debt, .otherDebt:
            return BaseCurrencyManager.shared.baseCurrency
        default:
            return accountType.defaultCurrency
        }
    }

    // 檢查帳戶名稱是否重複（同一類型）
    private func isDuplicateName(_ name: String, accountType: AccountType) -> Bool {
        return viewModel.accounts.contains { account in
            account.accountType == accountType && account.name == name
        }
    }
    
    // 動態導航標題
    private var navigationTitle: String {
        if showingAccountDetails, let accountType = selectedAccountType {
            return "新增\(accountType.displayName)"
        }
        return "新增帳戶"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !showingAccountDetails {
                    // 第一步：選擇帳戶類型
                    VStack(spacing: 0) {
                        // 標題和說明
                        VStack(alignment: .leading, spacing: 8) {
                            Text("新增帳戶")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("請選擇您想建立的帳戶類型。")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 8)
                        
                        // 帳戶類型選擇（存款／投資／債務）
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(AccountCategory.allCases) { category in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(category.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondaryText)
                                        
                                        ForEach(category.accountTypes, id: \.self) { accountType in
                                            AccountTypeSelectionCard(
                                                accountType: accountType,
                                                isSelected: selectedAccountType == accountType
                                            ) {
                                                resetForm()
                                                selectedAccountType = accountType
                                                selectedCurrency = preferredDefaultCurrency(for: accountType)
                                                withAnimation {
                                                    showingAccountDetails = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    // 第二步：輸入帳戶詳情
                    if selectedAccountType == .debt {
                        DebtAccountDetailsFormView(
                            name: $name,
                            principal: $principal,
                            totalPeriods: $totalPeriods,
                            paidPeriods: $paidPeriods,
                            interestRate: $interestRate,
                            monthlyPayment: $monthlyPayment,
                            repaymentDay: $repaymentDay,
                            startDate: $startDate,
                            selectedCurrency: $selectedCurrency,
                            accountsViewModel: viewModel,
                            duplicateNameError: $duplicateNameError,
                            onCancel: {
                                resetForm() // 重置表單
                                withAnimation {
                                    showingAccountDetails = false
                                }
                            },
                            onSave: {
                                saveDebtAccount()
                            }
                        )
                    } else if selectedAccountType == .otherDebt {
                        OtherDebtAccountDetailsFormView(
                            name: $name,
                            amount: $otherDebtAmount,
                            notes: $otherDebtNotes,
                            startDate: $startDate,
                            selectedCurrency: $selectedCurrency,
                            duplicateNameError: $duplicateNameError,
                            onCancel: {
                                resetForm()
                                withAnimation {
                                    showingAccountDetails = false
                                }
                            },
                            onSave: {
                                saveOtherDebtAccount()
                            }
                        )
                    } else {
                        AccountDetailsFormView(
                            accountType: selectedAccountType!,
                            name: $name,
                            initialBalance: $initialBalance,
                            selectedCurrency: $selectedCurrency,
                            duplicateNameError: $duplicateNameError,
                            onCancel: {
                                resetForm() // 重置表單
                                withAnimation {
                                    showingAccountDetails = false
                                }
                            },
                            onSave: {
                                saveAccount()
                            }
                        )
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SnapToolbarIconButton(icon: .back) {
                        if showingAccountDetails {
                            resetForm()
                            withAnimation {
                                showingAccountDetails = false
                            }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            resetForm()
        }
        .snapFormSheetChrome()
    }
    
    private func saveAccount() {
        guard let accountType = selectedAccountType else { return }
        
        // 檢查名稱是否為空
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入帳戶名稱"
            return
        }
        
        // 檢查同一類型是否已有相同名稱的帳戶
        if isDuplicateName(name, accountType: accountType) {
            duplicateNameError = "此帳戶類型已存在相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        let account = Account(
            userId: userId,
            name: name,
            accountType: accountType,
            currency: selectedCurrency
        )
        
        Task {
            // 創建帳戶
            await viewModel.createAccount(account)
            
            // 如果有初始餘額，創建一筆 deposit 交易
            if let balance = Decimal(string: initialBalance), balance > 0 {
                let transaction = Transaction(
                    accountId: account.id,
                    type: .deposit,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: balance,
                    price: 1,
                    currency: account.currency,
                    fee: 0,
                    notes: "初始餘額",
                    transactionDate: Date()
                )
                await transactionsViewModel.createTransaction(transaction)
            }
            
            resetForm() // 重置表單
            dismiss()
        }
    }
    
    private func saveOtherDebtAccount() {
        guard selectedAccountType == .otherDebt,
              let amountValue = Decimal(string: otherDebtAmount),
              amountValue > 0 else { return }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入名稱"
            return
        }
        
        if isDuplicateName(name, accountType: .otherDebt) {
            duplicateNameError = "此類別已有相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        Task {
            let account = Account(
                userId: userId,
                name: name.trimmingCharacters(in: .whitespaces),
                accountType: .otherDebt,
                currency: selectedCurrency
            )
            await viewModel.createAccount(account)
            
            let noteText = otherDebtNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            var transactionNotes = "新增其他債務：\(account.name)"
            if !noteText.isEmpty {
                transactionNotes += "｜\(noteText)"
            }
            
            let transaction = Transaction(
                accountId: account.id,
                type: .liability,
                assetType: .cash,
                symbol: "DEBT",
                quantity: 1,
                price: amountValue,
                currency: account.currency,
                notes: transactionNotes,
                transactionDate: startDate
            )
            await transactionsViewModel.createTransaction(transaction)
            
            await viewModel.loadAccounts(userId: userId)
            await SnapshotRefreshCoordinator.rebuildAndNotify(
                userId: userId,
                dataService: MockDataService.shared
            )
            
            resetForm()
            dismiss()
        }
    }
    
    private func saveDebtAccount() {
        guard let accountType = selectedAccountType,
              accountType == .debt,
              let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate) else { return }
        
        // 檢查名稱是否為空
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入帳戶名稱"
            return
        }
        
        // 檢查同一類型是否已有相同名稱的帳戶
        if isDuplicateName(name, accountType: .debt) {
            duplicateNameError = "此帳戶類型已存在相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        Task {
            // 1. 創建債務帳戶
            let account = Account(
                userId: userId,
                name: name,
                accountType: .debt,
                currency: selectedCurrency
            )
            await viewModel.createAccount(account)
            
            // 2. 創建債務記錄
            // 計算總期數和已還期數
            let periods = Int(totalPeriods) ?? 12
            let paidPeriodsValue = Int(paidPeriods) ?? 0
            
            // 根據已還期數計算剩餘本金（方案A：等額本息公式反推）
            let calculatedRemainingBalance = calculateRemainingBalance(
                principal: principalValue,
                interestRate: rate,
                totalPeriods: periods,
                paidPeriods: paidPeriodsValue,
                monthlyPayment: monthlyPayment
            )
            
            // 使用用戶輸入的開始日期作為債務建立日期（新增債務的日期）
            // 注意：每月還款日與開始日期無關，僅用於未來還款提醒，目前不使用
            
            // 計算已還款本金和已支出利息（如果已還期數 > 0）
            let calculatedTotalPaidPrincipal: Decimal
            let calculatedTotalPaidInterest: Decimal
            
            if paidPeriodsValue > 0 {
                // 已還款本金 = 原始本金 - 剩餘本金
                calculatedTotalPaidPrincipal = principalValue - calculatedRemainingBalance
                // 已支出利息 = 已還期數 × 每月應繳金額 - 已還款本金
                calculatedTotalPaidInterest = monthlyPayment * Decimal(paidPeriodsValue) - calculatedTotalPaidPrincipal
            } else {
                // 如果還沒還款，初始值為 0
                calculatedTotalPaidPrincipal = 0
                calculatedTotalPaidInterest = 0
            }
            
            let liability = Liability(
                accountId: account.id,
                name: name,
                principal: principalValue,
                interestRate: rate,
                monthlyPayment: monthlyPayment,
                remainingBalance: calculatedRemainingBalance,
                currency: selectedCurrency,
                startDate: startDate,  // 直接使用用戶選擇的開始日期
                totalPeriods: periods,
                paidPeriods: paidPeriodsValue,
                totalPaidPrincipal: calculatedTotalPaidPrincipal,
                totalPaidInterest: calculatedTotalPaidInterest,
                totalSavedInterest: 0  // 新建債務，沒有提前還款，節省利息為 0
            )
            try? await MockDataService.shared.createLiability(liability)
            
            // 3. 創建債務帳戶的初始交易記錄（.liability 類型）
            // 如果已還期數 > 0，使用剩餘本金；否則使用原始本金
            let transactionAmount = calculatedRemainingBalance > 0 ? calculatedRemainingBalance : principalValue
            var transactionNotes = "新增債務：\(name)"
            if paidPeriodsValue > 0 {
                transactionNotes += "（已還 \(paidPeriodsValue) 期，剩餘本金 \(transactionAmount.formatted(currency: selectedCurrency))）"
            }
            
            let liabilityTransaction = Transaction(
                accountId: account.id, // 債務帳戶的 ID
                type: .liability,
                assetType: .cash,
                symbol: "CASH",
                quantity: transactionAmount,
                price: 1,
                currency: selectedCurrency,
                fee: 0,
                notes: transactionNotes,
                transactionDate: startDate  // 直接使用用戶選擇的開始日期（新增債務的日期）
            )
            await transactionsViewModel.createTransaction(liabilityTransaction)
            
            resetForm() // 重置表單
            dismiss()
        }
    }
    
    // MARK: - 計算剩餘本金（方案A：等額本息公式反推）
    /// 根據已還期數計算剩餘本金
    /// - Parameters:
    ///   - principal: 原始本金
    ///   - interestRate: 年利率
    ///   - totalPeriods: 總期數
    ///   - paidPeriods: 已還期數
    ///   - monthlyPayment: 每月還款額
    /// - Returns: 剩餘本金
    private func calculateRemainingBalance(
        principal: Decimal,
        interestRate: Decimal,
        totalPeriods: Int,
        paidPeriods: Int,
        monthlyPayment: Decimal
    ) -> Decimal {
        // 如果未還款，返回原始本金
        guard paidPeriods > 0 else {
            return principal
        }
        
        // 如果已還清，返回0
        guard paidPeriods < totalPeriods else {
            return 0
        }
        
        // 計算月利率
        let monthlyRate = interestRate / 100 / 12
        
        // 無息貸款：線性攤還
        if monthlyRate <= 0.0001 {
            let remainingPeriods = Decimal(totalPeriods - paidPeriods)
            let totalPeriodsDecimal = Decimal(totalPeriods)
            return principal * (remainingPeriods / totalPeriodsDecimal)
        }
        
        // 等額本息公式反推剩餘本金
        // remainingBalance = principal × [(1+r)^n - (1+r)^k] / [(1+r)^n - 1]
        // 其中：r = 月利率, n = 總期數, k = 已還期數
        
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        
        // 計算 (1+r)^n
        let powerN = onePlusRate.raising(toPower: totalPeriods)
        
        // 計算 (1+r)^k
        let powerK = onePlusRate.raising(toPower: paidPeriods)
        
        // 計算分子：(1+r)^n - (1+r)^k
        let numerator = powerN.subtracting(powerK)
        
        // 計算分母：(1+r)^n - 1
        let denominator = powerN.subtracting(NSDecimalNumber.one)
        
        // 防止除以0
        guard denominator.compare(NSDecimalNumber.zero) != .orderedSame else {
            return principal
        }
        
        // 計算結果：principal × numerator / denominator
        let principalNS = NSDecimalNumber(decimal: principal)
        let result = principalNS
            .multiplying(by: numerator)
            .dividing(by: denominator)
        
        return result.decimalValue
    }
}

// MARK: - 債務帳戶詳情表單
struct DebtAccountDetailsFormView: View {
    @Binding var name: String
    @Binding var principal: String
    @Binding var totalPeriods: String
    @Binding var paidPeriods: String  // 已還期數
    @Binding var interestRate: String
    @Binding var monthlyPayment: Decimal
    @Binding var repaymentDay: String
    @Binding var startDate: Date  // 開始日期
    @Binding var selectedCurrency: Currency
    @ObservedObject var accountsViewModel: AccountsViewModel
    @Binding var duplicateNameError: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var showingDatePicker = false
    
    // 計算剩餘本金（用於動態顯示）
    private var calculatedRemainingBalance: Decimal {
        return calculateRemainingBalance()
    }
    
    // 計算剩餘期數
    private var remainingPeriods: Int {
        let total = Int(totalPeriods) ?? 0
        let paid = Int(paidPeriods) ?? 0
        return max(0, total - paid)
    }
    
    // 計算剩餘應還總額（使用臨時的 Liability 對象）
    private var remainingTotalAmount: Decimal {
        guard let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate),
              let periods = Int(totalPeriods),
              let paid = Int(paidPeriods),
              periods > 0,
              paid >= 0,
              paid < periods,
              monthlyPayment > 0 else {
            return 0
        }
        
        let remainingBalance = calculateRemainingBalance()
        guard remainingBalance > 0 else {
            return 0
        }
        
        // 創建臨時 Liability 對象來使用其計算屬性
        let tempLiability = Liability(
            accountId: "",
            name: "",
            principal: principalValue,
            interestRate: rate,
            monthlyPayment: monthlyPayment,
            remainingBalance: remainingBalance,
            currency: selectedCurrency,
            startDate: Date(),
            totalPeriods: periods,
            paidPeriods: paid
        )
        
        return tempLiability.remainingTotalAmount
    }
    
    // 計算剩餘利息
    private var remainingInterest: Decimal {
        guard remainingTotalAmount > 0 else {
            return 0
        }
        let remainingTotal = remainingTotalAmount
        let remaining = calculatedRemainingBalance
        return max(0, remainingTotal - remaining)
    }
    
    // 計算剩餘本金（方案A：等額本息公式反推）
    private func calculateRemainingBalance() -> Decimal {
        guard let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate),
              let periods = Int(totalPeriods),
              let paid = Int(paidPeriods),
              periods > 0 else {
            return Decimal(string: principal) ?? 0
        }
        
        // 如果未還款，返回原始本金
        guard paid > 0 else {
            return principalValue
        }
        
        // 如果已還清，返回0
        guard paid < periods else {
            return 0
        }
        
        // 計算月利率
        let monthlyRate = rate / 100 / 12
        
        // 無息貸款：線性攤還
        if monthlyRate <= 0.0001 {
            let remainingPeriods = Decimal(periods - paid)
            let totalPeriodsDecimal = Decimal(periods)
            return principalValue * (remainingPeriods / totalPeriodsDecimal)
        }
        
        // 等額本息公式反推剩餘本金
        // remainingBalance = principal × [(1+r)^n - (1+r)^k] / [(1+r)^n - 1]
        // 其中：r = 月利率, n = 總期數, k = 已還期數
        
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        
        // 計算 (1+r)^n
        let powerN = onePlusRate.raising(toPower: periods)
        
        // 計算 (1+r)^k
        let powerK = onePlusRate.raising(toPower: paid)
        
        // 計算分子：(1+r)^n - (1+r)^k
        let numerator = powerN.subtracting(powerK)
        
        // 計算分母：(1+r)^n - 1
        let denominator = powerN.subtracting(NSDecimalNumber.one)
        
        // 防止除以0
        guard denominator.compare(NSDecimalNumber.zero) != .orderedSame else {
            return principalValue
        }
        
        // 計算結果：principal × numerator / denominator
        let principalNS = NSDecimalNumber(decimal: principalValue)
        let result = principalNS
            .multiplying(by: numerator)
            .dividing(by: denominator)
        
        return result.decimalValue
    }
    
    private let accountType = AccountType.debt
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 24) {
                    // 帳戶類型圖標卡片
                    VStack(spacing: 12) {
                        Image(systemName: accountType.icon)
                            .font(.system(size: 48))
                            .foregroundColor(accountType.color)
                            .frame(width: 80, height: 80)
                            .background(accountType.color.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(accountType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text(accountType.description)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    
                    // 表單卡片
                    VStack(spacing: 0) {
                        // 貸款名稱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("貸款名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("例如：房屋貸款", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in
                                    duplicateNameError = nil // 清除錯誤訊息
                                }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "貸款幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "預設使用主要幣別，也可以改成其他借款幣別。"
                            )
                            .padding(20)

                            Divider()
                                .padding(.horizontal, 20)
                        }

                        // 貸款總額
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("貸款總額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $principal)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: principal) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字和小數點
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        principal = filtered
                                    }
                                    // 防止負數或零
                                    if let value = Decimal(string: filtered), value <= 0 {
                                        principal = oldValue.isEmpty ? "" : oldValue
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 總期數
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("總期數")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(月)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $totalPeriods)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: totalPeriods) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        totalPeriods = filtered
                                    }
                                    // 防止負數或零
                                    if let value = Int(filtered), value <= 0, !filtered.isEmpty {
                                        totalPeriods = oldValue.isEmpty ? "" : oldValue
                                    } else {
                                        // 驗證已還期數不超過總期數
                                        if let total = Int(filtered),
                                           let paid = Int(paidPeriods),
                                           paid > total {
                                            paidPeriods = String(total)
                                        }
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 已還期數
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("已還期數")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(月)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $paidPeriods)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: paidPeriods) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        paidPeriods = filtered
                                    }
                                    // 防止負數
                                    if let value = Int(filtered), value < 0, !filtered.isEmpty {
                                        paidPeriods = oldValue.isEmpty ? "0" : oldValue
                                    } else if let paid = Int(filtered),
                                              let total = Int(totalPeriods),
                                              total > 0,
                                              paid > total {
                                        // 已還期數不能超過總期數
                                        paidPeriods = String(total)
                                    }
                                }
                            
                            // 提示訊息
                            if let paid = Int(paidPeriods), paid > 0 {
                                if let total = Int(totalPeriods), total > 0 {
                                    if paid >= total {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Text("貸款已還清")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            Text("剩餘 \(total - paid) 期")
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                        }
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 年利率
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "percent")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("年利率")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(%)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $interestRate)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: interestRate) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字和小數點
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        interestRate = filtered
                                    }
                                    // 防止負數
                                    if let value = Decimal(string: filtered), value < 0 {
                                        interestRate = oldValue
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 每月應繳金額（自動計算）
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("每月應繳金額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            HStack {
                                Text(monthlyPayment.formatted(currency: selectedCurrency))
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                Spacer()
                                
                                if monthlyPayment > 0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(accountType.color.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("系統會根據貸款總額、期數和利率自動計算")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        // 還款狀態（如果已還期數 > 0 且有有效數據）
                        if let paid = Int(paidPeriods),
                           let total = Int(totalPeriods),
                           total > 0,
                           paid > 0,
                           paid < total,
                           calculatedRemainingBalance > 0,
                           monthlyPayment > 0 {
                            Divider()
                            .padding(.horizontal, 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(accountType.color)
                                    Text("還款狀態")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primaryText)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    // 剩餘本金
                                    HStack {
                                        Text("剩餘本金")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(calculatedRemainingBalance.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .foregroundColor(.lossRed)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘期數
                                    HStack {
                                        Text("剩餘期數")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text("\(remainingPeriods) 期")
                                            .font(.headline)
                                            .foregroundColor(.primaryText)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘利息
                                    HStack {
                                        Text("剩餘利息")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(remainingInterest.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .foregroundColor(.secondaryText)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘應還總額
                                    HStack {
                                        Text("剩餘應還總額")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(remainingTotalAmount.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.lossRed)
                                    }
                                }
                                .padding()
                                .background(accountType.color.opacity(0.05))
                                .cornerRadius(12)
                            }
                            .padding(20)
                            
                            Divider()
                            .padding(.horizontal, 20)
                        }
                        
                        // 每月還款日
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("每月還款日")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("1", text: $repaymentDay)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: repaymentDay) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        repaymentDay = filtered
                                    }
                                    // 限制在1-31之間
                                    if let day = Int(filtered), !filtered.isEmpty {
                                        if day < 1 {
                                            repaymentDay = "1"
                                        } else if day > 31 {
                                            repaymentDay = "31"
                                        }
                                    }
                                }
                            
                            Text("請輸入 1-31 之間的數字")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 開始日期
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("開始日期")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            Button(action: {
                                showingDatePicker = true
                            }) {
                                HStack {
                                    Text(formatDate(startDate))
                                        .font(.body)
                                        .foregroundColor(.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondaryText)
                                }
                                .padding()
                                .background(Color.secondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("貸款的開始日期")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .background(Color.secondaryBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            // 儲存按鈕
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("建立帳戶")
                        .font(.headline)
                }
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isDebtFormValid ? accountType.color : AppColors.disabledBackground)
                .cornerRadius(12)
            }
            .disabled(!isDebtFormValid)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "選擇開始日期",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("選擇開始日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // 格式化日期為文字
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // 債務帳戶表單驗證
    private var isDebtFormValid: Bool {
        // 首先檢查每月應繳金額是否已計算（這是最嚴格的檢查）
        guard monthlyPayment > 0 else {
            return false
        }
        
        // 檢查貸款名稱
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return false
        }
        
        // 檢查貸款總額
        let trimmedPrincipal = principal.trimmingCharacters(in: .whitespaces)
        guard !trimmedPrincipal.isEmpty,
              let principalValue = Decimal(string: trimmedPrincipal),
              principalValue > 0 else {
            return false
        }
        
        // 檢查總期數
        let trimmedPeriods = totalPeriods.trimmingCharacters(in: .whitespaces)
        guard !trimmedPeriods.isEmpty,
              let periods = Int(trimmedPeriods),
              periods > 0 else {
            return false
        }
        
        // 檢查已還期數
        let trimmedPaidPeriods = paidPeriods.trimmingCharacters(in: .whitespaces)
        guard !trimmedPaidPeriods.isEmpty,
              let paid = Int(trimmedPaidPeriods),
              paid >= 0 else {
            return false
        }
        
        // 檢查已還期數不超過總期數
        guard paid <= periods else {
            return false
        }
        
        // 檢查年利率
        let trimmedRate = interestRate.trimmingCharacters(in: .whitespaces)
        guard !trimmedRate.isEmpty,
              let rate = Decimal(string: trimmedRate),
              rate >= 0 else {
            return false
        }
        
        // 檢查每月還款日
        let trimmedDay = repaymentDay.trimmingCharacters(in: .whitespaces)
        guard !trimmedDay.isEmpty,
              let day = Int(trimmedDay),
              day >= 1 && day <= 31 else {
            return false
        }
        
        return true
    }
    
    private func calculateMonthlyPayment() {
        guard let principalValue = Decimal(string: principal),
              let periods = Int(totalPeriods),
              let rate = Decimal(string: interestRate),
              periods > 0,
              rate >= 0 else {
            monthlyPayment = 0
            return
        }
        
        // 計算每月應繳金額（等額本息）
        // M = P * [r(1+r)^n] / [(1+r)^n - 1]
        // 其中 M = 每月還款額，P = 本金，r = 月利率，n = 期數
        
        // 使用 NSDecimalNumber 進行精確計算
        let principalNS = NSDecimalNumber(decimal: principalValue)
        let monthlyRateNS = NSDecimalNumber(decimal: rate / 100 / 12)
        let n = periods
        
        if rate == 0 {
            // 無利息，平均攤還
            monthlyPayment = (principalNS.dividing(by: NSDecimalNumber(value: n))).decimalValue
        } else {
            // 計算 (1+r)^n
            let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
            let power = onePlusRate.raising(toPower: n)
            
            // 計算分子：P * r * (1+r)^n
            let numerator = principalNS
                .multiplying(by: monthlyRateNS)
                .multiplying(by: power)
            
            // 計算分母：(1+r)^n - 1
            let denominator = power.subtracting(NSDecimalNumber.one)
            
            // 計算結果：numerator / denominator
            monthlyPayment = numerator.dividing(by: denominator).decimalValue
        }
    }
}

// MARK: - 幣別下拉選單

private struct CurrencyDropdownField: View {
    let title: String
    let icon: String
    let color: Color
    let options: [Currency]
    @Binding var selectedCurrency: Currency
    var helperText: String?
    @State private var showingCurrencyPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }

            Button {
                showingCurrencyPicker = true
            } label: {
                HStack(spacing: 10) {
                    CurrencyCodeChip(currency: selectedCurrency, tint: color)

                    Text(selectedCurrency.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: 44)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencySelectionSheet(
                    title: title,
                    options: options,
                    selectedCurrency: $selectedCurrency,
                    tint: color
                )
                .snapFormSheetChrome()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }

            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(.leading, 4)
            }
        }
    }
}

private struct CurrencySelectionSheet: View {
    let title: String
    let options: [Currency]
    @Binding var selectedCurrency: Currency
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    selectedSummary

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { currency in
                            currencyRow(currency)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color.mainBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .background(Color.mainBackground)
    }

    private var selectedSummary: some View {
        HStack(spacing: 12) {
            CurrencyIconBadge(currency: selectedCurrency, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("目前選擇")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(selectedCurrency.settingsDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }

    private func currencyRow(_ currency: Currency) -> some View {
        let isSelected = selectedCurrency == currency
        return Button {
            selectedCurrency = currency
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CurrencyIconBadge(currency: currency, tint: isSelected ? tint : .secondaryText)

                VStack(alignment: .leading, spacing: 3) {
                    Text(currency.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(currency.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText.opacity(0.7))
                }
            }
            .padding(14)
            .background(isSelected ? tint.opacity(0.10) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.36) : Color.separator.opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 帳戶詳情表單
struct AccountDetailsFormView: View {
    let accountType: AccountType
    @Binding var name: String
    @Binding var initialBalance: String
    @Binding var selectedCurrency: Currency
    @Binding var duplicateNameError: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    // 根據帳戶類型返回對應的提示詞
    private var namePlaceholder: String {
        switch accountType {
        case .twdDeposit:
            return "例如：生活帳戶"
        case .twdSecurities:
            return "例如：元大證券"
        case .usdAccount:
            return "例如：美股證券戶"
        case .cryptoWallet:
            return "例如：Binance"
        case .debt:
            return "例如：房屋貸款"
        case .otherDebt:
            return "例如：欠朋友"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 24) {
                    // 帳戶類型圖標卡片
                    VStack(spacing: 12) {
                        Image(systemName: accountType.icon)
                            .font(.system(size: 48))
                            .foregroundColor(accountType.color)
                            .frame(width: 80, height: 80)
                            .background(accountType.color.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(accountType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text(accountType.description)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    
                    // 表單卡片
                    VStack(spacing: 0) {
                        // 帳戶名稱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("帳戶名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField(namePlaceholder, text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in
                                    duplicateNameError = nil // 清除錯誤訊息
                                }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "帳戶幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "原幣仍依標的決定；帳戶幣別用於現金餘額與折算顯示。"
                            )
                            .padding(20)

                            Divider()
                                .padding(.horizontal, 20)
                        }

                        // 初始餘額
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("初始餘額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            AmountKeypadInputView(
                                text: $initialBalance,
                                currency: selectedCurrency,
                                accentColor: accountType.color
                            )
                            .onChange(of: initialBalance) { oldValue, newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                if filtered != newValue {
                                    initialBalance = filtered
                                }
                                if let value = Decimal(string: filtered), value < 0 {
                                    initialBalance = oldValue
                                }
                            }
                            
                            Text("可選：設定帳戶的初始餘額")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .background(Color.secondaryBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            // 儲存按鈕
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("建立帳戶")
                        .font(.headline)
                }
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(name.isEmpty ? AppColors.disabledBackground : accountType.color)
                .cornerRadius(12)
            }
            .disabled(name.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - 帳戶類型選擇卡片
struct AccountTypeSelectionCard: View {
    let accountType: AccountType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(accountType.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: accountType.icon)
                        .foregroundColor(accountType.color)
                        .font(.system(size: 24))
                }
                
                // 資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountType.displayName)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text(accountType.description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 選擇指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accountType.color)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accountType.color.opacity(isSelected ? 0.15 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accountType.color, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 帳戶選擇器 Sheet
struct AccountPickerSheet: View {
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
            .tint(.appPrimary)
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

// MARK: - 其他債務帳戶詳情表單

struct OtherDebtAccountDetailsFormView: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var notes: String
    @Binding var startDate: Date
    @Binding var selectedCurrency: Currency
    @Binding var duplicateNameError: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var showingDatePicker = false
    
    private let accountType = AccountType.otherDebt
    
    private var isFormValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let value = Decimal(string: amount),
              value > 0 else { return false }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: accountType.icon)
                            .font(.system(size: 48))
                            .foregroundColor(accountType.color)
                            .frame(width: 80, height: 80)
                            .background(accountType.color.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(accountType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text(accountType.description)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("帳戶名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("例如：欠朋友", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in duplicateNameError = nil }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "債務幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "預設使用主要幣別，也可以改成其他借款幣別。"
                            )
                            .padding(20)

                            Divider().padding(.horizontal, 20)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("目前欠款")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: amount) { oldValue, newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue { amount = filtered }
                                    if let value = Decimal(string: filtered), value <= 0, !filtered.isEmpty {
                                        amount = oldValue.isEmpty ? "" : oldValue
                                    }
                                }
                            
                            Text("不需填寫期數或利率，還款後會直接減少欠款")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("備註（選填）")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("備註", text: $notes)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("開始日期")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            Button { showingDatePicker = true } label: {
                                HStack {
                                    Text(formatDate(startDate))
                                        .font(.body)
                                        .foregroundColor(.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondaryText)
                                }
                                .padding()
                                .background(Color.secondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Text("此筆債務的開始日期")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .background(Color.secondaryBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("建立帳戶")
                        .font(.headline)
                }
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? accountType.color : AppColors.disabledBackground)
                .cornerRadius(12)
            }
            .disabled(!isFormValid)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "選擇開始日期",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle("選擇開始日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { showingDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

#Preview {
    AddAccountView(viewModel: AccountsViewModel())
}

#Preview {
    AddAccountView(viewModel: AccountsViewModel())
}

