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
    @StateObject private var viewModel: AccountDetailViewModel
    @StateObject private var accountsViewModel = AccountsViewModel()
    @State private var showingAdjustCashBalance = false
    @State private var showingRepayment = false
    @State private var repaymentSheetItem: DebtRepaymentSheetItem?
    @State private var currentLiability: Liability?
    @State private var repaymentAccountName: String = ""
    @State private var isDetailsExpanded: Bool = false
    @State private var showTransactionHistory = false
    @State private var selectedHolding: HoldingNavigationItem?
    @State private var isLoadingHoldingDetail = false
    
    init(account: Account, prefilledBalance: AccountBalanceDisplay? = nil) {
        self.account = account
        let vm = AccountDetailViewModel()
        if let prefilledBalance {
            vm.applyPrefill(prefilledBalance)
        }
        vm.displayCurrency = account.currency == .TWD ? .TWD : account.currency
        _viewModel = StateObject(wrappedValue: vm)
    }
    
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
        .navigationDestination(isPresented: $showTransactionHistory) {
            TransactionHistoryView(account: account)
        }
        .navigationDestination(item: $selectedHolding) { item in
            HoldingDetailView(
                aggregatedHolding: item.aggregatedHolding,
                assetPriceSnapshot: item.assetPriceSnapshot,
                totalAssets: item.totalAssets,
                totalInvestments: item.totalInvestments
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapshotsDidUpdate)) { _ in
            Task {
                if account.accountType == .debt {
                    await loadDebtAccountData()
                } else {
                    await viewModel.refresh(accountId: account.id)
                }
            }
        }
    }
    
    // MARK: - 一般帳戶視圖
    private var regularAccountView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if account.currency == .USD {
                    HStack {
                        Spacer(minLength: 0)
                        AccountsCurrencyControlsBar(currencyDisplay: accountCurrencyDisplayBinding)
                    }
                }
                
                accountHeroCard
                
                accountCashHoldingsMetricsRow
                
                accountHoldingsSection
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
                TransactionHistoryToolbarChip {
                    showTransactionHistory = true
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            adjustCashBalanceBottomBar
        }
        .sheet(isPresented: $showingAdjustCashBalance) {
            AdjustCashBalanceView(
                account: account,
                viewModel: viewModel,
                currentBalance: viewModel.cashBalance
            )
        }
        .task {
            await viewModel.loadAccountData(accountId: account.id)
        }
    }
    
    private func navigateToHoldingDetail(_ holding: HoldingSnapshot) {
        guard !isLoadingHoldingDetail else { return }
        isLoadingHoldingDetail = true
        Task {
            defer { isLoadingHoldingDetail = false }
            do {
                if let item = try await HoldingNavigationBuilder.load(
                    userId: account.userId,
                    assetType: holding.holding.assetType,
                    symbol: holding.holding.symbol
                ) {
                    selectedHolding = item
                }
            } catch {
                // 無法載入合併持股時靜默略過
            }
        }
    }
    
    @ViewBuilder
    private var accountHoldingsSection: some View {
        if account.accountType != .twdDeposit {
            if viewModel.isLoading && viewModel.holdings.isEmpty {
                AccountHoldingsLoadingSection()
            } else if !viewModel.holdings.isEmpty {
                AccountHoldingsTableSection(
                    holdings: viewModel.holdings,
                    account: account,
                    displayCurrency: viewModel.displayCurrency,
                    exchangeRate: viewModel.exchangeRate,
                    onHoldingTap: { holding in
                        navigateToHoldingDetail(holding)
                    }
                )
            }
        }
    }
    
    // MARK: - 一般帳戶：顯示用計算
    
    private var accountDisplayCashBalance: Decimal {
        if account.currency == .USD && viewModel.displayCurrency == .TWD {
            return viewModel.cashBalance * viewModel.exchangeRate
        }
        return viewModel.cashBalance
    }
    
    private var accountDisplayHoldingsValue: Decimal {
        if account.currency == .USD && viewModel.displayCurrency == .TWD {
            return viewModel.holdingsValue * viewModel.exchangeRate
        }
        return viewModel.holdingsValue
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
    
    private var accountCurrencyDisplayBinding: Binding<AssetsCurrencyDisplay> {
        Binding(
            get: {
                viewModel.displayCurrency == .TWD ? .twd : .original
            },
            set: { newValue in
                withAnimation(ChartMotion.switchSpring) {
                    viewModel.displayCurrency = newValue == .twd ? .TWD : account.currency
                }
            }
        )
    }
    
    private var accountHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
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
                Text(accountHeroPrimaryLabel)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(accountHeroPrimaryAmount.formatted(currency: viewModel.displayCurrency))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
    
    private var accountCashHoldingsMetricsRow: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricTile(
                title: "現金餘額",
                value: accountDisplayCashBalance.formatted(currency: viewModel.displayCurrency)
            )
            MetricTile(
                title: "持股市值",
                value: accountDisplayHoldingsValue.formatted(currency: viewModel.displayCurrency)
            )
        }
    }
    
    private var adjustCashBalanceBottomBar: some View {
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
                    
                    DetailsCard(
                        liability: liability,
                        isExpanded: $isDetailsExpanded
                    )
                    
                    RepaymentInfoCard(
                        liability: liability,
                        repaymentAccount: accountsViewModel.accounts.first(where: { $0.id == liability.accountId }),
                        repaymentAccountName: repaymentAccountName
                    )
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                TransactionHistoryToolbarChip {
                    showTransactionHistory = true
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
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
    }
    
    // MARK: - 債務帳戶標題
    private var debtAccountHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentLiability?.name ?? account.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
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
                valueColor: .lossRed
            )
            MetricTile(
                title: "已還款（含息）",
                value: paidAmount.formatted(currency: liability.currency),
                valueColor: .profitGreen
            )
        }
    }
    
    // MARK: - 債務帳戶底部按鈕
    private var debtAccountBottomButtons: some View {
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

// MARK: - 帳戶詳情：持有標的載入占位
struct AccountHoldingsLoadingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("持有標的")
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

// MARK: - 帳戶詳情：持有標的表
struct AccountHoldingsTableSection: View {
    let holdings: [HoldingSnapshot]
    let account: Account
    let displayCurrency: Currency
    let exchangeRate: Decimal
    let onHoldingTap: (HoldingSnapshot) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("持有標的")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text("\(holdings.count) 檔")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            VStack(spacing: 0) {
                holdingsTableHeader
                Divider()
                ForEach(Array(holdings.enumerated()), id: \.element.id) { index, holding in
                    HoldingTableRow(
                        holding: holding,
                        account: account,
                        displayCurrency: displayCurrency,
                        exchangeRate: exchangeRate,
                        onTap: { onHoldingTap(holding) }
                    )
                    if index < holdings.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.separator.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    private var holdingsTableHeader: some View {
        HStack(spacing: 8) {
            headerCell("名稱", alignment: .leading)
                .frame(width: 60, alignment: .leading)
            headerCell("數量", alignment: .center)
                .frame(width: 45, alignment: .center)
            Spacer(minLength: 8)
            headerCell("現值", alignment: .trailing)
                .frame(width: 90, alignment: .trailing)
            headerCell("損益", alignment: .trailing)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.tertiaryBackground.opacity(0.6))
    }
    
    private func headerCell(_ title: String, alignment: HorizontalAlignment) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.primaryText.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - 持股表格行
struct HoldingTableRow: View {
    let holding: HoldingSnapshot
    let account: Account
    let displayCurrency: Currency
    let exchangeRate: Decimal
    let onTap: () -> Void
    
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
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(.plain)
    }
    
    private var rowContent: some View {
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
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: displayGainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text(displayGainLoss.formatted(currency: displayCurrency))
                    }
                    .font(.caption)
                    
                    Text("(\(percent.formatted(fractionDigits: 2))%)")
                        .font(.caption2)
                }
                .foregroundColor(Color.marketColor(for: displayGainLoss))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 110, alignment: .trailing)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .frame(width: 110, alignment: .trailing)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
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
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("還款資訊")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(account: Account(userId: "test", name: "國泰證券", accountType: .twdSecurities))
    }
}

