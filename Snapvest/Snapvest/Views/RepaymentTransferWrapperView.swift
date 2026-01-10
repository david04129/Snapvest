//
//  RepaymentTransferWrapperView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

// MARK: - 還款轉帳包裝視圖（使用轉帳功能）
struct RepaymentTransferWrapperView: View {
    let liability: Liability
    let repaymentAccount: Account
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var accountDetailViewModel = AccountDetailViewModel()
    @State private var debtAccount: Account?
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中...")
            } else if let debtAccount = debtAccount {
                repaymentTransferView(debtAccount: debtAccount)
            } else {
                Text("無法找到對應的債務帳戶")
                    .foregroundColor(.secondaryText)
            }
        }
        .task {
            await loadAccounts()
        }
    }
    
    private func repaymentTransferView(debtAccount: Account) -> some View {
        // 預填備註和金額（定期還款）
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        // 定期還款：預填每月還款金額（整數，四捨五入）
        let monthlyPaymentRounded = (liability.monthlyPayment as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
        let prepopulatedAmount = monthlyPaymentRounded.decimalValue
        let prepopulatedNotes = "\(year)/\(String(format: "%02d", month))定期還款"
        
        return TransferView(
            account: repaymentAccount,
            viewModel: accountDetailViewModel,
            allowSourceAccountSelection: true, // 還款模式：允許選擇轉出帳戶
            prepopulatedTargetAccount: debtAccount,
            prepopulatedAmount: prepopulatedAmount,
            prepopulatedNotes: prepopulatedNotes,
            allowAmountEdit: false // 定期還款不允許修改金額
        )
    }
    
    private func loadAccounts() async {
        await accountsViewModel.loadAccounts(userId: "test-user-id")
        
        // 找到債務帳戶
        debtAccount = accountsViewModel.accounts.first(where: { $0.accountType == .debt && $0.name == liability.name })
        
        await MainActor.run {
            isLoading = false
        }
    }
}

