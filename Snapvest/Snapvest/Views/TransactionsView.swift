//
//  TransactionsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct TransactionsView: View {
    @StateObject private var viewModel = TransactionsViewModel()
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingAddTransaction = false
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
    @State private var selectedFilter: FilterOption = .all
    @StateObject private var editingAccountViewModel = AccountDetailViewModel()
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String? = nil
    
    // 帳戶篩選（多選）
    @State private var selectedAccountIds: Set<String> = []
    @State private var showingAccountPicker = false
    
    // 時間篩選
    @State private var selectedTimeRange: TimeRangeFilter = .all
    @State private var customStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingDatePicker = false
    
    // 篩選偏好持久化的 key
    private let filterPreferencesKey = "TransactionFilterPreferences"
    
    enum FilterOption: String, CaseIterable {
        case all = "全部"
        case stock = "股票交易"
        case cashFlow = "現金流"
    }
    
    enum TimeRangeFilter: String, CaseIterable, Codable {
        case all = "全部時間"
        case today = "今天"
        case thisWeek = "本週"
        case thisMonth = "本月"
        case thisQuarter = "本季度"
        case thisYear = "今年"
        case custom = "自訂"
        
        var dateRange: (start: Date, end: Date)? {
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            
            switch self {
            case .all:
                return nil
            case .today:
                return (startOfDay, endOfDay)
            case .thisWeek:
                let weekday = calendar.component(.weekday, from: now)
                let daysFromMonday = (weekday + 5) % 7  // 週一是 0
                let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
                return (startOfWeek, endOfDay)
            case .thisMonth:
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startOfDay
                return (startOfMonth, endOfDay)
            case .thisQuarter:
                let quarter = (calendar.component(.month, from: now) - 1) / 3
                let startOfQuarter = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: quarter * 3 + 1, day: 1)) ?? startOfDay
                return (startOfQuarter, endOfDay)
            case .thisYear:
                let startOfYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1)) ?? startOfDay
                return (startOfYear, endOfDay)
            case .custom:
                return nil  // 自訂日期範圍需要單獨處理
            }
        }
    }
    
    struct FilterPreferences: Codable {
        var selectedAccountIds: [String] = []
        var selectedTimeRange: TimeRangeFilter = .all
        var customStartDate: Date?
        var customEndDate: Date?
    }
    
    // MARK: - View Components
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("篩選條件")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // 類型篩選（現有）
            Picker("篩選", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // 帳戶和時間篩選按鈕
            HStack(spacing: 12) {
                // 帳戶篩選按鈕
                Button(action: {
                    showingAccountPicker = true
                }) {
                    HStack {
                        Text("帳戶:")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        if selectedAccountIds.isEmpty {
                            Text("所有帳戶")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primaryText)
                        } else {
                            Text("已選 \(selectedAccountIds.count) 個帳戶")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                }
                
                // 時間篩選按鈕
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack {
                        Text("時間:")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Text(selectedTimeRange.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                }
                
                // 清除所有篩選按鈕
                if !selectedAccountIds.isEmpty || selectedTimeRange != .all {
                    Button(action: {
                        clearAllFilters()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.secondaryBackground)
    }
    
    private var filterTitleSection: some View {
        HStack {
            if !viewModel.isLoading {
                Text("\(selectedFilter.rawValue) - 共 \(filteredTransactions.count) 筆")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            } else {
                Text("載入中...")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.cardBackground)
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
            ForEach(filteredTransactions, id: \.id) { transaction in
                TransactionRowView(
                    transaction: transaction,
                    accountName: getAccountName(for: transaction),
                    onEdit: { transaction in
                        handleEditTransaction(transaction)
                    },
                    onDelete: { transaction in
                        Task {
                            // 如果是還款交易，先驗證是否為最新紀錄
                            if transaction.type == .repayment || 
                               (transaction.notes?.contains("還款") == true) {
                                let (canDelete, errorMessage) = await viewModel.canDeleteRepaymentTransaction(transaction, userId: userId)
                                
                                if !canDelete, let error = errorMessage {
                                    // 驗證失敗，顯示錯誤訊息，不執行刪除
                                    await MainActor.run {
                                        deleteErrorMessage = error
                                        showingDeleteError = true
                                    }
                                    return
                                }
                            }
                            
                            // 清除之前的錯誤訊息
                            await MainActor.run {
                                viewModel.errorMessage = nil
                                deleteErrorMessage = nil
                            }
                            
                            // 執行刪除
                            await viewModel.deleteTransaction(transaction.id)
                            
                            // 再次檢查是否有錯誤訊息（防止其他錯誤）
                            await MainActor.run {
                                if let error = viewModel.errorMessage {
                                    deleteErrorMessage = error
                                    showingDeleteError = true
                                    return
                                }
                            }
                            
                            // 如果沒有錯誤，繼續刪除流程
                            // 如果是債務交易，重新載入帳戶列表（因為刪除了債務帳戶）
                            if transaction.type == .liability {
                                await accountsViewModel.loadAccounts(userId: userId)
                            }
                            await viewModel.loadTransactions(userId: userId)
                            await portfolioViewModel.loadData(userId: userId)
                        }
                    }
                )
            }
            .onDelete(perform: deleteTransactions)
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadTransactions(userId: userId)
        }
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
        
        // 3. 類型篩選（最後進行，因為類型檢查最快）
        switch selectedFilter {
        case .all:
            break
        case .stock:
            result = result.filter { transaction in
                transaction.type == .buy || transaction.type == .sell
            }
        case .cashFlow:
            result = result.filter { transaction in
                transaction.type == .deposit || 
                transaction.type == .withdraw || 
                transaction.type == .dividend || 
                transaction.type == .fee ||
                transaction.type == .transfer ||
                transaction.type == .repayment
            }
        }
        
        return result
    }
    
    // 計算日期範圍（只計算一次，避免重複計算）
    private func calculateDateRange() -> (start: Date, end: Date)? {
        if selectedTimeRange == .custom {
            // 自訂日期範圍：使用選擇的日期，但需要設置時間為開始和結束
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: customStartDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            return (startOfDay, endOfDay)
        } else {
            // 預設選項
            return selectedTimeRange.dateRange
        }
    }
    
    // 清除所有篩選
    private func clearAllFilters() {
        selectedAccountIds.removeAll()
        selectedTimeRange = .all
        customStartDate = Calendar.current.startOfDay(for: Date())
        customEndDate = Calendar.current.startOfDay(for: Date())
        saveFilterPreferences()
    }
    
    // 保存篩選偏好
    private func saveFilterPreferences() {
        let preferences = FilterPreferences(
            selectedAccountIds: Array(selectedAccountIds),
            selectedTimeRange: selectedTimeRange,
            customStartDate: selectedTimeRange == .custom ? customStartDate : nil,
            customEndDate: selectedTimeRange == .custom ? customEndDate : nil
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
        selectedTimeRange = preferences.selectedTimeRange
        
        if let startDate = preferences.customStartDate {
            customStartDate = startDate
        }
        if let endDate = preferences.customEndDate {
            customEndDate = endDate
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection
                filterTitleSection
                transactionsListSection
            }
            .navigationTitle("所有紀錄")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
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
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(viewModel: viewModel)
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
            .sheet(isPresented: $showingAccountPicker) {
                accountPickerSheet
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
        }
    }
    
    // MARK: - 帳戶選擇器 Sheet
    
    private var accountPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 全選/全不選按鈕（卡片樣式）
                    CardView {
                        HStack {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if selectedAccountIds.count == viewModel.accounts.count {
                                        // 如果已全選，則全不選
                                        selectedAccountIds.removeAll()
                                    } else {
                                        // 全選
                                        selectedAccountIds = Set(viewModel.accounts.map { $0.id })
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedAccountIds.count == viewModel.accounts.count ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.appPrimary)
                                    
                                    Text(selectedAccountIds.count == viewModel.accounts.count ? "全不選" : "全選")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            if !selectedAccountIds.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedAccountIds.removeAll()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("清除選擇")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.secondaryText)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 帳戶列表（卡片樣式）
                    ForEach(viewModel.accounts, id: \.id) { account in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if selectedAccountIds.contains(account.id) {
                                    selectedAccountIds.remove(account.id)
                                } else {
                                    selectedAccountIds.insert(account.id)
                                }
                            }
                        }) {
                            CardView {
                                HStack(spacing: 12) {
                                    // 帳戶圖標（圓形背景）
                                    ZStack {
                                        Circle()
                                            .fill(account.accountType.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: account.accountType.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(account.accountType.color)
                                    }
                                    
                                    // 帳戶資訊
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(account.name)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primaryText)
                                        
                                        Text(account.accountType.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    // 選中標記
                                    if selectedAccountIds.contains(account.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(.appPrimary)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondaryText.opacity(0.3))
                                    }
                                }
                            }
                            .overlay(
                                // 選中時顯示邊框
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedAccountIds.contains(account.id) ? Color.appPrimary : Color.clear, lineWidth: 2)
                            )
                            .background(
                                // 選中時顯示背景色
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedAccountIds.contains(account.id) ? Color.appPrimary.opacity(0.05) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16)
            }
            .background(Color.secondaryBackground)
            .navigationTitle("選擇帳戶")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingAccountPicker = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveFilterPreferences()
                        showingAccountPicker = false
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - 時間篩選選擇器 Sheet
    
    private var datePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 預設選項（卡片樣式）
                    presetTimeRangeOptions
                        .padding(.top, 8)
                    
                    // 自訂日期範圍選項（卡片樣式）
                    customDateRangeOption
                }
                .padding(.bottom, 16)
            }
            .background(Color.secondaryBackground)
            .navigationTitle("選擇時間範圍")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDatePicker = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveFilterPreferences()
                        showingDatePicker = false
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - 預設時間範圍選項
    
    private var presetTimeRangeOptions: some View {
        ForEach(TimeRangeFilter.allCases.filter { $0 != .custom }, id: \.self) { timeRange in
            timeRangeOptionButton(timeRange: timeRange)
                .padding(.horizontal)
        }
    }
    
    // MARK: - 時間範圍選項按鈕
    
    private func timeRangeOptionButton(timeRange: TimeRangeFilter) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTimeRange = timeRange
                if timeRange != .custom {
                    customStartDate = Calendar.current.startOfDay(for: Date())
                    customEndDate = Calendar.current.startOfDay(for: Date())
                }
            }
        }) {
            timeRangeCard(timeRange: timeRange)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 時間範圍卡片
    
    private func timeRangeCard(timeRange: TimeRangeFilter) -> some View {
        let isSelected = selectedTimeRange == timeRange
        
        return CardView {
            HStack {
                Text(timeRange.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.appPrimary)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondaryText.opacity(0.3))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.appPrimary.opacity(0.05) : Color.clear)
        )
    }
    
    // MARK: - 自訂日期範圍選項
    
    private var customDateRangeOption: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTimeRange = .custom
            }
        }) {
            customDateRangeCard
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    // MARK: - 自訂日期範圍卡片
    
    private var customDateRangeCard: some View {
        let isSelected = selectedTimeRange == .custom
        
        return CardView {
            VStack(alignment: .leading, spacing: 16) {
                customDateRangeHeader(isSelected: isSelected)
                
                if isSelected {
                    customDatePickers
                        .padding(.top, 8)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.appPrimary.opacity(0.05) : Color.clear)
        )
    }
    
    // MARK: - 自訂日期範圍標題
    
    private func customDateRangeHeader(isSelected: Bool) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                
                Text("自訂")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.appPrimary)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundColor(.secondaryText.opacity(0.3))
            }
        }
    }
    
    // MARK: - 自訂日期選擇器
    
    private var customDatePickers: some View {
        VStack(spacing: 16) {
            datePickerRow(label: "開始日期", date: $customStartDate)
            
            Divider()
            
            datePickerRow(label: "結束日期", date: $customEndDate)
        }
    }
    
    // MARK: - 日期選擇器行
    
    private func datePickerRow(label: String, date: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18))
                .foregroundColor(.secondaryText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                
                DatePicker("", selection: date, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: {
                    showingAddTransaction = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增交易")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                
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
        } else {
            // 其他交易類型（buy, sell等）使用原有的EditTransactionView
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
    
    private func deleteTransactions(at offsets: IndexSet) {
        let transactionsToDelete = offsets.map { filteredTransactions[$0] }
        Task {
            // 逐一刪除，確保每個刪除操作完成後再進行下一個
            for transaction in transactionsToDelete {
                await viewModel.deleteTransaction(transaction.id)
            }
            // 刪除完成後，刷新所有相關的 ViewModel
            await refreshAllData()
        }
    }
    
    private func refreshAllData() async {
        // 使用 Task 確保異步操作不會阻塞
        await portfolioViewModel.loadData(userId: userId)
        await accountsViewModel.loadAccounts(userId: userId)
        // 重新載入交易以確保數據一致性
        await viewModel.loadTransactions(userId: userId)
    }
    
    private func getAccountName(for transaction: Transaction) -> String {
        // 確保 accounts 已載入
        if viewModel.accounts.isEmpty {
            return "未知帳戶"
        }
        
        // 如果是轉帳或還款交易，顯示「A到B」格式
        if transaction.type == .transfer || transaction.type == .repayment {
            // 優先使用 targetAccountId 直接從帳戶列表中查找（不使用字符串解析）
            if let sourceAccount = viewModel.accounts.first(where: { $0.id == transaction.accountId }),
               let targetAccountId = transaction.targetAccountId,
               let targetAccount = viewModel.accounts.first(where: { $0.id == targetAccountId }) {
                return "\(sourceAccount.name)到\(targetAccount.name)"
            }
            
            // 如果無法獲取，返回預設值
            if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
                return account.name
            }
            return "未知帳戶"
        }
        
        // 非轉帳/還款交易，返回帳戶名稱
        if let account = viewModel.accounts.first(where: { $0.id == transaction.accountId }) {
            return account.name
        }
        return "未知帳戶"
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let accountName: String
    let onEdit: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要交易行
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 圖示
                    Circle()
                        .fill(typeColor(for: transaction.type).opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: typeIcon(for: transaction.type))
                                .foregroundColor(typeColor(for: transaction.type))
                                .font(.system(size: 16))
                        }
                    
                    // 資訊
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transactionDescription)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Text(accountName)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    // 金額和日期
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(transactionAmount)
                            .font(.headline)
                            .foregroundColor(transaction.type == .repayment ? .lossRed : typeColor(for: transaction.type))
                        
                        Text(transaction.transactionDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    // 展開/收起圖標
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .frame(width: 20)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展開的備註區域
            if isExpanded, let notes = transaction.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("備註")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.secondaryBackground.opacity(0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("刪除")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(Color.red)
                .cornerRadius(0)
            }
            .tint(.red)
            
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
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.blue)
                    .cornerRadius(0)
                }
                .tint(.blue)
            }
        }
    }
    
    private var transactionDescription: String {
        // 統一的簡化標題顯示
        switch transaction.type {
        case .buy, .sell:
            return transaction.symbol
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
    
    private func typeIcon(for type: TransactionType) -> String {
        // 統一的圖標邏輯，與 TransactionHistoryView 保持一致
        switch type {
        case .transfer:
            return "arrow.left.arrow.right"
        case .repayment:
            return "creditcard.fill"
        case .buy:
            return "arrow.down"  // 買入：向下箭頭（支出）
        case .sell:
            return "arrow.up"  // 賣出：向上箭頭（收入）
        case .deposit:
            return "arrow.up"  // 收入：向上箭頭
        case .withdraw:
            return "arrow.down"  // 支出：向下箭頭
        case .dividend:
            return "arrow.up"  // 股利：向上箭頭（收入）
        case .fee:
            return "arrow.down"  // 手續費：向下箭頭（支出）
        case .liability:
            return "creditcard"
        }
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

#Preview {
    TransactionsView()
}

