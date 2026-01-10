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
    @State private var showingPrepayment = false  // 提前還款
    @State private var showingRegularRepayment = false  // 定期還款
    @State private var currentLiability: Liability?
    @State private var repaymentAccountName: String = ""
    @State private var isDetailsExpanded: Bool = false
    @State private var isHoldingsExpanded: Bool = false  // 持有股數展開/收起狀態
    @State private var holdingsHeight: CGFloat = 200  // 持有股數列表高度
    
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
        GeometryReader { geometry in
            ScrollView {
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
                            .frame(width: 130, height: 38)
                            .layoutPriority(0)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // 主要指標卡片區域
                    if account.accountType == .twdDeposit {
                        // 台幣現金帳戶：單卡片（格式統一，與其他帳戶類型保持一致）
                        CashBalanceCard(
                            account: account,
                            cashBalance: viewModel.cashBalance,
                            displayCurrency: viewModel.displayCurrency,
                            exchangeRate: viewModel.exchangeRate
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                    } else {
                        // 台股、美股、加密貨幣帳戶：兩個卡片並排
                        HStack(spacing: 12) {
                            CashBalanceCard(
                                account: account,
                                cashBalance: viewModel.cashBalance,
                                displayCurrency: viewModel.displayCurrency,
                                exchangeRate: viewModel.exchangeRate
                            )
                            .frame(maxWidth: .infinity)
                            
                            HoldingsValueCard(
                                account: account,
                                holdingsValue: viewModel.holdingsValue,
                                holdings: viewModel.holdings,
                                displayCurrency: viewModel.displayCurrency,
                                exchangeRate: viewModel.exchangeRate
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                        
                        // 資產分配比例條（僅在總資產 > 0 時顯示）
                        let totalAssetsValue = (account.currency == .USD && viewModel.displayCurrency == .TWD) 
                            ? (viewModel.cashBalance + viewModel.holdingsValue) * viewModel.exchangeRate
                            : (viewModel.cashBalance + viewModel.holdingsValue)
                        
                        if totalAssetsValue > 0 {
                            AssetAllocationProgressCard(
                                account: account,
                                cashBalance: viewModel.cashBalance,
                                holdingsValue: viewModel.holdingsValue,
                                displayCurrency: viewModel.displayCurrency,
                                exchangeRate: viewModel.exchangeRate
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                    }
                    
                        // 持有股數標題和表頭（固定，包含展開/收起按鈕）
                        if account.accountType != .twdDeposit && !viewModel.holdings.isEmpty {
                            HoldingsTableHeader(isExpanded: $isHoldingsExpanded)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    
                    // 持股列表內容（根據展開狀態調整是否限制高度）
                    if account.accountType != .twdDeposit && !viewModel.holdings.isEmpty {
                        ZStack(alignment: .top) {
                            ScrollView {
                                HoldingsTableContent(
                                    holdings: viewModel.holdings,
                                    account: account,
                                    displayCurrency: viewModel.displayCurrency,
                                    exchangeRate: viewModel.exchangeRate
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                            }
                            
                            // 收起時的漸層遮罩（不阻擋滑動）
                            if !isHoldingsExpanded {
                                VStack {
                                    Spacer()
                                    LinearGradient(
                                        colors: [.clear, .cardBackground],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 40)
                                    .allowsHitTesting(false)
                                }
                                .frame(height: 200)
                            }
                        }
                        .frame(height: holdingsHeight)
                        .clipped()
                        .onChange(of: isHoldingsExpanded) { _, newValue in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                holdingsHeight = newValue ? 600 : 200
                            }
                        }
                        .onAppear {
                            holdingsHeight = isHoldingsExpanded ? 600 : 200
                        }
                    }
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
            // 底部操作按鈕
            Group {
                if account.accountType != .debt {
                    // 一般帳戶：收入、支出、轉帳按鈕
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
                    // 債務帳戶不顯示按鈕（在 debtAccountView 中顯示）
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
            debtAccountContent
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
            debtAccountBottomButtons
        }
        .sheet(isPresented: $showingPrepayment) {
            if let liability = currentLiability {
                RepaymentView(liability: liability, repaymentType: .prepayment)
                    .onDisappear {
                        Task {
                            await loadDebtAccountData()
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRegularRepayment) {
            if let liability = currentLiability {
                RepaymentView(liability: liability, repaymentType: .regular)
                    .onDisappear {
                        Task {
                            await loadDebtAccountData()
                        }
                    }
            }
        }
        .task {
            await loadDebtAccountData()
        }
        .onChange(of: showingPrepayment) { oldValue, newValue in
            if !newValue {
                Task {
                    await loadDebtAccountData()
                }
            }
        }
        .onChange(of: showingRegularRepayment) { oldValue, newValue in
            if !newValue {
                Task {
                    await loadDebtAccountData()
                }
            }
        }
    }
    
    // MARK: - 債務帳戶內容
    @ViewBuilder
    private var debtAccountContent: some View {
        VStack(spacing: 20) {
            // 標題
            debtAccountHeader
            
            if let liability = currentLiability {
                debtAccountCards(liability: liability)
            }
        }
        .padding()
    }
    
    // MARK: - 債務帳戶標題
    private var debtAccountHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: account.accountType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(account.accountType.color)
                
                Text(currentLiability?.name ?? account.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Text("貸款詳情與狀態")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    // MARK: - 債務帳戶卡片區域
    @ViewBuilder
    private func debtAccountCards(liability: Liability) -> some View {
        // 主要指標卡片區域（並排）
        HStack(spacing: 12) {
            remainingPrincipalCard(liability: liability)
            paidAmountCard(liability: liability)
        }
        .padding(.horizontal, 20)
        
        // 還款進度卡片
        RepaymentProgressCard(liability: liability)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        
        // 詳細資訊（可折疊）
        DetailsCard(
            liability: liability,
            isExpanded: $isDetailsExpanded
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        
        // 還款資訊卡片
        RepaymentInfoCard(
            liability: liability,
            repaymentAccount: accountsViewModel.accounts.first(where: { $0.id == liability.accountId }),
            repaymentAccountName: repaymentAccountName
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - 剩餘本金卡片
    private func remainingPrincipalCard(liability: Liability) -> some View {
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
                
                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveFontText(
                        text: liability.remainingBalance.formatted(currency: liability.currency),
                        baseFontSize: 28,
                        color: .lossRed
                    )
                }
                
                Text("")
                    .font(.caption)
                    .foregroundColor(.clear)
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - 已還款金額（含利息）卡片
    private func paidAmountCard(liability: Liability) -> some View {
        let paidAmount = liability.totalPaidPrincipal + liability.totalPaidInterest
        
        return CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("已還款金額（含利息）")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.profitGreen)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveFontText(
                        text: paidAmount.formatted(currency: liability.currency),
                        baseFontSize: 28,
                        color: .profitGreen
                    )
                }
                
                Text("")
                    .font(.caption)
                    .foregroundColor(.clear)
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - 債務帳戶底部按鈕
    private var debtAccountBottomButtons: some View {
        HStack(spacing: 12) {
            // 提前還款按鈕（左側）- 紅色漸層
            Button(action: {
                showingPrepayment = true
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("提前還款")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.85, green: 0.15, blue: 0.15), Color(red: 0.95, green: 0.3, blue: 0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            // 定期還款按鈕（右側）- 橘色漸層
            Button(action: {
                showingRegularRepayment = true
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text("定期還款")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 1.0, green: 0.55, blue: 0.0), Color(red: 1.0, green: 0.7, blue: 0.2)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
    }
    
    // MARK: - 載入債務帳戶數據
    private func loadDebtAccountData() async {
        await accountsViewModel.loadAccounts(userId: "test-user-id")
        
        // 找到債務帳戶
        if account.accountType == .debt {
            // 在所有還款帳戶中查找對應的債務記錄
            for repaymentAccount in accountsViewModel.accounts {
                do {
                    let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: repaymentAccount.id)
                    if let liability = liabilities.first(where: { $0.name == account.name }) {
                        await MainActor.run {
                            currentLiability = liability
                            repaymentAccountName = repaymentAccount.name
                        }
                        break
                    }
                } catch {
                    // 繼續查找下一個帳戶
                    continue
                }
            }
        }
    }
}

// MARK: - 自適應字體大小的文字視圖
struct AdaptiveFontText: View {
    let text: String
    let baseFontSize: CGFloat
    let color: Color
    
    private var fontSize: CGFloat {
        // 根據文字長度動態調整字體大小
        let length = text.count
        if length <= 8 {
            // 8位數以下保持正常大小
            return baseFontSize
        } else if length <= 12 {
            // 9-12位數稍微縮小
            return baseFontSize * 0.85
        } else if length <= 16 {
            // 13-16位數中等縮小
            return baseFontSize * 0.7
        } else {
            // 17位數以上大幅縮小
            return baseFontSize * 0.5
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
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
                    AdaptiveFontText(
                        text: displayAmount.formatted(currency: displayCurrency),
                        baseFontSize: 28,
                        color: .primaryText
                    )
                }
                
                // 添加一行空白以對齊持股市值卡片的第三行（保持相同高度）
                Text("")
                    .font(.caption)
                    .foregroundColor(.clear)
                    .frame(height: 16)  // 與持股市值卡片的第三行高度一致
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
                    AdaptiveFontText(
                        text: displayAmount.formatted(currency: displayCurrency),
                        baseFontSize: 28,
                        color: .primaryText
                    )
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
    @Binding var isExpanded: Bool
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("持有股數")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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
    
    // 更現代的漸變藍色（替代 appPrimary 的純藍色）
    // 使用更柔和、更現代的藍紫色漸變，類似 iOS 17+ 的設計風格
    private var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.58, blue: 0.96),  // 柔和的亮藍色
                Color(red: 0.25, green: 0.45, blue: 0.88)   // 深藍紫色
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var isUSDSelected: Bool {
        displayCurrency == .USD
    }
    
    private var backgroundOffset: CGFloat {
        isUSDSelected ? 0 : 1
    }
    
    var body: some View {
        GeometryReader { geometry in
            let buttonWidth = geometry.size.width / 2
            let buttonHeight = geometry.size.height
            
            ZStack(alignment: .leading) {
                // 背景容器
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.separator.opacity(0.2), lineWidth: 1)
                    )
                
                // 選中背景（滑動動畫）
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedGradient)
                    .frame(width: buttonWidth - 4)
                    .padding(2)
                    .offset(x: backgroundOffset * buttonWidth)
                    .shadow(color: Color(red: 0.25, green: 0.45, blue: 0.88).opacity(0.25), radius: 6, x: 0, y: 3)
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                
                // 按鈕區域
                HStack(spacing: 0) {
                    // USD 按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            displayCurrency = .USD
                        }
                    }) {
                        Text("USD")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isUSDSelected ? .white : .secondaryText)
                            .opacity(isUSDSelected ? 1.0 : 0.7)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // TWD 按鈕
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            displayCurrency = .TWD
                        }
                    }) {
                        Text("TWD")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(!isUSDSelected ? .white : .secondaryText)
                            .opacity(!isUSDSelected ? 1.0 : 0.7)
                            .frame(width: buttonWidth, height: buttonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 分隔線（在兩個按鈕之間）
                Rectangle()
                    .fill(Color.separator.opacity(0.3))
                    .frame(width: 1)
                    .offset(x: buttonWidth - 0.5)
            }
        }
        .clipped()  // 確保滑動背景不會溢出
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
    var valueColor: Color = .primaryText  // 默認為主要文字顏色
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
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
                
                // 期數顯示（字體自適應）
                Text("\(paidPeriods)/\(totalPeriods) 期")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
                        
                        // 第一部分：原始資訊
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
                        
                        // 新增：已還款本金（在總還款金額下面）
                        InfoRowWithoutIcon(
                            label: "已還款本金",
                            value: liability.totalPaidPrincipal.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總利息",
                            value: liability.totalInterest.formatted(currency: liability.currency)
                        )
                        
                        Divider()
                        
                        // 新增：已支出利息（在總利息下面）
                        InfoRowWithoutIcon(
                            label: "已支出利息",
                            value: liability.totalPaidInterest.formatted(currency: liability.currency)
                        )
                        
                        // 如果有提前還款，顯示節省利息（在已支出利息下面）
                        if liability.totalSavedInterest > 0 {
                            Divider()
                            
                            InfoRowWithoutIcon(
                                label: "節省利息",
                                value: liability.totalSavedInterest.formatted(currency: liability.currency),
                                valueColor: .profitGreen
                            )
                        }
                        
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
                
                Divider()
                
                // 還款總期數（無 ICON）
                InfoRowWithoutIcon(
                    label: "還款總期數",
                    value: "\(liability.totalPeriods) 期"
                )
                
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

// MARK: - 資產分配比例條卡片
struct AssetAllocationProgressCard: View {
    let account: Account
    let cashBalance: Decimal
    let holdingsValue: Decimal
    let displayCurrency: Currency
    let exchangeRate: Decimal
    @State private var animatedCashProgress: Double = 0.0
    @State private var animatedHoldingsProgress: Double = 0.0
    
    // 計算顯示金額（考慮貨幣轉換）
    private var displayCashBalance: Decimal {
        if account.currency == .USD && displayCurrency == .TWD {
            return cashBalance * exchangeRate
        }
        return cashBalance
    }
    
    private var displayHoldingsValue: Decimal {
        if account.currency == .USD && displayCurrency == .TWD {
            return holdingsValue * exchangeRate
        }
        return holdingsValue
    }
    
    // 計算總資產
    private var totalAssets: Decimal {
        return displayCashBalance + displayHoldingsValue
    }
    
    // 計算比例（目標值）
    private var targetCashRatio: Double {
        guard totalAssets > 0 else { return 0.0 }
        return Double(NSDecimalNumber(decimal: displayCashBalance / totalAssets).doubleValue)
    }
    
    private var targetHoldingsRatio: Double {
        guard totalAssets > 0 else { return 0.0 }
        return Double(NSDecimalNumber(decimal: displayHoldingsValue / totalAssets).doubleValue)
    }
    
    // 百分比顯示
    private var cashPercentage: String {
        let percentage = targetCashRatio * 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: percentage)) ?? "0.0"
    }
    
    private var holdingsPercentage: String {
        let percentage = targetHoldingsRatio * 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: percentage)) ?? "0.0"
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                // 標題和圖標
                HStack {
                    Text("資產分配")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(account.accountType.color)
                        .font(.system(size: 18))
                }
                
                // 進度條（使用連續的矩形，無縫連接）
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景（有圓角）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondaryBackground)
                            .frame(height: 12)
                        
                        // 進度條容器（整體矩形，然後用 mask 切割）
                        HStack(spacing: 0) {
                            // 現金部分
                            if animatedCashProgress > 0 {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.appPrimary, .profitGreen],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * animatedCashProgress, height: 12)
                            }
                            
                            // 持股部分（緊接著，無間隙）
                            if animatedHoldingsProgress > 0 {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [account.accountType.color, account.accountType.color.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * animatedHoldingsProgress, height: 12)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))  // 整體圓角，確保兩段連接連續
                    }
                }
                .frame(height: 12)
                
                // 比例顯示
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.appPrimary, .profitGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 8, height: 8)
                        Text("現金 \(cashPercentage)%")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(account.accountType.color)
                            .frame(width: 8, height: 8)
                        Text("持股 \(holdingsPercentage)%")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .onAppear {
            // 載入動畫：從0開始動畫到目標比例（確保每次進入頁面都看到動畫）
            // 先重置為0
            animatedCashProgress = 0.0
            animatedHoldingsProgress = 0.0
            
            // 延遲一小段時間後開始動畫，確保視圖已完全渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                    animatedCashProgress = targetCashRatio
                    animatedHoldingsProgress = targetHoldingsRatio
                }
            }
        }
        // 使用 id 確保每次進入頁面時視圖重新創建，觸發 onAppear
        .id("asset-allocation-\(account.id)")
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(account: Account(userId: "test", name: "國泰證券", accountType: .twdSecurities))
    }
}

