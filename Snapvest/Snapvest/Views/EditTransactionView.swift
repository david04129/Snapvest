//
//  EditTransactionView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct EditTransactionView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) var dismiss
    var onEditLiability: ((Liability) -> Void)?
    
    @State private var amount: String = ""
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fee: String = ""
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    @State private var account: Account?
    @State private var liability: Liability?
    
    init(transaction: Transaction, viewModel: TransactionsViewModel, onEditLiability: ((Liability) -> Void)? = nil) {
        self.transaction = transaction
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onEditLiability = onEditLiability
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 根據交易類型顯示不同的表單
                    if transaction.type == .liability {
                        // 債務交易：直接跳轉到編輯債務頁面
                        EmptyView()
                            .task {
                                await loadLiabilityFromTransaction()
                                if let liability = liability {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onEditLiability?(liability)
                                    }
                                }
                            }
                    } else if transaction.type == .deposit || transaction.type == .withdraw {
                        // 收支交易
                        VStack(alignment: .leading, spacing: 8) {
                            Text("金額 (\(transaction.currency.rawValue))")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("日期")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            SnapTappableDateField(
                                date: $transactionDate,
                                sheetTitle: "日期",
                                showsLeadingIcon: false
                            )
                            .padding()
                            .background(Color.secondaryBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("備註（選填）")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                    } else if transaction.type == .buy || transaction.type == .sell {
                        // 股票交易
                        VStack(alignment: .leading, spacing: 8) {
                            Text("股票代碼")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            Text(transaction.symbol)
                                .font(.headline)
                                .padding()
                                .background(Color.secondaryBackground)
                                .cornerRadius(12)
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("數量")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("0", text: $quantity)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("價格 (\(transaction.currency.rawValue))")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("0", text: $price)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("手續費 (\(transaction.currency.rawValue))")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("0", text: $fee)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("日期")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            SnapTappableDateField(
                                date: $transactionDate,
                                sheetTitle: "日期",
                                showsLeadingIcon: false
                            )
                            .padding()
                            .background(Color.secondaryBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("備註（選填）")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                            
                            TextField("", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding()
                    }
                }
            }
            .snapFormScrollDismissesKeyboard()
            .navigationTitle("編輯交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                // 獲取帳戶資訊
                await viewModel.loadTransactions(userId: AppUser.id)
                account = viewModel.accounts.first(where: { $0.id == transaction.accountId })
                
                // 如果是債務交易，載入債務資訊
                if transaction.type == .liability {
                    await loadLiabilityFromTransaction()
                } else {
                    // 預填資料
                    amount = transaction.totalAmount.formatted(fractionDigits: 2)
                    quantity = transaction.quantity.formattedQuantityInput(
                        maxFractionDigits: transaction.assetType == .crypto ? 8 : 4
                    )
                    price = transaction.price.formatted(fractionDigits: 2)
                    fee = transaction.fee.formatted(fractionDigits: 2)
                    notes = transaction.notes ?? ""
                    transactionDate = transaction.transactionDate
                }
            }
        }
        .snapFormSheetChrome()
    }
    
    private func loadLiabilityFromTransaction() async {
        let liabilityName = transaction.notes?.replacingOccurrences(of: "新增債務：", with: "") ?? ""
        let dataService = MockDataService.shared

        do {
            let accounts = try await dataService.fetchAccounts(userId: AppUser.id)
            for repaymentAccount in accounts where repaymentAccount.accountType != .debt {
                let liabilities = try await dataService.fetchLiabilities(accountId: repaymentAccount.id)
                if let found = liabilities.first(where: {
                    $0.name == liabilityName || $0.accountId == transaction.accountId
                }) {
                    liability = found
                    return
                }
            }
        } catch {
            liability = nil
        }
    }
    
    private var isValid: Bool {
        if transaction.type == .deposit || transaction.type == .withdraw {
            return !amount.isEmpty && Decimal(string: amount) != nil
        } else {
            return !quantity.isEmpty && !price.isEmpty &&
                   Decimal(string: quantity) != nil &&
                   Decimal(string: price) != nil
        }
    }
    
    private func saveTransaction() {
        var updatedTransaction = transaction
        
        if transaction.type == .deposit || transaction.type == .withdraw {
            if let amountValue = Decimal(string: amount) {
                updatedTransaction.quantity = amountValue
                updatedTransaction.price = 1
            }
        } else {
            if let quantityValue = Decimal(string: quantity),
               let priceValue = Decimal(string: price) {
                updatedTransaction.quantity = quantityValue
                updatedTransaction.price = priceValue
            }
        }
        
        if let feeValue = Decimal(string: fee) {
            updatedTransaction.fee = feeValue
        }
        
        updatedTransaction.notes = notes.isEmpty ? nil : notes
        updatedTransaction.transactionDate = transactionDate
        
        Task {
            await viewModel.updateTransaction(updatedTransaction)
            dismiss()
        }
    }
}

#Preview {
    EditTransactionView(
        transaction: Transaction(
            accountId: "test",
            type: .deposit,
            assetType: .cash,
            symbol: "CASH",
            quantity: 10000,
            price: 1,
            currency: .TWD,
            fee: 0,
            notes: "初始餘額",
            transactionDate: Date()
        ),
        viewModel: TransactionsViewModel()
    )
}

