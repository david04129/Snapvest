//
//  EarlyRepaymentInfoView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

// MARK: - 提前還款資訊視圖
struct EarlyRepaymentInfoView: View {
    let targetAccount: Account
    let sourceAccount: Account  // 實際使用的轉出帳戶（用於顯示貨幣）
    let repaymentAccountId: String  // 原始還款帳戶 ID（用於查找債務記錄）
    @Binding var amount: String
    let dataService: DataServiceProtocol
    
    @State private var remainingBalance: Decimal?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("載入中...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            } else if let remainingBalance = remainingBalance {
                // 顯示剩餘本金提示
                HStack {
                    Text("剩餘本金：")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    Text(remainingBalance.formatted(currency: sourceAccount.currency))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                // 顯示快捷按鈕
                HStack(spacing: 8) {
                    Button(action: {
                        amount = remainingBalance.formatted(fractionDigits: 0)
                    }) {
                        Text("還清全部")
                            .font(.caption)
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .task {
            await loadRemainingBalance()
        }
    }
    
    private func loadRemainingBalance() async {
        do {
            // 債務記錄是根據原始還款帳戶 ID（repaymentAccountId）存儲的
            // 即使用戶選擇了其他帳戶來還款，債務記錄仍然在原始還款帳戶下
            let liabilities = try await dataService.fetchLiabilities(accountId: repaymentAccountId)
            if let liability = liabilities.first(where: { $0.name == targetAccount.name }) {
                await MainActor.run {
                    remainingBalance = liability.remainingBalance
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}


