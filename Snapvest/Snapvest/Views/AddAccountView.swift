//
//  AddAccountView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

private enum AddItemScreen: Equatable {
    case hub
    case manualAsset
    case accountForm(AccountType)

    var accountType: AccountType? {
        if case .accountForm(let accountType) = self {
            return accountType
        }
        return nil
    }
}

struct AddAccountView: View {
    @ObservedObject var viewModel: AccountsViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var manualAssetsViewModel = ManualAssetsViewModel()
    
    @State private var screen: AddItemScreen = .hub
    @State private var selectedCurrency: Currency = .TWD
    @State private var name: String = ""
    @State private var initialBalance: String = ""
    // 債務相關欄位
    @State private var principal: String = ""
    @State private var totalPeriods: String = ""
    @State private var paidPeriods: String = "0"  // 已還期數
    @State private var interestRate: String = ""
    @State private var monthlyPayment: Decimal = 0
    @State private var repaymentDay: String = "1"
    @State private var startDate: Date = Date()  // 開始日期
    @State private var otherDebtAmount: String = ""
    @State private var otherDebtNotes: String = ""
    @State private var userId: String = AppUser.id
    @State private var duplicateNameError: String? = nil
    
    // 重置所有輸入欄位
    private func resetForm() {
        name = ""
        initialBalance = ""
        principal = ""
        totalPeriods = ""
        paidPeriods = "0"
        interestRate = ""
        monthlyPayment = 0
        repaymentDay = "1"
        startDate = Date()
        otherDebtAmount = ""
        otherDebtNotes = ""
        selectedCurrency = preferredDefaultCurrency(for: screen.accountType)
        duplicateNameError = nil
    }
    
    private func preferredDefaultCurrency(for accountType: AccountType?) -> Currency {
        guard let accountType else { return .TWD }
        switch accountType {
        case .debt, .otherDebt:
            return BaseCurrencyManager.shared.baseCurrency
        default:
            return accountType.defaultCurrency
        }
    }

    // 檢查帳戶名稱是否重複（同一類型）
    private func isDuplicateName(_ name: String, accountType: AccountType) -> Bool {
        return viewModel.accounts.contains { account in
            account.accountType == accountType && account.name == name
        }
    }
    
    // 動態導航標題
    private var navigationTitle: String {
        switch screen {
        case .hub:
            return "新增項目"
        case .manualAsset:
            return AddItemKind.manualAsset.navigationTitle
        case .accountForm(let accountType):
            return "新增\(accountType.displayName)"
        }
    }

    private func openAccountForm(_ accountType: AccountType) {
        resetForm()
        selectedCurrency = preferredDefaultCurrency(for: accountType)
        withAnimation(.easeInOut(duration: 0.22)) {
            screen = .accountForm(accountType)
        }
    }

