//
//  BuyTradeFormView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct BuyTradeFormView: View {
    let market: TradeMarket
    let prefill: BuyTradePrefill?
    let editingTransaction: Transaction?
    /// 嵌在 NewTradeFlowView 時隱藏表單內標題（流程頁已有買賣切換）
    var embedInTradeFlow: Bool = false
    let onSubmit: (() -> Void)?
    var isImportDraftMode: Bool = false
    var onImportDraftSave: ((Transaction) -> Void)? = nil
    var onImportDraftRemove: (() -> Void)? = nil
    
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    
    @State private var selectedAccountId: String = ""
    @State private var selectedSymbol: String = ""
    @State private var selectedSymbolName: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var exchangeRateText: String = ""

    @State private var transactionDate: Date = Date()
    @State private var deductFromAccount: Bool = false
    @State private var errorMessage: String?
    @State private var showingSymbolPicker = false
    @State private var accountCashBalance: Decimal = 0
    @State private var userId: String = AppUser.id
    @State private var showingDuplicateAlert = false
    @State private var duplicateAlertMessage = ""
    @State private var livePriceState: SymbolLiveReferencePrice.State = .idle
    @State private var livePriceFetchedForSymbol: String = ""
    @State private var livePriceTaskToken = 0
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        market: TradeMarket,
        prefill: BuyTradePrefill? = nil,
        editingTransaction: Transaction? = nil,
        embedInTradeFlow: Bool = false,
        isImportDraftMode: Bool = false,
        onImportDraftSave: ((Transaction) -> Void)? = nil,
        onImportDraftRemove: (() -> Void)? = nil,
        onSubmit: (() -> Void)? = nil
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
        return isEditMode ? "確認修改" : "買入"
    }
    
    private var isSymbolLocked: Bool {
        isEditMode || prefill?.lockSymbol == true
    }
    
    private var isAccountLocked: Bool {
        isImportDraftMode || prefill?.lockAccount == true
    }
    
    private var availableAccounts: [Account] {
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
    
    private var selectedAccount: Account? {
        availableAccounts.first { $0.id == selectedAccountId }
    }
    
    private var needsExchangeRate: Bool {
        guard let account = selectedAccount else { return false }
        return priceCurrency != account.currency
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
        case .stockTW:
            return .TWD
        case .stockUS, .crypto:
            return .USD
        }
    }
    
    private var assetType: AssetType {
        market.assetType
    }
    
    /// 本筆交易需扣款金額（帳戶貨幣）
    private var transactionAmountInAccountCurrency: Decimal? {
        guard let qty = quantityValue, let price = priceValue, qty > 0, price > 0 else { return nil }
        let amountInTradeCurrency = qty * price
        guard let account = selectedAccount else { return amountInTradeCurrency }
        if priceCurrency == account.currency {
            return amountInTradeCurrency
        }
        guard needsExchangeRate, let rate = exchangeRateValue, rate > 0 else { return amountInTradeCurrency }
        return amountInTradeCurrency * rate
    }
    
    /// 新增買進需先完成選股預抓參考現價；編輯既有交易不強制。
    private var needsLiveReferencePrice: Bool {
        !isEditMode
    }

    private var normalizedSelectedSymbol: String {
        SymbolLiveReferencePrice.normalizedSymbol(assetType: assetType, symbol: selectedSymbol)
    }

    private var livePriceReady: Bool {
        guard needsLiveReferencePrice else { return true }
        guard !normalizedSelectedSymbol.isEmpty else { return false }
        guard livePriceFetchedForSymbol == normalizedSelectedSymbol else { return false }
        if case .ready = livePriceState { return true }
        return false
    }

    private var canSubmit: Bool {
        isValid && errorMessage == nil && livePriceReady
    }
    
    private var isValid: Bool {
        guard selectedAccount != nil,
              !selectedSymbol.isEmpty,
              let quantityValue = quantityValue,
              let priceValue = priceValue,
              quantityValue > 0,
              priceValue > 0 else {
            return false
        }
        
        if needsExchangeRate {
            guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else {
                return false
            }
        }
        
        return true
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedInTradeFlow {
                    TradeFormCompactHeader(
                        market: market,
                        actionTitle: "買入",
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
            VStack(spacing: 10) {
                buyAmountSummary
                if isImportDraftMode {
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            onImportDraftRemove?()
                            dismiss()
                        } label: {
                            Text("移除")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
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
                            .padding(.vertical, 16)
                            .background(canSubmit ? Color.profitGreen : AppColors.disabledBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!canSubmit)
                    }
                } else {
                    Button(action: handleSubmit) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                            Text(submitButtonTitle)
                        }
                        .font(.headline)
                        .foregroundColor(AppColors.actionForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit ? Color.profitGreen : AppColors.disabledBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmit)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
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
               availableAccounts.contains(where: { $0.id == preferred }) {
                selectedAccountId = preferred
            } else if selectedAccountId.isEmpty, let first = availableAccounts.first {
                selectedAccountId = first.id
            }
            if let transaction = editingTransaction {
                applyEditingPrefill(from: transaction)
            } else {
                applySymbolPrefill()
            }
            if !selectedAccountId.isEmpty {
                loadAccountCashBalance(accountId: selectedAccountId)
            }
            validateInput()
            if needsLiveReferencePrice, !normalizedSelectedSymbol.isEmpty {
                await prefetchLiveReferencePrice()
            }
        }
        .onChange(of: selectedAccountId) { _, newValue in
            if needsExchangeRate {
                if exchangeRateText.isEmpty {
                    loadExchangeRate()
                }
            } else {
                exchangeRateText = ""
            }
            if !newValue.isEmpty {
                loadAccountCashBalance(accountId: newValue)
            } else {
                accountCashBalance = 0
            }
            validateInput()
        }
        .onChange(of: quantityText) { _, _ in validateInput() }
        .onChange(of: priceText) { _, _ in validateInput() }
        .onChange(of: exchangeRateText) { _, _ in validateInput() }
        .onChange(of: deductFromAccount) { _, _ in validateInput() }
        .onChange(of: selectedSymbol) { _, newSymbol in
            guard needsLiveReferencePrice else { return }
            if newSymbol.isEmpty {
                resetLiveReferencePrice()
            } else {
                Task { await prefetchLiveReferencePrice() }
            }
        }
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerView(market: market) { symbol, name in
                selectedSymbol = market == .crypto
                    ? SymbolListService.normalizedCryptoSymbol(symbol)
                    : symbol
                selectedSymbolName = name
            }
        }
        .alert("可能重複的交易", isPresented: $showingDuplicateAlert) {
            Button("取消", role: .cancel) { }
            Button("仍要建立", role: .destructive) {
                Task { await finishSubmit(allowDuplicate: true) }
            }
        } message: {
            Text(duplicateAlertMessage)
        }
    }
    
    @ViewBuilder
    private var buyAmountSummary: some View {
        if !deductFromAccount {
            TradeFormAmountSummary(
                label: "本筆買入",
                amountText: tradeAmountDisplayText ?? "—",
                detailText: amountBreakdownDetail,
                footnote: "不從帳戶扣款"
            )
        } else if let account = selectedAccount, let amount = transactionAmountInAccountCurrency {
            TradeFormAmountSummary(
                label: "預估扣款",
                amountText: amount.formatted(currency: account.currency),
                detailText: amountBreakdownDetail,
                footnote: accountBalanceFootnote
            )
        } else {
            TradeFormAmountSummary(
                label: "預估扣款",
                amountText: "—",
                detailText: "請填寫數量與價格"
            )
        }
    }
    
    private var tradeAmountDisplayText: String? {
        guard let amount = transactionAmountInAccountCurrency else { return nil }
        let currency = selectedAccount?.currency ?? priceCurrency
        return amount.formatted(currency: currency)
    }
    
    private var amountBreakdownDetail: String? {
        guard let qty = quantityValue, let price = priceValue, qty > 0, price > 0 else { return nil }
        let qtyLabel = qty.formattedQuantityInput(maxFractionDigits: market == .crypto ? 8 : 4)
        let priceLabel = price.formattedTradePrice(currency: priceCurrency)
        return "\(qtyLabel) × \(priceLabel)"
    }
    
    private var accountBalanceFootnote: String? {
        guard deductFromAccount, let account = selectedAccount else { return nil }
        let label = isEditMode ? "可用餘額" : "帳戶餘額"
        return "\(label) \(accountCashBalance.formatted(currency: account.currency))"
    }
    
    private var formCard: some View {
        VStack(spacing: 0) {
            symbolSection
            Divider().padding(.horizontal, 20)
            quantitySection
            Divider().padding(.horizontal, 20)
            priceSection
            Divider().padding(.horizontal, 20)
            accountSection
            Divider().padding(.horizontal, 20)
            deductFromAccountSection
            if needsExchangeRate {
                Divider().padding(.horizontal, 20)
                exchangeRateSection
            }
            Divider().padding(.horizontal, 20)
            dateSection
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.separator.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var accountSection: some View {
        buyFormRow(title: "帳戶", icon: "building.columns.fill", color: market.themeColor, showsIcon: false) {
            if isAccountLocked {
                if let account = selectedAccount {
                    HStack(spacing: 8) {
                        CurrencyCodeChip(currency: account.currency, tint: account.accountType.color, style: .filled)
                        Text(account.name)
                            .foregroundColor(.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Picker(selection: $selectedAccountId) {
                ForEach(availableAccounts) { account in
                    HStack(spacing: 8) {
                        CurrencyCodeChip(currency: account.currency, tint: account.accountType.color, style: .filled)
                        Text(account.name)
                    }
                    .tag(account.id)
                }
            } label: {
                HStack(spacing: 8) {
                    if let account = selectedAccount {
                        CurrencyCodeChip(currency: account.currency, tint: account.accountType.color, style: .filled)
                        Text(account.name).foregroundColor(.primaryText)
                    } else {
                        Text("選擇帳戶").foregroundColor(.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
                .snapFormFieldTapTarget()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var symbolSection: some View {
        buyFormRow(title: market == .crypto ? "加密貨幣" : "股票代號", icon: "tag.fill", color: market.themeColor) {
            Button(action: { showingSymbolPicker = true }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if !selectedSymbol.isEmpty {
                            Text(selectedSymbol)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryText)
                            if market != .crypto, !selectedSymbolName.isEmpty {
                                Text("—")
                                    .foregroundColor(.secondaryText)
                                Text(selectedSymbolName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("點擊選擇")
                                .foregroundColor(.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                    .snapFormFieldTapTarget()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            liveReferencePriceStatus
        }
    }

    @ViewBuilder
    private var liveReferencePriceStatus: some View {
        if needsLiveReferencePrice, !normalizedSelectedSymbol.isEmpty {
            switch livePriceState {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("股價載入中…")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 4)
            case .ready(let price):
                VStack(alignment: .leading, spacing: 6) {
                    Text("參考現價")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                    Text(price.formattedTradePrice(currency: priceCurrency))
                        .font(.snapReferencePrice)
                        .foregroundColor(.primaryText)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(market.themeColor.opacity(0.1))
                .cornerRadius(10)
                .padding(.top, 6)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.lossRed)
                    Button("重試載入股價") {
                        Task { await prefetchLiveReferencePrice() }
                    }
                    .font(.caption)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var quantitySection: some View {
        buyFormRow(title: "數量", icon: "number.circle.fill", color: market.themeColor) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("0", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .snapFormFieldTapTarget()
                if market == .crypto {
                    Text("加密貨幣可輸入小數，例如 0.01")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
    
    private var priceSection: some View {
        buyFormRow(
            title: TradeFormUnitPriceLabels.rowTitle(market: market, isSell: false),
            icon: "dollarsign.circle.fill",
            color: market.themeColor
        ) {
            TradeFormUnitPriceInput(priceText: $priceText, currency: priceCurrency)
        }
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        let target = selectedAccount?.currency.rawValue ?? ""
        buyFormRow(title: "\(priceCurrency.rawValue) 對 \(target) 匯率", icon: "arrow.triangle.2.circlepath", color: market.themeColor) {
            TextField("0", text: $exchangeRateText)
                .keyboardType(.decimalPad)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .snapFormFieldTapTarget()
        }
    }
    
    private var deductFromAccountSection: some View {
        buyFormRow(title: "從帳戶扣款", icon: "creditcard.fill", color: market.themeColor) {
            Toggle(isOn: $deductFromAccount) {
                Text("從帳戶中扣除此筆款項")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
            }
            .toggleStyle(SwitchToggleStyle(tint: market.themeColor))
            .snapFormFieldTapTarget()
        }
    }
    
    private var dateSection: some View {
        buyFormRow(title: "交易日期", icon: "calendar", color: market.themeColor) {
            TradeFormDatePicker(date: $transactionDate)
        }
    }
    
    @ViewBuilder
    private var errorMessageSection: some View {
        if let msg = errorMessage {
            CardView {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.lossRed)
                    Text(msg)
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
        validateInput()
        guard errorMessage == nil else { return }
        guard selectedAccount != nil,
              quantityValue != nil,
              priceValue != nil else { return }
        
        Task {
            await finishSubmit(allowDuplicate: false)
        }
    }
    
    private func finishSubmit(allowDuplicate: Bool) async {
        validateInput()
        guard errorMessage == nil else { return }
        guard let account = selectedAccount,
              let qty = quantityValue,
              let price = priceValue else { return }
        
        if needsLiveReferencePrice, !livePriceReady {
            switch livePriceState {
            case .failed(let message):
                errorMessage = message
            case .loading, .idle:
                errorMessage = "股價載入中，請稍候"
            case .ready:
                errorMessage = "請重新選擇股票代號"
            }
            return
        }
        
        if isImportDraftMode,
           let existing = editingTransaction,
           let onImportDraftSave {
            let updated = Transaction(
                id: existing.id,
                accountId: account.id,
                type: .buy,
                assetType: assetType,
                symbol: selectedSymbol,
                quantity: qty,
                price: price,
                currency: priceCurrency,
                fee: existing.fee,
                notes: selectedSymbolName.isEmpty
                    ? (existing.notes ?? "買入 \(selectedSymbol)")
                    : "買入 \(selectedSymbol) - \(selectedSymbolName)",
                transactionDate: transactionDate,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                exchangeRate: exchangeRateForSave,
                deductFromAccount: deductFromAccount
            )
            onImportDraftSave(updated)
            onSubmit?()
            dismiss()
            return
        }
        
        if !allowDuplicate {
            let draft = Transaction(
                accountId: account.id,
                type: .buy,
                assetType: assetType,
                symbol: selectedSymbol,
                quantity: qty,
                price: price,
                currency: priceCurrency,
                fee: 0,
                notes: selectedSymbolName.isEmpty ? nil : "買入 \(selectedSymbol) - \(selectedSymbolName)",
                transactionDate: transactionDate,
                exchangeRate: exchangeRateForSave,
                deductFromAccount: deductFromAccount
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
        
        transactionsViewModel.errorMessage = nil
        
        if let existing = editingTransaction {
            await transactionsViewModel.updateBuyTransaction(
                existing: existing,
                account: account,
                quantity: qty,
                price: price,
                currency: priceCurrency,
                fee: 0,
                exchangeRate: exchangeRateForSave,
                deductFromAccount: deductFromAccount,
                transactionDate: transactionDate,
                symbolName: selectedSymbolName.isEmpty ? nil : selectedSymbolName,
                allowDuplicate: allowDuplicate
            )
        } else {
            await transactionsViewModel.createBuyTransaction(
                account: account,
                assetType: assetType,
                symbol: selectedSymbol,
                symbolName: selectedSymbolName.isEmpty ? nil : selectedSymbolName,
                quantity: qty,
                price: price,
                currency: priceCurrency,
                fee: 0,
                exchangeRate: exchangeRateForSave,
                deductFromAccount: deductFromAccount,
                transactionDate: transactionDate,
                allowDuplicate: allowDuplicate,
                skipPriceValidation: livePriceReady
            )
        }
        
        if let vmError = transactionsViewModel.errorMessage {
            errorMessage = vmError
            return
        }
        
        onSubmit?()
        dismiss()
    }
    
    private func applyEditingPrefill(from transaction: Transaction) {
        selectedAccountId = transaction.accountId
        selectedSymbol = transaction.symbol
        selectedSymbolName = transaction.buySymbolNameFromNotes ?? ""
        quantityText = transaction.quantity.formattedQuantityInput(
            maxFractionDigits: transaction.assetType == .crypto ? 8 : 4
        )
        priceText = transaction.price.formattedQuantityInput(maxFractionDigits: 4)
        transactionDate = transaction.transactionDate
        deductFromAccount = transaction.deductFromAccount ?? false
        if needsExchangeRate, let rate = transaction.exchangeRate {
            exchangeRateText = formattedExchangeRate(rate)
        } else {
            exchangeRateText = ""
        }
    }
    
    private func validateInput() {
        errorMessage = nil
        
        if availableAccounts.isEmpty {
            errorMessage = "請先新增適合的帳戶（\(market.title)）"
            return
        }
        
        guard let qty = quantityValue, !quantityText.isEmpty else { return }
        if qty <= 0 {
            errorMessage = "數量必須大於 0"
            return
        }
        
        if needsExchangeRate,
           (exchangeRateValue == nil || (exchangeRateValue ?? 0) <= 0) {
            let target = selectedAccount?.currency.rawValue ?? ""
            errorMessage = "請填寫 \(priceCurrency.rawValue) 對 \(target) 匯率"
            return
        }
        
        if !isImportDraftMode,
           deductFromAccount,
           let amount = transactionAmountInAccountCurrency,
           let account = selectedAccount,
           amount > accountCashBalance {
            let balanceLabel = isEditMode ? "可用餘額" : "帳戶餘額"
            errorMessage = "現金餘額不足。\(balanceLabel)：\(accountCashBalance.formatted(currency: account.currency))，本筆需扣款：\(amount.formatted(currency: account.currency))"
        }
    }
    
    private func loadAccountCashBalance(accountId: String) {
        Task {
            do {
                let transactions = try await dataService.fetchTransactions(accountId: accountId)
                let allAccounts = try await dataService.fetchAccounts(userId: userId)
                let account = allAccounts.first { $0.id == accountId }
                    ?? availableAccounts.first { $0.id == accountId }
                let balance: Decimal
                if let account {
                    balance = CashCalculator.availableCashForBuy(
                        accountId: accountId,
                        account: account,
                        transactions: transactions,
                        accounts: allAccounts,
                        existingTransaction: editingTransaction
                    )
                } else {
                    balance = CashCalculator.calculateCash(
                        accountId: accountId,
                        transactions: transactions,
                        accounts: allAccounts
                    )
                }
                await MainActor.run {
                    accountCashBalance = balance
                    validateInput()
                }
            } catch {
                await MainActor.run {
                    accountCashBalance = 0
                    validateInput()
                }
            }
        }
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
    
    private func resetLiveReferencePrice() {
        livePriceTaskToken += 1
        livePriceState = .idle
        livePriceFetchedForSymbol = ""
    }

    @MainActor
    private func prefetchLiveReferencePrice() async {
        let key = normalizedSelectedSymbol
        guard needsLiveReferencePrice, !key.isEmpty else {
            resetLiveReferencePrice()
            return
        }

        livePriceTaskToken += 1
        let token = livePriceTaskToken
        livePriceFetchedForSymbol = key
        livePriceState = .loading

        let result = await SymbolLiveReferencePrice.prefetch(
            assetType: assetType,
            symbol: selectedSymbol
        )

        guard token == livePriceTaskToken, normalizedSelectedSymbol == key else { return }
        livePriceState = result
    }

    private func applySymbolPrefill() {
        guard let prefill, selectedSymbol.isEmpty else { return }
        selectedSymbol = prefill.symbol
        selectedSymbolName = prefill.symbolName ?? ""
    }

    private func formattedExchangeRate(_ rate: Decimal) -> String {
        rate.formatted(fractionDigits: rate < 1 ? 4 : 2)
    }
}

// MARK: - Form Components (Buy)

private struct buyFormRow<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var showsIcon: Bool = true
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if showsIcon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.separator.opacity(0.35), lineWidth: 1)
                }
        }
        .padding(16)
    }
}

private func buyInfoRow(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(.caption)
            .foregroundColor(.secondaryText)
        Spacer()
        Text(value)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.primaryText)
    }
    .padding(.leading, 4)
    .padding(.top, 4)
}

#Preview {
    BuyTradeFormView(market: .stockUS)
}
