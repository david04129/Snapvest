//
//  TransactionsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct TransactionsView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = TransactionsViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingEditTransaction: Transaction?
    @State private var showingEditLiability = false
    @State private var editingLiability: Liability?
    @State private var showingEditIncome = false
    @State private var showingEditExpense = false
    @State private var showingEditTransfer = false
    @State private var showingEditRepayment = false
    @State private var editingIncomeTransaction: Transaction?
    @State private var editingExpenseTransaction: Transaction?
    @State private var editingTransferTransaction: Transaction?
    @State private var editingRepaymentTransaction: Transaction?
    @State private var editingAccount: Account?
    @State private var userId: String = "test-user-id"
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String? = nil
    @State private var transactionPendingDelete: Transaction?
    @State private var showingDeleteConfirmation = false
    @State private var buyTradeEditItem: BuyTradeEditItem?
    @State private var sellTradeEditItem: SellTradeEditItem?
    
    // 帳戶篩選（多選）
    @State private var selectedAccountIds: Set<String> = []
    @State private var showingAccountFilterSheet = false
    @State private var tempSelectedAccountIds: Set<String> = []
    
    // 時間篩選（開始／結束日期）
    @State private var isTimeFilterEnabled = false
    @State private var filterStartDate: Date = TransactionsView.defaultFilterStartDate
    @State private var filterEndDate: Date = TransactionsView.defaultFilterEndDate
    @State private var showingTimeFilterSheet = false
    @State private var tempFilterStartDate: Date = TransactionsView.defaultFilterStartDate
    @State private var tempFilterEndDate: Date = TransactionsView.defaultFilterEndDate
    
    // 篩選偏好持久化的 key
    private let filterPreferencesKey = "TransactionFilterPreferences"
    @State private var navigationStackResetID = UUID()
    private static var defaultFilterEndDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    private static var defaultFilterStartDate: Date {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .month, value: -1, to: end) ?? end
    }
    
    struct FilterPreferences: Codable {
        var selectedAccountIds: [String] = []
        var isTimeFilterEnabled: Bool = false
        var filterStartDate: Date?
        var filterEndDate: Date?
    }
    
    // MARK: - View Components
    
    private struct TransactionDayGroup: Identifiable {
        let day: Date
        let transactions: [Transaction]
        var id: Date { day }
    }
    
    private var transactionDayGroups: [TransactionDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.startOfDay(for: $0.transactionDate)
        }
        return grouped.keys.sorted(by: >).map { day in
            TransactionDayGroup(
                day: day,
                transactions: grouped[day]!.sorted { $0.transactionDate > $1.transactionDate }
            )
        }
    }
    
    private var hasActiveFilters: Bool {
        isTimeFilterEnabled || !selectedAccountIds.isEmpty
    }
    
    private var filterStatusText: String {
        if viewModel.isLoading { return "載入中…" }
        if !hasActiveFilters {
            return "共 \(filteredTransactions.count) 筆"
        }
        var parts: [String] = []
        if isTimeFilterEnabled { parts.append(timeFilterChipTitle) }
        if !selectedAccountIds.isEmpty { parts.append("已選 \(selectedAccountIds.count) 帳戶") }
        parts.append("共 \(filteredTransactions.count) 筆")
        return parts.joined(separator: " · ")
    }
    
    private var filterListRefreshToken: String {
        "\(isTimeFilterEnabled)_\(filterStartDate.timeIntervalSince1970)_\(filterEndDate.timeIntervalSince1970)_\(selectedAccountIds.hashValue)_\(filteredTransactions.count)"
    }
    
    private var timeFilterChipTitle: String {
        guard isTimeFilterEnabled else { return "選擇時間" }
        return "\(formatFilterDate(filterStartDate)) – \(formatFilterDate(filterEndDate))"
    }
    
    private func formatFilterDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
    
    private var accountFilterChipTitle: String {
        selectedAccountIds.isEmpty ? "選帳戶" : "已選 \(selectedAccountIds.count) 帳戶"
    }
    
    private func openTimeFilterSheet() {
        if isTimeFilterEnabled {
            tempFilterStartDate = filterStartDate
            tempFilterEndDate = filterEndDate
        } else {
            tempFilterStartDate = Self.defaultFilterStartDate
            tempFilterEndDate = Self.defaultFilterEndDate
        }
        showingTimeFilterSheet = true
    }
    
    private func openAccountFilterSheet() {
        tempSelectedAccountIds = selectedAccountIds
        showingAccountFilterSheet = true
    }
    
    private func applyTimeFilter() {
        var start = tempFilterStartDate
        var end = tempFilterEndDate
        if start > end {
            swap(&start, &end)
        }
        withAnimation(ChartMotion.switchSpring) {
            isTimeFilterEnabled = true
            filterStartDate = start
            filterEndDate = end
        }
        saveFilterPreferences()
        showingTimeFilterSheet = false
    }
    
    private func clearTimeFilter() {
        withAnimation(ChartMotion.switchSpring) {
            isTimeFilterEnabled = false
        }
        saveFilterPreferences()
        showingTimeFilterSheet = false
    }
    
    private func applyAccountFilter() {
        withAnimation(ChartMotion.switchSpring) {
            selectedAccountIds = tempSelectedAccountIds
        }
        saveFilterPreferences()
        showingAccountFilterSheet = false
    }
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: openTimeFilterSheet) {
                    FilterSheetChipLabel(
                        title: timeFilterChipTitle,
                        icon: "calendar",
                        isActive: isTimeFilterEnabled
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: openAccountFilterSheet) {
                    FilterSheetChipLabel(
                        title: accountFilterChipTitle,
                        icon: "building.columns",
                        isActive: !selectedAccountIds.isEmpty
                    )
                }
                .buttonStyle(.plain)
                
                if hasActiveFilters {
                    Button {
                        withAnimation(ChartMotion.switchSpring) {
                            clearAllFilters()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer(minLength: 0)
            }
            
            Text(filterStatusText)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.numericText())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(ChartMotion.switchSpring, value: filterListRefreshToken)
    }
    
    @ViewBuilder
    private var transactionsListSection: some View {
        if viewModel.isLoading {
            loadingView
        } else if filteredTransactions.isEmpty {
            emptyStateView
        } else {
            transactionsListView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入中...")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 50))
                .foregroundColor(.secondaryText)
            Text("尚無交易紀錄")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var transactionsListView: some View {
        List {
            ForEach(transactionDayGroups) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        transactionListRow(for: transaction)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    TransactionDateSectionHeader(
                        date: group.day,
                        count: group.transactions.count
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.mainBackground)
        .animation(ChartMotion.switchSpring, value: filterListRefreshToken)
        .refreshable {
            await viewModel.loadTransactions(userId: userId)
        }
    }
    
    @ViewBuilder
    private func transactionListRow(for transaction: Transaction) -> some View {
        let accountDisplay = getAccountDisplay(for: transaction)
        TransactionRowView(
            transaction: transaction,
            accountName: accountDisplay.name,
            accountIconName: accountDisplay.icon,
            accountColor: accountDisplay.color,
            onEdit: { transaction in
                handleEditTransaction(transaction)
            },
            onDelete: { transaction in
                transactionPendingDelete = transaction
                showingDeleteConfirmation = true
            }
        )
    }
    
    var filteredTransactions: [Transaction] {
        // 如果正在載入，返回空數組
        guard !viewModel.isLoading else {
            return []
        }
        
        // 確保 transactions 數組已初始化
        let allTransactions = viewModel.transactions
        
        // 優化：先進行最嚴格的篩選，減少後續篩選的數據量
        // 1. 先進行時間篩選（通常能過濾掉最多數據）
        var result = allTransactions
        
        // 計算日期範圍（只計算一次）
        let dateRange = calculateDateRange()
        if let range = dateRange {
            result = result.filter { transaction in
                transaction.transactionDate >= range.start && transaction.transactionDate <= range.end
            }
        }
        
        // 2. 帳戶篩選（如果有選擇帳戶）
        if !selectedAccountIds.isEmpty {
            result = result.filter { transaction in
                // 單一帳戶交易：使用 accountId 匹配
                // 轉帳/還款交易：使用 accountId 或 targetAccountId 任一匹配即顯示
                selectedAccountIds.contains(transaction.accountId) ||
                (transaction.targetAccountId != nil && selectedAccountIds.contains(transaction.targetAccountId!))
            }
        }
        
        return result
    }
    
    // 計算日期範圍（只計算一次，避免重複計算）
    private func calculateDateRange() -> (start: Date, end: Date)? {
        guard isTimeFilterEnabled else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: filterStartDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: filterEndDate) ?? filterEndDate
        return (startOfDay, endOfDay)
    }
    
    // 清除所有篩選
    private func clearAllFilters() {
        selectedAccountIds.removeAll()
        isTimeFilterEnabled = false
        filterStartDate = Self.defaultFilterStartDate
        filterEndDate = Self.defaultFilterEndDate
        saveFilterPreferences()
    }
    
    // 保存篩選偏好
    private func saveFilterPreferences() {
        let preferences = FilterPreferences(
            selectedAccountIds: Array(selectedAccountIds),
            isTimeFilterEnabled: isTimeFilterEnabled,
            filterStartDate: isTimeFilterEnabled ? filterStartDate : nil,
            filterEndDate: isTimeFilterEnabled ? filterEndDate : nil
        )
        
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: filterPreferencesKey)
        }
    }
    
    // 載入篩選偏好（優化：在主線程上執行，避免阻塞）
    private func loadFilterPreferences() {
        // 使用同步方式快速載入（UserDefaults 和 JSONDecoder 通常很快）
        guard let data = UserDefaults.standard.data(forKey: filterPreferencesKey),
              let preferences = try? JSONDecoder().decode(FilterPreferences.self, from: data) else {
            return
        }
        
        // 批量更新狀態，減少視圖重繪次數
        selectedAccountIds = Set(preferences.selectedAccountIds)
        isTimeFilterEnabled = preferences.isTimeFilterEnabled
        if let startDate = preferences.filterStartDate {
            filterStartDate = startDate
        }
        if let endDate = preferences.filterEndDate {
            filterEndDate = endDate
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection
                transactionsListSection
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBar(icon: "clock.fill", title: "所有紀錄")
            }
            .refreshable {
                await viewModel.loadTransactions(userId: userId)
            }
            .task {
                // 先載入篩選偏好（快速操作，不阻塞）
                loadFilterPreferences()
                // 然後載入交易數據
                await viewModel.loadTransactions(userId: userId)
            }
            .sheet(item: $showingEditTransaction) { transaction in
                editTransactionSheet(transaction: transaction)
            }
            .sheet(isPresented: $showingEditLiability) {
                editLiabilitySheet
            }
            .sheet(isPresented: $showingEditIncome) {
                editIncomeSheet
            }
            .sheet(isPresented: $showingEditExpense) {
                editExpenseSheet
            }
            .sheet(isPresented: $showingEditTransfer) {
                editTransferSheet
            }
            .sheet(isPresented: $showingEditRepayment) {
                editRepaymentSheet
            }
            .onChange(of: showingEditIncome) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditExpense) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditTransfer) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditRepayment) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditTransaction) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
            }
            .alert("無法刪除", isPresented: $showingDeleteError) {
                Button("確定", role: .cancel) {
                    deleteErrorMessage = nil
                }
            } message: {
                if let errorMessage = deleteErrorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showingTimeFilterSheet) {
                timeFilterSheet
            }
            .sheet(isPresented: $showingAccountFilterSheet) {
                accountFilterSheet
            }
            .sheet(item: $buyTradeEditItem) { item in
                editBuyTradeSheet(item: item)
            }
            .sheet(item: $sellTradeEditItem) { item in
                editSellTradeSheet(item: item)
            }
            .alert("刪除這筆紀錄？", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    transactionPendingDelete = nil
                }
                Button("刪除", role: .destructive) {
                    guard let transaction = transactionPendingDelete else { return }
                    transactionPendingDelete = nil
                    Task { await performDelete(transaction) }
                }
            } message: {
                if let transaction = transactionPendingDelete {
                    Text(transaction.deleteConfirmationMessage)
                }
            }
        }
        .id(navigationStackResetID)
        .resetNavigationWhenTabReappears(selectedTab: $selectedTab, resignedTab: .transactions) {
            dismissPresentedSheets()
            navigationStackResetID = UUID()
        }
    }
    
    private func dismissPresentedSheets() {
        showingEditTransaction = nil
        showingEditLiability = false
        showingEditIncome = false
        showingEditExpense = false
        showingEditTransfer = false
        showingEditRepayment = false
        showingTimeFilterSheet = false
        showingAccountFilterSheet = false
        buyTradeEditItem = nil
        sellTradeEditItem = nil
        transactionPendingDelete = nil
        showingDeleteConfirmation = false
        showingDeleteError = false
    }
    
    private func editBuyTradeSheet(item: BuyTradeEditItem) -> some View {
        NavigationStack {
            BuyTradeFormView(market: item.market, editingTransaction: item.transaction) {
                buyTradeEditItem = nil
                Task {
                    await viewModel.loadTransactions(userId: userId)
                    await portfolioViewModel.loadData(userId: userId)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        buyTradeEditItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }
    
    private func editSellTradeSheet(item: SellTradeEditItem) -> some View {
        NavigationStack {
            SellTradeFormView(market: item.market, editingTransaction: item.transaction) { _ in
                sellTradeEditItem = nil
                Task {
                    await viewModel.loadTransactions(userId: userId)
                    await portfolioViewModel.loadData(userId: userId)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        sellTradeEditItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }
    
    private func performDelete(_ transaction: Transaction) async {
        if transaction.type == .repayment ||
            (transaction.notes?.contains("還款") == true) {
            let (canDelete, errorMessage) = await viewModel.canDeleteRepaymentTransaction(transaction, userId: userId)
            if !canDelete, let error = errorMessage {
                await MainActor.run {
                    deleteErrorMessage = error
                    showingDeleteError = true
                }
                return
            }
        }
        await MainActor.run {
            viewModel.errorMessage = nil
            deleteErrorMessage = nil
        }
        await viewModel.deleteTransaction(transaction.id)
        await MainActor.run {
            if let error = viewModel.errorMessage {
                deleteErrorMessage = error
                showingDeleteError = true
                return
            }
        }
        if transaction.type == .liability {
            await accountsViewModel.loadAccounts(userId: userId)
        }
        await viewModel.loadTransactions(userId: userId)
        await portfolioViewModel.loadData(userId: userId)
    }
    
    // MARK: - 時間篩選 Sheet
    
    private var timeFilterSheet: some View {
        NavigationStack {
            ScrollView {
                customDateRangeEditor(
                    startDate: $tempFilterStartDate,
                    endDate: $tempFilterEndDate
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.secondaryBackground)
            .navigationTitle("選擇日期")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingTimeFilterSheet = false
                    }
                    .foregroundColor(.appPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("套用", action: applyTimeFilter)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("不限時間", action: clearTimeFilter)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - 帳戶篩選 Sheet
    
    private var accountFilterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.accounts.isEmpty {
                        CardView {
                            HStack {
                                Button {
                                    withAnimation(ChartMotion.switchSpring) {
                                        if tempSelectedAccountIds.count == viewModel.accounts.count {
                                            tempSelectedAccountIds.removeAll()
                                        } else {
                                            tempSelectedAccountIds = Set(viewModel.accounts.map(\.id))
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: tempSelectedAccountIds.count == viewModel.accounts.count ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.appPrimary)
                                        Text(tempSelectedAccountIds.count == viewModel.accounts.count ? "全不選" : "全選")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appPrimary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                if !tempSelectedAccountIds.isEmpty {
                                    Button {
                                        withAnimation(ChartMotion.switchSpring) {
                                            tempSelectedAccountIds.removeAll()
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                            Text("清除")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    if viewModel.accounts.isEmpty {
                        Text("尚無帳戶")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        ForEach(viewModel.accounts, id: \.id) { account in
                            let isSelected = tempSelectedAccountIds.contains(account.id)
                            Button {
                                withAnimation(ChartMotion.switchSpring) {
                                    if isSelected {
                                        tempSelectedAccountIds.remove(account.id)
                                    } else {
                                        tempSelectedAccountIds.insert(account.id)
                                    }
                                }
                            } label: {
                                FilterSelectableRow(
                                    title: account.name,
                                    subtitle: account.accountType.displayName,
                                    icon: account.accountType.icon,
                                    accentColor: account.accountType.color,
                                    isSelected: isSelected
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.secondaryBackground)
            .navigationTitle("選擇帳戶")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingAccountFilterSheet = false
                    }
                    .foregroundColor(.appPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("套用", action: applyAccountFilter)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func customDateRangeEditor(startDate: Binding<Date>, endDate: Binding<Date>) -> some View {
        VStack(spacing: 12) {
            customDatePickerCard(label: "開始日期", date: startDate)
            customDatePickerCard(label: "結束日期", date: endDate)
        }
    }
    
    private func customDatePickerCard(label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            DatePicker("", selection: date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.appPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.separator.opacity(0.35), lineWidth: 1)
        }
    }
    
    // MARK: - 自定義標題欄
    private func customHeaderBar(icon: String, title: String) -> some View {
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
            
            // 右側：使用者頭像
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
    
    // MARK: - Sheet Views
    
    @ViewBuilder
    private func editTransactionSheet(transaction: Transaction) -> some View {
        EditTransactionView(
            transaction: transaction,
            viewModel: viewModel,
            onEditLiability: { liability in
                editingLiability = liability
                showingEditLiability = true
            }
        )
        .onDisappear {
            Task {
                await viewModel.loadTransactions(userId: userId)
            }
        }
    }
    
    @ViewBuilder
    private var editLiabilitySheet: some View {
        if let liability = editingLiability {
            AddLiabilityView(portfolioViewModel: portfolioViewModel, userId: userId, editingLiability: liability)
        }
    }
    
    @ViewBuilder
    private var editIncomeSheet: some View {
        if let account = editingAccount, let transaction = editingIncomeTransaction {
            IncomeView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editExpenseSheet: some View {
        if let account = editingAccount, let transaction = editingExpenseTransaction {
            ExpenseView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editTransferSheet: some View {
        if let account = editingAccount, let transaction = editingTransferTransaction {
            TransferView(account: account, viewModel: editingAccountViewModel, editingTransaction: transaction)
                .onAppear {
                    Task {
                        await editingAccountViewModel.loadAccountData(accountId: account.id)
                    }
                }
                .onDisappear {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var editRepaymentSheet: some View {
        if let transaction = editingRepaymentTransaction {
            RepaymentEditWrapperView(
                transaction: transaction,
                viewModel: viewModel,
                portfolioViewModel: portfolioViewModel,
                userId: userId,
                onDismiss: {
                    Task {
                        await viewModel.loadTransactions(userId: userId)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleEditSheetChange(oldValue: Bool, newValue: Bool) {
        if oldValue == true && newValue == false {
            Task {
                await viewModel.loadTransactions(userId: userId)
            }
        }
    }
    
    private func handleEditTransaction(_ transaction: Transaction) {
        // 還款和債務交易不能編輯，只能刪除
        if transaction.type == .repayment || transaction.type == .liability {
            return
        }
        
        // 獲取帳戶資訊
        guard let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) else {
            return
        }
        
        editingAccount = account
        
        // 檢查是否為轉帳交易（使用新的類型）
        if transaction.type == .transfer {
            // 轉帳交易：直接編輯
            editingTransferTransaction = transaction
            showingEditTransfer = true
            return
        }
        
        // 舊的轉帳/還款交易格式（兼容舊數據）
        let isRepayment = (transaction.notes?.contains("還款至") ?? false) || 
                         (transaction.notes?.contains("還款自") ?? false)
        let isTransfer = (transaction.notes?.contains("轉帳至") ?? false) || 
                        (transaction.notes?.contains("轉帳自") ?? false)
        
        // 還款和轉帳使用相同的編輯邏輯
        if isTransfer || isRepayment {
            // 轉帳或還款交易：如果是轉入交易（deposit），需要找到對應的轉出交易
            if transaction.type == .deposit && (transaction.notes?.contains("轉帳自") == true || transaction.notes?.contains("還款自") == true) {
                // 這是轉入交易，需要找到對應的轉出交易來編輯
                // 解析轉出帳戶名稱
                if let notes = transaction.notes {
                    let accountName = extractAccountNameFromTransferNotes(notes, isFrom: false)
                    if let sourceAccount = viewModel.accounts.first(where: { $0.name == accountName }) {
                        // 找到對應的轉出交易
                        let isRepaymentNote = transaction.notes?.contains("還款自") ?? false
                        if let fromTransaction = viewModel.transactions.first(where: { trans in
                            trans.accountId == sourceAccount.id &&
                            trans.type == .withdraw &&
                            abs(trans.transactionDate.timeIntervalSince(transaction.transactionDate)) < 1.0 &&
                            (isRepaymentNote ? (trans.notes?.contains("還款至") ?? false) : (trans.notes?.contains("轉帳至") ?? false))
                        }) {
                            editingAccount = sourceAccount
                            if isRepaymentNote {
                                editingTransferTransaction = fromTransaction // 還款也用轉帳的編輯
                                showingEditTransfer = true
                            } else {
                                editingTransferTransaction = fromTransaction
                                showingEditTransfer = true
                            }
                            return
                        }
                    }
                }
            } else {
                // 轉出交易（withdraw），直接使用（轉帳和還款都用這個）
                editingTransferTransaction = transaction
                showingEditTransfer = true
            }
        } else if transaction.type == .deposit {
            // 收入交易
            editingIncomeTransaction = transaction
            showingEditIncome = true
        } else if transaction.type == .withdraw {
            // 支出交易
            editingExpenseTransaction = transaction
            showingEditExpense = true
        } else if transaction.type == .buy || transaction.type == .sell {
            guard let market = TradeMarket(assetType: transaction.assetType) else {
                showingEditTransaction = transaction
                return
            }
            if transaction.type == .buy {
                buyTradeEditItem = BuyTradeEditItem(transaction: transaction, market: market)
            } else {
                sellTradeEditItem = SellTradeEditItem(transaction: transaction, market: market)
            }
        } else {
            // 股利、手續費等暫用通用編輯
            showingEditTransaction = transaction
        }
    }
    
    /// 從轉帳交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromTransferNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "轉帳至 " : "轉帳自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取後面的部分
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[dashRange.upperBound...])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    /// 從還款交易的 notes 中提取帳戶名稱
    private func extractAccountNameFromRepaymentNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "還款至 " : "還款自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱在備註之前）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
    
    private func refreshAllData() async {
        // 使用 Task 確保異步操作不會阻塞
        await portfolioViewModel.loadData(userId: userId)
        await accountsViewModel.loadAccounts(userId: userId)
        // 重新載入交易以確保數據一致性
        await viewModel.loadTransactions(userId: userId)
    }
    
    private func getAccountDisplay(for transaction: Transaction) -> (name: String, icon: String, color: Color) {
        // 確保 accounts 已載入
        if viewModel.accounts.isEmpty {
            return (name: "未知帳戶", icon: "questionmark.circle", color: .secondaryText)
        }
        
        // 如果是轉帳或還款交易，顯示「A到B」格式
        if transaction.type == .transfer || transaction.type == .repayment {
            // 優先使用 targetAccountId 直接從帳戶列表中查找（不使用字符串解析）
            if let sourceAccount = viewModel.accounts.first(where: { $0.id == transaction.accountId }),
               let targetAccountId = transaction.targetAccountId,
               let targetAccount = viewModel.accounts.first(where: { $0.id == targetAccountId }) {
                return (
                    name: "\(sourceAccount.name)到\(targetAccount.name)",
                    icon: sourceAccount.accountType.icon,
                    color: sourceAccount.accountType.color
                )
            }
            
            // 如果無法獲取，返回預設值
            if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
                return (name: account.name, icon: account.accountType.icon, color: account.accountType.color)
            }
            return (name: "未知帳戶", icon: "questionmark.circle", color: .secondaryText)
        }
        
        // 非轉帳/還款交易，返回帳戶名稱
        if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
            return (name: account.name, icon: account.accountType.icon, color: account.accountType.color)
        }
        return (name: "未知帳戶", icon: "questionmark.circle", color: .secondaryText)
    }
}

// MARK: - 日期區段標題

private struct TransactionDateSectionHeader: View {
    let date: Date
    let count: Int
    
    private static let headerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
    
    var body: some View {
        HStack {
            Text(Self.headerFormatter.string(from: date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            Text("· \(count) 筆")
                .font(.caption)
                .foregroundColor(.secondaryText)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

// MARK: - 篩選 Sheet 可選列

private struct FilterSelectableRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var accentColor: Color = .appPrimary
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 22)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? accentColor.opacity(0.1) : Color.cardBackground)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentColor)
                .frame(width: isSelected ? 4 : 0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? accentColor.opacity(0.45) : Color.separator.opacity(0.35),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .animation(ChartMotion.switchSpring, value: isSelected)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let accountName: String
    let accountIconName: String
    let accountColor: Color
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    
    private var accentColor: Color {
        typeColor(for: transaction.type)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(primaryTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                Text(detailSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transactionAmount)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onDelete(transaction)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("刪除")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppColors.actionForeground)
                .frame(width: 70, height: 70)
                .background(AppColors.actionDestructiveBackground)
                .cornerRadius(0)
            }
            .tint(AppColors.actionDestructiveBackground)
            
            // 還款和債務交易只能刪除，不能編輯
            if transaction.type != .repayment && transaction.type != .liability {
                Button {
                    onEdit(transaction)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                        Text("編輯")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(width: 70, height: 70)
                    .background(AppColors.actionEditBackground)
                    .cornerRadius(0)
                }
                .tint(AppColors.actionEditBackground)
            }
        }
    }
    
    private var primaryTitle: String {
        switch transaction.type {
        case .buy:
            return "買入 \(tradeTitleSuffix)"
        case .sell:
            return "賣出 \(tradeTitleSuffix)"
        case .transfer:
            return "轉帳"
        case .repayment:
            return "還款"
        case .deposit:
            return "收入"
        case .withdraw:
            return "支出"
        case .dividend:
            return "股利"
        case .fee:
            return "手續費"
        case .liability:
            return "債務"
        }
    }
    
    private var tradeTitleSuffix: String {
        let name = tradeDisplayName
        if transaction.assetType == .stockTW, name != transaction.symbol {
            return "\(name) \(transaction.symbol)"
        }
        return name
    }
    
    private var detailSubtitle: String {
        var parts: [String] = [accountName]
        if let tradeLine = tradeDetailLine {
            parts.append(tradeLine)
        }
        if let note = userNotePreview {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }
    
    private var tradeDetailLine: String? {
        guard transaction.type == .buy || transaction.type == .sell else { return nil }
        let qty = formatQuantity(transaction.quantity)
        let price = transaction.price.formatted(currency: transaction.currency, fractionDigits: 2)
        return "\(qty) 股 @ \(price)"
    }
    
    private var userNotePreview: String? {
        guard let raw = transaction.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if transaction.type == .buy || transaction.type == .sell {
            if raw.contains("自訂備註：") {
                return raw.components(separatedBy: "自訂備註：").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if raw.hasPrefix("買入") || raw.hasPrefix("賣出") { return nil }
        }
        return raw
    }
    
    private var amountColor: Color {
        if transaction.type == .repayment { return .lossRed }
        return typeColor(for: transaction.type)
    }
    
    private var transactionAmount: String {
        // 安全地計算金額
        let amount = transaction.totalAmountWithFee
        let absAmount = abs(amount)
        let sign: String
        
        switch transaction.type {
        case .liability:
            // 債務總是顯示為負數
            sign = "-"
        case .deposit, .dividend:
            sign = "+"
        case .sell:
            sign = amount > 0 ? "+" : "-"
        case .transfer:
            // 轉帳：不顯示負號，因為對用戶來說沒有損失
            sign = ""
        case .repayment:
            // 還款：顯示負號
            sign = "-"
        default:
            sign = "-"
        }
        
        // 安全地格式化金額
        let formattedAmount = absAmount.formatted(currency: transaction.currency)
        // 如果 sign 為空，直接返回金額，否則返回帶符號的金額
        return sign.isEmpty ? formattedAmount : "\(sign) \(formattedAmount)"
    }
    
    private func isTransferTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為轉帳類型
        return transaction.type == .transfer
    }
    
    private func isRepaymentTransaction(_ transaction: Transaction) -> Bool {
        // 檢查是否為還款類型
        return transaction.type == .repayment
    }

    private var expandedNotes: String? {
        let userNote = transaction.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUserNote = !(userNote?.isEmpty ?? true)
        
        if transaction.type == .buy || transaction.type == .sell {
            let action = transaction.type == .buy ? "買入" : "賣出"
            let name = tradeDisplayName
            let quantityText = formatQuantity(transaction.quantity)
            let priceText = transaction.price.formatted(currency: transaction.currency)
            let autoNote = "\(action)\(quantityText)股\(name)，股價\(priceText)"
            
            if hasUserNote {
                return "\(autoNote)\n自訂備註：\(userNote!)"
            }
            return autoNote
        }
        
        if hasUserNote {
            return userNote
        }
        return nil
    }
    
    private var tradeDisplayName: String {
        if transaction.assetType == .stockTW {
            return twStockNameMap[transaction.symbol] ?? transaction.symbol
        }
        return transaction.symbol
    }
    
    private func formatQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = true
        return formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
    }
    
    private var twStockNameMap: [String: String] {
        [
            "2330": "台積電",
            "2317": "鴻海",
            "2454": "聯發科",
            "2308": "台達電",
            "2891": "中信金",
            "2882": "國泰金",
            "2886": "兆豐金",
            "1301": "台塑",
            "1303": "南亞",
            "2002": "中鋼",
            "2412": "中華電",
            "2382": "廣達",
            "2379": "瑞昱",
            "3008": "大立光",
            "2884": "玉山金"
        ]
    }
    
    private func typeColor(for type: TransactionType) -> Color {
        // 統一的顏色邏輯，與 TransactionHistoryView 保持一致
        switch type {
        case .transfer:
            return .appPrimary
        case .repayment:
            return .lossRed
        case .buy:
            return .lossRed  // 買入：紅色（支出）
        case .sell:
            return .profitGreen  // 賣出：綠色（收入）
        case .deposit, .dividend:
            return .profitGreen  // 收入、股利：綠色（收入）
        case .withdraw, .fee, .liability:
            return .lossRed  // 支出、手續費、債務：紅色（支出）
        }
    }
}

// MARK: - 還款編輯包裝視圖
struct RepaymentEditWrapperView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: TransactionsViewModel
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    let userId: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var liability: Liability?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中...")
            } else if let liability = liability {
                RepaymentView(liability: liability, editingTransaction: transaction)
                    .onDisappear {
                        onDismiss()
                    }
            } else {
                Text("無法找到對應的債務")
                    .foregroundColor(.secondaryText)
            }
        }
        .task {
            await loadLiability()
        }
    }
    
    private func loadLiability() async {
        // 從交易 notes 中提取債務帳戶名稱（參考轉帳的邏輯）
        guard let notes = transaction.notes else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        var debtAccountName: String?
        
        if notes.contains("還款至 ") {
            // 轉出交易：直接從 notes 中提取債務帳戶名稱
            debtAccountName = extractAccountNameFromRepaymentNotes(notes, isFrom: true)
        } else if notes.contains("還款自 ") {
            // 轉入交易：當前交易的帳戶就是債務帳戶
            if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId && $0.accountType == .debt }) {
                debtAccountName = account.name
            } else {
                // 如果當前帳戶不是債務帳戶，從轉出交易中提取
                let sourceAccountName = extractAccountNameFromRepaymentNotes(notes, isFrom: false)
                if let sourceAccount = viewModel.accounts.first(where: { $0.name == sourceAccountName }) {
                    do {
                        let allTransactions = try await MockDataService.shared.fetchAllTransactions(userId: userId)
                        if let fromTransaction = allTransactions.first(where: { trans in
                            trans.accountId == sourceAccount.id &&
                            trans.type == .withdraw &&
                            abs(trans.transactionDate.timeIntervalSince(transaction.transactionDate)) < 1.0 &&
                            (trans.notes?.contains("還款至") ?? false)
                        }) {
                            debtAccountName = extractAccountNameFromRepaymentNotes(fromTransaction.notes ?? "", isFrom: true)
                        }
                    } catch {
                        await MainActor.run {
                            isLoading = false
                        }
                        return
                    }
                }
            }
        }
        
        guard let debtAccountName = debtAccountName,
              let debtAccount = viewModel.accounts.first(where: { $0.name == debtAccountName && $0.accountType == .debt }) else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // 找到對應的債務記錄
        do {
            let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: debtAccount.id)
            await MainActor.run {
                liability = liabilities.first(where: { $0.name == debtAccountName })
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func extractAccountNameFromRepaymentNotes(_ notes: String, isFrom: Bool) -> String {
        let prefix = isFrom ? "還款至 " : "還款自 "
        
        if let range = notes.range(of: prefix) {
            var accountName = String(notes[range.upperBound...])
            
            // 移除 " (匯率: ...)" 部分
            if let rateRange = accountName.range(of: " (匯率:") {
                accountName = String(accountName[..<rateRange.lowerBound])
            }
            
            // 如果有 " - " 分隔符，取前面的部分（帳戶名稱在備註之前）
            if let dashRange = accountName.range(of: " - ") {
                accountName = String(accountName[..<dashRange.lowerBound])
            }
            
            return accountName.trimmingCharacters(in: .whitespaces)
        }
        
        return ""
    }
}

// MARK: - 買賣編輯 Sheet 資料（item 驅動，避免首次彈出空白）

struct BuyTradeEditItem: Identifiable {
    let transaction: Transaction
    let market: TradeMarket
    var id: String { transaction.id }
}

struct SellTradeEditItem: Identifiable {
    let transaction: Transaction
    let market: TradeMarket
    var id: String { transaction.id }
}

// MARK: - 篩選 Sheet 觸發 chip（與 AssetsFilterChipButton 同款 + chevron）

private struct FilterSheetChipLabel: View {
    let title: String
    var icon: String? = nil
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(isActive ? .appPrimary : .secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.appPrimary.opacity(0.12) : Color.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.appPrimary.opacity(0.35) : Color.separator.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    TransactionsView(selectedTab: .constant(AppTab.transactions.rawValue))
}

