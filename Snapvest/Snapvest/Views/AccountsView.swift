//
//  AccountsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import UniformTypeIdentifiers

private enum ManagementSectionID: Hashable, Codable, Identifiable {
    case account(AccountType)
    case manualAsset(ManualAssetCategory)

    var id: String { rawIdentifier }

    private var rawIdentifier: String {
        switch self {
        case .account(let accountType):
            return "account:\(accountType.rawValue)"
        case .manualAsset(let category):
            return "manualAsset:\(category.rawValue)"
        }
    }

    init?(rawIdentifier: String) {
        let parts = rawIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "account":
            guard let accountType = AccountType(rawValue: parts[1]) else { return nil }
            self = .account(accountType)
        case "manualAsset":
            guard let category = ManualAssetCategory(rawValue: parts[1]) else { return nil }
            self = .manualAsset(category)
        default:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawIdentifier = try container.decode(String.self)
        guard let value = ManagementSectionID(rawIdentifier: rawIdentifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid management section id"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawIdentifier)
    }
}

struct AccountsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var viewModel: AccountsViewModel
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @Environment(\.openSettings) private var openSettings
    @StateObject private var manualAssetsViewModel = ManualAssetsViewModel()
    @State private var showingAddAccount = false
    @State private var showingAddLiability = false
    @State private var userId: String = AppUser.id
    @State private var expandedCategories: Set<AccountType> = Set(AccountType.allCases)
    @State private var accountOrder: [AccountType] = AccountType.allCases
    @State private var managementSectionOrder: [ManagementSectionID] = []
    @State private var accountOrders: [AccountType: [String]] = [:]
    @State private var navigationStackResetID = UUID()
    @State private var accountsCurrencyDisplay: AssetsCurrencyDisplay = .twd
    @State private var managementShareDisplayMode: ManagementShareDisplayMode = ManagementShareDisplayPreference.get()
    @State private var isEditingOrder = false
    @State private var accountPendingDelete: Account?
    @State private var manualAssetPendingDelete: ManualAsset?
    @State private var showDeleteConfirmation = false
    @State private var showManualAssetDeleteConfirmation = false
    @State private var deleteConfirmationMessage = ""
    @State private var deleteErrorMessage: String?
    @State private var expandedManualAssetCategories: Set<ManualAssetCategory> = Set(ManualAssetCategory.allCases)
    @State private var isDeleting = false
    @State private var accountDetailRoute: AccountDetailRoute?
    @State private var manualAssetDetailRoute: ManualAssetDetailRoute?
    @State private var accountDetailRefreshToken = 0
    @State private var draggedManagementSection: ManagementSectionID?

    private var activeAccounts: [Account] {
        viewModel.accounts.filter { !$0.isArchived }
    }

