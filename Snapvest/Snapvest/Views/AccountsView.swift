//
//  AccountsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct AccountsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var viewModel: AccountsViewModel
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var showingAddAccount = false
    @State private var showingAddLiability = false
    @State private var userId: String = AppUser.id
    @State private var expandedCategories: Set<AccountType> = Set(AccountType.allCases)
    @State private var accountOrder: [AccountType] = AccountType.allCases
    @State private var accountOrders: [AccountType: [String]] = [:]
    @State private var navigationStackResetID = UUID()
    @State private var accountsCurrencyDisplay: AssetsCurrencyDisplay = .twd
    @State private var isEditingOrder = false
    @State private var accountPendingDelete: Account?
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationMessage = ""
    @State private var deleteErrorMessage: String?
    @State private var isDeleting = false
    @State private var accountDetailRoute: AccountDetailRoute?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    AccountsCurrencyControlsBar(
                        currencyDisplay: $accountsCurrencyDisplay,
                        showsEditControl: true,
                        isEditingOrder: isEditingOrder,
                        isEditDisabled: viewModel.accounts.filter(\.isActiveForListing).isEmpty,
                        onEditTapped: {
                            toggleOrderEditing()
                        }
                    )
                    
                    ForEach(accountOrder, id: \.self) { accountType in
                        accountCategorySection(for: accountType)
                    }
                    
                    archivedDebtAccountsSection
                    
                    DataFreshnessFooterView(style: .valuationTabs)
                }
                .padding()
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
            .safeAreaInset(edge: .top) {
                accountsHeaderBar
            }
            .refreshable {
                await SnapshotRefreshCoordinator.rebuildAndNotify(userId: userId)
            }
            .sheet(isPresented: $showingAddAccount, onDismiss: {
                loadAccountOrder()
                reconcileAccountOrders()
            }) {
                AddAccountView(viewModel: viewModel)
            }
            .onAppear {
                loadAccountOrder()
                reconcileAccountOrders()
            }
            .onChange(of: selectedTab) { _, newTab in
                if isEditingOrder, newTab != AppTab.accounts.rawValue {
                    finishOrderEditing()
                    return
                }
                guard newTab == AppTab.accounts.rawValue else { return }
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: viewModel,
                        assetsViewModel: assetsViewModel
                    )
                    reconcileAccountOrders()
                }
            }
            .onChange(of: viewModel.accounts.map(\.id)) { _, _ in
                reconcileAccountOrders()
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: viewModel,
                        assetsViewModel: assetsViewModel
                    )
                    reconcileAccountOrders()
                }
            }
            .alert("刪除帳戶", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    accountPendingDelete = nil
                }
                Button("刪除", role: .destructive) {
                    Task { await performDeleteAccount() }
                }
            } message: {
                Text(deleteConfirmationMessage)
            }
            .alert("無法刪除", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "")
            }
            .navigationDestination(item: $accountDetailRoute) { route in
                accountDetailDestination(for: route)
            }
        }
        .id(navigationStackResetID)
        .resetNavigationWhenTabReappears(selectedTab: $selectedTab, resignedTab: .accounts) {
            navigationStackResetID = UUID()
        }
    }
    
    private func openAccountDetail(_ account: Account) {
        guard !isEditingOrder else { return }
        accountDetailRoute = AccountDetailRoute(accountId: account.id)
    }
    
    @ViewBuilder
    private func accountDetailDestination(for route: AccountDetailRoute) -> some View {
        if let account = viewModel.accounts.first(where: { $0.id == route.accountId }) {
            AccountDetailView(
                account: account,
                prefilledBalance: viewModel.balancesByAccountId[account.id]
            )
        } else {
            ContentUnavailableView("找不到帳戶", systemImage: "building.columns")
        }
    }
    
    @ViewBuilder
    private func accountCategorySection(for accountType: AccountType) -> some View {
        let typeAccounts = viewModel.accounts.activeAccounts(ofType: accountType)
        if typeAccounts.isEmpty { EmptyView() } else {
            let isLoading = viewModel.balancesLoading && !viewModel.balancesLoadedOnce
            let categoryTotal: Decimal = accountType == .debt
                ? -viewModel.debtCategoryTotalBalance
                : accountType == .otherDebt
                ? -viewModel.otherDebtCategoryTotalBalance
                : (viewModel.categoryTotalsTWD[accountType] ?? 0)
            let ordered = getOrderedAccounts(typeAccounts, for: accountType)
            ExpandableAccountCategorySection(
                accountType: accountType,
                accounts: ordered,
                categoryTotalTWD: categoryTotal,
                currencyDisplay: accountsCurrencyDisplay,
                isCategoryLoading: isLoading,
                balancesByAccountId: viewModel.balancesByAccountId,
                isBalanceLoading: isLoading,
                isExpanded: expandedBinding(for: accountType),
                isEditingOrder: isEditingOrder,
                onMove: { source, destination in
                    moveAccounts(from: source, to: destination, for: accountType)
                },
                onRequestDelete: { account in
                    presentDeleteConfirmation(for: account)
                },
                onOpenAccount: openAccountDetail
            )
        }
    }
    
    private func expandedBinding(for accountType: AccountType) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(accountType) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(accountType)
                } else {
                    expandedCategories.remove(accountType)
                }
            }
        )
    }

    @ViewBuilder
    private var archivedDebtAccountsSection: some View {
        let archived = viewModel.accounts.archivedDebtAccounts
        if archived.isEmpty {
            EmptyView()
        } else {
            ArchivedDebtAccountsSection(
                accounts: archived,
                balancesByAccountId: viewModel.balancesByAccountId,
                currencyDisplay: accountsCurrencyDisplay,
                isEditingOrder: isEditingOrder,
                onRequestDelete: { account in
                    presentDeleteConfirmation(for: account)
                },
                onOpenAccount: openAccountDetail
            )
        }
    }
    
    // MARK: - 標題欄
    
    private var accountsHeaderBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                
                Text("帳戶管理")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    guard !isEditingOrder else { return }
                    showingAddAccount = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增帳戶")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                .disabled(isEditingOrder)
                .opacity(isEditingOrder ? 0.45 : 1)
                
                AppHeaderMoreButton(action: openSettings)
                    .disabled(isEditingOrder)
                    .opacity(isEditingOrder ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
    
    // MARK: - 刪除帳戶
    
    private func presentDeleteConfirmation(for account: Account) {
        guard !isDeleting, !isEditingOrder else { return }
        accountPendingDelete = account
        Task {
            deleteConfirmationMessage = await AccountDeletionSummaryBuilder.buildForAccountList(
                account: account,
                dataService: MockDataService.shared,
                balancesByAccountId: viewModel.balancesByAccountId,
                liabilities: portfolioViewModel.liabilities,
                accounts: viewModel.accounts
            )
            showDeleteConfirmation = true
        }
    }
    
    private func performDeleteAccount() async {
        guard let account = accountPendingDelete else { return }
        isDeleting = true
        defer { isDeleting = false }
        
        if let error = await viewModel.deleteAccount(account) {
            deleteErrorMessage = error
        } else {
            var order = accountOrders[account.accountType] ?? []
            order.removeAll { $0 == account.id }
            accountOrders[account.accountType] = order
            saveAccountOrder()
            accountPendingDelete = nil
        }
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
        let accounts = viewModel.accounts.activeAccounts(ofType: accountType)
        var order = accountOrders[accountType] ?? accounts.map(\.id)
        order.move(fromOffsets: source, toOffset: destination)
        accountOrders[accountType] = order
        saveAccountOrder()
    }
    
    private func reconcileAccountOrders() {
        for accountType in AccountType.allCases {
            let active = viewModel.accounts.activeAccounts(ofType: accountType)
            var order = accountOrders[accountType] ?? []
            order = order.filter { id in active.contains { $0.id == id } }
            for account in active where !order.contains(account.id) {
                order.append(account.id)
            }
            accountOrders[accountType] = order
        }
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
    
    private func toggleOrderEditing() {
        if isEditingOrder {
            finishOrderEditing()
        } else {
            beginOrderEditing()
        }
    }
    
    private func beginOrderEditing() {
        let nonEmptyTypes = AccountType.allCases.filter { accountType in
            !viewModel.accounts.activeAccounts(ofType: accountType).isEmpty
        }
        withAnimation(ChartMotion.switchSpring) {
            expandedCategories.formUnion(nonEmptyTypes)
            isEditingOrder = true
        }
    }
    
    private func finishOrderEditing() {
        saveAccountOrder()
        withAnimation(ChartMotion.switchSpring) {
            isEditingOrder = false
        }
    }
}

private struct AccountDetailRoute: Identifiable, Hashable {
    let accountId: String
    var id: String { accountId }
}

// MARK: - 已封存債務帳戶

struct ArchivedDebtAccountsSection: View {
    let accounts: [Account]
    let balancesByAccountId: [String: AccountBalanceDisplay]
    let currencyDisplay: AssetsCurrencyDisplay
    let isEditingOrder: Bool
    let onRequestDelete: (Account) -> Void
    let onOpenAccount: (Account) -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                guard !isEditingOrder else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .foregroundColor(.secondaryText)
                    Text("已封存負債")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text("(\(accounts.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondaryText.opacity(0.5))
                        .frame(width: 4)
                }
                .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                List {
                    ForEach(accounts) { account in
                        AccountListRowButton(
                            account: account,
                            isEditingOrder: isEditingOrder,
                            onOpen: { onOpenAccount(account) },
                            onDelete: { onRequestDelete(account) }
                        ) {
                            AccountCardView(
                                account: account,
                                balance: balancesByAccountId[account.id],
                                currencyDisplay: currencyDisplay,
                                isBalanceLoading: false,
                                showsArchivedBadge: true
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(accounts.count) * 88)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - 帳戶列（無 NavigationLink 箭頭）

private struct AccountListRowButton<RowContent: View>: View {
    let account: Account
    let isEditingOrder: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let rowContent: () -> RowContent
    
    var body: some View {
        Button(action: onOpen) {
            rowContent()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(isEditingOrder)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isEditingOrder {
                Button(role: .destructive, action: onDelete) {
                    SwiftUI.Label("刪除", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - 帳戶列表顯示用（台幣 / 原幣）

enum AccountListAmountDisplay {
    static func categoryTotal(
        accountType: AccountType,
        accounts: [Account],
        categoryTotalTWD: Decimal,
        balancesByAccountId: [String: AccountBalanceDisplay],
        currencyDisplay: AssetsCurrencyDisplay
    ) -> (amount: Decimal, currency: Currency) {
        if accountType == .debt || accountType == .otherDebt {
            return (categoryTotalTWD, .TWD)
        }
        
        if currencyDisplay == .twd {
            return (categoryTotalTWD, .TWD)
        }
        
        let nativeCurrency = accountType.defaultCurrency
        let sum = accounts.reduce(Decimal.zero) { partial, account in
            guard let balance = balancesByAccountId[account.id] else { return partial }
            switch account.accountType {
            case .twdDeposit:
                return partial + balance.cashBalance
            case .debt, .otherDebt:
                return partial + balance.remainingBalance
            default:
                return partial + balance.totalAssets
            }
        }
        return (sum, nativeCurrency)
    }
    
    static func cardAmount(
        account: Account,
        balance: AccountBalanceDisplay,
        currencyDisplay: AssetsCurrencyDisplay
    ) -> (amount: Decimal, currency: Currency) {
        switch account.accountType {
        case .debt, .otherDebt:
            return (-balance.remainingBalance, account.currency)
        case .twdDeposit:
            return (balance.cashBalance, account.currency)
        default:
            if currencyDisplay == .twd {
                if let twdEquivalent = balance.twdEquivalent {
                    return (twdEquivalent, .TWD)
                }
                return (balance.totalAssets, account.currency)
            }
            return (balance.totalAssets, account.currency)
        }
    }
}

// MARK: - 可收縮/展開的帳戶類別區塊
struct ExpandableAccountCategorySection: View {
    let accountType: AccountType
    let accounts: [Account]
    let categoryTotalTWD: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let isCategoryLoading: Bool
    let balancesByAccountId: [String: AccountBalanceDisplay]
    let isBalanceLoading: Bool
    @Binding var isExpanded: Bool
    let isEditingOrder: Bool
    let onMove: (IndexSet, Int) -> Void
    let onRequestDelete: (Account) -> Void
    let onOpenAccount: (Account) -> Void
    
    private var categoryTotalText: String {
        if isCategoryLoading { return "—" }
        let display = AccountListAmountDisplay.categoryTotal(
            accountType: accountType,
            accounts: accounts,
            categoryTotalTWD: categoryTotalTWD,
            balancesByAccountId: balancesByAccountId,
            currencyDisplay: currencyDisplay
        )
        return display.amount.formatted(currency: display.currency)
    }
    
    private var categoryAmountColor: Color {
        accountType == .debt || accountType == .otherDebt ? .lossRed : .primaryText
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                guard !isEditingOrder else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
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
                        Text(accountType == .debt || accountType == .otherDebt ? "類別總債務" : "類別總資產")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Text(categoryTotalText)
                            .font(.snapAmountRow)
                            .foregroundColor(categoryAmountColor)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                List {
                    ForEach(accounts) { account in
                        AccountListRowButton(
                            account: account,
                            isEditingOrder: isEditingOrder,
                            onOpen: { onOpenAccount(account) },
                            onDelete: { onRequestDelete(account) }
                        ) {
                            AccountCardView(
                                account: account,
                                balance: balancesByAccountId[account.id],
                                currencyDisplay: currencyDisplay,
                                isBalanceLoading: isBalanceLoading
                            )
                        }
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(accounts.count) * 88)
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(accountType.color)
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appPrimary.opacity(isEditingOrder ? 0.28 : 0), lineWidth: isEditingOrder ? 1 : 0)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

// MARK: - 帳戶卡片
struct AccountCardView: View {
    let account: Account
    let balance: AccountBalanceDisplay?
    let currencyDisplay: AssetsCurrencyDisplay
    let isBalanceLoading: Bool
    var showsArchivedBadge: Bool = false
    
    private var showLoadingPlaceholder: Bool {
        isBalanceLoading && balance == nil
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(account.accountType.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(account.name)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        if showsArchivedBadge || account.isArchived {
                            Text("已封存")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondaryBackground)
                                .clipShape(Capsule())
                        }
                    }
                    Text(accountSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    amountPrimaryText
                    if !showLoadingPlaceholder, let balance {
                        let display = AccountListAmountDisplay.cardAmount(
                            account: account,
                            balance: balance,
                            currencyDisplay: currencyDisplay
                        )
                        Text(display.currency.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            HStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(account.accountType.color)
                    .frame(width: 4)
                Spacer()
            }
        )
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
    }
    
    private var accountSubtitle: String {
        switch account.accountType {
        case .debt: return "剩餘本金"
        case .otherDebt: return "目前欠款"
        case .twdDeposit: return "現金餘額"
        default: return "總資產"
        }
    }
    
    @ViewBuilder
    private var amountPrimaryText: some View {
        if showLoadingPlaceholder {
            Text("—")
                .font(.snapAmountRow)
                .foregroundColor(.secondaryText)
        } else if account.accountType == .debt || account.accountType == .otherDebt, let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay
            )
            Text(display.amount.formatted(currency: display.currency))
                .font(.snapAmountRow)
                .foregroundColor(.lossRed)
        } else if account.accountType == .twdDeposit, let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay
            )
            Text(display.amount.formatted(currency: display.currency))
                .font(.snapAmountRow)
                .foregroundColor(.primaryText)
        } else if let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay
            )
            Text(display.amount.formatted(currency: display.currency))
                .font(.snapAmountRow)
                .foregroundColor(.primaryText)
        } else {
            Text("—")
                .font(.snapAmountRow)
                .foregroundColor(.secondaryText)
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
                            .font(.snapAmountRow)
                            .foregroundColor(.lossRed)
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
        HStack {
            Image(systemName: "creditcard.fill")
                .foregroundColor(.lossRed)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(liability.name)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Text("剩餘本金")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let negativeBalance = -liability.remainingBalance
                Text(negativeBalance.formatted(currency: liability.currency))
                    .font(.snapAmountRow)
                    .foregroundColor(.lossRed)
                
                Text(liability.currency.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lossRed)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
    }
}

#Preview {
    AccountsView(selectedTab: .constant(AppTab.accounts.rawValue))
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
}

