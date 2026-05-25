//
//  ExpenseView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct ExpenseView: View {
    let account: Account
    @ObservedObject var viewModel: AccountDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    // 編輯模式：如果提供，則為編輯模式
    let editingTransaction: Transaction?
    
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var twdEquivalent: Decimal? = nil
    @State private var errorMessage: String? = nil
    
    // TODO: 從匯率服務獲取即時匯率
    private let usdToTwdRate: Decimal = 32 // 臨時固定值
    
    init(account: Account, viewModel: AccountDetailViewModel, editingTransaction: Transaction? = nil) {
        self.account = account
        self.viewModel = viewModel
        self.editingTransaction = editingTransaction
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(Color.lossRed.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.lossRed)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("支出")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("記錄此帳戶的現金支出。")
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
    
    private var cashBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.lossRed)
                Text("目前帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
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
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.lossRed)
                Text("金額 (\(account.currency.rawValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.headline)
                        .snapFormFieldTapTarget()
                        .onChange(of: amount) { oldValue, newValue in
                            handleAmountChange(oldValue: oldValue, newValue: newValue)
                        }
                }
            }
            
            // 如果是美金帳戶，顯示台幣等值
            if account.currency == .USD, let twd = twdEquivalent {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                    Text("≈ \(twd.formatted(currency: .TWD))")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 4)
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
                    .foregroundColor(.lossRed)
                Text("日期")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                SnapTappableDateField(date: $transactionDate, sheetTitle: "日期")
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
                    .foregroundColor(.lossRed)
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
                    
                    TextField("例如:餐費", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .snapFormFieldTapTarget(alignment: .topLeading)
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
                    cashBalanceSection
                    amountSection
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .snapFormScrollDismissesKeyboard()
            .navigationTitle(editingTransaction != nil ? "編輯支出" : "支出")
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
                    saveExpense()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18))
                        Text(editingTransaction != nil ? "確認修改" : "確認支出")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? Color.lossRed : AppColors.disabledBackground)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
            .task {
                // 如果是編輯模式，預填資料
                if let transaction = editingTransaction {
                    amount = transaction.quantity.formatted(fractionDigits: 2)
                    notes = transaction.notes ?? ""
                    transactionDate = transaction.transactionDate
                    calculateTwdEquivalent(amount)
                }
            }
        }
        .snapFormSheetChrome()
    }
    
    // MARK: - Helper Methods
    private func handleAmountChange(oldValue: String, newValue: String) {
        // 過濾非數字字符
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            amount = filtered
        }
        // 驗證不能為負數或零
        if let value = Decimal(string: filtered), value <= 0 {
            amount = oldValue.isEmpty ? "" : oldValue
        }
        calculateTwdEquivalent(filtered)
        validateInput()
    }
    
    private func validateInput() {
        errorMessage = nil
        
        guard let amountValue = Decimal(string: amount), !amount.isEmpty else {
            return
        }
        
        if amountValue <= 0 {
            errorMessage = "金額必須大於 0"
            return
        }
        
        // 檢查支出金額不能大於現金餘額
        if amountValue > viewModel.cashBalance {
            errorMessage = "支出金額不能大於現金餘額 \(viewModel.cashBalance.formatted(currency: account.currency))"
            return
        }
    }
    
    private func calculateTwdEquivalent(_ amountString: String) {
        guard let amountValue = Decimal(string: amountString) else {
            twdEquivalent = nil
            return
        }
        
        if account.currency == .USD {
            twdEquivalent = amountValue * usdToTwdRate
        } else {
            twdEquivalent = nil
        }
    }
    
    /// 編輯時須把原支出金額加回，否則會誤判餘額不足
    private var maxAllowedExpenseAmount: Decimal {
        if let existing = editingTransaction {
            return viewModel.cashBalance + existing.totalAmountWithFee
        }
        return viewModel.cashBalance
    }
    
    private var isValid: Bool {
        guard let amountValue = Decimal(string: amount),
              !amount.isEmpty,
              amountValue > 0,
              amountValue <= maxAllowedExpenseAmount else {
            return false
        }
        return true
    }
    
    private func saveExpense() {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return }
        
        Task {
            let transactionsViewModel = TransactionsViewModel()
            
            if let existing = editingTransaction {
                // 編輯模式：重建交易以重算 totalAmount / totalAmountWithFee
                let updatedTransaction = Transaction(
                    id: existing.id,
                    accountId: existing.accountId,
                    type: .withdraw,
                    assetType: existing.assetType,
                    symbol: existing.symbol,
                    quantity: amountValue,
                    price: 1,
                    currency: existing.currency,
                    fee: existing.fee,
                    notes: notes.isEmpty ? nil : notes,
                    transactionDate: transactionDate,
                    createdAt: existing.createdAt,
                    updatedAt: Date()
                )
                await transactionsViewModel.updateTransaction(updatedTransaction)
            } else {
                // 新增模式：建立新交易
                let transaction = Transaction(
                    accountId: account.id,
                    type: .withdraw,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: amountValue,
                    price: 1,
                    currency: account.currency,
                    fee: 0,
                    notes: notes.isEmpty ? nil : notes,
                    transactionDate: transactionDate
                )
                await transactionsViewModel.createTransaction(transaction)
            }
            
            await viewModel.refresh(accountId: account.id)
            dismiss()
        }
    }
}

#Preview {
    ExpenseView(
        account: Account(userId: "test", name: "測試帳戶", type: .cash, currency: .TWD),
        viewModel: AccountDetailViewModel()
    )
}