    private var showsManagementOnboardingEmpty: Bool {
        !viewModel.isLoading && activeAccounts.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    AccountsCurrencyControlsBar(
                        currencyDisplay: $accountsCurrencyDisplay,
                        shareDisplayMode: $managementShareDisplayMode,
                        showsEditControl: true,
                        isEditingOrder: isEditingOrder,
                        isEditDisabled: orderedVisibleManagementSections.isEmpty && !showsManagementOnboardingEmpty,
                        onEditTapped: {
                            toggleOrderEditing()
                        }
                    )

                    if showsManagementOnboardingEmpty {
                        OnboardingEmptyStateCard(
                            icon: "building.columns.fill",
                            title: "還沒有帳戶",
                            message: "先建立現金、台股、美股或加密錢包，淨資產與走勢才會開始累積。",
                            actionTitle: "新增第一個帳戶"
                        ) {
                            showingAddAccount = true
                        }
                    }
                    
                    ForEach(orderedVisibleManagementSections) { sectionID in
                        sortableManagementSectionView(for: sectionID)
                    }
                    
                    archivedDebtAccountsSection
                    
                    DataFreshnessFooterView(style: .valuationTabs)
                }
                .padding()
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .environment(\.managementShareDisplayMode, managementShareDisplayMode)
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
            .onReceive(NotificationCenter.default.publisher(for: .openAddAccountSheet)) { _ in
                showingAddAccount = true
            }
            .onAppear {
                accountsCurrencyDisplay = .twd
                loadAccountOrder()
                reconcileAccountOrders()
                reconcileManagementSectionOrder()
                Task { await manualAssetsViewModel.loadAssets(userId: userId) }
            }
            .onChange(of: selectedTab) { _, newTab in
                if isEditingOrder, newTab != AppTab.accounts.rawValue {
                    finishOrderEditing()
                    return
                }
                guard newTab == AppTab.accounts.rawValue else { return }
                accountsCurrencyDisplay = .twd
            }
            .onChange(of: viewModel.accounts.map(\.id)) { _, _ in
                reconcileAccountOrders()
                reconcileManagementSectionOrder()
            }
            .onChange(of: manualAssetsViewModel.assets.map(\.id)) { _, _ in
                reconcileManagementSectionOrder()
            }
            .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { notification in
                if notification.userInfo?[SnapshotUpdateUserInfoKey.alreadyApplied] as? Bool == true {
                    reconcileAccountOrders()
                    reconcileManagementSectionOrder()
                    accountDetailRefreshToken += 1
                    return
                }
                Task {
                    await LaunchCoordinator.applyPersistedState(
                        userId: userId,
                        portfolioViewModel: portfolioViewModel,
                        accountsViewModel: viewModel,
                        assetsViewModel: assetsViewModel,
                        rebuildAccountDetailCache: false
                    )
                    await manualAssetsViewModel.loadAssets(userId: userId)
                    reconcileAccountOrders()
                    reconcileManagementSectionOrder()
                    accountDetailRefreshToken += 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                reconcileAccountOrders()
                reconcileManagementSectionOrder()
                accountDetailRefreshToken += 1
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
            .alert("刪除其他資產", isPresented: $showManualAssetDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    manualAssetPendingDelete = nil
                }
                Button("刪除", role: .destructive) {
                    guard let asset = manualAssetPendingDelete else { return }
                    manualAssetPendingDelete = nil
                    Task { await deleteManualAsset(asset) }
                }
            } message: {
                if let asset = manualAssetPendingDelete {
                    Text("確定刪除「\(asset.name)」？會一併刪除所有估值紀錄，此操作無法復原。")
                }
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
            .navigationDestination(item: $manualAssetDetailRoute) { route in
                manualAssetDetailDestination(for: route)
            }
        }
        .id(navigationStackResetID)
        .resetNavigationWhenTabReappears(selectedTab: $selectedTab, resignedTab: .accounts) {
            accountsCurrencyDisplay = .twd
            navigationStackResetID = UUID()
        }
    }
    
    private func openAccountDetail(_ account: Account) {
        guard !isEditingOrder else { return }
        accountDetailRoute = AccountDetailRoute(accountId: account.id)
    }

    private func openManualAssetDetail(_ asset: ManualAsset) {
        guard !isEditingOrder else { return }
        manualAssetDetailRoute = ManualAssetDetailRoute(assetId: asset.id)
    }
    
    @ViewBuilder
    private func accountDetailDestination(for route: AccountDetailRoute) -> some View {
        if let account = viewModel.accounts.first(where: { $0.id == route.accountId }) {
            AccountDetailView(
                account: account,
                prefilledBalance: viewModel.balancesByAccountId[account.id],
                initialDisplayCurrency: accountsCurrencyDisplay == .original
                    ? account.currency
                    : portfolioViewModel.viewCurrency,
                refreshToken: accountDetailRefreshToken
            )
        } else {
            ContentUnavailableView("找不到帳戶", systemImage: "building.columns")
        }
    }

    @ViewBuilder
    private func manualAssetDetailDestination(for route: ManualAssetDetailRoute) -> some View {
        if let asset = manualAssetsViewModel.assets.first(where: { $0.id == route.assetId }) {
            ManualAssetDetailView(
                asset: asset,
                viewModel: manualAssetsViewModel,
                baseCurrency: portfolioViewModel.viewCurrency,
                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
                twdRateByCurrency: portfolioViewModel.pieChartInputs?.twdRateByCurrency ?? [.TWD: 1]
            )
        } else {
            ContentUnavailableView("找不到其他資產", systemImage: "square.grid.2x2")
        }
    }
    
