//
//  BuyTradeFormView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct BuyTradeFormView: View {
    let market: TradeMarket
    let onSubmit: (() -> Void)?
    
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    
    @State private var selectedAccountId: String = ""
    @State private var selectedSymbol: String = ""
    @State private var selectedSymbolName: String = ""
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var feeText: String = ""
    @State private var exchangeRateText: String = ""
    @State private var transactionDate: Date = Date()
    @State private var deductFromAccount: Bool = true
    @State private var errorMessage: String?
    @State private var showingSymbolPicker = false
    @State private var currentPrice: Decimal?
    @State private var accountCashBalance: Decimal = 0
    @State private var userId: String = "test-user-id"
    
    private let dataService: DataServiceProtocol = MockDataService.shared
    private let priceService = PriceService(dataService: MockDataService.shared)
    
    @Environment(\.dismiss) private var dismiss
    
    init(market: TradeMarket, onSubmit: (() -> Void)? = nil) {
        self.market = market
        self.onSubmit = onSubmit
    }
    
    private var availableAccounts: [Account] {
        accountsViewModel.accounts.filter { account in
            switch market {
            case .stockTW:
                return account.accountType == .twdSecurities
            case .stockUS:
                return account.accountType == .twdSecurities || account.accountType == .usdAccount
            case .crypto:
                return account.accountType == .cryptoWallet
            }
        }
    }
    
    private var selectedAccount: Account? {
        availableAccounts.first { $0.id == selectedAccountId }
    }
    
    private var needsExchangeRate: Bool {
        market == .stockUS && selectedAccount?.accountType == .twdSecurities
    }
    
    private var quantityValue: Decimal? {
        Decimal(string: quantityText)
    }
    
    private var priceValue: Decimal? {
        Decimal(string: priceText)
    }
    
    private var feeValue: Decimal {
        Decimal(string: feeText) ?? 0
    }
    
    private var exchangeRateValue: Decimal? {
        Decimal(string: exchangeRateText)
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
        let amountInTradeCurrency = qty * price + feeValue
        guard let account = selectedAccount else { return amountInTradeCurrency }
        if priceCurrency == account.currency {
            return amountInTradeCurrency
        }
        guard needsExchangeRate, let rate = exchangeRateValue, rate > 0 else { return amountInTradeCurrency }
        return amountInTradeCurrency * rate
    }
    
    private var canSubmit: Bool {
        isValid && errorMessage == nil
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
            VStack(spacing: 24) {
                headerSection
                formCard
                errorMessageSection
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: handleSubmit) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                    Text("買入")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? Color.profitGreen : AppColors.disabledBackground)
                .cornerRadius(12)
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
        }
        .task {
            await accountsViewModel.loadAccounts(userId: userId)
            transactionsViewModel.accounts = accountsViewModel.accounts
            if selectedAccountId.isEmpty, let first = availableAccounts.first {
                selectedAccountId = first.id
            }
            if !selectedAccountId.isEmpty {
                loadAccountCashBalance(accountId: selectedAccountId)
            }
            validateInput()
        }
        .onChange(of: selectedAccountId) { _, newValue in
            if needsExchangeRate && exchangeRateText.isEmpty {
                loadExchangeRate()
            }
            if !newValue.isEmpty {
                loadAccountCashBalance(accountId: newValue)
            } else {
                accountCashBalance = 0
            }
        }
        .onChange(of: quantityText) { _, _ in validateInput() }
        .onChange(of: priceText) { _, _ in validateInput() }
        .onChange(of: feeText) { _, _ in validateInput() }
        .onChange(of: exchangeRateText) { _, _ in validateInput() }
        .onChange(of: deductFromAccount) { _, _ in validateInput() }
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerView(market: market) { symbol, name in
                selectedSymbol = symbol
                selectedSymbolName = name
                currentPrice = nil
                Task { await loadCurrentPrice() }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: market.iconName)
                .font(.system(size: 48))
                .foregroundColor(market.themeColor)
                .frame(width: 80, height: 80)
                .background(market.themeColor.opacity(0.1))
                .clipShape(Circle())
            
            Text("買入\(market.title)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("請填寫買入資訊")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var formCard: some View {
        VStack(spacing: 0) {
            accountSection
            Divider().padding(.horizontal, 20)
            symbolSection
            Divider().padding(.horizontal, 20)
            quantitySection
            Divider().padding(.horizontal, 20)
            priceSection
            Divider().padding(.horizontal, 20)
            feeSection
            if needsExchangeRate {
                Divider().padding(.horizontal, 20)
                exchangeRateSection
            }
            Divider().padding(.horizontal, 20)
            deductFromAccountSection
            Divider().padding(.horizontal, 20)
            dateSection
        }
        .background(Color.secondaryBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var accountSection: some View {
        buyFormRow(title: "帳戶", icon: "building.columns.fill", color: market.themeColor) {
            Picker(selection: $selectedAccountId) {
                ForEach(availableAccounts) { account in
                    HStack(spacing: 8) {
                        Image(systemName: account.accountType.icon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(account.accountType.color)
                        Text(account.name)
                    }
                    .tag(account.id)
                }
            } label: {
                HStack(spacing: 8) {
                    if let account = selectedAccount {
                        Image(systemName: account.accountType.icon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(account.accountType.color)
                        Text(account.name).foregroundColor(.primaryText)
                    } else {
                        Text("選擇帳戶").foregroundColor(.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
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
                            if !selectedSymbolName.isEmpty {
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
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let price = currentPrice {
                        buyInfoRow(label: "目前股價", value: price.formatted(currency: priceCurrency))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var quantitySection: some View {
        buyFormRow(title: "數量", icon: "number.circle.fill", color: market.themeColor) {
            TextField("0", text: $quantityText)
                .keyboardType(.decimalPad)
        }
    }
    
    private var priceSection: some View {
        buyFormRow(title: "每股買價", icon: "dollarsign.circle.fill", color: market.themeColor) {
            HStack(spacing: 8) {
                if priceCurrency == .USD {
                    Text("$").foregroundColor(.secondaryText)
                }
                TextField("0", text: $priceText)
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    private var feeSection: some View {
        buyFormRow(title: "手續費（選填）", icon: "percent", color: market.themeColor) {
            HStack(spacing: 8) {
                if priceCurrency == .USD {
                    Text("$").foregroundColor(.secondaryText)
                }
                TextField("0", text: $feeText)
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        buyFormRow(title: "美金對台匯率", icon: "arrow.triangle.2.circlepath", color: market.themeColor) {
            TextField("0", text: $exchangeRateText)
                .keyboardType(.decimalPad)
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
        }
    }
    
    private var dateSection: some View {
        buyFormRow(title: "交易日期", icon: "calendar", color: market.themeColor) {
            DatePicker("", selection: $transactionDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
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
        guard let account = selectedAccount,
              let qty = quantityValue,
              let price = priceValue else { return }
        
        Task {
            await transactionsViewModel.createBuyTransaction(
                account: account,
                assetType: assetType,
                symbol: selectedSymbol,
                symbolName: selectedSymbolName.isEmpty ? nil : selectedSymbolName,
                quantity: qty,
                price: price,
                currency: priceCurrency,
                fee: feeValue,
                exchangeRate: exchangeRateValue,
                deductFromAccount: deductFromAccount,
                transactionDate: transactionDate
            )
            onSubmit?()
            dismiss()
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
        
        if deductFromAccount,
           let amount = transactionAmountInAccountCurrency,
           let account = selectedAccount,
           amount > accountCashBalance {
            errorMessage = "現金餘額不足。帳戶餘額：\(accountCashBalance.formatted(currency: account.currency))，本筆需扣款：\(amount.formatted(currency: account.currency))"
        }
    }
    
    private func loadAccountCashBalance(accountId: String) {
        Task {
            do {
                var transactions = try await dataService.fetchTransactions(accountId: accountId)
                let allAccounts = try await dataService.fetchAccounts(userId: userId)
                if let account = allAccounts.first(where: { $0.id == accountId }) {
                    let allTransactions = try await dataService.fetchAllTransactions(userId: account.userId)
                    let incoming = allTransactions.filter { t in
                        (t.type == .transfer || t.type == .repayment) && t.targetAccountId == accountId && t.accountId != accountId
                    }
                    transactions.append(contentsOf: incoming)
                }
                let balance = CashCalculator.calculateCash(accountId: accountId, transactions: transactions, accounts: allAccounts)
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
        guard needsExchangeRate else { return }
        Task {
            do {
                if let data = try await dataService.fetchExchangeRate(from: .USD, to: .TWD, date: nil) {
                    await MainActor.run {
                        if exchangeRateText.isEmpty {
                            exchangeRateText = data.rate.formatted(fractionDigits: 2)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if exchangeRateText.isEmpty {
                        exchangeRateText = "32.00"
                    }
                }
            }
        }
    }
    
    private func loadCurrentPrice() async {
        guard !selectedSymbol.isEmpty else { return }
        do {
            let price = try await priceService.fetchCurrentPrice(assetType: assetType, symbol: selectedSymbol)
            await MainActor.run {
                currentPrice = price
            }
        } catch {
            await MainActor.run {
                currentPrice = nil
            }
        }
    }
}

// MARK: - Form Components (Buy)

private struct buyFormRow<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondaryBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(20)
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
