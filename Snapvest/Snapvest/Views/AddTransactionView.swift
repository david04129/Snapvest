//
//  AddTransactionView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var viewModel: TransactionsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAccountId: String = ""
    @State private var selectedType: TransactionType = .buy
    @State private var selectedAssetType: AssetType = .stockTW
    @State private var symbol: String = ""
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fee: String = "0"
    @State private var notes: String = ""
    @State private var transactionDate: Date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本資訊")) {
                    Picker("帳戶", selection: $selectedAccountId) {
                        ForEach(viewModel.accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                    
                    Picker("交易類型", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    DatePicker("交易日期", selection: $transactionDate, displayedComponents: .date)
                }
                
                Section(header: Text("資產資訊")) {
                    Picker("資產類型", selection: $selectedAssetType) {
                        ForEach(AssetType.allCases.filter { $0 != .cash }, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("代碼", text: $symbol)
                        .autocapitalization(.allCharacters)
                }
                
                Section(header: Text("交易詳情")) {
                    TextField("數量", text: $quantity)
                        .keyboardType(.decimalPad)
                    
                    TextField("價格", text: $price)
                        .keyboardType(.decimalPad)
                    
                    TextField("手續費", text: $fee)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("備註")) {
                    TextField("備註（選填）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("新增交易")
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
        }
    }
    
    private var isValid: Bool {
        !selectedAccountId.isEmpty &&
        !symbol.isEmpty &&
        !quantity.isEmpty &&
        !price.isEmpty &&
        Decimal(string: quantity) != nil &&
        Decimal(string: price) != nil
    }
    
    private func saveTransaction() {
        guard let account = viewModel.accounts.first(where: { $0.id == selectedAccountId }),
              let qty = Decimal(string: quantity),
              let prc = Decimal(string: price),
              let feeValue = Decimal(string: fee) else {
            return
        }
        
        let transaction = Transaction(
            accountId: account.id,
            type: selectedType,
            assetType: selectedAssetType,
            symbol: symbol.uppercased(),
            quantity: qty,
            price: prc,
            currency: account.currency,
            fee: feeValue,
            notes: notes.isEmpty ? nil : notes,
            transactionDate: transactionDate
        )
        
        Task {
            await viewModel.createTransaction(transaction)
            dismiss()
        }
    }
}

#Preview {
    AddTransactionView(viewModel: TransactionsViewModel())
}

