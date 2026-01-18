//
//  LiabilityDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct LiabilityDetailView: View {
    let liability: Liability
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingRepayment = false
    @State private var repaymentAccountName: String = ""
    @State private var currentLiability: Liability // 用於顯示最新的債務數據
    
    init(liability: Liability) {
        self.liability = liability
        _currentLiability = State(initialValue: liability)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 標題
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentLiability.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("貸款詳情與狀態")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // 剩餘本金卡片
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("剩餘本金")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Image(systemName: "target")
                                .foregroundColor(.lossRed)
                        }
                        
                        Text(currentLiability.remainingBalance.formatted(currency: currentLiability.currency))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.lossRed)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lossRed, lineWidth: 2)
                )
                
                // 每月應繳金額卡片
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("每月應繳金額")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            Image(systemName: "doc.text")
                                .foregroundColor(.appPrimary)
                        }
                        
                        Text(currentLiability.monthlyPayment.formatted(currency: currentLiability.currency))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primaryText)
                    }
                }
                
                // 詳細資訊
                TitledCardView(title: "貸款資訊") {
                    VStack(spacing: 16) {
                        InfoRow(
                            icon: "target",
                            label: "原始貸款金額",
                            value: currentLiability.principal.formatted(currency: currentLiability.currency)
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "percent",
                            label: "年利率",
                            value: "\(currentLiability.interestRate.formatted(fractionDigits: 2))%"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "calendar",
                            label: "總期數",
                            value: "\(calculateTotalMonths()) 個月"
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "creditcard",
                            label: "還款帳戶",
                            value: repaymentAccountName.isEmpty ? "載入中..." : repaymentAccountName
                        )
                        
                        Divider()
                        
                        InfoRow(
                            icon: "calendar",
                            label: "每月還款日",
                            value: "每月 \(calculateRepaymentDay()) 日"
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: 導航到交易紀錄
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("交易紀錄")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.noticeForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.noticeBackground)
                    .cornerRadius(8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                showingRepayment = true
            }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("進行還款")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
            .padding()
            .background(Color.cardBackground)
        }
        .sheet(isPresented: $showingRepayment) {
            if let repaymentAccount = accountsViewModel.accounts.first(where: { $0.id == currentLiability.accountId }) {
                RepaymentTransferWrapperView(
                    liability: currentLiability,
                    repaymentAccount: repaymentAccount
                )
                .onDisappear {
                    // 還款完成後刷新數據
                    Task {
                        await portfolioViewModel.loadData(userId: "test-user-id")
                        await loadLiabilityData()
                    }
                }
            }
        }
        .task {
            // 初始化當前債務數據
            currentLiability = liability
            // 載入帳戶資訊以獲取還款帳戶名稱
            await accountsViewModel.loadAccounts(userId: "test-user-id")
            if let account = accountsViewModel.accounts.first(where: { $0.id == liability.accountId }) {
                repaymentAccountName = account.name
            }
            // 載入最新的債務數據
            await loadLiabilityData()
        }
    }
    
    private func loadLiabilityData() async {
        do {
            let dataService = MockDataService.shared
            let liabilities = try await dataService.fetchLiabilities(accountId: liability.accountId)
            if let updatedLiability = liabilities.first(where: { $0.id == liability.id }) {
                await MainActor.run {
                    currentLiability = updatedLiability
                }
            }
        } catch {
            // 如果載入失敗，保持當前數據
        }
    }
    
    private func calculateTotalMonths() -> Int {
        guard let endDate = liability.endDate else {
            // 如果沒有結束日期，根據原始本金和每月還款計算
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
                    raiseOnDivideByZero: false
                ))
                return rounded.intValue
            }
            return 0
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: liability.startDate, to: endDate)
        return components.month ?? 0
    }
    
    private func calculateRepaymentDay() -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: liability.startDate)
        return "\(day)"
    }
}

// MARK: - 資訊行
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.appPrimary)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        LiabilityDetailView(
            liability: Liability(
                accountId: "test",
                name: "信貸 (富邦)",
                principal: 2300000,
                interestRate: 2.3,
                monthlyPayment: 29671,
                remainingBalance: 2270329,
                currency: .TWD,
                startDate: Date(),
                totalPeriods: 12,
                paidPeriods: 0
            )
        )
    }
}

