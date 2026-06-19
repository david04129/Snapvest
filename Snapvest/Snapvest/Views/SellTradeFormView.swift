//
//  SellTradeFormView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct SellTradeFormView: View {
    let market: TradeMarket
    let prefill: SellTradePrefill?
    let editingTransaction: Transaction?
    var embedInTradeFlow: Bool = false
    let onSubmit: ((SellTradeDraft) -> Void)?
    var isImportDraftMode: Bool = false
    var onImportDraftSave: ((Transaction) -> Void)? = nil
    var onImportDraftRemove: (() -> Void)? = nil
    
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var accountDetailViewModel = AccountDetailViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    @State private var selectedAccountId: String = ""
    @State private var selectedHoldingId: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var exchangeRateText: String = ""
    @State private var transactionDate: Date = Date()
    @State private var errorMessage: String?
    @State private var userId: String = AppUser.id
    @State private var showingDuplicateAlert = false
    @State private var duplicateAlertMessage = ""
    @State private var sellAccountOptions: [SellAccountOption] = []
    @State private var editBaseline: SellTradeEditBaseline?
    @State private var limitSnapshot: PortfolioLimitSnapshot?
    @State private var isPaywallPresented = false
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    init(
        market: TradeMarket,
        prefill: SellTradePrefill? = nil,
        editingTransaction: Transaction? = nil,
        embedInTradeFlow: Bool = false,
        isImportDraftMode: Bool = false,
        onImportDraftSave: ((Transaction) -> Void)? = nil,
        onImportDraftRemove: (() -> Void)? = nil,
        onSubmit: ((SellTradeDraft) -> Void)? = nil
    ) {
        self.market = market
        self.prefill = prefill
        self.editingTransaction = editingTransaction
        self.embedInTradeFlow = embedInTradeFlow
        self.isImportDraftMode = isImportDraftMode
        self.onImportDraftSave = onImportDraftSave
        self.onImportDraftRemove = onImportDraftRemove
        self.onSubmit = onSubmit
    }
    
    private var isEditMode: Bool { editingTransaction != nil && !isImportDraftMode }
    
    private var submitButtonTitle: String {
        if isImportDraftMode { return "確認" }
        return isEditMode ? "確認修改" : "賣出"
    }
    
    private var marketEligibleAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            switch market {
            case .stockTW:
                return account.accountType == .twdSecurities
            case .stockUS:
                return account.accountType == .usdAccount
            case .crypto:
                return account.accountType == .cryptoWallet
            }
        }
    }

    /// 帶入即鎖定的代號（編輯、個股明細）；不依賴 selectedHolding，避免循環存取
    private var pinnedSymbol: String? {
        if let symbol = editingTransaction?.symbol, !symbol.isEmpty { return symbol }
        if let symbol = prefill?.symbol, !symbol.isEmpty { return symbol }
        return nil
    }

    /// 已確定要賣的標的（鎖定代號，或帳戶詳情選完持股）
    private var effectiveSymbol: String? {
        if let pinned = pinnedSymbol { return pinned }
        guard !selectedHoldingId.isEmpty,
              let snapshot = availableHoldings.first(where: { $0.id == selectedHoldingId }) else {
            return nil
        }
        let symbol = snapshot.holding.symbol
        return symbol.isEmpty ? nil : symbol
    }

    private var showsSellAccountPicker: Bool {
        effectiveSymbol != nil && !isImportDraftMode
    }

    private var canSwitchSellAccount: Bool {
        showsSellAccountPicker && !isAccountLocked && sellAccountOptions.count > 1
    }
    
    private var selectedAccount: Account? {
        sellAccountOptions.map(\.account).first { $0.id == selectedAccountId }
            ?? marketEligibleAccounts.first { $0.id == selectedAccountId }
    }
    
    private var availableHoldings: [HoldingSnapshot] {
        let filtered = accountDetailViewModel.holdings.filter { snapshot in
            snapshot.holding.assetType == market.assetType
        }
        return filtered.sorted { lhs, rhs in
            sortKey(for: lhs.holding) < sortKey(for: rhs.holding)
        }
    }
    
    private var isAccountLocked: Bool {
        isImportDraftMode || prefill?.lockAccount == true
    }
    
    /// 目前帳戶對該標的最多可賣數量（編輯時含加回此筆原賣出量）
    private var maxSellQuantity: Decimal {
        if let option = sellAccountOptions.first(where: { $0.account.id == selectedAccountId }) {
            return option.maxSellQuantity
        }
        let base = selectedHolding?.holding.quantity ?? 0
        if let editingTransaction,
           editingTransaction.accountId == selectedAccountId,
           let effectiveSymbol,
           editingTransaction.symbol == effectiveSymbol {
            return base + editingTransaction.quantity
        }
        return base
    }

    private var requiresComplianceLiquidation: Bool {
        guard let limitSnapshot else { return false }
        return PlusFeatureGate.requiresFullLiquidationSell(
            snapshot: limitSnapshot,
            isPlusActive: subscriptionManager.isPlusActive
        )
    }

    private var isQuantityLockedForCompliance: Bool {
        requiresComplianceLiquidation && !isEditMode
    }

    private var isSymbolLocked: Bool {
        if isEditMode || isImportDraftMode { return true }
        if prefill?.lockSymbol == true, pinnedSymbol != nil { return true }
        return false
    }

    private var showsHoldingPicker: Bool {
        if isEditMode || isImportDraftMode || isSymbolLocked { return false }
        if embedInTradeFlow { return true }
        return effectiveSymbol == nil
    }
    
    /// 持股選單候選（僅依 pinnedSymbol 篩選，避免與 effectiveSymbol 循環）
    private var selectableHoldings: [HoldingSnapshot] {
        guard let symbol = pinnedSymbol else {
            return availableHoldings
        }
        return availableHoldings.filter { $0.holding.symbol == symbol }
    }
    
    private var selectedHolding: HoldingSnapshot? {
        availableHoldings.first { $0.id == selectedHoldingId }
    }

    /// 提交用持股（已選 id，或依目前帳戶＋標的代號解析）
    private var holdingForSubmit: HoldingSnapshot? {
        if let selectedHolding { return selectedHolding }
        guard let symbol = effectiveSymbol else { return nil }
        return availableHoldings.first { $0.holding.symbol == symbol }
    }
    
    private var needsExchangeRate: Bool {
        guard let account = selectedAccount else { return false }
        return priceCurrency != account.currency
    }
    
    private var availableQuantity: Decimal {
        selectedHolding?.holding.quantity ?? 0
    }
    
    private var quantityValue: Decimal? {
        Decimal(string: quantityText)
    }
    
    private var priceValue: Decimal? {
        Decimal(string: priceText)
    }
    
    private var exchangeRateValue: Decimal? {
        Decimal(string: exchangeRateText)
    }

    private var exchangeRateForSave: Decimal? {
        guard needsExchangeRate else { return nil }
        return exchangeRateValue
    }
    
    private var priceCurrency: Currency {
        switch market {
        case .stockTW: return .TWD
        case .stockUS, .crypto: return .USD
        }
    }
    
    /// 賣出金額（交易幣別）
    private var sellProceedsInTradeCurrency: Decimal? {
        guard let qty = quantityValue, let price = priceValue, qty > 0, price > 0 else { return nil }
        return qty * price
    }
    
    /// 入帳金額（帳戶幣別）
    private var sellProceedsInAccountCurrency: Decimal? {
        guard let proceeds = sellProceedsInTradeCurrency else { return nil }
        guard let account = selectedAccount else { return proceeds }
        if priceCurrency == account.currency { return proceeds }
        guard needsExchangeRate, let rate = exchangeRateValue, rate > 0 else { return proceeds }
        return proceeds * rate
    }
    
    private var isValid: Bool {
        guard selectedAccount != nil,
              let quantityValue = quantityValue,
              let priceValue = priceValue,
              quantityValue > 0,
              priceValue > 0 else {
            return false
        }
        
        if isImportDraftMode {
            guard quantityValue > 0, priceValue > 0 else { return false }
            if needsExchangeRate {
                guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else { return false }
            }
            return true
        }
        
        if showsSellAccountPicker {
            guard !sellAccountOptions.isEmpty,
                  sellAccountOptions.contains(where: { $0.account.id == selectedAccountId }),
                  quantityValue <= maxSellQuantity else {
                return false
            }
        } else {
            guard selectedHolding != nil, quantityValue <= maxSellQuantity else { return false }
        }
        
        if needsExchangeRate {
            guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else {
                return false
            }
        }

        if isEditMode {
            return hasEditChanges
        }

        return true
    }

    private var hasEditChanges: Bool {
        guard let baseline = editBaseline else { return true }
        return selectedAccountId != baseline.accountId
            || !EditFormChangeTracking.decimalStringsEqual(quantityText, baseline.quantityText)
            || !EditFormChangeTracking.decimalStringsEqual(priceText, baseline.priceText)
            || !EditFormChangeTracking.decimalStringsEqual(exchangeRateText, baseline.exchangeRateText)
            || !EditFormChangeTracking.datesEqual(transactionDate, baseline.date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TradeFormLayout.scrollSpacing) {
                if !embedInTradeFlow {
                    TradeFormCompactHeader(
                        market: market,
                        actionTitle: "賣出",
                        isEditMode: isEditMode
                    )
                }
                formCard
                errorMessageSection
            }
            .padding(.top, embedInTradeFlow ? 4 : 0)
        }
        .snapFormScrollDismissesKeyboard()
        .background(Color.mainBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: TradeFormLayout.bottomBarSpacing) {
                sellAmountSummary
                if isImportDraftMode {
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            onImportDraftRemove?()
                            dismiss()
                        } label: {
                            Text("移除")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, TradeFormLayout.submitButtonVPadding)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.lossRed)
                        .background(Color.lossRed.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        Button(action: handleSubmit) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                Text("確認")
                            }
                            .font(.headline)
                            .foregroundColor(AppColors.actionForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TradeFormLayout.submitButtonVPadding)
                            .background(isValid ? Color.lossRed : AppColors.disabledBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!isValid)
                    }
                } else {
                    Button(action: handleSubmit) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down")
                            Text(submitButtonTitle)
                        }
                        .font(.headline)
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TradeFormLayout.submitButtonVPadding)
                        .background(isValid ? Color.lossRed : AppColors.disabledBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!isValid)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.mainBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.separator.opacity(0.3)),
                alignment: .top
            )
        }
        .task {
            await accountsViewModel.loadAccounts(userId: userId)
            transactionsViewModel.accounts = accountsViewModel.accounts

            if let preferred = prefill?.preferredAccountId,
               marketEligibleAccounts.contains(where: { $0.id == preferred }) {
                selectedAccountId = preferred
            } else if selectedAccountId.isEmpty, let firstAccount = marketEligibleAccounts.first {
                selectedAccountId = firstAccount.id
            }

            if !selectedAccountId.isEmpty {
                await accountDetailViewModel.loadAccountData(accountId: selectedAccountId)
            }

            if let transaction = editingTransaction {
                applyEditingPrefill(from: transaction)
            } else if showsHoldingPicker {
                applyHoldingPrefill()
            }

            await reloadSellAccountOptionsIfSymbolKnown()
            if showsSellAccountPicker, !selectedAccountId.isEmpty {
                await accountDetailViewModel.loadAccountData(accountId: selectedAccountId)
                syncHoldingSelectionForScopedSymbol()
            }

            if needsExchangeRate && exchangeRateText.isEmpty {
                loadExchangeRate()
            }
            await reloadLimitSnapshot()
            applyComplianceQuantityIfNeeded()
            validateInput()
        }
        .onChange(of: selectedHoldingId) { _, _ in
            Task {
                await reloadSellAccountOptionsIfSymbolKnown()
                if showsSellAccountPicker, !selectedAccountId.isEmpty {
                    await accountDetailViewModel.loadAccountData(accountId: selectedAccountId)
                    syncHoldingSelectionForScopedSymbol()
                }
                applyComplianceQuantityIfNeeded()
                validateInput()
            }
        }
        .onChange(of: quantityText) { _, newValue in
            quantityText = filterDecimalInput(newValue)
            validateInput()
        }
        .onChange(of: priceText) { _, newValue in
            priceText = filterDecimalInput(newValue)
            validateInput()
        }
        .onChange(of: exchangeRateText) { _, newValue in
            exchangeRateText = filterDecimalInput(newValue)
            validateInput()
        }
        .alert("可能重複的交易", isPresented: $showingDuplicateAlert) {
            Button("取消", role: .cancel) { }
            Button("仍要建立", role: .destructive) {
                Task { await finishSubmit(allowDuplicate: true) }
            }
        } message: {
            Text(duplicateAlertMessage)
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            WalleafPlusPaywallView()
        }
    }
    
    @ViewBuilder
    private var sellAmountSummary: some View {
        if let account = selectedAccount, let amount = sellProceedsInAccountCurrency {
            TradeFormAmountSummary(
                label: "預估入帳",
                amountText: amount.formatted(currency: account.currency),
                detailText: sellAmountBreakdownDetail
            )
        } else {
            TradeFormAmountSummary(
                label: "預估入帳",
                amountText: "—",
                detailText: "請填寫數量與價格"
            )
        }
    }
    
    private var sellAmountBreakdownDetail: String? {
        guard let qty = quantityValue, let price = priceValue, qty > 0, price > 0 else { return nil }
        let qtyLabel = qty.formattedQuantityInput(maxFractionDigits: market == .crypto ? 8 : 4)
        let priceLabel = price.formattedTradePrice(currency: priceCurrency)
        return "\(qtyLabel) × \(priceLabel)"
    }
    
    private var formCard: some View {
        VStack(spacing: 0) {
            holdingSection
            if showsSellAccountPicker {
                TradeFormCardDivider()
                sellAccountPickerSection
            } else if isImportDraftMode {
                TradeFormCardDivider()
                importAccountSection
            }
            TradeFormCardDivider()
            priceSection
            TradeFormCardDivider()
            quantitySection
            TradeFormCardDivider()
            if needsExchangeRate {
                TradeFormCardDivider()
                exchangeRateSection
            }
            TradeFormCardDivider()
            dateSection
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: TradeFormLayout.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TradeFormLayout.cardCornerRadius, style: .continuous)
                .stroke(Color.separator.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    /// 匯入草稿仍保留簡易帳戶列
    private var importAccountSection: some View {
        TradeFormRow(title: "帳戶", icon: "building.columns.fill", color: market.themeColor, showsIcon: false) {
            if let account = selectedAccount {
                HStack(spacing: 8) {
                    CurrencyIconBadge(currency: account.currency, tint: account.accountType.color)
                    Text(account.name)
                        .foregroundColor(.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sellAccountPickerSection: some View {
        TradeFormRow(title: "帳戶", icon: "building.columns.fill", color: market.themeColor, showsIcon: false) {
            VStack(alignment: .leading, spacing: 8) {
                if isAccountLocked {
                    Text("已從此帳戶進入，無法改選其他帳戶")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                } else if sellAccountOptions.count > 1 {
                    Text("點選下方帳戶，從該戶賣出")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }

                if sellAccountOptions.isEmpty {
                    Text("沒有任何帳戶持有此標的")
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                } else {
                    VStack(spacing: TradeFormLayout.accountPickerSpacing) {
                        ForEach(sellAccountOptions) { option in
                            sellAccountPickerRow(option: option)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sellAccountPickerRow(option: SellAccountOption) -> some View {
        let isSelected = option.account.id == selectedAccountId
        let quantityLabel = sellQuantityLabel(for: option.maxSellQuantity)

        return Button {
            selectSellAccount(option)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? market.themeColor : .secondaryText)

                CurrencyIconBadge(currency: option.account.currency, tint: option.account.accountType.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.account.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    Text(quantityLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, TradeFormLayout.accountPickerHPadding)
            .padding(.vertical, TradeFormLayout.accountPickerVPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? market.themeColor.opacity(0.12) : Color.secondaryBackground)
            .cornerRadius(TradeFormLayout.fieldCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? market.themeColor.opacity(0.45) : Color.secondaryText.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSwitchSellAccount && !isSelected)
    }

    private func sellQuantityLabel(for quantity: Decimal) -> String {
        let qty = formatQuantity(quantity)
        if market == .crypto {
            return "持有 \(qty)"
        }
        return "持有 \(qty) 股"
    }

    private func selectSellAccount(_ option: SellAccountOption) {
        guard canSwitchSellAccount || sellAccountOptions.count == 1 else { return }
        guard selectedAccountId != option.account.id else { return }

        selectedAccountId = option.account.id
        Task {
            await accountDetailViewModel.loadAccountData(accountId: option.account.id)
            syncHoldingSelectionForScopedSymbol()
            if needsExchangeRate && exchangeRateText.isEmpty {
                loadExchangeRate()
            } else if !needsExchangeRate {
                exchangeRateText = ""
            }
            validateInput()
        }
    }
    
    private var holdingSection: some View {
        TradeFormRow(title: market == .crypto ? "幣種" : "股票代號", icon: "tag.fill", color: market.themeColor) {
            VStack(alignment: .leading, spacing: 4) {
                if isImportDraftMode, let symbol = editingTransaction?.symbol {
                    Text(symbol)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if isSymbolLocked, let symbol = effectiveSymbol {
                    Text(holdingDisplayName(forSymbol: symbol))
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if showsHoldingPicker {
                    holdingPickerField

                    if let selectedHolding,
                       let currentPrice = selectedHolding.currentPrice {
                        TradeFormReferencePriceCard(
                            title: "參考現價",
                            priceText: currentPrice.formattedTradePrice(currency: selectedHolding.holding.currency),
                            tint: market.themeColor
                        )
                    }
                } else if let selectedHolding {
                    Text(holdingDisplayName(selectedHolding.holding))
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let currentPrice = selectedHolding.currentPrice {
                        TradeFormReferencePriceCard(
                            title: "參考現價",
                            priceText: currentPrice.formattedTradePrice(currency: selectedHolding.holding.currency),
                            tint: market.themeColor
                        )
                    }
                } else if let symbol = effectiveSymbol {
                    Text(holdingDisplayName(forSymbol: symbol))
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var holdingPickerField: some View {
        Menu {
            if selectableHoldings.isEmpty {
                Button("無持股") {}
                    .disabled(true)
            } else {
                ForEach(selectableHoldings) { snapshot in
                    Button {
                        selectedHoldingId = snapshot.id
                    } label: {
                        Text(holdingDisplayName(snapshot.holding))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let selectedHolding {
                    Text(holdingDisplayName(selectedHolding.holding))
                        .foregroundColor(.primaryText)
                } else {
                    Text("選擇持股")
                        .foregroundColor(.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondaryText)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .snapFormFieldTapTarget()
        }
    }
    
    private var quantitySection: some View {
        TradeFormRow(title: "數量", icon: "number.circle.fill", color: market.themeColor) {
            VStack(alignment: .leading, spacing: 4) {
                if isQuantityLockedForCompliance {
                    Text("合規清倉須一次賣出全部持股")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                }
                TextField("0", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .tradeFormDecimalFieldStyle()
                    .disabled(isQuantityLockedForCompliance)
                if market == .crypto {
                    Text("加密貨幣可輸入小數，例如 0.01")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                if showsSellAccountPicker, selectedAccount != nil {
                    Text("此帳戶最多可賣 \(formatQuantity(maxSellQuantity))\(market == .crypto ? "" : " 股")")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
    
    private var priceSection: some View {
        TradeFormRow(
            title: TradeFormUnitPriceLabels.rowTitle(market: market, isSell: true),
            icon: "dollarsign.circle.fill",
            color: market.themeColor
        ) {
            TradeFormUnitPriceInput(priceText: $priceText, currency: priceCurrency)
        }
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        let target = selectedAccount?.currency.rawValue ?? ""
        TradeFormRow(title: "\(priceCurrency.rawValue) 對 \(target) 匯率", icon: "arrow.triangle.2.circlepath", color: market.themeColor) {
            TextField("0", text: $exchangeRateText)
                .keyboardType(.decimalPad)
                .tradeFormDecimalFieldStyle()
        }
    }
    
    private var dateSection: some View {
        TradeFormRow(title: "交易日期", icon: "calendar", color: market.themeColor) {
            TradeFormDatePicker(date: $transactionDate)
        }
    }
    
    @ViewBuilder
    private var errorMessageSection: some View {
        if let errorMessage = errorMessage {
            CardView {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.lossRed)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func handleSubmit() {
        guard selectedAccount != nil,
              quantityValue != nil,
              priceValue != nil else {
            return
        }
        
        Task {
            await finishSubmit(allowDuplicate: false)
        }
    }
    
    private func finishSubmit(allowDuplicate: Bool) async {
        guard let selectedAccount = selectedAccount,
              let quantityValue = quantityValue,
              let priceValue = priceValue else {
            return
        }
        
        if isImportDraftMode,
           let existing = editingTransaction,
           let onImportDraftSave {
            let updated = Transaction(
                id: existing.id,
                accountId: selectedAccount.id,
                type: .sell,
                assetType: existing.assetType,
                symbol: existing.symbol,
                quantity: quantityValue,
                price: priceValue,
                currency: priceCurrency,
                fee: existing.fee,
                notes: existing.notes,
                transactionDate: transactionDate,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                exchangeRate: exchangeRateForSave
            )
            onImportDraftSave(updated)
            dismiss()
            return
        }
        
        let averageCostFallback: Decimal
        let sellSymbol: String
        if let existing = editingTransaction {
            averageCostFallback = existing.realizedCostPerUnit ?? existing.price
            sellSymbol = existing.symbol
        } else if let holding = holdingForSubmit {
            averageCostFallback = holding.holding.averageCost
            sellSymbol = holding.holding.symbol
        } else if let symbol = effectiveSymbol, !symbol.isEmpty {
            averageCostFallback = 0
            sellSymbol = symbol
        } else {
            errorMessage = "請選擇要賣出的持股"
            return
        }
        
        if !allowDuplicate {
            let draft = Transaction(
                accountId: selectedAccount.id,
                type: .sell,
                assetType: market.assetType,
                symbol: sellSymbol,
                quantity: quantityValue,
                price: priceValue,
                currency: priceCurrency,
                transactionDate: transactionDate,
                exchangeRate: exchangeRateForSave
            )
            if let duplicate = await transactionsViewModel.findDuplicateMatch(
                for: draft,
                excludingTransactionId: editingTransaction?.id
            ) {
                duplicateAlertMessage = TransactionDuplicateChecker.alertMessage(
                    for: draft,
                    existing: duplicate
                )
                showingDuplicateAlert = true
                return
            }
        }
        
        validateInput()
        guard errorMessage == nil else { return }

        transactionsViewModel.errorMessage = nil

        if let existing = editingTransaction {
            await transactionsViewModel.updateSellTransaction(
                existing: existing,
                account: selectedAccount,
                quantity: quantityValue,
                price: priceValue,
                currency: priceCurrency,
                exchangeRate: exchangeRateForSave,
                transactionDate: transactionDate,
                averageCostFallback: averageCostFallback,
                allowDuplicate: allowDuplicate
            )
        } else if !sellSymbol.isEmpty {
            let avgCost = holdingForSubmit?.holding.averageCost ?? averageCostFallback
            await transactionsViewModel.createSellTransaction(
                account: selectedAccount,
                assetType: market.assetType,
                symbol: sellSymbol,
                quantity: quantityValue,
                price: priceValue,
                currency: priceCurrency,
                exchangeRate: exchangeRateForSave,
                transactionDate: transactionDate,
                averageCostFallback: avgCost,
                allowDuplicate: allowDuplicate
            )
        } else {
            errorMessage = "請選擇要賣出的持股"
            return
        }

        if let vmError = transactionsViewModel.errorMessage {
            errorMessage = vmError
            return
        }

        notifySubmitCompletion()
        dismiss()
    }

    /// 新建／編輯成功後通知外層刷新（紀錄列表、帳戶持股等）
    private func notifySubmitCompletion() {
        guard let draft = makeCompletionDraft() else { return }
        onSubmit?(draft)
    }

    private func makeCompletionDraft() -> SellTradeDraft? {
        guard let account = selectedAccount,
              let qty = quantityValue,
              let price = priceValue else {
            return nil
        }

        let snapshot: HoldingSnapshot
        if let holding = holdingForSubmit {
            snapshot = holding
        } else if let existing = editingTransaction {
            let holding = Holding(
                accountId: account.id,
                assetType: existing.assetType,
                symbol: existing.symbol,
                quantity: maxSellQuantity,
                averageCost: existing.realizedCostPerUnit ?? existing.price,
                currency: existing.currency
            )
            snapshot = HoldingSnapshot(
                id: existing.id,
                holding: holding,
                currentPrice: nil
            )
        } else {
            return nil
        }

        return SellTradeDraft(
            market: market,
            account: account,
            holding: snapshot,
            quantity: qty,
            price: price,
            exchangeRate: exchangeRateForSave,
            transactionDate: transactionDate
        )
    }
    
    private func applyEditingPrefill(from transaction: Transaction) {
        selectedAccountId = transaction.accountId
        quantityText = transaction.quantity.formattedQuantityInput(
            maxFractionDigits: transaction.assetType == .crypto ? 8 : 4
        )
        priceText = transaction.price.formattedQuantityInput(maxFractionDigits: 4)
        transactionDate = transaction.transactionDate
        if needsExchangeRate, let rate = transaction.exchangeRate {
            exchangeRateText = formattedExchangeRate(rate)
        } else {
            exchangeRateText = ""
        }
        syncHoldingSelectionForScopedSymbol()
        captureEditBaseline()
    }

    private func captureEditBaseline() {
        guard isEditMode else {
            editBaseline = nil
            return
        }
        editBaseline = SellTradeEditBaseline(
            accountId: selectedAccountId,
            quantityText: quantityText,
            priceText: priceText,
            exchangeRateText: exchangeRateText,
            date: transactionDate
        )
    }

    private func reloadSellAccountOptionsIfSymbolKnown() async {
        guard let symbol = effectiveSymbol else { return }
        await reloadSellAccountOptions(for: symbol)
    }

    private func reloadSellAccountOptions(for symbol: String) async {
        var options = await SellHoldingAvailability.accountsWithSellCapacity(
            symbol: symbol,
            assetType: market.assetType,
            candidateAccounts: marketEligibleAccounts,
            dataService: dataService,
            editingTransaction: editingTransaction
        )

        if isAccountLocked {
            let lockedId = editingTransaction?.accountId
                ?? prefill?.preferredAccountId
                ?? selectedAccountId
            if !lockedId.isEmpty {
                options = options.filter { $0.account.id == lockedId }
            }
        }

        await MainActor.run {
            sellAccountOptions = options
            if options.isEmpty {
                errorMessage = "沒有任何帳戶持有此標的，無法賣出"
            } else if !options.contains(where: { $0.account.id == selectedAccountId }) {
                if let editing = editingTransaction,
                   let match = options.first(where: { $0.account.id == editing.accountId }) {
                    selectedAccountId = match.account.id
                } else if let preferred = prefill?.preferredAccountId,
                          options.contains(where: { $0.account.id == preferred }) {
                    selectedAccountId = preferred
                } else {
                    selectedAccountId = options.first?.account.id ?? ""
                }
            }
        }
    }

    private func syncHoldingSelectionForScopedSymbol() {
        guard let symbol = effectiveSymbol else { return }
        if let match = availableHoldings.first(where: { $0.holding.symbol == symbol }) {
            selectedHoldingId = match.id
        } else {
            selectedHoldingId = ""
        }
    }
    
    private func validateInput() {
        errorMessage = nil
        
        guard let quantityValue = quantityValue, !quantityText.isEmpty else {
            return
        }
        
        if quantityValue <= 0 {
            errorMessage = "數量必須大於 0"
            return
        }
        
        if isImportDraftMode {
            if needsExchangeRate {
                guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else {
                    let target = selectedAccount?.currency.rawValue ?? ""
                    errorMessage = "請輸入 \(priceCurrency.rawValue) 對 \(target) 匯率"
                    return
                }
            }
            return
        }
        
        if quantityValue > maxSellQuantity {
            let digits = market == .crypto ? 8 : 4
            let maxLabel = maxSellQuantity.formattedQuantityInput(maxFractionDigits: digits)
            errorMessage = "數量不可超過可賣數量（\(maxLabel)）"
            return
        }

        if isQuantityLockedForCompliance, quantityValue != maxSellQuantity {
            let digits = market == .crypto ? 8 : 4
            let maxLabel = maxSellQuantity.formattedQuantityInput(maxFractionDigits: digits)
            errorMessage = "合規清倉須一次賣出全部持股（\(maxLabel)）"
            return
        }

        if showsSellAccountPicker, sellAccountOptions.isEmpty {
            errorMessage = "沒有任何帳戶持有此標的"
            return
        }

        if showsSellAccountPicker,
           !sellAccountOptions.contains(where: { $0.account.id == selectedAccountId }) {
            errorMessage = "請選擇要賣出的帳戶"
            return
        }
        
        if needsExchangeRate {
            guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else {
                let target = selectedAccount?.currency.rawValue ?? ""
                errorMessage = "請輸入 \(priceCurrency.rawValue) 對 \(target) 匯率"
                return
            }
        }
    }
    
    private func filterDecimalInput(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "." }
    }
    
    private func loadExchangeRate() {
        guard needsExchangeRate, let account = selectedAccount else { return }
        Task {
            do {
                if let data = try await dataService.fetchExchangeRate(from: priceCurrency, to: account.currency, date: nil) {
                    await MainActor.run {
                        if exchangeRateText.isEmpty {
                            exchangeRateText = formattedExchangeRate(data.rate)
                        }
                    }
                }
            } catch {
                // 保持空白，讓使用者手動輸入，避免使用假的匯率。
            }
        }
    }
    
    private func applyHoldingPrefill() {
        guard let prefill else { return }
        if let match = selectableHoldings.first(where: { $0.holding.symbol == prefill.symbol }) {
            selectedHoldingId = match.id
            if priceText.isEmpty, let price = match.currentPrice {
                priceText = price.formattedQuantityInput(maxFractionDigits: 4)
            }
        } else if prefill.lockSymbol {
            selectedHoldingId = ""
        }
    }

    private func holdingDisplayName(_ holding: Holding) -> String {
        if holding.assetType == .stockTW, let name = holding.name, !name.isEmpty {
            return "\(holding.symbol)-\(name)"
        }
        return holding.symbol
    }

    private func holdingDisplayName(forSymbol symbol: String) -> String {
        if let holding = selectedHolding?.holding, holding.symbol == symbol {
            return holdingDisplayName(holding)
        }
        if let holding = availableHoldings.first(where: { $0.holding.symbol == symbol })?.holding {
            return holdingDisplayName(holding)
        }
        return symbol
    }

    private func formatQuantity(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
    
    private func sortKey(for holding: Holding) -> String {
        switch holding.assetType {
        case .stockTW:
            let symbol = holding.symbol
            let padding = String(repeating: "0", count: max(0, 10 - symbol.count))
            return padding + symbol
        case .stockUS, .crypto:
            return holding.symbol.uppercased()
        case .cash:
            return holding.symbol.uppercased()
        }
    }

    private func formattedExchangeRate(_ rate: Decimal) -> String {
        rate.formatted(fractionDigits: rate < 1 ? 4 : 2)
    }

    private func reloadLimitSnapshot() async {
        do {
            limitSnapshot = try await PlusFeatureGate.loadSnapshot(
                userId: userId,
                dataService: dataService
            )
        } catch {
            limitSnapshot = SubscriptionComplianceState.snapshot(
                accounts: accountsViewModel.accounts,
                holdings: []
            )
        }
    }

    private func applyComplianceQuantityIfNeeded() {
        guard isQuantityLockedForCompliance else { return }
        quantityText = formatQuantity(maxSellQuantity)
    }
}

// MARK: - 賣出資料草稿
struct SellTradeDraft {
    let market: TradeMarket
    let account: Account
    let holding: HoldingSnapshot
    let quantity: Decimal
    let price: Decimal
    let exchangeRate: Decimal?
    let transactionDate: Date
}

#Preview {
    SellTradeFormView(market: .stockUS)
}
