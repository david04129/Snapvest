//
//  AccountDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @StateObject private var viewModel = AccountDetailViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingIncome = false
    @State private var showingExpense = false
    @State private var showingTransfer = false
    @State private var showingRepayment = false
    @State private var currentLiability: Liability?
    @State private var repaymentAccountName: String = ""
    @State private var isDetailsExpanded: Bool = false
    
    var body: some View {
        Group {
            if account.accountType == .debt {
                // 債務帳戶：顯示原本的樣式
                debtAccountView
            } else {
                // 一般帳戶：顯示原本的樣式
                regularAccountView
            }
        }
    }
    
    // MARK: - 一般帳戶視圖
    private var regularAccountView: some View {
        VStack(spacing: 0) {
            // 固定區域：標題和卡片
            VStack(alignment: .leading, spacing: 12) {
                // 帳戶標題（包含貨幣切換按鈕）
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: account.accountType.icon)
                                .font(.system(size: 20))
                                .foregroundColor(account.accountType.color)
                            
                            Text(account.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Text("帳戶資產總覽")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    
                    // 貨幣切換開關（僅美股和加密貨幣帳戶）
                    if account.currency == .USD {
                        CurrencyToggleView(
                            displayCurrency: $viewModel.displayCurrency
                        )
                        .frame(height: 36)
                        .layoutPriority(0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // 現金餘額卡片
                CashBalanceCard(
                    account: account,
                    cashBalance: viewModel.cashBalance,
                    displayCurrency: viewModel.displayCurrency,
                    exchangeRate: viewModel.exchangeRate
                )
                .padding(.horizontal, 20)
                
                // 持股市值卡片（台股、美股、加密貨幣帳戶顯示）
                if account.accountType != .twdDeposit {
                    HoldingsValueCard(
                        account: account,
                        holdingsValue: viewModel.holdingsValue,
                        holdings: viewModel.holdings,
                        displayCurrency: viewModel.displayCurrency,
                        exchangeRate: viewModel.exchangeRate
                    )
                    .padding(.horizontal, 20)
                }
                
                // 持有股數標題和表頭（固定）
                if account.accountType != .twdDeposit && !viewModel.holdings.isEmpty {
                    HoldingsTableHeader()
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            // 可滾動區域：持股列表內容
            if account.accountType != .twdDeposit && !viewModel.holdings.isEmpty {
                ScrollView {
                    HoldingsTableContent(
                        holdings: viewModel.holdings,
                        account: account,
                        displayCurrency: viewModel.displayCurrency,
                        exchangeRate: viewModel.exchangeRate
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: TransactionHistoryView(account: account)) {
                    HStack {
                        Image(systemName: "clock")
                        Text("交易紀錄")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 底部操作按鈕（債務帳戶不顯示收入、支出、轉帳按鈕）
            Group {
                if account.accountType != .debt {
                    HStack(spacing: 12) {
                        Button(action: {
                            showingIncome = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.down")
                                Text("收入")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.profitGreen)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingExpense = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.up")
                                Text("支出")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.lossRed)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingTransfer = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("轉帳")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.cardBackground)
                } else {
                    // 債務帳戶不顯示按鈕，但保留背景以避免布局問題
                    Color.clear
                        .frame(height: 0)
                }
            }
        }
        .sheet(isPresented: $showingIncome) {
            IncomeView(account: account, viewModel: viewModel)
        }
        .sheet(isPresented: $showingExpense) {
            ExpenseView(account: account, viewModel: viewModel)
        }
        .sheet(isPresented: $showingTransfer) {
            TransferView(account: account, viewModel: viewModel)
        }
        .task {
            // 根據帳戶貨幣設置顯示貨幣
            if account.currency == .TWD {
                viewModel.displayCurrency = .TWD
            } else {
                viewModel.displayCurrency = .USD
            }
            await viewModel.loadAccountData(accountId: account.id)
        }
    }
    
    // MARK: - 債務帳戶視圖
    private var debtAccountView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 標題
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentLiability?.name ?? account.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("貸款詳情與狀態")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                if let liability = currentLiability {
                    // 剩餘本金卡片
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("剩餘本金")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                
                                Spacer()
                                
                                Image(systemName: "wallet.pass.fill")
                                    .foregroundColor(.lossRed)
                                    .font(.system(size: 18))
                            }
                            
                            Text(liability.remainingBalance.formatted(currency: liability.currency))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.lossRed)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lossRed, lineWidth: 2)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    
                    // 剩餘利息卡片
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("剩餘利息")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                            }
                            
                            // 剩餘利息 = 剩餘應還總額 - 剩餘本金
                            let remainingInterest = liability.remainingTotalAmount - liability.remainingBalance
                            Text(remainingInterest.formatted(currency: liability.currency))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primaryText)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    
                    // 還款進度卡片
                    RepaymentProgressCard(liability: liability)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    // 詳細資訊（可折疊）
                    DetailsCard(liability: liability, isExpanded: $isDetailsExpanded)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    // 還款資訊卡片
                    RepaymentInfoCard(
                        liability: liability,
                        repaymentAccount: accountsViewModel.accounts.first(where: { $0.id == liability.accountId }),
                        repaymentAccountName: repaymentAccountName
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: TransactionHistoryView(account: account)) {
                    HStack {
                        Image(systemName: "clock")
                        Text("交易紀錄")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 定期還款按鈕
            Button(action: {
                showingRepayment = true
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("定期還款")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
            .padding()
            .background(Color.cardBackground)
        }
        .sheet(isPresented: $showingRepayment) {
            if let liability = currentLiability,
               let repaymentAccount = accountsViewModel.accounts.first(where: { $0.id == liability.accountId }) {
                RepaymentTransferWrapperView(
                    liability: liability,
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
            await loadDebtAccountData()
        }
    }
    
    // MARK: - 載入債務帳戶數據
    private func loadDebtAccountData() async {
        // 載入帳戶資訊
        await accountsViewModel.loadAccounts(userId: "test-user-id")
        
        // 找到所有帳戶，然後找到對應的 Liability
        let allAccounts = accountsViewModel.accounts
        for acc in allAccounts {
            do {
                let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: acc.id)
                if let liability = liabilities.first(where: { $0.name == account.name }) {
                    await MainActor.run {
                        currentLiability = liability
                        if let repaymentAccount = allAccounts.first(where: { $0.id == liability.accountId }) {
                            repaymentAccountName = repaymentAccount.name
                        }
                    }
                    break
                }
            } catch {
                // 如果載入失敗，繼續嘗試下一個帳戶
            }
        }
    }
    
    // MARK: - 載入最新的債務數據
    private func loadLiabilityData() async {
        guard let liability = currentLiability else { return }
        do {
            let dataService = MockDataService.shared
            // 通過還款帳戶 ID 查找債務（liability.accountId 是還款帳戶的 ID）
            let liabilities = try await dataService.fetchLiabilities(accountId: liability.accountId)
            // 通過名稱匹配，因為 ID 可能會改變
            if let updatedLiability = liabilities.first(where: { $0.name == liability.name && $0.accountId == liability.accountId }) {
                await MainActor.run {
                    currentLiability = updatedLiability
                }
            }
        } catch {
            // 如果載入失敗，保持當前數據
        }
    }
    
    // MARK: - 計算總期數
    private func calculateTotalMonths(liability: Liability) -> Int {
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
    
    // MARK: - 計算還款日
    private func calculateRepaymentDay(liability: Liability) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: liability.startDate)
        return "\(day)"
    }
    
    // MARK: - 日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - 現金餘額卡片
struct CashBalanceCard: View {
    let account: Account
    let cashBalance: Decimal
    let displayCurrency: Currency
    let exchangeRate: Decimal
    
    var displayAmount: Decimal {
        if account.currency == .USD && displayCurrency == .TWD {
            return cashBalance * exchangeRate
        }
        return cashBalance
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("現金餘額")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(account.accountType.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayAmount.formatted(currency: displayCurrency))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primaryText)
                }
            }
        }
    }
}

// MARK: - 持股市值卡片
struct HoldingsValueCard: View {
    let account: Account
    let holdingsValue: Decimal
    let holdings: [HoldingSnapshot]
    let displayCurrency: Currency
    let exchangeRate: Decimal
    
    var displayAmount: Decimal {
        if account.currency == .USD && displayCurrency == .TWD {
            return holdingsValue * exchangeRate
        }
        return holdingsValue
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("持股市值")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(account.accountType.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayAmount.formatted(currency: displayCurrency))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                
                Text("\(holdings.count) 檔持股")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

// MARK: - 持股列表標題和表頭（固定）
struct HoldingsTableHeader: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                Text("持有股數")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                    .padding(.bottom, 12)
                
                // 表頭
                HStack(spacing: 8) {
                    Text("名稱")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .frame(width: 60, alignment: .leading)
                    
                    Text("數量")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .frame(width: 45, alignment: .center)
                    
                    Spacer(minLength: 8)
                    
                    Text("現值")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .frame(width: 90, alignment: .trailing)
                    
                    Text("損益")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .frame(width: 110, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 0)
                .background(Color.secondaryBackground)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - 持股列表內容（可滾動）
struct HoldingsTableContent: View {
    let holdings: [HoldingSnapshot]
    let account: Account
    let displayCurrency: Currency
    let exchangeRate: Decimal
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(holdings) { holding in
                HoldingTableRow(
                    holding: holding,
                    account: account,
                    displayCurrency: displayCurrency,
                    exchangeRate: exchangeRate
                )
                
                if holding.id != holdings.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.top, 4)
    }
}

// MARK: - 貨幣切換開關
struct CurrencyToggleView: View {
    @Binding var displayCurrency: Currency
    
    var body: some View {
        HStack(spacing: 0) {
            // USD 按鈕
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    displayCurrency = .USD
                }
            }) {
                Text("USD")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(displayCurrency == .USD ? .white : .primary)
                    .frame(width: 50, height: 36)
                    .background(displayCurrency == .USD ? Color.appPrimary : Color.clear)
            }
            
            // TWD 按鈕
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    displayCurrency = .TWD
                }
            }) {
                Text("TWD")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(displayCurrency == .TWD ? .white : .primary)
                    .frame(width: 50, height: 36)
                    .background(displayCurrency == .TWD ? Color.appPrimary : Color.clear)
            }
        }
        .background(Color.secondaryBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 持股表格行
struct HoldingTableRow: View {
    let holding: HoldingSnapshot
    let account: Account
    let displayCurrency: Currency
    let exchangeRate: Decimal
    
    // 轉換金額用於顯示
    private func convertAmount(_ amount: Decimal, from: Currency) -> Decimal {
        if from == .USD && displayCurrency == .TWD {
            return amount * exchangeRate
        }
        return amount
    }
    
    var displayMarketValue: Decimal? {
        guard let marketValue = holding.marketValue else { return nil }
        return convertAmount(marketValue, from: holding.holding.currency)
    }
    
    var displayGainLoss: Decimal? {
        guard let gainLoss = holding.unrealizedGainLoss else { return nil }
        return convertAmount(gainLoss, from: holding.holding.currency)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 名稱
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(holding.holding.assetType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            .frame(width: 60, alignment: .leading)
            
            // 數量
            Text(holding.holding.quantity.formatted(fractionDigits: 0))
                .font(.caption)
                .frame(width: 45, alignment: .center)
            
            Spacer(minLength: 8)
            
            // 現值
            if let displayValue = displayMarketValue {
                Text(displayValue.formatted(currency: displayCurrency))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 90, alignment: .trailing)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .frame(width: 90, alignment: .trailing)
            }
            
            // 損益
            if let displayGainLoss = displayGainLoss,
               let percent = holding.unrealizedGainLossPercent {
                HStack(spacing: 4) {
                    Image(systemName: displayGainLoss >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(displayGainLoss.formatted(currency: displayCurrency))
                    Text("(\(percent.formatted(fractionDigits: 2))%)")
                }
                .font(.caption)
                .foregroundColor(displayGainLoss >= 0 ? .profitGreen : .lossRed)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 110, alignment: .trailing)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .frame(width: 110, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - 無圖標的資訊行
struct InfoRowWithoutIcon: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
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

// MARK: - 還款進度卡片
struct RepaymentProgressCard: View {
    let liability: Liability
    @State private var animatedProgress: Double = 0.0
    
    private var paidPeriods: Int {
        liability.paidPeriods
    }
    
    private var totalPeriods: Int {
        liability.totalPeriods
    }
    
    private var remainingPeriods: Int {
        max(0, totalPeriods - paidPeriods)
    }
    
    private var targetProgress: Double {
        guard totalPeriods > 0 else { return 0.0 }
        return Double(paidPeriods) / Double(totalPeriods)
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                // 標題和圖標
                HStack {
                    Text("還款進度")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.lossRed)
                        .font(.system(size: 18))
                }
                
                // 期數顯示
                Text("\(paidPeriods)/\(totalPeriods) 期")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
                // 進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondaryBackground)
                            .frame(height: 12)
                        
                        // 進度條
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.lossRed, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                // 已還/剩餘期數
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.profitGreen)
                            .font(.caption)
                        Text("已還 \(paidPeriods) 期")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("剩餘 \(remainingPeriods) 期")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .onAppear {
            // 載入動畫：從0開始動畫到目標進度
            animatedProgress = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animatedProgress = targetProgress
                }
            }
        }
        .id("\(liability.id)-\(paidPeriods)")  // 當 id 或 paidPeriods 變化時，視圖會重新創建，觸發 onAppear
    }
}

// MARK: - 詳細資訊卡片（可折疊）
struct DetailsCard: View {
    let liability: Liability
    @Binding var isExpanded: Bool
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                // 標題欄（可點擊）
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("詳細資訊")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                            .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // 可折疊內容
                if isExpanded {
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.top, 8)
                        
                        InfoRowWithoutIcon(
                            label: "原始貸款金額",
                            value: liability.principal.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總還款金額（含利息）",
                            value: liability.totalAmount.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總利息",
                            value: liability.totalInterest.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "年利率",
                            value: "\(liability.interestRate.formatted(fractionDigits: 2))%"
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "每月應繳金額",
                            value: liability.monthlyPayment.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "開始日期",
                            value: formatDate(liability.startDate)
                        )
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    // 日期格式化（內部函數）
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - 還款資訊卡片
struct RepaymentInfoCard: View {
    let liability: Liability
    let repaymentAccount: Account?
    let repaymentAccountName: String
    
    private func calculateRepaymentDay(liability: Liability) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: liability.startDate)
        return "\(day)"
    }
    
    var body: some View {
        TitledCardView(title: "還款資訊") {
            VStack(spacing: 16) {
                // 還款帳戶（ICON 在帳戶名稱前面）
                HStack {
                    Text("還款帳戶")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    // 右側：ICON + 帳戶名稱
                    HStack(spacing: 6) {
                        if let account = repaymentAccount {
                            Image(systemName: account.accountType.icon)
                                .foregroundColor(account.accountType.color)
                                .font(.system(size: 16))
                        } else {
                            // 如果找不到帳戶，顯示灰色圖標
                            Image(systemName: "building.columns.fill")
                                .foregroundColor(.secondaryText)
                                .font(.system(size: 16))
                        }
                        
                        Text(repaymentAccountName.isEmpty ? "載入中..." : repaymentAccountName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                    }
                }
                
                Divider()
                
                // 每月還款日（無 ICON）
                InfoRowWithoutIcon(
                    label: "每月還款日",
                    value: "每月 \(calculateRepaymentDay(liability: liability)) 日"
                )
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(account: Account(userId: "test", name: "國泰證券", accountType: .twdSecurities))
    }
}

