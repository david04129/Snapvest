//
//  AccountDetailView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

private struct DebtRepaymentSheetItem: Identifiable {
    let id = UUID()
    let liability: Liability
    let accounts: [Account]
    let repaymentType: RepaymentType
}

struct AccountDetailView: View {
    let account: Account
    let refreshToken: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AccountDetailViewModel
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var assetsViewModel: AssetsViewModel
    @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
    @State private var showingAdjustCashBalance = false
    @State private var showingRepayment = false
    @State private var repaymentSheetItem: DebtRepaymentSheetItem?
    @State private var currentLiability: Liability?
    @State private var isDetailsExpanded: Bool = false
    @State private var showTransactionHistory = false
    @State private var selectedHolding: HoldingNavigationItem?
    @State private var isLoadingHoldingDetail = false
    @State private var showArchiveConfirmation = false
    @State private var archiveErrorMessage: String?
    @State private var isArchiving = false
    @State private var displayAccountName: String
    @State private var showingRenameSheet = false
    @State private var otherDebtRemaining: Decimal = 0
    @State private var otherDebtRepaid: Decimal = 0
    @State private var showingOtherDebtRepayment = false
    @State private var showingTransactionImport = false
    @State private var showingNewTradeFlow = false
    @State private var isPaywallPresented = false
    @State private var twdPerAccountCurrency: Decimal
    @StateObject private var importTransactionsViewModel = TransactionsViewModel()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    init(
        account: Account,
        prefilledBalance: AccountBalanceDisplay? = nil,
        initialDisplayCurrency: Currency? = nil,
        refreshToken: Int = 0
    ) {
        self.account = account
        self.refreshToken = refreshToken
        _displayAccountName = State(initialValue: account.name)
        _twdPerAccountCurrency = State(
            initialValue: Self.initialTwdPerAccountCurrency(for: account)
        )
        let vm = AccountDetailViewModel()
        if let prefilledBalance {
            vm.applyPrefill(prefilledBalance)
        }
        if let cachedHoldings = AccountDetailPresentationStore.holdings(for: account.id), !cachedHoldings.isEmpty {
            vm.applyCachedHoldings(cachedHoldings, account: account)
        }
        vm.displayCurrency = initialDisplayCurrency ?? (account.currency == .TWD ? .TWD : account.currency)
        _viewModel = StateObject(wrappedValue: vm)
    }

    private static func initialTwdPerAccountCurrency(for account: Account) -> Decimal {
        if account.currency == .TWD { return 1 }
        return ExchangeRateSessionCache.twdPer(account.currency) ?? 0
    }
    