    private func returnToAddItemHub() {
        resetForm()
        withAnimation(.easeInOut(duration: 0.22)) {
            screen = .hub
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .hub:
                    AddItemHubView(
                        onSelectAccountType: openAccountForm,
                        onSelectManualAsset: {
                            resetForm()
                            withAnimation(.easeInOut(duration: 0.22)) {
                                screen = .manualAsset
                            }
                        }
                    )
                case .manualAsset:
                    ManualAssetFormView(
                        viewModel: manualAssetsViewModel,
                        mode: .create(userId: userId),
                        chrome: .embedded,
                        onCancel: returnToAddItemHub,
                        onSaved: { dismiss() }
                    )
                case .accountForm(let accountType):
                    accountFormContent(for: accountType)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SnapToolbarIconButton(icon: .back) {
                        if screen == .hub {
                            dismiss()
                        } else {
                            returnToAddItemHub()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .onAppear {
            resetForm()
            screen = .hub
        }
        .snapFormSheetChrome()
    }

    @ViewBuilder
    private func accountFormContent(for accountType: AccountType) -> some View {
        switch accountType {
        case .debt:
            DebtAccountDetailsFormView(
                name: $name,
                principal: $principal,
                totalPeriods: $totalPeriods,
                paidPeriods: $paidPeriods,
                interestRate: $interestRate,
                monthlyPayment: $monthlyPayment,
                repaymentDay: $repaymentDay,
                startDate: $startDate,
                selectedCurrency: $selectedCurrency,
                accountsViewModel: viewModel,
                duplicateNameError: $duplicateNameError,
                onCancel: returnToAddItemHub,
                onSave: { Task { await saveDebtAccount() } }
            )
        case .otherDebt:
            OtherDebtAccountDetailsFormView(
                name: $name,
                amount: $otherDebtAmount,
                notes: $otherDebtNotes,
                startDate: $startDate,
                selectedCurrency: $selectedCurrency,
                accountsViewModel: viewModel,
                duplicateNameError: $duplicateNameError,
                onCancel: returnToAddItemHub,
                onSave: { Task { await saveOtherDebtAccount() } }
            )
        default:
            AccountDetailsFormView(
                accountType: accountType,
                name: $name,
                initialBalance: $initialBalance,
                selectedCurrency: $selectedCurrency,
                duplicateNameError: $duplicateNameError,
                accountsViewModel: viewModel,
                onCancel: returnToAddItemHub,
                onSave: { Task { await saveAccount() } }
            )
        }
    }
    
    @MainActor
    private func saveAccount() async {
        guard case .accountForm(let accountType) = screen else { return }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入帳戶名稱"
            return
        }
        
        if isDuplicateName(name, accountType: accountType) {
            duplicateNameError = "此帳戶類型已存在相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        let account = Account(
            userId: userId,
            name: name,
            accountType: accountType,
            currency: selectedCurrency
        )
        
        let succeeded = await viewModel.runAccountSave(userId: userId) {
            try await viewModel.createAccountRecord(account)
            if let balance = Decimal(string: initialBalance), balance > 0 {
                let transaction = Transaction(
                    accountId: account.id,
                    type: .deposit,
                    assetType: .cash,
                    symbol: "CASH",
                    quantity: balance,
                    price: 1,
                    currency: account.currency,
                    fee: 0,
                    notes: "初始餘額",
                    transactionDate: Date()
                )
                try await viewModel.persistTransaction(transaction)
            }
        }
        guard succeeded else { return }
        
        resetForm()
        dismiss()
    }
    
    @MainActor
    private func saveOtherDebtAccount() async {
        guard case .accountForm(.otherDebt) = screen,
              let amountValue = Decimal(string: otherDebtAmount),
              amountValue > 0 else { return }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入名稱"
            return
        }
        
        if isDuplicateName(name, accountType: .otherDebt) {
            duplicateNameError = "此類別已有相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        let account = Account(
            userId: userId,
            name: name.trimmingCharacters(in: .whitespaces),
            accountType: .otherDebt,
            currency: selectedCurrency
        )
        
        let noteText = otherDebtNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        var transactionNotes = "新增其他債務：\(account.name)"
        if !noteText.isEmpty {
            transactionNotes += "｜\(noteText)"
        }
        
        let transaction = Transaction(
            accountId: account.id,
            type: .liability,
            assetType: .cash,
            symbol: "DEBT",
            quantity: 1,
            price: amountValue,
            currency: account.currency,
            notes: transactionNotes,
            transactionDate: startDate
        )
        
        let succeeded = await viewModel.runAccountSave(userId: userId) {
            try await viewModel.createAccountRecord(account)
            try await viewModel.persistTransaction(transaction)
        }
        guard succeeded else { return }
        
        resetForm()
        dismiss()
    }
    
    @MainActor
    private func saveDebtAccount() async {
        guard case .accountForm(.debt) = screen,
              let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate) else { return }
        
        // 檢查名稱是否為空
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            duplicateNameError = "請輸入帳戶名稱"
            return
        }
        
        // 檢查同一類型是否已有相同名稱的帳戶
        if isDuplicateName(name, accountType: .debt) {
            duplicateNameError = "此帳戶類型已存在相同名稱的帳戶"
            return
        }
        
        duplicateNameError = nil
        
        let account = Account(
            userId: userId,
            name: name,
            accountType: .debt,
            currency: selectedCurrency
        )
        
        let periods = Int(totalPeriods) ?? 12
        let paidPeriodsValue = Int(paidPeriods) ?? 0
        
        let calculatedRemainingBalance = calculateRemainingBalance(
            principal: principalValue,
            interestRate: rate,
            totalPeriods: periods,
            paidPeriods: paidPeriodsValue,
            monthlyPayment: monthlyPayment
        )
        
        let calculatedTotalPaidPrincipal: Decimal
        let calculatedTotalPaidInterest: Decimal
        
        if paidPeriodsValue > 0 {
            calculatedTotalPaidPrincipal = principalValue - calculatedRemainingBalance
            calculatedTotalPaidInterest = monthlyPayment * Decimal(paidPeriodsValue) - calculatedTotalPaidPrincipal
        } else {
            calculatedTotalPaidPrincipal = 0
            calculatedTotalPaidInterest = 0
        }
        
        let liability = Liability(
            accountId: account.id,
            name: name,
            principal: principalValue,
            interestRate: rate,
            monthlyPayment: monthlyPayment,
            remainingBalance: calculatedRemainingBalance,
            currency: selectedCurrency,
            startDate: startDate,
            totalPeriods: periods,
            paidPeriods: paidPeriodsValue,
            totalPaidPrincipal: calculatedTotalPaidPrincipal,
            totalPaidInterest: calculatedTotalPaidInterest,
            totalSavedInterest: 0
        )
        
