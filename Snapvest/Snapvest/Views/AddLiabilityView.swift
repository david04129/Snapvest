//
//  AddLiabilityView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AddLiabilityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @StateObject private var accountsViewModel = AccountsViewModel()
    
    // 編輯模式
    let editingLiability: Liability?
    
    @State private var name: String = ""
    @State private var principal: String = ""
    @State private var totalPeriods: String = ""
    @State private var interestRate: String = ""
    @State private var monthlyPayment: Decimal = 0
    @State private var selectedRepaymentAccount: Account?
    @State private var repaymentDay: String = "1"
    @State private var userId: String = AppUser.id
    @State private var showingAccountPicker = false
    
    init(portfolioViewModel: PortfolioViewModel? = nil, userId: String = AppUser.id, editingLiability: Liability? = nil) {
        self._portfolioViewModel = ObservedObject(wrappedValue: portfolioViewModel ?? PortfolioViewModel())
        self.userId = userId
        self.editingLiability = editingLiability
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("請填寫帳戶詳細資訊。")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal)
                    
                    // 貸款名稱
                    VStack(alignment: .leading, spacing: 8) {
                        Text("貸款名稱")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
                        TextField("例如：房屋貸款", text: $name)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // 貸款總額
                    VStack(alignment: .leading, spacing: 8) {
                        Text("貸款總額 (TWD)")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
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
                    .padding(.horizontal)
                    
                    // 總期數
                    VStack(alignment: .leading, spacing: 8) {
                        Text("總期數 (月)")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
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
                                }
                                calculateMonthlyPayment()
                            }
                    }
                    .padding(.horizontal)
                    
                    // 年利率
                    VStack(alignment: .leading, spacing: 8) {
                        Text("年利率 (%)")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
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
                    .padding(.horizontal)
                    
                    // 每月應繳金額（自動計算）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每月應繳金額")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
                        HStack {
                            Text(monthlyPayment.formatted(currency: .TWD))
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.secondaryBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // 還款帳戶
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.lossRed)
                            Text("還款帳戶")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                        
                        Button(action: {
                            showingAccountPicker = true
                        }) {
                            CardView {
                                HStack(spacing: 12) {
                                    if let account = selectedRepaymentAccount {
                                        Image(systemName: account.accountType.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(account.accountType.color)
                                            .frame(width: 24, height: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(account.name)
                                                .font(.headline)
                                                .foregroundColor(.primaryText)
                                            Text(account.accountType.displayName)
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                        }
                                    } else {
                                        Text("選擇一個台幣帳戶")
                                            .foregroundColor(.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // 每月還款日
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每月還款日")
                            .font(.subheadline)
                            .foregroundColor(.primaryText)
                        
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
                    }
                    .padding(.horizontal)
                    
                    // 儲存按鈕
                    Button(action: {
                        saveLiability()
                    }) {
                        Text("儲存債務")
                            .font(.headline)
                            .foregroundColor(AppColors.actionForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid ? Color.lossRed : AppColors.disabledBackground)
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .task {
                // 如果是編輯模式，預填資料
                if let liability = editingLiability {
                    name = liability.name
                    principal = liability.principal.formatted(fractionDigits: 0)
                    interestRate = liability.interestRate.formatted(fractionDigits: 2)
                    // 計算總期數（從principal和monthlyPayment反推）
                    if liability.monthlyPayment > 0 {
                        let principalNS = NSDecimalNumber(decimal: liability.principal)
                        let monthlyPaymentNS = NSDecimalNumber(decimal: liability.monthlyPayment)
                        let result = principalNS.dividing(by: monthlyPaymentNS)
                        let rounded = result.rounding(accordingToBehavior: NSDecimalNumberHandler(
                            roundingMode: .up,
                            scale: 0,
                            raiseOnExactness: false,
                            raiseOnOverflow: false,
                            raiseOnUnderflow: false,
                            raiseOnDivideByZero: true
                        ))
                        totalPeriods = String(Int(rounded.doubleValue))
                    }
                    monthlyPayment = liability.monthlyPayment
                    repaymentDay = String(Calendar.current.component(.day, from: liability.startDate))
                    
                    // 載入帳戶以找到還款帳戶
                    await accountsViewModel.loadAccounts(userId: userId)
                    selectedRepaymentAccount = accountsViewModel.accounts.first { $0.id == liability.accountId }
                } else {
                    await accountsViewModel.loadAccounts(userId: userId)
                }
            }
            .task {
                await accountsViewModel.loadAccounts(userId: userId)
                // 預設選擇第一個台幣帳戶
                if selectedRepaymentAccount == nil {
                    selectedRepaymentAccount = accountsViewModel.accounts.first { account in
                        account.accountType == .twdDeposit || account.accountType == .twdSecurities
                    }
                }
            }
            .sheet(isPresented: $showingAccountPicker) {
                LiabilityAccountPickerSheet(
                    accounts: availableRepaymentAccounts,
                    selectedAccount: $selectedRepaymentAccount
                )
            }
        }
        .navigationTitle(editingLiability == nil ? "新增債務帳戶" : "編輯債務帳戶")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 可選擇的還款帳戶（台幣現金帳戶和台幣證券戶）
    private var availableRepaymentAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            account.accountType == .twdDeposit || account.accountType == .twdSecurities
        }
    }
    
    // 表單驗證
    private var isFormValid: Bool {
        // 首先檢查每月應繳金額是否已計算（這是最嚴格的檢查）
        // 如果 monthlyPayment <= 0，說明計算欄位不完整或無效
        guard monthlyPayment > 0 else {
            return false
        }
        
        // 然後檢查所有必填欄位是否都填寫完整且有效
        
        // 1. 檢查貸款名稱
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return false
        }
        
        // 2. 檢查貸款總額
        let trimmedPrincipal = principal.trimmingCharacters(in: .whitespaces)
        guard !trimmedPrincipal.isEmpty,
              let principalValue = Decimal(string: trimmedPrincipal),
              principalValue > 0 else {
            return false
        }
        
        // 3. 檢查總期數
        let trimmedPeriods = totalPeriods.trimmingCharacters(in: .whitespaces)
        guard !trimmedPeriods.isEmpty,
              let periods = Int(trimmedPeriods),
              periods > 0 else {
            return false
        }
        
        // 4. 檢查年利率
        let trimmedRate = interestRate.trimmingCharacters(in: .whitespaces)
        guard !trimmedRate.isEmpty,
              let rate = Decimal(string: trimmedRate),
              rate >= 0 else {
            return false
        }
        
        // 5. 檢查每月還款日
        let trimmedDay = repaymentDay.trimmingCharacters(in: .whitespaces)
        guard !trimmedDay.isEmpty,
              let day = Int(trimmedDay),
              day >= 1 && day <= 31 else {
            return false
        }
        
        // 6. 檢查還款帳戶
        guard selectedRepaymentAccount != nil else {
            return false
        }
        
        // 所有檢查都通過
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
        let rateNS = NSDecimalNumber(decimal: rate)
        let monthlyRateNS = rateNS.dividing(by: NSDecimalNumber(decimal: 100))
            .dividing(by: NSDecimalNumber(decimal: 12)) // 年利率轉月利率
        let n = NSDecimalNumber(value: periods)
        
        if monthlyRateNS.compare(NSDecimalNumber.zero) == .orderedSame {
            // 無利息，平均攤還
            monthlyPayment = (principalNS.dividing(by: n)).decimalValue
        } else {
            // 計算 (1+r)^n
            let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
            let power = onePlusRate.raising(toPower: periods)
            
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
    
    private func saveLiability() {
        guard let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate),
              let accountId = selectedRepaymentAccount?.id else { return }
        
        // 將還款日轉換為日期
        let calendar = Calendar.current
        let today = Date()
        var dateComponents = calendar.dateComponents([.year, .month], from: today)
        if let day = Int(repaymentDay), day >= 1 && day <= 31 {
            dateComponents.day = day
        } else {
            dateComponents.day = 1
        }
        let startDate = calendar.date(from: dateComponents) ?? Date()
        
        // 計算總期數
        let periods = Int(totalPeriods) ?? 12
        
        let liability = Liability(
            accountId: accountId,
            name: name,
            principal: principalValue,
            interestRate: rate,
            monthlyPayment: monthlyPayment,
            remainingBalance: principalValue,
            currency: .TWD,
            startDate: startDate,
            totalPeriods: periods,
            paidPeriods: 0,
            totalPaidPrincipal: 0,  // 新建債務，已還本金為 0
            totalPaidInterest: 0,   // 新建債務，已支出利息為 0
            totalSavedInterest: 0   // 新建債務，節省利息為 0
        )
        
        Task {
            do {
                if let existing = editingLiability {
                    // 更新現有債務
                    var updated = existing
                    updated.name = name
                    updated.principal = principalValue
                    updated.interestRate = rate
                    updated.monthlyPayment = monthlyPayment
                    updated.accountId = accountId
                    // 更新還款日
                    let calendar = Calendar.current
                    let today = Date()
                    var dateComponents = calendar.dateComponents([.year, .month], from: today)
                    if let day = Int(repaymentDay), day >= 1 && day <= 31 {
                        dateComponents.day = day
                    } else {
                        dateComponents.day = calendar.component(.day, from: existing.startDate)
                    }
                    updated.startDate = calendar.date(from: dateComponents) ?? existing.startDate
                    // 保留原有的remainingBalance
                    try await MockDataService.shared.updateLiability(updated)
                    
                } else {
                    // 創建新債務
                    try await MockDataService.shared.createLiability(liability)
                    
                    // 找到或創建對應的債務帳戶
                    await accountsViewModel.loadAccounts(userId: userId)
                    var debtAccount = accountsViewModel.accounts.first(where: { 
                        $0.accountType == .debt && $0.name == name 
                    })
                    
                    // 如果債務帳戶不存在，創建它
                    if debtAccount == nil {
                        let newDebtAccount = Account(
                            userId: userId,
                            name: name,
                            accountType: .debt
                        )
                        await accountsViewModel.createAccount(newDebtAccount)
                        debtAccount = newDebtAccount
                    }
                    
                    // 創建債務帳戶的初始交易記錄（.liability 類型）
                    if let debtAccount = debtAccount {
                        let transactionsViewModel = TransactionsViewModel()
                        let liabilityTransaction = Transaction(
                            accountId: debtAccount.id,
                            type: .liability,
                            assetType: .cash,
                            symbol: "CASH",
                            quantity: principalValue,
                            price: 1,
                            currency: .TWD,
                            fee: 0,
                            notes: "新增債務：\(name)",
                            transactionDate: startDate
                        )
                        await transactionsViewModel.createTransaction(liabilityTransaction)
                    }
                }
                
                await portfolioViewModel.loadData(userId: userId)
                dismiss()
            } catch {
                // TODO: 顯示錯誤訊息
            }
        }
    }
}

// MARK: - 債務還款帳戶選擇器 Sheet
struct LiabilityAccountPickerSheet: View {
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

#Preview {
    AddLiabilityView()
}

