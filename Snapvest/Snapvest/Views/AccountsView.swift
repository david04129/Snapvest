//
//  AccountsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AccountsView: View {
    @StateObject private var viewModel = AccountsViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @State private var showingAddAccount = false
    @State private var showingAddLiability = false
    @State private var userId: String = "test-user-id"
    @State private var expandedCategories: Set<AccountType> = Set(AccountType.allCases) // 預設全部展開
    @State private var accountOrder: [AccountType] = AccountType.allCases
    @State private var accountOrders: [AccountType: [String]] = [:] // 每個類別內的帳戶排序
    @State private var refreshTrigger: UUID = UUID() // 用於觸發類別總資產刷新
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 按帳戶類型分組顯示（可收縮/展開，支援拖曳排序）
                    ForEach(accountOrder, id: \.self) { accountType in
                        if accountType == .debt {
                            // 負債帳戶（顯示所有債務帳戶，就像其他帳戶類型一樣）
                            let debtAccounts = viewModel.accounts.filter { $0.accountType == .debt }
                            if !debtAccounts.isEmpty {
                                ExpandableAccountCategorySection(
                                    accountType: accountType,
                                    accounts: debtAccounts,
                                    portfolioViewModel: portfolioViewModel,
                                    isExpanded: Binding(
                                        get: { expandedCategories.contains(accountType) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedCategories.insert(accountType)
                                            } else {
                                                expandedCategories.remove(accountType)
                                            }
                                        }
                                    ),
                                    refreshTrigger: refreshTrigger
                                )
                            }
                        } else {
                            // 一般帳戶
                            ExpandableAccountCategorySection(
                                accountType: accountType,
                                accounts: viewModel.accounts.filter { $0.accountType == accountType },
                                portfolioViewModel: portfolioViewModel,
                                isExpanded: Binding(
                                    get: { expandedCategories.contains(accountType) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedCategories.insert(accountType)
                                        } else {
                                            expandedCategories.remove(accountType)
                                        }
                                    }
                                ),
                                refreshTrigger: refreshTrigger
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBarWithAddButton(icon: "building.columns.fill", title: "帳戶管理", addButtonText: "新增帳戶", addButtonAction: {
                    showingAddAccount = true
                })
            }
            .refreshable {
                await viewModel.loadAccounts(userId: userId)
                await portfolioViewModel.loadData(userId: userId)
            }
            .sheet(isPresented: $showingAddAccount, onDismiss: {
                // 當sheet關閉時，重新載入數據
                Task {
                    await viewModel.loadAccounts(userId: userId)
                    await portfolioViewModel.loadData(userId: userId)
                    // 觸發類別總資產刷新
                    refreshTrigger = UUID()
                }
            }) {
                AddAccountView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadAccounts(userId: userId)
                await portfolioViewModel.loadData(userId: userId)
                loadAccountOrder()
                // 觸發類別總資產刷新
                refreshTrigger = UUID()
            }
            .onAppear {
                // 當視圖出現時，觸發類別總資產刷新
                refreshTrigger = UUID()
            }
        }
    }
    
    // MARK: - 自定義標題欄（帶新增按鈕）
    private func customHeaderBarWithAddButton(icon: String, title: String, addButtonText: String, addButtonAction: @escaping () -> Void) -> some View {
        HStack {
            // 左側：ICON + 標題
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            // 右側：新增按鈕 + 使用者頭像
            HStack(spacing: 12) {
                Button(action: addButtonAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(addButtonText)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                
                Button(action: {
                    // TODO: 點擊後的功能
                }) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(.appPrimary)
                                .font(.caption)
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
    
    // MARK: - 拖曳排序輔助函數
    private func getOrderedAccounts(_ accounts: [Account], for accountType: AccountType) -> [Account] {
        let order = accountOrders[accountType] ?? []
        let ordered = accounts.sorted { a, b in
            let indexA = order.firstIndex(of: a.id) ?? Int.max
            let indexB = order.firstIndex(of: b.id) ?? Int.max
            return indexA < indexB
        }
        return ordered
    }
    
    private func moveAccounts(from source: IndexSet, to destination: Int, for accountType: AccountType) {
        let accounts = viewModel.accounts.filter { $0.accountType == accountType }
        var order = accountOrders[accountType] ?? accounts.map { $0.id }
        order.move(fromOffsets: source, toOffset: destination)
        accountOrders[accountType] = order
        saveAccountOrder()
    }
    
    private func loadAccountOrder() {
        // 從 UserDefaults 載入排序
        if let data = UserDefaults.standard.data(forKey: "accountOrder_\(userId)"),
           let order = try? JSONDecoder().decode([AccountType].self, from: data) {
            accountOrder = order
        }
        
        // 載入每個類別內的帳戶排序
        for accountType in AccountType.allCases {
            let key = "accountOrder_\(userId)_\(accountType.rawValue)"
            if let data = UserDefaults.standard.data(forKey: key),
               let order = try? JSONDecoder().decode([String].self, from: data) {
                accountOrders[accountType] = order
            }
        }
    }
    
    private func saveAccountOrder() {
        // 保存類別排序
        if let data = try? JSONEncoder().encode(accountOrder) {
            UserDefaults.standard.set(data, forKey: "accountOrder_\(userId)")
        }
        
        // 保存每個類別內的帳戶排序
        for (accountType, order) in accountOrders {
            let key = "accountOrder_\(userId)_\(accountType.rawValue)"
            if let data = try? JSONEncoder().encode(order) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

// MARK: - 可收縮/展開的帳戶類別區塊
struct ExpandableAccountCategorySection: View {
    let accountType: AccountType
    let accounts: [Account]
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @Binding var isExpanded: Bool
    let refreshTrigger: UUID // 用於觸發刷新
    @StateObject private var categoryViewModel = CategoryTotalViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var totalDebtBalance: Decimal = 0  // 債務帳戶的總剩餘本金
    
    var categoryTotal: Decimal {
        if accountType == .debt {
            // 債務帳戶：返回所有債務剩餘本金總和（負數）
            return -totalDebtBalance
        } else {
            // 一般帳戶：返回總資產
            return categoryViewModel.totalAssets
        }
    }
    
    var body: some View {
        if !accounts.isEmpty {
            VStack(spacing: 0) {
                // 可點擊的標題欄（收縮/展開）
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        // 圖標（帶背景色）
                        ZStack {
                            Circle()
                                .fill(accountType.color.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: accountType.icon)
                                .foregroundColor(accountType.color)
                                .font(.system(size: 20))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accountType.displayName)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Text("\(accounts.count)個帳戶")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(accountType == .debt ? "類別總債務" : "類別總資產")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Text(categoryTotal.formatted(currency: .TWD))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(accountType.color)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                    .task {
                        if accountType == .debt {
                            await loadTotalDebtBalance()
                        } else {
                            await categoryViewModel.calculateCategoryTotal(
                                accounts: accounts,
                                portfolioViewModel: portfolioViewModel
                            )
                        }
                    }
                    .onChange(of: refreshTrigger) { _, _ in
                        Task {
                            if accountType == .debt {
                                await loadTotalDebtBalance()
                            } else {
                                await categoryViewModel.calculateCategoryTotal(
                                    accounts: accounts,
                                    portfolioViewModel: portfolioViewModel
                                )
                            }
                        }
                    }
                    .onChange(of: accounts.map { $0.id }) { _, _ in
                        Task {
                            if accountType == .debt {
                                await loadTotalDebtBalance()
                            } else {
                                await categoryViewModel.calculateCategoryTotal(
                                    accounts: accounts,
                                    portfolioViewModel: portfolioViewModel
                                )
                            }
                        }
                    }
                    .onChange(of: portfolioViewModel.totalAssets) { _, _ in
                        Task {
                            if accountType == .debt {
                                await loadTotalDebtBalance()
                            } else {
                                await categoryViewModel.calculateCategoryTotal(
                                    accounts: accounts,
                                    portfolioViewModel: portfolioViewModel
                                )
                            }
                        }
                    }
                    .padding()
                }
                .buttonStyle(PlainButtonStyle())
                
                // 帳戶列表（可展開/收縮）
                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(accounts) { account in
                            NavigationLink(destination: AccountDetailView(account: account)) {
                                AccountCardView(account: account, portfolioViewModel: portfolioViewModel)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(accountType.color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accountType.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // 載入債務帳戶的總剩餘本金
    private func loadTotalDebtBalance() async {
        await accountsViewModel.loadAccounts(userId: "test-user-id")
        var total: Decimal = 0
        
        // 對於每個債務帳戶，找到對應的債務記錄
        for debtAccount in accounts {
            // 在所有還款帳戶中查找對應的債務
            for repaymentAccount in accountsViewModel.accounts {
                do {
                    let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: repaymentAccount.id)
                    if let liability = liabilities.first(where: { $0.name == debtAccount.name }) {
                        total += liability.remainingBalance
                        break  // 找到對應的債務後，跳出內層循環
                    }
                } catch {
                    // 如果載入失敗，繼續嘗試下一個帳戶
                    continue
                }
            }
        }
        
        await MainActor.run {
            totalDebtBalance = total
        }
    }
}

// MARK: - 帳戶卡片
struct AccountCardView: View {
    let account: Account
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @StateObject private var accountDetailViewModel = AccountDetailViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var totalAssets: Decimal = 0
    @State private var cashBalance: Decimal = 0
    @State private var holdingsValue: Decimal = 0
    @State private var twdEquivalent: Decimal? = nil
    @State private var remainingBalance: Decimal = 0  // 債務帳戶的剩餘本金
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(account.accountType.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    if account.accountType == .debt {
                        Text("剩餘本金")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else if account.accountType == .twdDeposit {
                        Text("現金餘額")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else {
                        Text("總資產")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if account.accountType == .debt {
                        // 債務帳戶顯示剩餘本金（負數）
                        let negativeBalance = -remainingBalance
                        Text(negativeBalance.formatted(currency: account.currency))
                            .font(.headline)
                            .foregroundColor(account.accountType.color)
                        
                        Text(account.currency.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else if account.accountType == .twdDeposit {
                        // 現金帳戶只顯示現金餘額
                        Text(cashBalance.formatted(currency: account.currency))
                            .font(.headline)
                            .foregroundColor(account.accountType.color)
                        
                        Text(account.currency.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else {
                        // 其他帳戶顯示總資產（現金+持股市值）
                        Text(totalAssets.formatted(currency: account.currency))
                            .font(.headline)
                            .foregroundColor(account.accountType.color)
                        
                        // 先顯示幣別
                        Text(account.currency.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        // 如果是美金帳戶或加密貨幣錢包，顯示台幣等值
                        if account.currency == .USD, let twd = twdEquivalent {
                            Text("≈ \(twd.formatted(currency: .TWD))")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(account.accountType.color.opacity(0.08))
        .cornerRadius(12)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 5,
            x: 0,
            y: 2
        )
        .task {
            await loadAccountAssets()
        }
    }
    
    private func loadAccountAssets() async {
        if account.accountType == .debt {
            // 債務帳戶：載入剩餘本金
            await accountsViewModel.loadAccounts(userId: "test-user-id")
            let allAccounts = accountsViewModel.accounts
            for acc in allAccounts {
                do {
                    let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: acc.id)
                    if let liability = liabilities.first(where: { $0.name == account.name }) {
                        await MainActor.run {
                            remainingBalance = liability.remainingBalance
                        }
                        break
                    }
                } catch {
                    // 如果載入失敗，繼續嘗試下一個帳戶
                }
            }
        } else {
            // 一般帳戶：載入資產
            await accountDetailViewModel.loadAccountData(accountId: account.id)
            cashBalance = accountDetailViewModel.cashBalance
            holdingsValue = accountDetailViewModel.holdingsValue
            totalAssets = cashBalance + holdingsValue
            
            // 如果是美金帳戶或加密貨幣錢包，計算台幣等值
            if account.currency == .USD {
                // TODO: 從匯率服務獲取即時匯率
                // 目前使用固定匯率 1 USD = 32 TWD（應該從 ExchangeRate 服務獲取）
                let usdToTwdRate: Decimal = 32 // 臨時固定值，之後應該從服務獲取
                twdEquivalent = totalAssets * usdToTwdRate
            }
        }
    }
}

// MARK: - 可收縮/展開的負債帳戶區塊
struct ExpandableDebtAccountSection: View {
    let accountType: AccountType
    let liabilities: [Liability]
    @Binding var isExpanded: Bool
    
    var totalDebt: Decimal {
        liabilities.map { $0.remainingBalance }.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 可點擊的標題欄（收縮/展開）
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    // 圖標（帶背景色）
                    ZStack {
                        Circle()
                            .fill(accountType.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: accountType.icon)
                            .foregroundColor(accountType.color)
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accountType.displayName)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Text("\(liabilities.count)個帳戶")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("類別總債務")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Text((-totalDebt).formatted(currency: .TWD))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(accountType.color)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                    }
                    .padding()
                    .background(accountType.color.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accountType.color.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            
            // 負債列表（可展開/收縮）
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(liabilities) { liability in
                        NavigationLink(destination: LiabilityDetailView(liability: liability)) {
                            DebtCardView(liability: liability)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - 負債卡片
struct DebtCardView: View {
    let liability: Liability
    
    var body: some View {
        CardView {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.lossRed)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(liability.name)
                        .font(.headline)
                    
                    Text("剩餘本金")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // 確保顯示負號：對於債務，金額應該是負數
                    let negativeBalance = -liability.remainingBalance
                    Text(negativeBalance.formatted(currency: liability.currency))
                        .font(.headline)
                        .foregroundColor(.lossRed)
                    
                    Text(liability.currency.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

#Preview {
    AccountsView()
}