        let transactionAmount = calculatedRemainingBalance > 0 ? calculatedRemainingBalance : principalValue
        var transactionNotes = "新增債務：\(name)"
        if paidPeriodsValue > 0 {
            transactionNotes += "（已還 \(paidPeriodsValue) 期，剩餘本金 \(transactionAmount.formatted(currency: selectedCurrency))）"
        }
        
        let liabilityTransaction = Transaction(
            accountId: account.id,
            type: .liability,
            assetType: .cash,
            symbol: "CASH",
            quantity: transactionAmount,
            price: 1,
            currency: selectedCurrency,
            fee: 0,
            notes: transactionNotes,
            transactionDate: startDate
        )
        
        let succeeded = await viewModel.runAccountSave(userId: userId) {
            try await viewModel.createAccountRecord(account)
            try await viewModel.persistLiability(liability)
            try await viewModel.persistTransaction(liabilityTransaction)
        }
        guard succeeded else { return }
        
        resetForm()
        dismiss()
    }
    
    // MARK: - 計算剩餘本金（方案A：等額本息公式反推）
    /// 根據已還期數計算剩餘本金
    /// - Parameters:
    ///   - principal: 原始本金
    ///   - interestRate: 年利率
    ///   - totalPeriods: 總期數
    ///   - paidPeriods: 已還期數
    ///   - monthlyPayment: 每月還款額
    /// - Returns: 剩餘本金
    private func calculateRemainingBalance(
        principal: Decimal,
        interestRate: Decimal,
        totalPeriods: Int,
        paidPeriods: Int,
        monthlyPayment: Decimal
    ) -> Decimal {
        // 如果未還款，返回原始本金
        guard paidPeriods > 0 else {
            return principal
        }
        
        // 如果已還清，返回0
        guard paidPeriods < totalPeriods else {
            return 0
        }
        
        // 計算月利率
        let monthlyRate = interestRate / 100 / 12
        
        // 無息貸款：線性攤還
        if monthlyRate <= 0.0001 {
            let remainingPeriods = Decimal(totalPeriods - paidPeriods)
            let totalPeriodsDecimal = Decimal(totalPeriods)
            return principal * (remainingPeriods / totalPeriodsDecimal)
        }
        
        // 等額本息公式反推剩餘本金
        // remainingBalance = principal × [(1+r)^n - (1+r)^k] / [(1+r)^n - 1]
        // 其中：r = 月利率, n = 總期數, k = 已還期數
        
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        
        // 計算 (1+r)^n
        let powerN = onePlusRate.raising(toPower: totalPeriods)
        
        // 計算 (1+r)^k
        let powerK = onePlusRate.raising(toPower: paidPeriods)
        
        // 計算分子：(1+r)^n - (1+r)^k
        let numerator = powerN.subtracting(powerK)
        
        // 計算分母：(1+r)^n - 1
        let denominator = powerN.subtracting(NSDecimalNumber.one)
        
        // 防止除以0
        guard denominator.compare(NSDecimalNumber.zero) != .orderedSame else {
            return principal
        }
        
        // 計算結果：principal × numerator / denominator
        let principalNS = NSDecimalNumber(decimal: principal)
        let result = principalNS
            .multiplying(by: numerator)
            .dividing(by: denominator)
        
        return result.decimalValue
    }
}

private enum AddItemKind: CaseIterable, Identifiable {
    case account
    case manualAsset
    case liability

    var id: String { title }

    var title: String {
        switch self {
        case .account: return "新增帳戶"
        case .manualAsset: return "新增其他資產"
        case .liability: return "新增負債"
        }
    }

    var navigationTitle: String { title }

    var description: String {
        switch self {
        case .account:
            return "現金、證券與加密貨幣帳戶，可用來記錄交易與現金餘額。"
        case .manualAsset:
            return "基金、房地產、保單、收藏品等沒有公開即時價格的資產。"
        case .liability:
            return "房貸、信貸、卡費或其他需要追蹤的欠款。"
        }
    }

    var selectionDescription: String {
        switch self {
        case .account:
            return "請選擇您想建立的帳戶類型。"
        case .manualAsset:
            return "請輸入其他資產資料。"
        case .liability:
            return "請選擇您想建立的負債類型。"
        }
    }

    var color: Color {
        switch self {
        case .account: return .appPrimary
        case .manualAsset: return .manualAssetColor
        case .liability: return .lossRed
        }
    }
}

// MARK: - 新增項目 Hub（帳戶／負債／其他資產三大類）

private struct AddItemHubGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let subsections: [AddItemHubSubsection]
}

private struct AddItemHubSubsection: Identifiable {
    let id: String
    /// 空字串表示不顯示小分層標題（選項直接列在大類底下）
    let title: String
    let accentColor: Color
    let options: [AddItemHubOption]
}

private struct AddItemHubOption: Identifiable {
    enum Destination {
        case account(AccountType)
        case manualAsset
    }

