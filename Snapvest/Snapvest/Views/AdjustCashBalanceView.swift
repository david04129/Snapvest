//
//  AdjustCashBalanceView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AdjustCashBalanceView: View {
    let account: Account
    @ObservedObject var viewModel: AccountDetailViewModel
    let currentBalance: Decimal
    @Environment(\.dismiss) private var dismiss
    
    @State private var newBalanceText: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var errorMessage: String? = nil
    @State private var usdToTwdRate: Decimal? = ExchangeRateSessionCache.usdToTwd
    
    private var newBalanceValue: Decimal? {
        Decimal(string: newBalanceText)
    }
    
    private var delta: Decimal? {
        guard let newBalanceValue = newBalanceValue else { return nil }
        return newBalanceValue - currentBalance
    }
    
    private var isNegative: Bool {
        guard let newBalanceValue = newBalanceValue else { return false }
        return newBalanceValue < 0
    }
    
    private var isUnchanged: Bool {
        guard let newBalanceValue = newBalanceValue else { return true }
        return newBalanceValue == currentBalance
    }
    
    private var isValid: Bool {
        guard newBalanceValue != nil else { return false }
        if isNegative { return false }
        if isUnchanged { return false }
        return true
    }
    
    private var themeColor: Color {
        .appPrimary
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 24))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("調整餘額")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("直接調整現金餘額，系統會自動記錄收支。")
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
                    .foregroundColor(themeColor)
                Text("目前帳戶")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Text("現金餘額：\(currentBalance.formatted(currency: account.currency))")
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
                Text(TradeFormMoneyLabels.balanceRowTitle(currency: account.currency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            AmountKeypadInputView(
                text: $newBalanceText,
                currency: account.currency,
                accentColor: themeColor
            )
            .onChange(of: newBalanceText) { oldValue, newValue in
                handleBalanceChange(oldValue: oldValue, newValue: newValue)
            }
            
            adjustmentResultCard
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var adjustmentResultCard: some View {
        if delta != nil {
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    if let delta = delta {
                        let absDelta = delta > 0 ? delta : -delta
                        let amountColor: Color = delta > 0 ? .profitGreen : .lossRed
                        HStack(alignment: .top) {
                            Text(delta > 0 ? "將新增收入" : "將新增支出")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(amountColor)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(absDelta.formatted(currency: account.currency))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(amountColor)
                                if account.currency == .USD,
                                   let rate = usdToTwdRate, rate > 0 {
                                    let twd = absDelta * rate
                                    Text("≈ NT$\(twd.formatted(currency: .TWD))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondaryText)
                                }
                            }
                        }
                    }
                }
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
                    
                    TextField("例如:餘額調整", text: $notes, axis: .vertical)
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
                    cashBalanceSection
                    amountSection
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .snapFormScrollDismissesKeyboard()
            .navigationTitle("調整餘額")
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
                    saveAdjustment()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                        Text("確認調整")
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
            .task {
                if newBalanceText.isEmpty {
                    newBalanceText = formattedBalanceInput(currentBalance)
                }
                await loadUsdToTwdRate()
            }
        }
        .snapFormSheetChrome()
    }
    
    // MARK: - Helper Methods
    
    private func loadUsdToTwdRate() async {
        if let cached = ExchangeRateSessionCache.usdToTwd, cached > 0 {
            usdToTwdRate = cached
            return
        }
        if let rate = try? await MockDataService.shared.fetchExchangeRate(from: .USD, to: .TWD, date: nil)?.rate,
           rate > 0 {
            usdToTwdRate = rate
            return
        }
        if viewModel.exchangeRate > 0 {
            usdToTwdRate = viewModel.exchangeRate
        }
    }
    
    private func handleBalanceChange(oldValue: String, newValue: String) {
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            newBalanceText = filtered
        }
        if let value = Decimal(string: filtered), value < 0 {
            newBalanceText = oldValue.isEmpty ? "" : oldValue
        }
        validateInput()
    }
    
    private func validateInput() {
        errorMessage = nil
        
        guard let newBalanceValue = Decimal(string: newBalanceText), !newBalanceText.isEmpty else {
            return
        }
        
        if newBalanceValue < 0 {
            errorMessage = "餘額不可為負數"
            return
        }
        
        if newBalanceValue == currentBalance {
            errorMessage = "金額未變更"
            return
        }
    }

    private func formattedBalanceInput(_ value: Decimal) -> String {
        value.formattedQuantityInput(maxFractionDigits: 2)
    }
    
    private func saveAdjustment() {
        guard let newBalanceValue = Decimal(string: newBalanceText) else { return }
        if newBalanceValue < 0 || newBalanceValue == currentBalance { return }
        
        let deltaValue = newBalanceValue - currentBalance
        if deltaValue == 0 { return }
        
        let transactionType: TransactionType = deltaValue > 0 ? .deposit : .withdraw
        let amount = deltaValue > 0 ? deltaValue : -deltaValue
        let autoNote = "餘額調整：\(currentBalance.formatted(currency: account.currency)) → \(newBalanceValue.formatted(currency: account.currency))"
        let finalNotes = notes.isEmpty ? autoNote : "\(notes)（\(autoNote)）"
        
        Task {
            let transactionsViewModel = TransactionsViewModel()
            let transaction = Transaction(
                accountId: account.id,
                type: transactionType,
                assetType: .cash,
                symbol: "CASH",
                quantity: amount,
                price: 1,
                currency: account.currency,
                fee: 0,
                notes: finalNotes,
                transactionDate: transactionDate
            )
            await transactionsViewModel.createTransaction(
                transaction,
                skipPriceValidation: true,
                showsLoadingOverlay: false
            )
            dismiss()
        }
    }
}

#Preview {
    AdjustCashBalanceView(
        account: Account(userId: "test", name: "測試帳戶", type: .cash, currency: .TWD),
        viewModel: AccountDetailViewModel(),
        currentBalance: 1000
    )
}
