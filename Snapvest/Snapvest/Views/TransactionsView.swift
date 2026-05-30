//
//  TransactionsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct TransactionsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @Environment(\.openSettings) private var openSettings
    @StateObject private var viewModel = TransactionsViewModel()
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
    @State private var userId: String = AppUser.id
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
    @State private var timePreset: DateRangePreset = .all
    @State private var filterStartDate: Date = TransactionsView.defaultFilterStartDate
    @State private var filterEndDate: Date = TransactionsView.defaultFilterEndDate
    @State private var activeTimeFilterDateField: CustomDatePickerField?
    
    private static let legacyFilterPreferencesKey = "TransactionFilterPreferences"
    private static var sessionFilterPreferences: FilterPreferences?
    @State private var navigationStackResetID = UUID()
    private static var defaultFilterEndDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    private static var defaultFilterStartDate: Date {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -6, to: end) ?? end
    }
    private static var filterEarliestDate: Date {
        Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? .distantPast
    }
    
    struct FilterPreferences: Codable {
        var selectedAccountIds: [String] = []
        var timePreset: String?
        var filterStartDate: Date?
        var filterEndDate: Date?
        // 舊版相容
        var isTimeFilterEnabled: Bool?
    }
    
    private var isTimeFilterEnabled: Bool {
        timePreset != .all
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
        if isTimeFilterEnabled { parts.append(timeFilterStatusLabel) }
        if !selectedAccountIds.isEmpty { parts.append("已選 \(selectedAccountIds.count) 帳戶") }
        parts.append("共 \(filteredTransactions.count) 筆")
        return parts.joined(separator: " · ")
    }
    
    private var filterListRefreshToken: String {
        "\(timePreset.rawValue)_\(filterStartDate.timeIntervalSince1970)_\(filterEndDate.timeIntervalSince1970)_\(selectedAccountIds.hashValue)_\(filteredTransactions.count)"
    }
    
    private var timeFilterStatusLabel: String {
        switch timePreset {
        case .all:
            return "全部時間"
        case .custom:
            return "\(formatFilterDate(filterStartDate)) – \(formatFilterDate(filterEndDate))"
        default:
            return timePreset.rawValue
        }
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
    
    private func openAccountFilterSheet() {
        tempSelectedAccountIds = selectedAccountIds
        showingAccountFilterSheet = true
    }
    
    private func applyTimePreset(_ preset: DateRangePreset) {
        guard preset != .all else {
            saveFilterPreferences()
            return
        }
        guard preset != .custom else {
            saveFilterPreferences()
            return
        }
        let range = DateRangePresetCalculator.dateRange(
            for: preset,
            customStart: filterStartDate,
            customEnd: filterEndDate
        )
        filterStartDate = range.start
        filterEndDate = range.end
        saveFilterPreferences()
    }
    
    private func normalizeCustomDateRange() {
        if filterStartDate > filterEndDate {
            swap(&filterStartDate, &filterEndDate)
        }
        saveFilterPreferences()
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
            DateRangePresetPicker(selection: $timePreset)
                .onChange(of: timePreset) { _, preset in
                    withAnimation(ChartMotion.switchSpring) {
                        applyTimePreset(preset)
                    }
                }
            
            if timePreset == .custom {
                CustomDateRangeBar(
                    startDate: filterStartDate,
                    endDate: filterEndDate,
                    onStartTapped: { activeTimeFilterDateField = .start },
                    onEndTapped: { activeTimeFilterDateField = .end }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            HStack(spacing: 8) {
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
        .animation(ChartMotion.switchSpring, value: timePreset == .custom)
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
                selectedAccountIds.contains(transaction.accountId)
            }
        }
        
        return result
    }
    
    // 計算日期範圍（只計算一次，避免重複計算）
    private func calculateDateRange() -> (start: Date, end: Date)? {
        guard timePreset != .all else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: filterStartDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: filterEndDate) ?? filterEndDate
        return (startOfDay, endOfDay)
    }
    
    // 清除所有篩選
    private func clearAllFilters() {
        selectedAccountIds.removeAll()
        timePreset = .all
        filterStartDate = Self.defaultFilterStartDate
        filterEndDate = Self.defaultFilterEndDate
        saveFilterPreferences()
    }
    
    // 保存篩選偏好：只保存在本次 App session，完全關閉 App 後回到預設。
    private func saveFilterPreferences() {
        Self.sessionFilterPreferences = FilterPreferences(
            selectedAccountIds: Array(selectedAccountIds),
            timePreset: timePreset.rawValue,
            filterStartDate: timePreset == .all ? nil : filterStartDate,
            filterEndDate: timePreset == .all ? nil : filterEndDate,
            isTimeFilterEnabled: timePreset != .all
        )
    }
    
    // 載入本次 App session 的篩選偏好；舊版 UserDefaults 篩選會被清除。
    private func loadFilterPreferences() {
        UserDefaults.standard.removeObject(forKey: Self.legacyFilterPreferencesKey)
        guard let preferences = Self.sessionFilterPreferences else {
            return
        }

        // 批量更新狀態，減少視圖重繪次數
        selectedAccountIds = Set(preferences.selectedAccountIds)
        if let startDate = preferences.filterStartDate {
            filterStartDate = startDate
        }
        if let endDate = preferences.filterEndDate {
            filterEndDate = endDate
        }
        if let presetRaw = preferences.timePreset,
           let preset = DateRangePreset(rawValue: presetRaw) {
            timePreset = preset
        } else if preferences.isTimeFilterEnabled == true {
            timePreset = DateRangePresetCalculator.matchingPreset(
                start: filterStartDate,
                end: filterEndDate
            ) ?? .custom
        } else {
            timePreset = .all
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
            .safeAreaInset(edge: .bottom) {
                DataFreshnessFooterView(style: .transactions)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.mainBackground)
            }
            .refreshable {
                await viewModel.loadTransactions(userId: userId)
            }
            .task {
                loadFilterPreferences()
                await viewModel.loadTransactions(userId: userId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: accountsViewModel,
                        assetsViewModel: assetsViewModel,
                        rebuildAccountDetailCache: false
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                Task {
                    await viewModel.loadTransactions(userId: userId)
                }
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
            .sheet(isPresented: $showingEditRepayment) {
                editRepaymentSheet
            }
            .onChange(of: showingEditIncome) { oldValue, newValue in
                handleEditSheetChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: showingEditExpense) { oldValue, newValue in
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
            .sheet(item: $activeTimeFilterDateField) { field in
                WheelDatePickerSheet(
                    title: field.title,
                    selection: field == .start ? $filterStartDate : $filterEndDate,
                    earliestDate: Self.filterEarliestDate,
                    onDone: {
                        normalizeCustomDateRange()
                        activeTimeFilterDateField = nil
                    }
                )
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
        showingEditRepayment = false
        showingAccountFilterSheet = false
        activeTimeFilterDateField = nil
        buyTradeEditItem = nil
        sellTradeEditItem = nil
        transactionPendingDelete = nil
        showingDeleteConfirmation = false
        showingDeleteError = false
    }
    
    private func editBuyTradeSheet(item: BuyTradeEditItem) -> some View {
        NavigationStack {
            BuyTradeFormView(market: item.market, editingTransaction: item.transaction, onSubmit: {
                buyTradeEditItem = nil
                Task {
                    await viewModel.loadTransactions(userId: userId)
                }
            })
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
        .snapFormSheetChrome()
        .background(Color.mainBackground)
        .presentationBackground(Color.mainBackground)
    }
    
    private func editSellTradeSheet(item: SellTradeEditItem) -> some View {
        NavigationStack {
            SellTradeFormView(market: item.market, editingTransaction: item.transaction, onSubmit: { _ in
                sellTradeEditItem = nil
                Task {
                    await viewModel.loadTransactions(userId: userId)
                }
            })
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
        .snapFormSheetChrome()
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
        await viewModel.loadTransactions(userId: userId)
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
            
            AppHeaderMoreButton(action: openSettings)
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
            AddLiabilityView(userId: userId, editingLiability: liability)
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
        if transaction.type == .liability {
            return
        }
        
        guard let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) else {
            return
        }
        
        editingAccount = account
        
        if transaction.type == .repayment,
           account.accountType == .debt {
            editingRepaymentTransaction = transaction
            showingEditRepayment = true
            return
        }
        
        if transaction.type == .withdraw,
           transaction.notes?.contains("還款扣款：") == true {
            editingExpenseTransaction = transaction
            showingEditExpense = true
            return
        }
        
        if transaction.type == .deposit {
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
    
    private func getAccountDisplay(for transaction: Transaction) -> (name: String, icon: String, color: Color) {
        // 確保 accounts 已載入
        if viewModel.accounts.isEmpty {
            return (name: "未知帳戶", icon: "questionmark.circle", color: .secondaryText)
        }
        
        if transaction.type == .repayment,
           let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
            return (name: account.name, icon: account.accountType.icon, color: account.accountType.color)
        }
        
        if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
            return (name: account.name, icon: account.accountType.icon, color: account.accountType.color)
        }
        return (name: "未知帳戶", icon: "questionmark.circle", color: .secondaryText)
    }
}

// MARK: - 日期區段標題

struct TransactionDateSectionHeader: View {
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
    
    @State private var isExpanded = false
    
    private var display: TransactionDisplayFormatter {
        TransactionDisplayFormatter(transaction: transaction)
    }
    
    private var accentColor: Color {
        display.typeAccentColor
    }
    
    var body: some View {
        Group {
            if display.shouldShowExpandedDetail, let detail = display.expandedNotes {
                cardContent {
                    Button {
                        withAnimation(ChartMotion.switchSpring) {
                            isExpanded.toggle()
                        }
                    } label: {
                        rowHeader(showsChevron: true, isExpandable: true)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        detailSection(detail)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } else {
                cardContent {
                    rowHeader(showsChevron: true, isExpandable: false)
                }
            }
        }
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
    
    @ViewBuilder
    private func cardContent<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }
    
    private func rowHeader(showsChevron: Bool = false, isExpandable: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                CurrencyTitleLabel(
                    title: display.primaryTitle,
                    currency: transaction.currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: .primaryText,
                    chipTint: display.typeAccentColor
                )
                
                Text(display.detailSubtitle(accountName: accountName))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 4) {
                CurrencyAmountLabel(
                    text: transactionAmount,
                    currency: transaction.currency,
                    font: .system(size: 17, weight: .bold),
                    weight: .bold,
                    color: amountColor,
                    chipTint: display.typeAccentColor
                )
                
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            if showsChevron {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isExpandable ? .secondaryText : .secondaryText.opacity(0.38))
                    .frame(width: 16)
            }
        }
        .contentShape(Rectangle())
    }
    
    private func detailSection(_ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("明細")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
            Text(detail)
                .font(.caption)
                .foregroundColor(.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var amountColor: Color {
        if transaction.type == .repayment { return .lossRed }
        return display.typeAccentColor
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
        case .repayment:
            // 還款：顯示負號
            sign = "-"
        default:
            sign = "-"
        }
        
        // 安全地格式化金額
        let formattedAmount = absAmount.formatted(currency: transaction.currency, showSymbol: false)
        // 如果 sign 為空，直接返回金額，否則返回帶符號的金額
        return sign.isEmpty ? formattedAmount : "\(sign) \(formattedAmount)"
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
        guard let debtAccount = viewModel.accounts.first(where: {
            $0.id == transaction.accountId && ($0.accountType == .debt || $0.accountType == .otherDebt)
        }) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        if debtAccount.accountType == .otherDebt {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let liabilities = try await MockDataService.shared.fetchLiabilities(accountId: debtAccount.id)
            await MainActor.run {
                liability = liabilities.first(where: { $0.name == debtAccount.name }) ?? liabilities.first
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
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
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    TransactionsView(selectedTab: .constant(AppTab.transactions.rawValue))
        .environmentObject(PortfolioViewModel())
        .environmentObject(AccountsViewModel())
        .environmentObject(AssetsViewModel())
}