    let id: String
    let title: String
    let subtitle: String?
    let accentColor: Color
    let destination: Destination
}

private struct AddItemHubView: View {
    let onSelectAccountType: (AccountType) -> Void
    let onSelectManualAsset: () -> Void

    /// Hub 頂部說明卡：中性色，不與「帳戶」大類品牌綠重複
    private static let heroAccentColor = Color.secondaryText.opacity(0.55)

    private static let groups: [AddItemHubGroup] = [
        AddItemHubGroup(
            id: "accounts",
            title: "帳戶",
            subtitle: "現金與投資帳戶，可記錄餘額與交易",
            accentColor: .appPrimary,
            subsections: [
                AddItemHubSubsection(
                    id: "cash",
                    title: "現金帳戶",
                    accentColor: AccountType.twdDeposit.color,
                    options: [
                        AddItemHubOption(
                            id: AccountType.twdDeposit.rawValue,
                            title: AccountType.twdDeposit.displayName,
                            subtitle: "台幣存款、外幣現金與日常資金",
                            accentColor: AccountType.twdDeposit.color,
                            destination: .account(.twdDeposit)
                        )
                    ]
                ),
                AddItemHubSubsection(
                    id: "investment",
                    title: "投資帳戶",
                    accentColor: AccountType.twdSecurities.color,
                    options: [
                        hubOption(.twdSecurities),
                        hubOption(.usdAccount),
                        hubOption(.cryptoWallet)
                    ]
                )
            ]
        ),
        AddItemHubGroup(
            id: "liability",
            title: "負債",
            subtitle: "房貸、信貸、卡費與其他欠款",
            accentColor: AccountType.debt.color,
            subsections: [
                AddItemHubSubsection(
                    id: "liability_items",
                    title: "",
                    accentColor: AccountType.debt.color,
                    options: [
                        AddItemHubOption(
                            id: AccountType.debt.rawValue,
                            title: "分期貸款",
                            subtitle: AccountType.debt.description,
                            accentColor: AccountType.debt.color,
                            destination: .account(.debt)
                        ),
                        AddItemHubOption(
                            id: AccountType.otherDebt.rawValue,
                            title: "其他負債",
                            subtitle: AccountType.otherDebt.description,
                            accentColor: AccountType.otherDebt.color,
                            destination: .account(.otherDebt)
                        )
                    ]
                )
            ]
        ),
        AddItemHubGroup(
            id: "manual_asset",
            title: "其他資產",
            subtitle: "基金、房地產、保單等無即時市價的資產",
            accentColor: AddItemKind.manualAsset.color,
            subsections: [
                AddItemHubSubsection(
                    id: "manual_asset_items",
                    title: "",
                    accentColor: AddItemKind.manualAsset.color,
                    options: [
                        AddItemHubOption(
                            id: "manual_asset_row",
                            title: "新增其他資產",
                            subtitle: AddItemKind.manualAsset.description,
                            accentColor: AddItemKind.manualAsset.color,
                            destination: .manualAsset
                        )
                    ]
                )
            ]
        )
    ]