    var body: some View {
        Group {
            if account.accountType == .debt {
                debtAccountView
            } else if account.accountType == .otherDebt {
                otherDebtAccountView
            } else {
                regularAccountView
            }
        }
        .navigationBarBackButtonHidden(true)
        .enableNavigationSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                SnapToolbarIconButton(icon: .back) { dismiss() }
            }
        }
        .navigationDestination(isPresented: $showTransactionHistory) {
            TransactionHistoryView(account: account)
        }
        .navigationDestination(item: $selectedHolding) { item in
            HoldingDetailView(
                aggregatedHolding: item.aggregatedHolding,
                assetPriceSnapshot: item.assetPriceSnapshot,
                totalAssets: item.totalAssets,
                totalInvestments: item.totalInvestments,
                initialUsdToTwdRate: viewModel.exchangeRate,
                initialTwdPerBaseCurrency: portfolioViewModel.twdPerBaseCurrency
            )
            .id(item)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { notification in
            Task {
                await refreshAfterPortfolioMutation(
                    appliesPersistedState: notification.userInfo?[SnapshotUpdateUserInfoKey.alreadyApplied] as? Bool != true
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { notification in
            if let affectedAccountIds = notification.userInfo?[PortfolioMutationUserInfoKey.affectedAccountIds] as? [String],
               !affectedAccountIds.contains(account.id) {
                return
            }
            let appliesPersistedState = !(notification.object is PortfolioMutationRefreshRequest)
            Task {
                await refreshAfterPortfolioMutation(appliesPersistedState: appliesPersistedState)
            }
        }
        .onChange(of: refreshToken) { _, _ in
            Task {
                await refreshAfterPortfolioMutation(appliesPersistedState: false)
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameAccountSheet(
                viewModel: accountsViewModel,
                accountId: account.id,
                userId: account.userId,
                accountType: account.accountType,
                initialName: displayAccountName
            ) { newName in
                displayAccountName = newName
                if account.accountType == .debt, var liability = currentLiability {
                    liability.name = newName
                    currentLiability = liability
                }
            }
        }
    }
    
    @ViewBuilder
    private func accountNameTitleRow(name: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Button {
                showingRenameSheet = true
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appPrimary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新命名帳戶")
        }
    }
    
    // MARK: - 一般帳戶視圖
    private var regularAccountView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if account.currency != portfolioViewModel.viewCurrency {
                    HStack {
                        Spacer(minLength: 0)
                        AccountsCurrencyControlsBar(currencyDisplay: accountCurrencyDisplayBinding)
                    }
                }
                
                accountHeroCard

                if account.accountType == .twdDeposit {
                    accountTransactionHistorySection
                } else if account.accountType.showsInvestmentHoldingsOnDetail {
                    accountCashHoldingsMetricsRow
                    accountHoldingsSection
                    accountTransactionHistorySection
                } else {
                    accountCashHoldingsMetricsRow
                    accountHoldingsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.mainBackground)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if account.accountType.supportsTransactionImport {
                        TransactionImportToolbarChip {
                            if PlusFeatureGate.canUseImport(isPlusActive: subscriptionManager.isPlusActive) {
                                showingTransactionImport = true
                            } else {
                                isPaywallPresented = true
                            }
                        }
                    }
                    if !account.accountType.showsInlineTransactionHistory {
                        TransactionHistoryToolbarChip {
                            showTransactionHistory = true
                        }
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            accountDetailBottomBar
        }
        .sheet(isPresented: $showingNewTradeFlow) {
            NewTradeFlowView(sourceAccount: account) { _, _ in
                Task {
                    await viewModel.refresh(accountId: account.id, account: account)
                    await accountsViewModel.loadAccounts(userId: account.userId)
                }
            }
        }
        .sheet(isPresented: $showingAdjustCashBalance) {
            AdjustCashBalanceView(
                account: account,
                viewModel: viewModel,
                currentBalance: viewModel.cashBalance
            )
        }
        .sheet(isPresented: $showingTransactionImport) {
            TransactionImportView(account: account, viewModel: importTransactionsViewModel) {
                Task {
                    await viewModel.refresh(accountId: account.id, account: account)
                    await accountsViewModel.loadAccounts(userId: account.userId)
                }
            }
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            WalleafPlusPaywallView()
        }
        .task {
            await loadAccountCurrencyRateIfNeeded()
            await viewModel.loadFromPersisted(accountId: account.id, account: account)
            if account.accountType.supportsTransactionImport {
                await importTransactionsViewModel.loadTransactions(userId: account.userId)
            }
        }
    }
    
    private func navigateToHoldingDetail(_ holding: HoldingSnapshot) {
        let assetType = holding.holding.assetType
        let symbol = holding.holding.symbol

        if let aggregated = assetsViewModel.aggregatedHoldings.first(where: {
            $0.assetType == assetType && $0.symbol == symbol
        }) {
            selectedHolding = holdingNavigationItem(for: aggregated)
            return
        }

        guard !isLoadingHoldingDetail else { return }
        isLoadingHoldingDetail = true
        Task {
            defer { isLoadingHoldingDetail = false }
            do {
                if let item = try await HoldingNavigationBuilder.loadFromPersisted(
                    userId: account.userId,
                    assetType: assetType,
                    symbol: symbol
                ) {
                    selectedHolding = item
                }
            } catch {
                // 無法載入合併持股時靜默略過
            }
        }
    }

    private func holdingNavigationItem(for aggregated: AggregatedHoldingSnapshot) -> HoldingNavigationItem {
        HoldingNavigationBuilder.make(
            aggregatedHolding: aggregated,
            assetPriceSnapshots: assetsViewModel.assetPriceSnapshots,
            totalAssets: assetsViewModel.totalAssets,
            totalInvestments: assetsViewModel.totalInvestments
        )
    }

    private func refreshSelectedHoldingIfNeeded() async {
        guard let current = selectedHolding else { return }

        do {
            if let freshItem = try await HoldingNavigationBuilder.loadFromPersisted(
                userId: account.userId,
                assetType: current.aggregatedHolding.assetType,
                symbol: current.aggregatedHolding.symbol
            ) {
                if freshItem != current {
                    selectedHolding = freshItem
                }
            } else {
                selectedHolding = nil
            }
        } catch {
            if let updated = assetsViewModel.aggregatedHoldings.first(where: { $0.id == current.id }) {
                let newItem = holdingNavigationItem(for: updated)
                if newItem != current {
                    selectedHolding = newItem
                }
            } else {
                selectedHolding = nil
            }
        }
    }

    @MainActor
    private func refreshAfterPortfolioMutation(appliesPersistedState: Bool) async {
        if appliesPersistedState {
            await LaunchCoordinator.applyPersistedState(
                userId: account.userId,
                portfolioViewModel: portfolioViewModel,
                accountsViewModel: accountsViewModel,
                assetsViewModel: assetsViewModel,
                rebuildAccountDetailCache: true,
                accountDetailCacheAccountIds: [account.id]
            )
        }

        if account.accountType == .debt {
            await loadDebtAccountData()
        } else if account.accountType == .otherDebt {
            await loadOtherDebtAccountData()
        } else {
            await loadAccountCurrencyRateIfNeeded()
            await viewModel.refresh(accountId: account.id, account: account)
        }
        if let updated = accountsViewModel.accounts.first(where: { $0.id == account.id }) {
            displayAccountName = updated.name
        }
        await refreshSelectedHoldingIfNeeded()
    }
    
    private var accountTransactionHistorySection: some View {
        AccountTransactionHistorySection(
            account: account,
            showFullTransactionHistory: $showTransactionHistory
        ) {
            await refreshRegularAccountDetail()
        }
    }

    @MainActor
    private func refreshRegularAccountDetail() async {
        await loadAccountCurrencyRateIfNeeded()
        await viewModel.refresh(accountId: account.id, account: account)
        await accountsViewModel.loadAccounts(userId: account.userId)
    }

    @ViewBuilder
    private var accountHoldingsSection: some View {
        if account.accountType != .twdDeposit {
            if viewModel.isLoading && viewModel.holdings.isEmpty && viewModel.holdingsValue > 0 {
                AccountHoldingsLoadingSection()
            } else if !viewModel.holdings.isEmpty {
                AccountHoldingsTableSection(
                    holdings: viewModel.holdings,
                    displayCurrency: viewModel.displayCurrency,
                    exchangeRate: viewModel.exchangeRate,
                    twdPerDisplayCurrency: displayCurrencyTWDValue,
                    onHoldingTap: { holding in
                        navigateToHoldingDetail(holding)
                    }
                )
            }
        }
    }
    
    // MARK: - 一般帳戶：顯示用計算
    
    private var accountDisplayCashBalance: Decimal {
        convertAccountAmount(viewModel.cashBalance, to: viewModel.displayCurrency)
    }
    
    private var accountDisplayHoldingsValue: Decimal {
        convertAccountAmount(viewModel.holdingsValue, to: viewModel.displayCurrency)
    }
    
    private var accountTotalValue: Decimal {
        accountDisplayCashBalance + accountDisplayHoldingsValue
    }
    
    private var accountHeroPrimaryLabel: String {
        account.accountType == .twdDeposit ? "現金餘額" : "帳戶總資產"
    }
    
    private var accountHeroPrimaryAmount: Decimal {
        account.accountType == .twdDeposit ? accountDisplayCashBalance : accountTotalValue
    }

    private var accountAmountsDisplayReady: Bool {
        if account.currency == .TWD { return true }
        if viewModel.displayCurrency == account.currency { return true }
        if account.currency == .USD, viewModel.exchangeRate > 0 { return true }
        return twdPerAccountCurrency > 0
    }

    private func accountFormattedAmount(_ amount: Decimal) -> String {
        guard accountAmountsDisplayReady else { return "—" }
        return amount.formatted(currency: viewModel.displayCurrency)
    }
    
    private var accountCurrencyDisplayBinding: Binding<AssetsCurrencyDisplay> {
        Binding(
            get: {
                viewModel.displayCurrency == portfolioViewModel.viewCurrency ? .twd : .original
            },
            set: { newValue in
                withAnimation(ChartMotion.switchSpring) {
                    viewModel.displayCurrency = newValue == .twd ? portfolioViewModel.viewCurrency : account.currency
                }
            }
        )
    }

    private var displayCurrencyTWDValue: Decimal {
        if viewModel.displayCurrency == .TWD { return 1 }
        if viewModel.displayCurrency == account.currency { return twdPerAccountCurrency }
        if viewModel.displayCurrency == portfolioViewModel.viewCurrency { return portfolioViewModel.twdPerBaseCurrency }
        if viewModel.displayCurrency == .USD { return viewModel.exchangeRate }
        return 1
    }

    private func convertAccountAmount(_ amount: Decimal, to targetCurrency: Currency) -> Decimal {
        guard account.currency != targetCurrency else { return amount }
        let twdAmount: Decimal
        if account.currency == .TWD {
            twdAmount = amount
        } else if account.currency == .USD, viewModel.exchangeRate > 0 {
            twdAmount = amount * viewModel.exchangeRate
        } else if twdPerAccountCurrency > 0 {
            twdAmount = amount * twdPerAccountCurrency
        } else {
            return amount
        }

        if targetCurrency == .TWD { return twdAmount }
        if targetCurrency == portfolioViewModel.viewCurrency,
           portfolioViewModel.twdPerBaseCurrency > 0 {
            return twdAmount / portfolioViewModel.twdPerBaseCurrency
        }
        if targetCurrency == .USD, viewModel.exchangeRate > 0 {
            return twdAmount / viewModel.exchangeRate
        }
        return amount
    }

    @MainActor
    private func loadAccountCurrencyRateIfNeeded() async {
        if account.currency == .TWD {
            twdPerAccountCurrency = 1
            return
        }
        if let cached = ExchangeRateSessionCache.twdPer(account.currency) {
            twdPerAccountCurrency = cached
            if account.currency == .USD, viewModel.exchangeRate <= 0 {
                viewModel.exchangeRate = cached
            }
            return
        }
        if account.currency == .USD, viewModel.exchangeRate > 0 {
            twdPerAccountCurrency = viewModel.exchangeRate
            ExchangeRateSessionCache.mergeTwdRate(currency: .USD, rate: viewModel.exchangeRate)
            return
        }
        if account.currency == portfolioViewModel.viewCurrency,
           portfolioViewModel.twdPerBaseCurrency > 0 {
            twdPerAccountCurrency = portfolioViewModel.twdPerBaseCurrency
            ExchangeRateSessionCache.mergeTwdRate(currency: account.currency, rate: portfolioViewModel.twdPerBaseCurrency)
            return
        }
        if let rate = try? await MockDataService.shared.fetchExchangeRate(from: account.currency, to: .TWD, date: nil)?.rate,
           rate > 0 {
            twdPerAccountCurrency = rate
        }
    }
    
    private var accountHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    accountNameTitleRow(name: displayAccountName)
                }
                Spacer()
                Text(account.accountType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(account.accountType.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(account.accountType.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                CurrencyIconBadge(
                    currency: account.currency,
                    tint: account.accountType.color,
                    showsLabel: true
                )
                .padding(.bottom, 4)

                Text(accountHeroPrimaryLabel)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                CurrencyAmountWithChip(
                    text: accountFormattedAmount(accountHeroPrimaryAmount),
                    currency: viewModel.displayCurrency,
                    font: .snapAmountHero,
                    weight: .bold,
                    color: .primaryText,
                    chipTint: account.accountType.color
                )
            }
            
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(account.accountType.color)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var accountCashHoldingsMetricsRow: some View {
        if account.accountType == .twdDeposit {
            EmptyView()
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                MetricTile(
                    title: "現金餘額",
                    value: accountFormattedAmount(accountDisplayCashBalance),
                    currency: viewModel.displayCurrency
                )
                MetricTile(
                    title: "持股市值",
                    value: accountFormattedAmount(accountDisplayHoldingsValue),
                    currency: viewModel.displayCurrency
                )
            }
        }
    }
    
    @ViewBuilder
    private var accountDetailBottomBar: some View {
        HStack(spacing: 12) {
            if account.accountType.supportsStockTrading {
                Button(action: {
                    showingNewTradeFlow = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增交易")
                    }
                    .font(.headline)
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.profitGreen)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: {
                showingAdjustCashBalance = true
            }) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                    Text("調整餘額")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
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
    
    // MARK: - 債務帳戶視圖
    private var debtAccountView: some View {
        ScrollView {
            VStack(spacing: 16) {
                debtAccountHeader
                
                if let liability = currentLiability {
                    debtAccountMetricsGrid(liability: liability)
                    
                    RepaymentProgressCard(liability: liability)

                    AccountTransactionHistorySection(
                        account: liveDebtAccount,
                        showFullTransactionHistory: $showTransactionHistory
                    ) {
                        await loadDebtAccountData()
                    }
                    
                    DetailsCard(
                        liability: liability,
                        isExpanded: $isDetailsExpanded
                    )
                    
                    RepaymentInfoCard(liability: liability)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.mainBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .safeAreaInset(edge: .bottom) {
            debtAccountBottomButtons
        }
        .sheet(item: $repaymentSheetItem, onDismiss: {
            Task {
                await loadDebtAccountData()
            }
        }) { item in
            RepaymentView(
                liability: item.liability,
                repaymentType: item.repaymentType,
                preloadedAccounts: item.accounts
            )
        }
        .task {
            await loadDebtAccountData()
        }
        .alert("封存帳戶", isPresented: $showArchiveConfirmation) {
            Button("取消", role: .cancel) {}
            Button("封存", role: .destructive) {
                Task { await performArchiveDebtAccount() }
            }
        } message: {
            Text("封存後將自帳戶列表隱藏，還款紀錄會保留。若要完全移除，可於帳戶列表左滑刪除。確定要封存「\(liveDebtAccount.name)」嗎？")
        }
        .alert("無法封存", isPresented: Binding(
            get: { archiveErrorMessage != nil },
            set: { if !$0 { archiveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(archiveErrorMessage ?? "")
        }
    }
    
    private var liveDebtAccount: Account {
        accountsViewModel.accounts.first(where: { $0.id == account.id }) ?? account
    }
    
    private var isDebtArchived: Bool {
        liveDebtAccount.isArchived
    }
    
    private var canArchiveDebtAccount: Bool {
        guard let liability = currentLiability else { return false }
        return DebtAccountArchive.canArchive(debtAccount: liveDebtAccount, liability: liability).allowed
    }
    
    // MARK: - 債務帳戶標題
    private var debtAccountHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    accountNameTitleRow(name: displayAccountName)
                }
                Spacer()
                if isDebtArchived {
                    Text("已封存")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondaryBackground)
                        .clipShape(Capsule())
                } else {
                    Text(account.accountType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(account.accountType.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(account.accountType.color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(account.accountType.color)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private func debtAccountMetricsGrid(liability: Liability) -> some View {
        let paidAmount = liability.totalPaidPrincipal + liability.totalPaidInterest
        
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "剩餘本金",
                value: liability.remainingBalance.formatted(currency: liability.currency),
                currency: liability.currency,
                valueColor: .lossRed
            )
            MetricTile(
                title: "已還款（含息）",
                value: paidAmount.formatted(currency: liability.currency),
                currency: liability.currency,
                valueColor: .profitGreen
            )
        }
    }
    
    // MARK: - 債務帳戶底部按鈕
    @ViewBuilder
    private var debtAccountBottomButtons: some View {
        if isDebtArchived {
            archivedDebtBottomNotice
        } else if canArchiveDebtAccount {
            archiveDebtBottomBar
        } else {
            debtRepaymentBottomButtons
        }
    }
    
    private var debtRepaymentBottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                presentRepaymentSheet(type: .prepayment)
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("提前還款")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.lossRed)
                .cornerRadius(12)
            }
            
            Button(action: {
                presentRepaymentSheet(type: .regular)
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text("定期還款")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
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
    
    private var archiveDebtBottomBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                showArchiveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                    Text("封存帳戶")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isArchiving)
            Spacer(minLength: 0)
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
    
    private var archivedDebtBottomNotice: some View {
        Text("此債務帳戶已封存，僅供查閱紀錄。若要完全移除，可於帳戶列表左滑刪除。")
            .font(.subheadline)
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.mainBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.separator.opacity(0.3)),
                alignment: .top
            )
    }
    
    private func performArchiveDebtAccount() async {
        isArchiving = true
        defer { isArchiving = false }
        if let error = await accountsViewModel.archiveDebtAccount(liveDebtAccount) {
            archiveErrorMessage = error
        } else {
            dismiss()
        }
    }
    
    private func loadOtherDebtAccountData() async {
        if let updated = accountsViewModel.accounts.first(where: { $0.id == account.id }) {
            displayAccountName = updated.name
        }
        do {
            let transactions = try await MockDataService.shared.fetchAllTransactions(userId: account.userId)
            let remaining = OtherDebtCalculator.remainingBalance(
                accountId: account.id,
                transactions: transactions,
                accounts: accountsViewModel.accounts
            )
            let repaid = OtherDebtCalculator.totalRepaid(
                accountId: account.id,
                transactions: transactions,
                accounts: accountsViewModel.accounts
            )
            await MainActor.run {
                otherDebtRemaining = remaining
                otherDebtRepaid = repaid
            }
        } catch {
            await MainActor.run {
                otherDebtRemaining = 0
                otherDebtRepaid = 0
            }
        }
    }
    
    // MARK: - 其他債務帳戶視圖
    private var otherDebtAccountView: some View {
        ScrollView {
            VStack(spacing: 16) {
                otherDebtAccountHeader
                otherDebtMetricsGrid
                AccountTransactionHistorySection(
                    account: liveOtherDebtAccount,
                    showFullTransactionHistory: $showTransactionHistory
                ) {
                    await loadOtherDebtAccountData()
                }
                OtherDebtInfoCard(account: liveOtherDebtAccount)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.mainBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.appPrimary)
        .safeAreaInset(edge: .bottom) {
            otherDebtBottomButtons
        }
        .sheet(isPresented: $showingOtherDebtRepayment, onDismiss: {
            Task { await loadOtherDebtAccountData() }
        }) {
            OtherDebtRepaymentView(
                debtAccount: liveOtherDebtAccount,
                prefilledAccounts: accountsViewModel.accounts
            )
        }
        .task {
            await loadOtherDebtAccountData()
        }
        .alert("封存帳戶", isPresented: $showArchiveConfirmation) {
            Button("取消", role: .cancel) {}
            Button("封存", role: .destructive) {
                Task { await performArchiveOtherDebtAccount() }
            }
        } message: {
            Text("封存後將自帳戶列表隱藏，還款紀錄會保留。若要完全移除，可於帳戶列表左滑刪除。確定要封存「\(liveOtherDebtAccount.name)」嗎？")
        }
        .alert("無法封存", isPresented: Binding(
            get: { archiveErrorMessage != nil },
            set: { if !$0 { archiveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(archiveErrorMessage ?? "")
        }
    }
    
    private var otherDebtAccountHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    accountNameTitleRow(name: displayAccountName)
                }
                Spacer()
                if liveOtherDebtAccount.isArchived {
                    Text("已封存")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondaryBackground)
                        .clipShape(Capsule())
                } else {
                    Text(AccountType.otherDebt.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AccountType.otherDebt.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AccountType.otherDebt.color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(AccountType.otherDebt.color)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
    
    private var otherDebtMetricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "目前欠款",
                value: otherDebtRemaining.formatted(currency: liveOtherDebtAccount.currency),
                currency: liveOtherDebtAccount.currency,
                valueColor: .lossRed
            )
            MetricTile(
                title: "已還總額",
                value: otherDebtRepaid.formatted(currency: liveOtherDebtAccount.currency),
                currency: liveOtherDebtAccount.currency,
                valueColor: .profitGreen
            )
        }
    }
    
    private var otherDebtRepaymentBottomButtons: some View {
        HStack(spacing: 12) {
            Button { showingOtherDebtRepayment = true } label: {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text("還款")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
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
    
    private var liveOtherDebtAccount: Account {
        accountsViewModel.accounts.first(where: { $0.id == account.id }) ?? account
    }
    
    private var canArchiveOtherDebtAccount: Bool {
        otherDebtRemaining <= DebtAccountArchive.balanceTolerance && !liveOtherDebtAccount.isArchived
    }
    
    @ViewBuilder
    private var otherDebtBottomButtons: some View {
        if liveOtherDebtAccount.isArchived {
            archivedDebtBottomNotice
        } else if canArchiveOtherDebtAccount {
            archiveDebtBottomBar
        } else {
            otherDebtRepaymentBottomButtons
        }
    }
    
    private func performArchiveOtherDebtAccount() async {
        isArchiving = true
        defer { isArchiving = false }
        if let error = await accountsViewModel.archiveOtherDebtAccount(liveOtherDebtAccount) {
            archiveErrorMessage = error
        } else {
            dismiss()
        }
    }
    
    // MARK: - 載入債務帳戶數據
    private func presentRepaymentSheet(type: RepaymentType) {
        guard let liability = currentLiability else { return }
        repaymentSheetItem = DebtRepaymentSheetItem(
            liability: liability,
            accounts: accountsViewModel.accounts,
            repaymentType: type
        )
    }
    
    private func loadDebtAccountData() async {
        if let updated = accountsViewModel.accounts.first(where: { $0.id == account.id }) {
            displayAccountName = updated.name
        }

        guard account.accountType == .debt else { return }
        let debtName = displayAccountName

        if portfolioViewModel.liabilities.isEmpty {
            await portfolioViewModel.reloadLiabilities(userId: account.userId)
        }

        if let liability = portfolioViewModel.liabilities.first(where: { $0.name == debtName }) {
            currentLiability = liability
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

// MARK: - 帳戶／債務詳情區塊卡（與指標格同款邊框，全寬）
struct AccountSectionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
            )
    }
}

// MARK: - 帳戶詳情：持股明細載入占位
struct AccountHoldingsLoadingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("持股明細")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text("載入中…")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondaryBackground)
                .frame(minHeight: 120)
                .overlay {
                    ProgressView()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.separator.opacity(0.5), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 帳戶詳情：持股明細列表
struct AccountHoldingsTableSection: View {
    let holdings: [HoldingSnapshot]
    let displayCurrency: Currency
    let exchangeRate: Decimal
    let twdPerDisplayCurrency: Decimal
    let onHoldingTap: (HoldingSnapshot) -> Void
    
    @State private var marketValueSort: HoldingsMarketValueSort = .descending
    
    private func displayMarketValue(for holding: HoldingSnapshot) -> Decimal? {
        guard let marketValue = holding.marketValue else { return nil }
        return convertAmount(marketValue, from: holding.holding.currency)
    }

    private func convertAmount(_ amount: Decimal, from sourceCurrency: Currency) -> Decimal {
        guard sourceCurrency != displayCurrency else { return amount }
        let twdAmount: Decimal
        if sourceCurrency == .TWD {
            twdAmount = amount
        } else if sourceCurrency == .USD, exchangeRate > 0 {
            twdAmount = amount * exchangeRate
        } else {
            return amount
        }

        guard displayCurrency != .TWD,
              twdPerDisplayCurrency > 0 else {
            return twdAmount
        }
        return twdAmount / twdPerDisplayCurrency
    }
    
    private func symbolSortKey(_ holding: HoldingSnapshot) -> String {
        switch holding.holding.assetType {
        case .stockUS, .crypto:
            return holding.holding.symbol.uppercased()
        default:
            return holding.holding.symbol
        }
    }
    
    private var sortedHoldings: [HoldingSnapshot] {
        holdings.sorted { lhs, rhs in
            let leftValue = displayMarketValue(for: lhs)
            let rightValue = displayMarketValue(for: rhs)
            
            switch (leftValue, rightValue) {
            case (nil, nil):
                return symbolSortKey(lhs) < symbolSortKey(rhs)
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (left?, right?):
                if left != right {
                    switch marketValueSort {
                    case .descending: return left > right
                    case .ascending: return left < right
                    }
                }
                return symbolSortKey(lhs) < symbolSortKey(rhs)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("持股明細")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text("\(holdings.count) 檔")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                AssetsFilterChipButton(
                    title: "市值",
                    icon: marketValueSort.iconName,
                    isActive: true
                ) {
                    withAnimation(ChartMotion.switchSpring) {
                        marketValueSort.cycle()
                    }
                }
            }
            
            VStack(spacing: 8) {
                ForEach(sortedHoldings) { holding in
                    AccountHoldingCardRow(
                        holding: holding,
                        displayCurrency: displayCurrency,
                        exchangeRate: exchangeRate,
                        twdPerDisplayCurrency: twdPerDisplayCurrency,
                        onTap: { onHoldingTap(holding) }
                    )
                }
            }
            .animation(ChartMotion.switchSpring, value: marketValueSort)
        }
    }
}

// MARK: - 帳戶持股卡片列（與資產 Tab 列表同款）
struct AccountHoldingCardRow: View {
    let holding: HoldingSnapshot
    let displayCurrency: Currency
    let exchangeRate: Decimal
    let twdPerDisplayCurrency: Decimal
    let onTap: () -> Void
    
    private var assetAccentColor: Color {
        switch holding.holding.assetType {
        case .stockTW: return .stockTWColor
        case .stockUS: return .stockUSColor
        case .crypto: return .cryptoColor
        case .cash: return .appPrimary
        }
    }
    
    private func convertAmount(_ amount: Decimal, from sourceCurrency: Currency) -> Decimal {
        guard sourceCurrency != displayCurrency else { return amount }
        let twdAmount: Decimal
        if sourceCurrency == .TWD {
            twdAmount = amount
        } else if sourceCurrency == .USD && exchangeRate > 0 {
            twdAmount = amount * exchangeRate
        } else {
            return amount
        }

        guard displayCurrency != .TWD,
              twdPerDisplayCurrency > 0 else {
            return twdAmount
        }
        return twdAmount / twdPerDisplayCurrency
    }
    
    private var displayMarketValue: Decimal? {
        guard let marketValue = holding.marketValue else { return nil }
        return convertAmount(marketValue, from: holding.holding.currency)
    }
    
    private var displayGainLoss: Decimal? {
        guard let gainLoss = holding.unrealizedGainLoss else { return nil }
        return convertAmount(gainLoss, from: holding.holding.currency)
    }
    
    private var quantitySubtitle: String {
        let assetType = holding.holding.assetType
        let maxFractionDigits = assetType == .crypto ? 8 : 4
        let formatted = holding.holding.quantity.formattedQuantityInput(maxFractionDigits: maxFractionDigits)
        if assetType == .crypto {
            return "持有 \(formatted)"
        }
        return "持有 \(formatted) 股"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    Text(quantitySubtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer(minLength: 8)
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let displayValue = displayMarketValue {
                        CurrencyAmountWithChip(
                            text: displayValue.formatted(currency: displayCurrency),
                            currency: displayCurrency,
                            font: .snapAmountRow,
                            weight: .semibold,
                            color: .primaryText,
                            chipTint: assetAccentColor
                        )
                    } else {
                        Text("—")
                            .font(.snapAmountRow)
                            .foregroundColor(.secondaryText)
                    }
                    
                    if let displayGainLoss = displayGainLoss,
                       let percent = holding.unrealizedGainLossPercent {
                        HStack(spacing: 4) {
                            Image(systemName: MarketDirectionSymbol.systemName(for: displayGainLoss))
                                .font(.caption2)
                            Text(displayGainLoss.formatted(currency: displayCurrency, showSymbol: false))
                            Text("(\(percent.formatted(fractionDigits: 1))%)")
                        }
                        .font(.caption)
                        .foregroundColor(Color.marketColor(for: displayGainLoss))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondaryText)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(assetAccentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 無圖標的資訊行
struct InfoRowWithoutIcon: View {
    let label: String
    let value: String
    var currency: Currency? = nil
    var valueColor: Color = .primaryText  // 默認為主要文字顏色
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            if let currency {
                CurrencyAmountWithChip(
                    text: value,
                    currency: currency,
                    font: .subheadline,
                    weight: .semibold,
                    color: valueColor,
                    chipTint: valueColor
                )
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor)
            }
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
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("還款進度")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
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
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("詳細資訊")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Spacer(minLength: 0)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // 可折疊內容
                if isExpanded {
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.top, 8)
                        
                        // 第一部分：原始資訊
                        InfoRowWithoutIcon(
                            label: "原始貸款金額",
                            value: liability.principal.formatted(currency: liability.currency),
                            currency: liability.currency
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總還款金額（含利息）",
                            value: liability.totalAmount.formatted(currency: liability.currency),
                            currency: liability.currency
                        )
                        
                        Divider()
                        
                        // 新增：已還款本金（在總還款金額下面）
                        InfoRowWithoutIcon(
                            label: "已還款本金",
                            value: liability.totalPaidPrincipal.formatted(currency: liability.currency),
                            currency: liability.currency
                        )
                        
                        Divider()
                        
                        InfoRowWithoutIcon(
                            label: "總利息",
                            value: liability.totalInterest.formatted(currency: liability.currency),
                            currency: liability.currency
                        )
                        
                        Divider()
                        
                        // 新增：已支出利息（在總利息下面）
                        InfoRowWithoutIcon(
                            label: "已支出利息",
                            value: liability.totalPaidInterest.formatted(currency: liability.currency),
                            currency: liability.currency
                        )
                        
                        // 如果有提前還款，顯示節省利息（在已支出利息下面）
                        if liability.totalSavedInterest > 0 {
                            Divider()
                            
                            InfoRowWithoutIcon(
                                label: "節省利息",
                                value: liability.totalSavedInterest.formatted(currency: liability.currency),
                                currency: liability.currency,
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
                            value: liability.monthlyPayment.formatted(currency: liability.currency),
                            currency: liability.currency
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

// MARK: - 其他債務資訊卡片
struct OtherDebtInfoCard: View {
    let account: Account
    
    var body: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("債務資訊")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("類型")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: account.accountType.icon)
                                .foregroundColor(account.accountType.color)
                                .font(.system(size: 16))
                            Text(account.accountType.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                        }
                    }
                    
                    Divider()
                    
                    InfoRowWithoutIcon(
                        label: "幣別",
                        value: account.currency.rawValue
                    )
                    
                    Divider()
                    
                    InfoRowWithoutIcon(
                        label: "計算方式",
                        value: "手動紀錄欠款"
                    )
                }
            }
        }
    }
}

// MARK: - 還款資訊卡片
struct RepaymentInfoCard: View {
    let liability: Liability
    
    private func calculateRepaymentDay(liability: Liability) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: liability.startDate)
        return "\(day)"
    }
    
    var body: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("還款資訊")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
            VStack(spacing: 16) {
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(account: Account(userId: "test", name: "國泰證券", accountType: .twdSecurities))
            .environmentObject(AccountsViewModel())
            .environmentObject(AssetsViewModel())
            .environmentObject(PortfolioViewModel())
    }
}