    @ViewBuilder
    private func sortableManagementSectionView(for sectionID: ManagementSectionID) -> some View {
        if isEditingOrder {
            managementSectionView(for: sectionID)
                .opacity(draggedManagementSection == sectionID ? 0.35 : 1)
                .scaleEffect(draggedManagementSection == sectionID ? 0.985 : 1)
                .animation(ChartMotion.switchSpring, value: draggedManagementSection)
                .onDrag {
                    dragProvider(for: sectionID)
                } preview: {
                    managementSectionDragPreview(for: sectionID)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ManagementSectionDropDelegate(
                        targetSection: sectionID,
                        sections: orderedVisibleManagementSections,
                        draggedSection: $draggedManagementSection,
                        onMove: { source, target in
                            moveManagementSection(source, before: target)
                        },
                        onCommit: saveAccountOrder
                    )
                )
        } else {
            managementSectionView(for: sectionID)
        }
    }

    @ViewBuilder
    private func managementSectionDragPreview(for sectionID: ManagementSectionID) -> some View {
        managementSectionView(for: sectionID)
            .frame(width: 340)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func managementSectionView(for sectionID: ManagementSectionID) -> some View {
        switch sectionID {
        case .account(let accountType):
            accountCategorySection(for: accountType, sectionID: sectionID)
        case .manualAsset(let category):
            manualAssetCategorySection(for: category, sectionID: sectionID)
        }
    }

    @ViewBuilder
    private func accountCategorySection(for accountType: AccountType, sectionID: ManagementSectionID) -> some View {
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
                totalAssetsDenominator: portfolioViewModel.totalAssets,
                currencyDisplay: accountsCurrencyDisplay,
                baseCurrency: portfolioViewModel.viewCurrency,
                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
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
                totalAssetsDenominator: portfolioViewModel.totalAssets,
                currencyDisplay: accountsCurrencyDisplay,
                baseCurrency: portfolioViewModel.viewCurrency,
                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
                isEditingOrder: isEditingOrder,
                onRequestDelete: { account in
                    presentDeleteConfirmation(for: account)
                },
                onOpenAccount: openAccountDetail
            )
        }
    }

    @ViewBuilder
    private func manualAssetCategorySection(for category: ManualAssetCategory, sectionID: ManagementSectionID) -> some View {
        let groups = Dictionary(grouping: manualAssetsViewModel.assets, by: \.category)
        let assets = groups[category] ?? []
        if assets.isEmpty {
            EmptyView()
        } else {
            ManualAssetCategorySection(
                category: category,
                assets: assets.sorted { $0.updatedAt > $1.updatedAt },
                totalAssetsDenominator: portfolioViewModel.totalAssets,
                currencyDisplay: accountsCurrencyDisplay,
                baseCurrency: portfolioViewModel.viewCurrency,
                twdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency,
                twdRateByCurrency: portfolioViewModel.pieChartInputs?.twdRateByCurrency ?? [.TWD: 1],
                isExpanded: manualAssetExpandedBinding(for: category),
                isEditingOrder: isEditingOrder,
                onOpenAsset: openManualAssetDetail,
                onDeleteAsset: { asset in
                    presentManualAssetDeleteConfirmation(for: asset)
                }
            )
        }
    }

    private func presentManualAssetDeleteConfirmation(for asset: ManualAsset) {
        guard !isDeleting, !isEditingOrder else { return }
        manualAssetPendingDelete = asset
        showManualAssetDeleteConfirmation = true
    }

    private func deleteManualAsset(_ asset: ManualAsset) async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        _ = await manualAssetsViewModel.deleteAsset(id: asset.id, userId: userId)
        if manualAssetDetailRoute?.assetId == asset.id {
            manualAssetDetailRoute = nil
        }
    }

    private func manualAssetExpandedBinding(for category: ManualAssetCategory) -> Binding<Bool> {
        Binding(
            get: { expandedManualAssetCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedManualAssetCategories.insert(category)
                } else {
                    expandedManualAssetCategories.remove(category)
                }
            }
        )
    }
    
    // MARK: - 標題欄
    
    private var accountsHeaderBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("管理")
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
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("新增項目")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.actionForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
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

        let succeeded = await PortfolioMutationCoordinator.perform(
            userId: userId,
            loading: PortfolioMutationCoordinator.LoadingMessage(
                title: "正在刪除帳戶…",
                message: "會一併更新相關資產與分類總額"
            ),
            portfolioViewModel: portfolioViewModel,
            accountsViewModel: viewModel,
            assetsViewModel: assetsViewModel,
            forceFullRebuild: true,
            operation: {
                if let error = await viewModel.deleteAccount(account) {
                    deleteErrorMessage = error
                    return false
                }
                return true
            }
        )

        guard succeeded else { return }

        var order = accountOrders[account.accountType] ?? []
        order.removeAll { $0 == account.id }
        accountOrders[account.accountType] = order
        saveAccountOrder()
        accountPendingDelete = nil
    }
    
    // MARK: - 拖曳排序輔助函數
    private var visibleManagementSectionIDs: [ManagementSectionID] {
        let accountSections = AccountType.allCases
            .filter { !viewModel.accounts.activeAccounts(ofType: $0).isEmpty }
            .map(ManagementSectionID.account)
        let manualAssetGroups = Dictionary(grouping: manualAssetsViewModel.assets, by: \.category)
        let manualSections = ManualAssetCategory.allCases
            .filter { manualAssetGroups[$0]?.isEmpty == false }
            .map(ManagementSectionID.manualAsset)
        return accountSections + manualSections
    }

    private var orderedVisibleManagementSections: [ManagementSectionID] {
        let visible = visibleManagementSectionIDs
        let orderedExisting = managementSectionOrder.filter { visible.contains($0) }
        let appended = visible.filter { !orderedExisting.contains($0) }
        return orderedExisting + appended
    }

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

    private func dragProvider(for sectionID: ManagementSectionID) -> NSItemProvider {
        draggedManagementSection = sectionID
        return NSItemProvider(object: sectionID.id as NSString)
    }

    private func moveManagementSection(_ sectionID: ManagementSectionID, before targetSectionID: ManagementSectionID) {
        var order = orderedVisibleManagementSections
        guard let sourceIndex = order.firstIndex(of: sectionID),
              let targetIndex = order.firstIndex(of: targetSectionID),
              sourceIndex != targetIndex else { return }
        let moved = order.remove(at: sourceIndex)
        order.insert(moved, at: targetIndex)
        withAnimation(ChartMotion.switchSpring) {
            managementSectionOrder = order
        }
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

    private func reconcileManagementSectionOrder() {
        let visible = visibleManagementSectionIDs
        var order = managementSectionOrder.filter { visible.contains($0) }
        for sectionID in visible where !order.contains(sectionID) {
            order.append(sectionID)
        }
        managementSectionOrder = order
    }
    
    private func loadAccountOrder() {
        // 從 UserDefaults 載入排序
        if let data = UserDefaults.standard.data(forKey: "accountOrder_\(userId)"),
           let order = try? JSONDecoder().decode([AccountType].self, from: data) {
            accountOrder = order
        }
        let managementKey = "managementSectionOrder_\(userId)"
        if let data = UserDefaults.standard.data(forKey: managementKey),
           let order = try? JSONDecoder().decode([ManagementSectionID].self, from: data) {
            managementSectionOrder = order
        } else {
            let migratedAccountOrder = accountOrder.map(ManagementSectionID.account)
            let manualAssetOrder = ManualAssetCategory.allCases.map(ManagementSectionID.manualAsset)
            managementSectionOrder = migratedAccountOrder + manualAssetOrder
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
        accountOrder = managementSectionOrder.compactMap {
            if case .account(let accountType) = $0 { return accountType }
            return nil
        }
        if let data = try? JSONEncoder().encode(accountOrder) {
            UserDefaults.standard.set(data, forKey: "accountOrder_\(userId)")
        }
        if let data = try? JSONEncoder().encode(managementSectionOrder) {
            UserDefaults.standard.set(data, forKey: "managementSectionOrder_\(userId)")
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
        let manualAssetGroups = Dictionary(grouping: manualAssetsViewModel.assets, by: \.category)
        let nonEmptyManualCategories = ManualAssetCategory.allCases.filter {
            manualAssetGroups[$0]?.isEmpty == false
        }
        reconcileManagementSectionOrder()
        withAnimation(ChartMotion.switchSpring) {
            expandedCategories.formUnion(nonEmptyTypes)
            expandedManualAssetCategories.formUnion(nonEmptyManualCategories)
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

private struct ManualAssetDetailRoute: Identifiable, Hashable {
    let assetId: String
    var id: String { assetId }
}

// MARK: - 已封存債務帳戶

struct ArchivedDebtAccountsSection: View {
    let accounts: [Account]
    let balancesByAccountId: [String: AccountBalanceDisplay]
    let totalAssetsDenominator: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
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
                                totalAssetsDenominator: totalAssetsDenominator,
                                currencyDisplay: currencyDisplay,
                                baseCurrency: baseCurrency,
                                twdPerBaseCurrency: twdPerBaseCurrency,
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

// MARK: - 其他資產類別

struct ManualAssetCategorySection: View {
    let category: ManualAssetCategory
    let assets: [ManualAsset]
    let totalAssetsDenominator: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let twdRateByCurrency: [Currency: Decimal]
    @Binding var isExpanded: Bool
    let isEditingOrder: Bool
    let onOpenAsset: (ManualAsset) -> Void
    let onDeleteAsset: (ManualAsset) -> Void

    private var accentColor: Color { .manualAssetColor }

    private var includedAssets: [ManualAsset] {
        assets.filter(\.isIncludedInTotalAssets)
    }

    private var categoryTotalTWD: Decimal {
        includedAssets.reduce(Decimal.zero) { partial, asset in
            partial + (ManualAssetMetrics.valueTWD(asset: asset, rates: twdRateByCurrency) ?? 0)
        }
    }

    private var categorySharePercent: Decimal {
        let numerator = TotalAssetsShareCalculator.displayAmount(
            fromTWD: categoryTotalTWD,
            twdPerBaseCurrency: twdPerBaseCurrency
        )
        return TotalAssetsShareCalculator.sharePercentFromDisplay(
            numeratorDisplay: numerator,
            totalAssetsDisplay: totalAssetsDenominator
        )
    }

    private var categoryTotalDisplays: [(amount: Decimal, currency: Currency)] {
        if currencyDisplay == .twd {
            let amount = TotalAssetsShareCalculator.displayAmount(
                fromTWD: categoryTotalTWD,
                twdPerBaseCurrency: twdPerBaseCurrency
            )
            return [(amount, baseCurrency)]
        }

        let grouped = includedAssets.reduce(into: [Currency: Decimal]()) { partial, asset in
            partial[asset.currency, default: 0] += asset.currentValue
        }
        return grouped
            .filter { $0.value != 0 }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { (amount: $0.value, currency: $0.key) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard !isEditingOrder else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TotalAssetsShareRingView(
                        sharePercent: categorySharePercent,
                        accentColor: accentColor
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.snapOverviewText)
                            .foregroundColor(.primaryText)
                            .snapOverviewFittingLine()
                        Text("\(assets.count)項其他資產")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("類別總資產")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondaryText)
                        ForEach(categoryTotalDisplays, id: \.currency) { display in
                            categoryOverviewAmountChip(
                                amount: display.amount,
                                currency: display.currency,
                                color: .primaryText,
                                chipTint: accentColor
                            )
                        }
                    }
                    .layoutPriority(1)

                    if isEditingOrder {
                        SectionDragHandle()
                    } else {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding()
                .snapCappedDynamicTypeSize()
            }
            .buttonStyle(.plain)

            if isExpanded {
                List {
                    ForEach(assets) { asset in
                        Button {
                            onOpenAsset(asset)
                        } label: {
                            ManualAssetCardView(
                                asset: asset,
                                totalAssetsDenominator: totalAssetsDenominator,
                                currencyDisplay: currencyDisplay,
                                baseCurrency: baseCurrency,
                                twdPerBaseCurrency: twdPerBaseCurrency,
                                twdRateByCurrency: twdRateByCurrency
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDeleteAsset(asset)
                            } label: {
                                SwiftUI.Label("刪除", systemImage: "trash")
                            }
                            .tint(.lossRed)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(assets.count) * 88)
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor)
                .frame(width: SnapOverviewBarMetrics.overviewWidth)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

struct ManualAssetCardView: View {
    let asset: ManualAsset
    let totalAssetsDenominator: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let twdRateByCurrency: [Currency: Decimal]

    private var accentColor: Color { .manualAssetColor }

    private var sharePercent: Decimal {
        guard asset.isIncludedInTotalAssets else { return 0 }
        let twd = ManualAssetMetrics.valueTWD(asset: asset, rates: twdRateByCurrency) ?? 0
        let numerator = TotalAssetsShareCalculator.displayAmount(
            fromTWD: twd,
            twdPerBaseCurrency: twdPerBaseCurrency
        )
        return TotalAssetsShareCalculator.sharePercentFromDisplay(
            numeratorDisplay: numerator,
            totalAssetsDisplay: totalAssetsDenominator
        )
    }

    private var displayAmount: (amount: Decimal, currency: Currency) {
        if currencyDisplay == .original {
            return (asset.currentValue, asset.currency)
        }
        let valueTWD = ManualAssetMetrics.valueTWD(asset: asset, rates: twdRateByCurrency) ?? asset.currentValue
        let amount = twdPerBaseCurrency > 0 ? valueTWD / twdPerBaseCurrency : valueTWD
        return (amount, baseCurrency)
    }

    var body: some View {
        HStack(spacing: 12) {
            ManagementRowLeadingIndicator(
                currency: asset.currency,
                accentColor: accentColor,
                sharePercent: sharePercent
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(asset.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if asset.isIncludedInTotalAssets {
                        badge("總資產")
                    }
                    if asset.isIncludedInInvestments {
                        badge("投資")
                    }
                }
            }

            Spacer(minLength: 8)

            CurrencyAmountWithChip(
                text: displayAmount.amount.formatted(currency: displayAmount.currency),
                currency: displayAmount.currency,
                font: .snapAmountRow,
                weight: .bold,
                color: .primaryText,
                chipTint: accentColor
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor)
                .frame(width: SnapOverviewBarMetrics.detailWidth)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accentColor.opacity(0.10))
            .clipShape(Capsule())
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
                .tint(.lossRed)
            }
        }
    }
}

// MARK: - 類別總覽金額（統一字級，避免長數字被壓縮）

@ViewBuilder
private func categoryOverviewAmountChip(
    amount: Decimal,
    currency: Currency,
    color: Color,
    chipTint: Color
) -> some View {
    CurrencyAmountWithChip(
        text: amount.formatted(currency: currency),
        currency: currency,
        font: .snapOverviewAmount,
        weight: .bold,
        color: color,
        chipTint: chipTint,
        minimumScaleFactor: SnapOverviewBarMetrics.minScaleFactor
    )
    .monospacedDigit()
    .snapOverviewFittingLine()
}

// MARK: - 帳戶列表顯示用（台幣 / 原幣）

enum AccountListAmountDisplay {
    static func categoryTotals(
        accountType: AccountType,
        accounts: [Account],
        categoryTotalTWD: Decimal,
        balancesByAccountId: [String: AccountBalanceDisplay],
        currencyDisplay: AssetsCurrencyDisplay,
        baseCurrency: Currency,
        twdPerBaseCurrency: Decimal
    ) -> [(amount: Decimal, currency: Currency)] {
        let baseAmount = twdPerBaseCurrency > 0 ? categoryTotalTWD / twdPerBaseCurrency : categoryTotalTWD

        if currencyDisplay == .twd {
            return [(baseAmount, baseCurrency)]
        }

        let grouped = accounts.reduce(into: [Currency: Decimal]()) { partial, account in
            guard let balance = balancesByAccountId[account.id] else { return }
            let amount: Decimal
            switch account.accountType {
            case .twdDeposit:
                amount = balance.cashBalance
            case .debt, .otherDebt:
                amount = -balance.remainingBalance
            default:
                amount = balance.totalAssets
            }
            partial[account.currency, default: 0] += amount
        }
        return grouped
            .filter { $0.value != 0 }
            .sorted { lhs, rhs in
                if lhs.key == baseCurrency { return true }
                if rhs.key == baseCurrency { return false }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .map { (amount: $0.value, currency: $0.key) }
    }
    
    /// 換算為 TWD 的帳戶資產／現金／欠款，供佔總資產比例計算。
    static func accountValueTWD(account: Account, balance: AccountBalanceDisplay?) -> Decimal {
        guard let balance else { return 0 }
        switch account.accountType {
        case .debt, .otherDebt:
            let native = balance.remainingBalance
            return account.currency == .TWD ? native : (balance.twdEquivalent ?? native)
        case .twdDeposit:
            let native = balance.cashBalance
            return account.currency == .TWD ? native : (balance.twdEquivalent ?? native)
        default:
            let native = balance.totalAssets
            return account.currency == .TWD ? native : (balance.twdEquivalent ?? native)
        }
    }

    static func cardAmount(
        account: Account,
        balance: AccountBalanceDisplay,
        currencyDisplay: AssetsCurrencyDisplay,
        baseCurrency: Currency,
        twdPerBaseCurrency: Decimal
    ) -> (amount: Decimal, currency: Currency) {
        switch account.accountType {
        case .debt, .otherDebt:
            if currencyDisplay == .twd {
                let nativeAmount = balance.remainingBalance
                let twdAmount = account.currency == .TWD ? nativeAmount : (balance.twdEquivalent ?? nativeAmount)
                let baseAmount = twdPerBaseCurrency > 0 ? twdAmount / twdPerBaseCurrency : twdAmount
                return (-baseAmount, baseCurrency)
            }
            return (-balance.remainingBalance, account.currency)
        case .twdDeposit:
            if currencyDisplay == .twd {
                let nativeAmount = balance.cashBalance
                let twdAmount = account.currency == .TWD ? nativeAmount : (balance.twdEquivalent ?? nativeAmount)
                let baseAmount = twdPerBaseCurrency > 0 ? twdAmount / twdPerBaseCurrency : twdAmount
                return (baseAmount, baseCurrency)
            }
            return (balance.cashBalance, account.currency)
        default:
            if currencyDisplay == .twd {
                let nativeAmount = balance.totalAssets
                let twdAmount = account.currency == .TWD ? nativeAmount : (balance.twdEquivalent ?? nativeAmount)
                let baseAmount = twdPerBaseCurrency > 0 ? twdAmount / twdPerBaseCurrency : twdAmount
                return (baseAmount, baseCurrency)
            }
            return (balance.totalAssets, account.currency)
        }
    }
}

private struct ManagementSectionDropDelegate: DropDelegate {
    let targetSection: ManagementSectionID
    let sections: [ManagementSectionID]
    @Binding var draggedSection: ManagementSectionID?
    let onMove: (ManagementSectionID, ManagementSectionID) -> Void
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedSection,
              draggedSection != targetSection,
              sections.contains(draggedSection),
              sections.contains(targetSection) else {
            return
        }
        onMove(draggedSection, targetSection)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        onCommit()
        return true
    }
}

private struct SectionDragHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.secondaryText)
            .frame(width: 32, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("拖曳調整大類排序")
    }
}

// MARK: - 可收縮/展開的帳戶類別區塊
struct ExpandableAccountCategorySection: View {
    let accountType: AccountType
    let accounts: [Account]
    let categoryTotalTWD: Decimal
    let totalAssetsDenominator: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let isCategoryLoading: Bool
    let balancesByAccountId: [String: AccountBalanceDisplay]
    let isBalanceLoading: Bool
    @Binding var isExpanded: Bool
    let isEditingOrder: Bool
    let onMove: (IndexSet, Int) -> Void
    let onRequestDelete: (Account) -> Void
    let onOpenAccount: (Account) -> Void
    
    private var categoryTotalDisplays: [(amount: Decimal, currency: Currency)] {
        guard !isCategoryLoading else { return [] }
        return AccountListAmountDisplay.categoryTotals(
            accountType: accountType,
            accounts: accounts,
            categoryTotalTWD: categoryTotalTWD,
            balancesByAccountId: balancesByAccountId,
            currencyDisplay: currencyDisplay,
            baseCurrency: baseCurrency,
            twdPerBaseCurrency: twdPerBaseCurrency
        )
    }
    
    private var categoryAmountColor: Color {
        accountType == .debt || accountType == .otherDebt ? .lossRed : .primaryText
    }

    private var categorySharePercent: Decimal {
        let numeratorTWD = abs(categoryTotalTWD)
        let numerator = TotalAssetsShareCalculator.displayAmount(
            fromTWD: numeratorTWD,
            twdPerBaseCurrency: twdPerBaseCurrency
        )
        return TotalAssetsShareCalculator.sharePercentFromDisplay(
            numeratorDisplay: numerator,
            totalAssetsDisplay: totalAssetsDenominator
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                guard !isEditingOrder else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TotalAssetsShareRingView(
                        sharePercent: categorySharePercent,
                        accentColor: accountType == .debt || accountType == .otherDebt ? .lossRed : accountType.color
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(accountType.displayName)
                            .font(.snapOverviewText)
                            .foregroundColor(.primaryText)
                            .snapOverviewFittingLine()
                        Text("\(accounts.count)個帳戶")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .layoutPriority(1)
                    
                    Spacer(minLength: 8)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if !categoryTotalDisplays.isEmpty {
                            Text(accountType == .debt || accountType == .otherDebt ? "類別總債務" : "類別總資產")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondaryText)
                            ForEach(categoryTotalDisplays, id: \.currency) { display in
                                categoryOverviewAmountChip(
                                    amount: display.amount,
                                    currency: display.currency,
                                    color: categoryAmountColor,
                                    chipTint: accountType.color
                                )
                            }
                        } else {
                            Text(accountType == .debt || accountType == .otherDebt ? "類別總債務" : "類別總資產")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondaryText)
                            Text("—")
                                .font(.snapOverviewAmount)
                                .foregroundColor(.secondaryText)
                                .snapOverviewFittingLine()
                        }
                    }
                    .layoutPriority(1)
                    
                    if isEditingOrder {
                        SectionDragHandle()
                    } else {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding()
                .snapCappedDynamicTypeSize()
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
                                totalAssetsDenominator: totalAssetsDenominator,
                                currencyDisplay: currencyDisplay,
                                baseCurrency: baseCurrency,
                                twdPerBaseCurrency: twdPerBaseCurrency,
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
                .frame(width: SnapOverviewBarMetrics.overviewWidth)
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
    let totalAssetsDenominator: Decimal
    let currencyDisplay: AssetsCurrencyDisplay
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let isBalanceLoading: Bool
    var showsArchivedBadge: Bool = false
    
    private var showLoadingPlaceholder: Bool {
        isBalanceLoading && balance == nil
    }

    private var sharePercent: Decimal {
        let twd = AccountListAmountDisplay.accountValueTWD(account: account, balance: balance)
        let numerator = TotalAssetsShareCalculator.displayAmount(
            fromTWD: twd,
            twdPerBaseCurrency: twdPerBaseCurrency
        )
        return TotalAssetsShareCalculator.sharePercentFromDisplay(
            numeratorDisplay: numerator,
            totalAssetsDisplay: totalAssetsDenominator
        )
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                ManagementRowLeadingIndicator(
                    currency: account.currency,
                    accentColor: account.accountType.color,
                    sharePercent: sharePercent
                )

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
                    .frame(width: SnapOverviewBarMetrics.detailWidth)
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
                .fontWeight(.bold)
                .foregroundColor(.secondaryText)
        } else if account.accountType == .debt || account.accountType == .otherDebt, let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay,
                baseCurrency: baseCurrency,
                twdPerBaseCurrency: twdPerBaseCurrency
            )
            CurrencyAmountWithChip(
                text: display.amount.formatted(currency: display.currency),
                currency: display.currency,
                font: .snapAmountRow,
                weight: .bold,
                color: .lossRed,
                chipTint: account.accountType.color
            )
        } else if account.accountType == .twdDeposit, let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay,
                baseCurrency: baseCurrency,
                twdPerBaseCurrency: twdPerBaseCurrency
            )
            CurrencyAmountWithChip(
                text: display.amount.formatted(currency: display.currency),
                currency: display.currency,
                font: .snapAmountRow,
                weight: .bold,
                color: .primaryText,
                chipTint: account.accountType.color
            )
        } else if let balance {
            let display = AccountListAmountDisplay.cardAmount(
                account: account,
                balance: balance,
                currencyDisplay: currencyDisplay,
                baseCurrency: baseCurrency,
                twdPerBaseCurrency: twdPerBaseCurrency
            )
            CurrencyAmountWithChip(
                text: display.amount.formatted(currency: display.currency),
                currency: display.currency,
                font: .snapAmountRow,
                weight: .bold,
                color: .primaryText,
                chipTint: account.accountType.color
            )
        } else {
            Text("—")
                .font(.snapAmountRow)
                .fontWeight(.bold)
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
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accountType.displayName)
                            .font(.snapOverviewText)
                            .foregroundColor(.primaryText)
                            .snapOverviewFittingLine()
                        
                        Text("\(liabilities.count)個帳戶")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .layoutPriority(1)
                    
                    Spacer(minLength: 8)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("類別總債務")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        categoryOverviewAmountChip(
                            amount: -totalDebt,
                            currency: .TWD,
                            color: .lossRed,
                            chipTint: .lossRed
                        )
                    }
                    .layoutPriority(1)
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding()
                .snapCappedDynamicTypeSize()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(liabilities) { liability in
                        NavigationLink(destination: LiabilityDetailView(liability: liability)) {
                            DebtCardView(liability: liability)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
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
                .frame(width: SnapOverviewBarMetrics.overviewWidth)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
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
                CurrencyAmountLabel(
                    text: negativeBalance.formatted(currency: liability.currency),
                    currency: liability.currency,
                    font: .snapAmountRow,
                    weight: .bold,
                    color: .lossRed,
                    chipTint: .lossRed
                )
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lossRed)
                .frame(width: SnapOverviewBarMetrics.detailWidth)
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