    private static func hubOption(_ accountType: AccountType) -> AddItemHubOption {
        AddItemHubOption(
            id: accountType.rawValue,
            title: accountType.displayName,
            subtitle: accountType.description,
            accentColor: accountType.color,
            destination: .account(accountType)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AddSheetHeroCard(
                    title: "新增項目",
                    subtitle: "選擇要建立的帳戶、負債或其他資產；完成後會出現在管理分頁。",
                    accentColor: Self.heroAccentColor
                )

                ForEach(Self.groups) { group in
                    AddItemHubMajorGroupCard(group: group, onSelect: handleSelection)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func handleSelection(_ option: AddItemHubOption) {
        switch option.destination {
        case .account(let accountType):
            onSelectAccountType(accountType)
        case .manualAsset:
            onSelectManualAsset()
        }
    }
}

private struct AddItemHubMajorGroupCard: View {
    let group: AddItemHubGroup
    let onSelect: (AddItemHubOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(group.accentColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primaryText)
                    Text(group.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(group.subsections) { subsection in
                    VStack(alignment: .leading, spacing: 8) {
                        if !subsection.title.isEmpty {
                            AddItemHubSubsectionHeader(
                                title: subsection.title,
                                accentColor: subsection.accentColor
                            )
                        }
                        AddItemHubOptionsGroup(
                            options: subsection.options,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(group.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(group.accentColor.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(group.accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

private struct AddItemHubSubsectionHeader: View {
    let title: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor.opacity(0.85))
                .frame(width: 3, height: 12)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }
}

private struct AddItemHubOptionsGroup: View {
    let options: [AddItemHubOption]
    let onSelect: (AddItemHubOption) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                AddItemHubOptionRow(option: option) {
                    onSelect(option)
                }
                if index < options.count - 1 {
                    Divider()
                        .overlay(Color.separator.opacity(0.35))
                        .padding(.leading, 14)
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.separator.opacity(0.32), lineWidth: 1)
        }
    }
}

private struct AddItemHubOptionRow: View {
    let option: AddItemHubOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(option.accentColor)
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primaryText)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 債務帳戶詳情表單
struct DebtAccountDetailsFormView: View {
    @Binding var name: String
    @Binding var principal: String
    @Binding var totalPeriods: String
    @Binding var paidPeriods: String  // 已還期數
    @Binding var interestRate: String
    @Binding var monthlyPayment: Decimal
    @Binding var repaymentDay: String
    @Binding var startDate: Date  // 開始日期
    @Binding var selectedCurrency: Currency
    @ObservedObject var accountsViewModel: AccountsViewModel
    @Binding var duplicateNameError: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var showingDatePicker = false
    
    // 計算剩餘本金（用於動態顯示）
    private var calculatedRemainingBalance: Decimal {
        return calculateRemainingBalance()
    }
    
    // 計算剩餘期數
    private var remainingPeriods: Int {
        let total = Int(totalPeriods) ?? 0
        let paid = Int(paidPeriods) ?? 0
        return max(0, total - paid)
    }
    
    // 計算剩餘應還總額（使用臨時的 Liability 對象）
    private var remainingTotalAmount: Decimal {
        guard let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate),
              let periods = Int(totalPeriods),
              let paid = Int(paidPeriods),
              periods > 0,
              paid >= 0,
              paid < periods,
              monthlyPayment > 0 else {
            return 0
        }
        
        let remainingBalance = calculateRemainingBalance()
        guard remainingBalance > 0 else {
            return 0
        }
        
        // 創建臨時 Liability 對象來使用其計算屬性
        let tempLiability = Liability(
            accountId: "",
            name: "",
            principal: principalValue,
            interestRate: rate,
            monthlyPayment: monthlyPayment,
            remainingBalance: remainingBalance,
            currency: selectedCurrency,
            startDate: Date(),
            totalPeriods: periods,
            paidPeriods: paid
        )
        
        return tempLiability.remainingTotalAmount
    }
    
    // 計算剩餘利息
    private var remainingInterest: Decimal {
        guard remainingTotalAmount > 0 else {
            return 0
        }
        let remainingTotal = remainingTotalAmount
        let remaining = calculatedRemainingBalance
        return max(0, remainingTotal - remaining)
    }
    
    // 計算剩餘本金（方案A：等額本息公式反推）
    private func calculateRemainingBalance() -> Decimal {
        guard let principalValue = Decimal(string: principal),
              let rate = Decimal(string: interestRate),
              let periods = Int(totalPeriods),
              let paid = Int(paidPeriods),
              periods > 0 else {
            return Decimal(string: principal) ?? 0
        }
        
        // 如果未還款，返回原始本金
        guard paid > 0 else {
            return principalValue
        }
        
        // 如果已還清，返回0
        guard paid < periods else {
            return 0
        }
        
        // 計算月利率
        let monthlyRate = rate / 100 / 12
        
        // 無息貸款：線性攤還
        if monthlyRate <= 0.0001 {
            let remainingPeriods = Decimal(periods - paid)
            let totalPeriodsDecimal = Decimal(periods)
            return principalValue * (remainingPeriods / totalPeriodsDecimal)
        }
        
        // 等額本息公式反推剩餘本金
        // remainingBalance = principal × [(1+r)^n - (1+r)^k] / [(1+r)^n - 1]
        // 其中：r = 月利率, n = 總期數, k = 已還期數
        
        let monthlyRateNS = NSDecimalNumber(decimal: monthlyRate)
        let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
        
        // 計算 (1+r)^n
        let powerN = onePlusRate.raising(toPower: periods)
        
        // 計算 (1+r)^k
        let powerK = onePlusRate.raising(toPower: paid)
        
        // 計算分子：(1+r)^n - (1+r)^k
        let numerator = powerN.subtracting(powerK)
        
        // 計算分母：(1+r)^n - 1
        let denominator = powerN.subtracting(NSDecimalNumber.one)
        
        // 防止除以0
        guard denominator.compare(NSDecimalNumber.zero) != .orderedSame else {
            return principalValue
        }
        
        // 計算結果：principal × numerator / denominator
        let principalNS = NSDecimalNumber(decimal: principalValue)
        let result = principalNS
            .multiplying(by: numerator)
            .dividing(by: denominator)
        
        return result.decimalValue
    }
    
    private let accountType = AccountType.debt
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 24) {
                    AddSheetHeroCard(
                        title: accountType.displayName,
                        subtitle: accountType.description,
                        accentColor: accountType.color,
                        badge: "新增負債"
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 表單卡片
                    VStack(spacing: 0) {
                        // 貸款名稱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("貸款名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("例如：房屋貸款", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in
                                    duplicateNameError = nil // 清除錯誤訊息
                                }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "貸款幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "預設使用主要幣別，也可以改成其他借款幣別。"
                            )
                            .padding(20)

                            Divider()
                                .padding(.horizontal, 20)
                        }

                        // 貸款總額
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("貸款總額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $principal)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: principal) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字和小數點
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        principal = filtered
                                    }
                                    // 防止負數或零
                                    if let value = Decimal(string: filtered), value <= 0 {
                                        principal = oldValue.isEmpty ? "" : oldValue
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 總期數
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("總期數")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(月)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $totalPeriods)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: totalPeriods) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        totalPeriods = filtered
                                    }
                                    // 防止負數或零
                                    if let value = Int(filtered), value <= 0, !filtered.isEmpty {
                                        totalPeriods = oldValue.isEmpty ? "" : oldValue
                                    } else {
                                        // 驗證已還期數不超過總期數
                                        if let total = Int(filtered),
                                           let paid = Int(paidPeriods),
                                           paid > total {
                                            paidPeriods = String(total)
                                        }
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 已還期數
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("已還期數")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(月)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $paidPeriods)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: paidPeriods) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        paidPeriods = filtered
                                    }
                                    // 防止負數
                                    if let value = Int(filtered), value < 0, !filtered.isEmpty {
                                        paidPeriods = oldValue.isEmpty ? "0" : oldValue
                                    } else if let paid = Int(filtered),
                                              let total = Int(totalPeriods),
                                              total > 0,
                                              paid > total {
                                        // 已還期數不能超過總期數
                                        paidPeriods = String(total)
                                    }
                                }
                            
                            // 提示訊息
                            if let paid = Int(paidPeriods), paid > 0 {
                                if let total = Int(totalPeriods), total > 0 {
                                    if paid >= total {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Text("貸款已還清")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                            Text("剩餘 \(total - paid) 期")
                                                .font(.caption)
                                                .foregroundColor(.secondaryText)
                                        }
                                        .padding(.leading, 4)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 年利率
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "percent")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("年利率")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(%)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $interestRate)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: interestRate) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字和小數點
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue {
                                        interestRate = filtered
                                    }
                                    // 防止負數
                                    if let value = Decimal(string: filtered), value < 0 {
                                        interestRate = oldValue
                                    }
                                    calculateMonthlyPayment()
                                }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        // 每月應繳金額（自動計算）
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("每月應繳金額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            HStack {
                                Text(monthlyPayment.formatted(currency: selectedCurrency))
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                Spacer()
                                
                                if monthlyPayment > 0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(accountType.color.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("系統會根據貸款總額、期數和利率自動計算")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        // 還款狀態（如果已還期數 > 0 且有有效數據）
                        if let paid = Int(paidPeriods),
                           let total = Int(totalPeriods),
                           total > 0,
                           paid > 0,
                           paid < total,
                           calculatedRemainingBalance > 0,
                           monthlyPayment > 0 {
                            Divider()
                            .padding(.horizontal, 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(accountType.color)
                                    Text("還款狀態")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primaryText)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    // 剩餘本金
                                    HStack {
                                        Text("剩餘本金")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(calculatedRemainingBalance.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .foregroundColor(.lossRed)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘期數
                                    HStack {
                                        Text("剩餘期數")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text("\(remainingPeriods) 期")
                                            .font(.headline)
                                            .foregroundColor(.primaryText)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘利息
                                    HStack {
                                        Text("剩餘利息")
                                            .font(.subheadline)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(remainingInterest.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .foregroundColor(.secondaryText)
                                    }
                                    
                                    Divider()
                                    
                                    // 剩餘應還總額
                                    HStack {
                                        Text("剩餘應還總額")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primaryText)
                                        Spacer()
                                        Text(remainingTotalAmount.formatted(currency: selectedCurrency))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.lossRed)
                                    }
                                }
                                .padding()
                                .background(accountType.color.opacity(0.05))
                                .cornerRadius(12)
                            }
                            .padding(20)
                            
                            Divider()
                            .padding(.horizontal, 20)
                        }
                        
                        // 每月還款日
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("每月還款日")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("1", text: $repaymentDay)
                                .keyboardType(.numberPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: repaymentDay) { oldValue, newValue in
                                    // 過濾無效字符，只允許數字
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        repaymentDay = filtered
                                    }
                                    // 限制在1-31之間
                                    if let day = Int(filtered), !filtered.isEmpty {
                                        if day < 1 {
                                            repaymentDay = "1"
                                        } else if day > 31 {
                                            repaymentDay = "31"
                                        }
                                    }
                                }
                            
                            Text("請輸入 1-31 之間的數字")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        Divider()
                        .padding(.horizontal, 20)
                        
                        // 開始日期
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("開始日期")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            Button(action: {
                                showingDatePicker = true
                            }) {
                                HStack {
                                    Text(formatDate(startDate))
                                        .font(.body)
                                        .foregroundColor(.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondaryText)
                                }
                                .padding()
                                .background(Color.secondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("貸款的開始日期")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .addSheetFormCard()
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            AddAccountSaveButton(
                isEnabled: isDebtFormValid,
                isSaving: accountsViewModel.isSaving,
                accentColor: accountType.color,
                action: onSave
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "選擇開始日期",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("選擇開始日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // 格式化日期為文字
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // 債務帳戶表單驗證
    private var isDebtFormValid: Bool {
        // 首先檢查每月應繳金額是否已計算（這是最嚴格的檢查）
        guard monthlyPayment > 0 else {
            return false
        }
        
        // 檢查貸款名稱
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return false
        }
        
        // 檢查貸款總額
        let trimmedPrincipal = principal.trimmingCharacters(in: .whitespaces)
        guard !trimmedPrincipal.isEmpty,
              let principalValue = Decimal(string: trimmedPrincipal),
              principalValue > 0 else {
            return false
        }
        
        // 檢查總期數
        let trimmedPeriods = totalPeriods.trimmingCharacters(in: .whitespaces)
        guard !trimmedPeriods.isEmpty,
              let periods = Int(trimmedPeriods),
              periods > 0 else {
            return false
        }
        
        // 檢查已還期數
        let trimmedPaidPeriods = paidPeriods.trimmingCharacters(in: .whitespaces)
        guard !trimmedPaidPeriods.isEmpty,
              let paid = Int(trimmedPaidPeriods),
              paid >= 0 else {
            return false
        }
        
        // 檢查已還期數不超過總期數
        guard paid <= periods else {
            return false
        }
        
        // 檢查年利率
        let trimmedRate = interestRate.trimmingCharacters(in: .whitespaces)
        guard !trimmedRate.isEmpty,
              let rate = Decimal(string: trimmedRate),
              rate >= 0 else {
            return false
        }
        
        // 檢查每月還款日
        let trimmedDay = repaymentDay.trimmingCharacters(in: .whitespaces)
        guard !trimmedDay.isEmpty,
              let day = Int(trimmedDay),
              day >= 1 && day <= 31 else {
            return false
        }
        
        return true
    }
    
    private func calculateMonthlyPayment() {
        guard let principalValue = Decimal(string: principal),
              let periods = Int(totalPeriods),
              let rate = Decimal(string: interestRate),
              periods > 0,
              rate >= 0 else {
            monthlyPayment = 0
            return
        }
        
        // 計算每月應繳金額（等額本息）
        // M = P * [r(1+r)^n] / [(1+r)^n - 1]
        // 其中 M = 每月還款額，P = 本金，r = 月利率，n = 期數
        
        // 使用 NSDecimalNumber 進行精確計算
        let principalNS = NSDecimalNumber(decimal: principalValue)
        let monthlyRateNS = NSDecimalNumber(decimal: rate / 100 / 12)
        let n = periods
        
        if rate == 0 {
            // 無利息，平均攤還
            monthlyPayment = (principalNS.dividing(by: NSDecimalNumber(value: n))).decimalValue
        } else {
            // 計算 (1+r)^n
            let onePlusRate = NSDecimalNumber.one.adding(monthlyRateNS)
            let power = onePlusRate.raising(toPower: n)
            
            // 計算分子：P * r * (1+r)^n
            let numerator = principalNS
                .multiplying(by: monthlyRateNS)
                .multiplying(by: power)
            
            // 計算分母：(1+r)^n - 1
            let denominator = power.subtracting(NSDecimalNumber.one)
            
            // 計算結果：numerator / denominator
            monthlyPayment = numerator.dividing(by: denominator).decimalValue
        }
    }
}

// MARK: - 建立帳戶儲存按鈕
private struct AddAccountSaveButton: View {
    let isEnabled: Bool
    let isSaving: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(AppColors.actionForeground)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                }
                Text(isSaving ? "建立中..." : "建立帳戶")
                    .font(.headline)
            }
            .foregroundColor(AppColors.actionForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? accentColor : AppColors.disabledBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isSaving)
        .scaleEffect(isSaving ? 0.97 : 1)
        .opacity(isSaving ? 0.92 : 1)
        .animation(.easeInOut(duration: 0.15), value: isSaving)
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - 帳戶詳情表單
struct AccountDetailsFormView: View {
    let accountType: AccountType
    @Binding var name: String
    @Binding var initialBalance: String
    @Binding var selectedCurrency: Currency
    @Binding var duplicateNameError: String?
    @ObservedObject var accountsViewModel: AccountsViewModel
    let onCancel: () -> Void
    let onSave: () -> Void
    
    // 根據帳戶類型返回對應的提示詞
    private var namePlaceholder: String {
        switch accountType {
        case .twdDeposit:
            return "例如：生活帳戶"
        case .twdSecurities:
            return "例如：元大證券"
        case .usdAccount:
            return "例如：美股證券戶"
        case .cryptoWallet:
            return "例如：Binance"
        case .debt:
            return "例如：房屋貸款"
        case .otherDebt:
            return "例如：欠朋友"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 24) {
                    AddSheetHeroCard(
                        title: accountType.displayName,
                        subtitle: accountType.description,
                        accentColor: accountType.color,
                        badge: "新增帳戶"
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 表單卡片
                    VStack(spacing: 0) {
                        // 帳戶名稱
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("帳戶名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField(namePlaceholder, text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in
                                    duplicateNameError = nil // 清除錯誤訊息
                                }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "帳戶幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "原幣仍依標的決定；帳戶幣別用於現金餘額與折算顯示。"
                            )
                            .padding(20)

                            Divider()
                                .padding(.horizontal, 20)
                        }

                        // 初始餘額
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("初始餘額")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            AmountKeypadInputView(
                                text: $initialBalance,
                                currency: selectedCurrency,
                                accentColor: accountType.color
                            )
                            .onChange(of: initialBalance) { oldValue, newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                if filtered != newValue {
                                    initialBalance = filtered
                                }
                                if let value = Decimal(string: filtered), value < 0 {
                                    initialBalance = oldValue
                                }
                            }
                            
                            Text("可選：設定帳戶的初始餘額")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .addSheetFormCard()
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            AddAccountSaveButton(
                isEnabled: !name.isEmpty,
                isSaving: accountsViewModel.isSaving,
                accentColor: accountType.color,
                action: onSave
            )
        }
    }
}

// MARK: - 帳戶類型選擇卡片
struct AccountTypeSelectionCard: View {
    let accountType: AccountType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountType.displayName)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text(accountType.description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()

                Text(isSelected ? "已選" : "選擇")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accountType.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accountType.color.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accountType.color)
                    .frame(width: isSelected ? 5 : 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accountType.color.opacity(isSelected ? 0.55 : 0.28), lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 其他債務帳戶詳情表單

struct OtherDebtAccountDetailsFormView: View {
    @Binding var name: String
    @Binding var amount: String
    @Binding var notes: String
    @Binding var startDate: Date
    @Binding var selectedCurrency: Currency
    @ObservedObject var accountsViewModel: AccountsViewModel
    @Binding var duplicateNameError: String?
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var showingDatePicker = false
    
    private let accountType = AccountType.otherDebt
    
    private var isFormValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let value = Decimal(string: amount),
              value > 0 else { return false }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    AddSheetHeroCard(
                        title: accountType.displayName,
                        subtitle: accountType.description,
                        accentColor: accountType.color,
                        badge: "新增負債"
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("帳戶名稱")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("例如：欠朋友", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: name) { _, _ in duplicateNameError = nil }
                            
                            if let error = duplicateNameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        if accountType.allowsCurrencySelection {
                            CurrencyDropdownField(
                                title: "債務幣別",
                                icon: "dollarsign.arrow.circlepath",
                                color: accountType.color,
                                options: accountType.selectableCurrencies,
                                selectedCurrency: $selectedCurrency,
                                helperText: "預設使用主要幣別，也可以改成其他借款幣別。"
                            )
                            .padding(20)

                            Divider().padding(.horizontal, 20)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("目前欠款")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                                Text("(\(selectedCurrency.rawValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                            
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                                .onChange(of: amount) { oldValue, newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue { amount = filtered }
                                    if let value = Decimal(string: filtered), value <= 0, !filtered.isEmpty {
                                        amount = oldValue.isEmpty ? "" : oldValue
                                    }
                                }
                            
                            Text("不需填寫期數或利率，還款後會直接減少欠款")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("備註（選填）")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            TextField("備註", text: $notes)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding(20)
                        
                        Divider().padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(accountType.color)
                                Text("開始日期")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primaryText)
                            }
                            
                            Button { showingDatePicker = true } label: {
                                HStack {
                                    Text(formatDate(startDate))
                                        .font(.body)
                                        .foregroundColor(.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondaryText)
                                }
                                .padding()
                                .background(Color.secondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Text("此筆債務的開始日期")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                        }
                        .padding(20)
                    }
                    .addSheetFormCard()
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .snapFormScrollDismissesKeyboard()
            
            AddAccountSaveButton(
                isEnabled: isFormValid,
                isSaving: accountsViewModel.isSaving,
                accentColor: accountType.color,
                action: onSave
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "選擇開始日期",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle("選擇開始日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { showingDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

#Preview {
    AddAccountView(viewModel: AccountsViewModel())
}

#Preview {
    AddAccountView(viewModel: AccountsViewModel())
}

