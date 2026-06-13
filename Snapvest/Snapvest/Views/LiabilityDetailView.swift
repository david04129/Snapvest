//
//  LiabilityDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct LiabilityDetailView: View {
    let liability: Liability
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingRepayment = false
    @State private var currentLiability: Liability
    @State private var isDetailsExpanded: Bool = false
    
    init(liability: Liability) {
        self.liability = liability
        _currentLiability = State(initialValue: liability)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                liabilityHeroHeader
                
                liabilityMetricsGrid
                
                if currentLiability.totalPeriods > 0 {
                    RepaymentProgressCard(liability: currentLiability)
                }
                
                liabilityInfoSection
            }
            .padding()
        }
        .background(Color.mainBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                TransactionHistoryToolbarChip {
                    // TODO: 導航到交易紀錄
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
                .padding(.vertical, 14)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.mainBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.separator.opacity(0.3)),
                alignment: .top
            )
        }
        .sheet(isPresented: $showingRepayment) {
            RepaymentView(
                liability: currentLiability,
                repaymentType: .regular,
                preloadedAccounts: accountsViewModel.accounts
            )
            .onDisappear {
                Task { await loadLiabilityData() }
            }
        }
        .task {
            currentLiability = liability
            await accountsViewModel.loadAccounts(userId: AppUser.id)
            await loadLiabilityData()
        }
    }
    
    private var liabilityHeroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentLiability.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    Text("貸款詳情與狀態")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Text(AccountType.debt.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AccountType.debt.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AccountType.debt.color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(AccountType.debt.color)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var liabilityMetricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "剩餘本金",
                value: currentLiability.remainingBalance.formatted(currency: currentLiability.currency),
                currency: currentLiability.currency,
                valueColor: .lossRed
            )
            MetricTile(
                title: "每月應繳",
                value: currentLiability.monthlyPayment.formatted(currency: currentLiability.currency),
                currency: currentLiability.currency
            )
        }
    }
    
    private var liabilityInfoSection: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDetailsExpanded.toggle()
                    }
                }) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("貸款資訊")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Spacer(minLength: 0)
                        Image(systemName: isDetailsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if isDetailsExpanded {
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.top, 8)
                        
                        InfoRowWithoutIcon(
                            label: "原始貸款金額",
                            value: currentLiability.principal.formatted(currency: currentLiability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "年利率",
                            value: "\(currentLiability.interestRate.formatted(fractionDigits: 2))%"
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總期數",
                            value: "\(calculateTotalMonths()) 個月"
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "每月還款日",
                            value: "每月 \(calculateRepaymentDay()) 日"
                        )
                    }
                }
            }
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
