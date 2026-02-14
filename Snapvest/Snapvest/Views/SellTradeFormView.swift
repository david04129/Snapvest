//
//  SellTradeFormView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct SellTradeFormView: View {
    let market: TradeMarket
    let onSubmit: ((SellTradeDraft) -> Void)?
    
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
    @State private var userId: String = "test-user-id"
    @Environment(\.dismiss) private var dismiss
    
    init(market: TradeMarket, onSubmit: ((SellTradeDraft) -> Void)? = nil) {
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
    
    private var availableHoldings: [HoldingSnapshot] {
        let filtered = accountDetailViewModel.holdings.filter { snapshot in
            snapshot.holding.assetType == market.assetType
        }
        return filtered.sorted { lhs, rhs in
            sortKey(for: lhs.holding) < sortKey(for: rhs.holding)
        }
    }
    
    private var selectedHolding: HoldingSnapshot? {
        availableHoldings.first { $0.id == selectedHoldingId }
    }
    
    private var needsExchangeRate: Bool {
        market == .stockUS && selectedAccount?.accountType == .twdSecurities
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
    
    private var isValid: Bool {
        guard selectedAccount != nil,
              selectedHolding != nil,
              let quantityValue = quantityValue,
              let priceValue = priceValue,
              quantityValue > 0,
              priceValue > 0,
              quantityValue <= availableQuantity else {
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
                    Image(systemName: "arrow.down")
                    Text("賣出")
                }
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid ? Color.lossRed : AppColors.disabledBackground)
                .cornerRadius(12)
            }
            .disabled(!isValid)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
        }
        .task {
            await accountsViewModel.loadAccounts(userId: userId)
            if selectedAccountId.isEmpty, let firstAccount = availableAccounts.first {
                selectedAccountId = firstAccount.id
                await accountDetailViewModel.loadAccountData(accountId: firstAccount.id)
            }
            transactionsViewModel.accounts = accountsViewModel.accounts
            if needsExchangeRate && exchangeRateText.isEmpty {
                loadExchangeRate()
            }
        }
        .onChange(of: selectedAccountId) { _, newValue in
            Task {
                await accountDetailViewModel.loadAccountData(accountId: newValue)
                selectedHoldingId = availableHoldings.first?.id ?? ""
                validateInput()
            }
            if needsExchangeRate && exchangeRateText.isEmpty {
                loadExchangeRate()
            }
        }
        .onChange(of: selectedHoldingId) { _, _ in
            validateInput()
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
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: market.iconName)
                .font(.system(size: 48))
                .foregroundColor(market.themeColor)
                .frame(width: 80, height: 80)
                .background(market.themeColor.opacity(0.1))
                .clipShape(Circle())
            
            Text("賣出\(market.title)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("請填寫賣出資訊")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var formCard: some View {
        VStack(spacing: 0) {
            accountSection
            Divider()
                .padding(.horizontal, 20)
            holdingSection
            Divider()
                .padding(.horizontal, 20)
            quantitySection
            Divider()
                .padding(.horizontal, 20)
            priceSection
            if needsExchangeRate {
                Divider()
                    .padding(.horizontal, 20)
                exchangeRateSection
            }
            Divider()
                .padding(.horizontal, 20)
            dateSection
        }
        .background(Color.secondaryBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var accountSection: some View {
        FormRow(title: "帳戶", icon: "building.columns.fill", color: market.themeColor) {
            VStack(alignment: .leading) {
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
                        if let selectedAccount = selectedAccount {
                            Image(systemName: selectedAccount.accountType.icon)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(selectedAccount.accountType.color)
                            Text(selectedAccount.name)
                                .foregroundColor(.primaryText)
                        } else {
                            Text("選擇帳戶")
                                .foregroundColor(.secondaryText)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var holdingSection: some View {
        FormRow(title: market == .crypto ? "幣種" : "股票代號", icon: "tag.fill", color: market.themeColor) {
            VStack(alignment: .leading) {
                Picker(selection: $selectedHoldingId) {
                    if availableHoldings.isEmpty {
                        Text("無持股").tag("")
                    } else {
                        ForEach(availableHoldings) { snapshot in
                            Text(holdingDisplayName(snapshot.holding)).tag(snapshot.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if let selectedHolding = selectedHolding {
                            Text(holdingDisplayName(selectedHolding.holding))
                                .foregroundColor(.primaryText)
                        } else {
                            Text("選擇持股")
                                .foregroundColor(.secondaryText)
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
                
                if let selectedHolding = selectedHolding,
                   let currentPrice = selectedHolding.currentPrice {
                    infoRow(
                        label: "目前股價",
                        value: currentPrice.formatted(currency: selectedHolding.holding.currency)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var quantitySection: some View {
        FormRow(title: "數量", icon: "number.circle.fill", color: market.themeColor) {
            TextField("0", text: $quantityText)
                .keyboardType(.decimalPad)
            
            if selectedHolding != nil {
                infoRow(
                    label: "目前該帳戶持有",
                    value: formatQuantity(availableQuantity)
                )
            }
        }
    }
    
    private var priceSection: some View {
        FormRow(title: "每股賣價", icon: "dollarsign.circle.fill", color: market.themeColor) {
            HStack(spacing: 8) {
                if priceCurrency == .USD {
                    Text("$")
                        .foregroundColor(.secondaryText)
                }
                TextField("0", text: $priceText)
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    @ViewBuilder
    private var exchangeRateSection: some View {
        FormRow(title: "美金對台匯率", icon: "arrow.triangle.2.circlepath", color: market.themeColor) {
            TextField("0", text: $exchangeRateText)
                .keyboardType(.decimalPad)
        }
    }
    
    private var dateSection: some View {
        FormRow(title: "交易日期", icon: "calendar", color: market.themeColor) {
            DatePicker("", selection: $transactionDate, displayedComponents: .date)
                .datePickerStyle(.compact)
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
        guard let selectedAccount = selectedAccount,
              let selectedHolding = selectedHolding,
              let quantityValue = quantityValue,
              let priceValue = priceValue else {
            return
        }
        
        let draft = SellTradeDraft(
            market: market,
            account: selectedAccount,
            holding: selectedHolding,
            quantity: quantityValue,
            price: priceValue,
            exchangeRate: exchangeRateValue,
            transactionDate: transactionDate
        )
        Task {
            await transactionsViewModel.createSellTransaction(
                account: selectedAccount,
                assetType: market.assetType,
                symbol: selectedHolding.holding.symbol,
                quantity: quantityValue,
                price: priceValue,
                currency: priceCurrency,
                exchangeRate: exchangeRateValue,
                transactionDate: transactionDate,
                averageCostFallback: selectedHolding.holding.averageCost
            )
            onSubmit?(draft)
            dismiss()
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
        
        if quantityValue > availableQuantity {
            errorMessage = "數量不可超過持有數量"
            return
        }
        
        if needsExchangeRate {
            guard let exchangeRateValue = exchangeRateValue, exchangeRateValue > 0 else {
                errorMessage = "請輸入美金對台匯率"
                return
            }
        }
    }
    
    private func filterDecimalInput(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "." }
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
    
    private func holdingDisplayName(_ holding: Holding) -> String {
        if holding.assetType == .stockTW, let name = holding.name, !name.isEmpty {
            return "\(holding.symbol)-\(name)"
        }
        return holding.symbol
    }

    private var priceCurrency: Currency {
        switch market {
        case .stockTW:
            return .TWD
        case .stockUS, .crypto:
            return .USD
        }
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
    
    private func infoRow(label: String, value: String) -> some View {
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

// MARK: - 表單區塊
private struct FormRow<Content: View>: View {
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
            
            InputContainer {
                content
            }
        }
        .padding(20)
    }
}

private struct InputContainer<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
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
}

#Preview {
    SellTradeFormView(market: .stockUS)
}
