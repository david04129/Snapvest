//
//  ManualAssetFormView.swift
//  Snapvest
//
//  新增／編輯其他資產共用表單。
//

import SwiftUI

enum ManualAssetFormMode {
    case create(userId: String)
    case edit(asset: ManualAsset, syncCreationValuation: Bool)
}

enum ManualAssetFormChrome {
    case embedded
    case sheet
}

struct ManualAssetFormView: View {
    private enum FieldID: Hashable {
        case costBasis
    }

    @ObservedObject var viewModel: ManualAssetsViewModel
    let mode: ManualAssetFormMode
    let chrome: ManualAssetFormChrome
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var name: String
    @State private var category: ManualAssetCategory
    @State private var currency: Currency
    @State private var currentValue: String
    @State private var costBasis: String
    @State private var includesPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var notes: String
    @State private var isIncludedInTotalAssets: Bool
    @State private var isIncludedInInvestments: Bool
    @State private var localErrorMessage: String?
    @State private var costBasisErrorMessage: String?

    private let accentColor = Color.manualAssetColor

    init(
        viewModel: ManualAssetsViewModel,
        mode: ManualAssetFormMode,
        chrome: ManualAssetFormChrome = .embedded,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.mode = mode
        self.chrome = chrome
        self.onCancel = onCancel
        self.onSaved = onSaved

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _category = State(initialValue: .other)
            _currency = State(initialValue: BaseCurrencyManager.shared.baseCurrency)
            _currentValue = State(initialValue: "")
            _costBasis = State(initialValue: "")
            _includesPurchaseDate = State(initialValue: false)
            _purchaseDate = State(initialValue: Date())
            _notes = State(initialValue: "")
            _isIncludedInTotalAssets = State(initialValue: true)
            _isIncludedInInvestments = State(initialValue: false)
        case .edit(let asset, _):
            _name = State(initialValue: asset.name)
            _category = State(initialValue: asset.category)
            _currency = State(initialValue: asset.currency)
            _currentValue = State(initialValue: asset.currentValue.formattedQuantityInput(maxFractionDigits: 2))
            _costBasis = State(initialValue: asset.costBasis.map { $0.formattedQuantityInput(maxFractionDigits: 2) } ?? "")
            _includesPurchaseDate = State(initialValue: asset.purchaseDate != nil)
            _purchaseDate = State(initialValue: asset.purchaseDate ?? Date())
            _notes = State(initialValue: asset.notes ?? "")
            _isIncludedInTotalAssets = State(initialValue: asset.isIncludedInTotalAssets)
            _isIncludedInInvestments = State(initialValue: asset.isIncludedInInvestments)
        }
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var navigationTitle: String {
        isCreate ? "新增其他資產" : "編輯其他資產"
    }

    private var heroBadge: String {
        isCreate ? "新增其他資產" : "編輯其他資產"
    }

    private var heroSubtitle: String {
        isCreate
            ? "記錄沒有公開即時價格、但需要納入資產總覽的項目。"
            : "修改名稱、類別、幣別與納入總覽的設定。"
    }

    private var saveButtonTitle: String {
        if viewModel.isSaving {
            return isCreate ? "建立中..." : "儲存中..."
        }
        return isCreate ? "建立其他資產" : "確認儲存"
    }

    private var isSaveDisabled: Bool {
        viewModel.isSaving
            || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || currentValue.isEmpty
    }

    var body: some View {
        switch chrome {
        case .embedded:
            embeddedBody
        case .sheet:
            NavigationStack {
                scrollContent
                    .background(Color.mainBackground)
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .tint(accentColor)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            SnapToolbarIconButton(icon: .close) {
                                onCancel()
                                dismiss()
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        sheetSaveButton
                    }
            }
            .snapFormSheetChrome()
        }
    }

    private var embeddedBody: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                scrollContent
                embeddedSaveButton(scrollProxy: scrollProxy)
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                formCard
                errorMessageSection
                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
        .snapFormScrollDismissesKeyboard()
        .onAppear(perform: applyCreateDefaultsIfNeeded)
        .onChange(of: isIncludedInInvestments) { _, isIncluded in
            if isIncluded { isIncludedInTotalAssets = true }
        }
        .onChange(of: isIncludedInTotalAssets) { _, isIncluded in
            if !isIncluded { isIncludedInInvestments = false }
        }
    }

    private var heroSection: some View {
        AddSheetHeroCard(
            title: "其他資產",
            subtitle: heroSubtitle,
            accentColor: accentColor,
            badge: heroBadge
        )
        .padding(.horizontal)
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            ManualAssetCategoryDropdownField(
                selectedCategory: $category,
                tint: accentColor
            )
            .padding(20)

            ManualAssetFormDivider()

            ManualAssetFormFieldSection(title: "資產名稱", icon: "tag.fill", accentColor: accentColor) {
                TextField("例如：台北房子、基金、保單", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .onChange(of: name) { _, _ in clearErrors() }
            }

            ManualAssetFormDivider()

            CurrencyDropdownField(
                title: "資產幣別",
                icon: "dollarsign.arrow.circlepath",
                color: accentColor,
                options: Currency.baseCurrencyOptions,
                selectedCurrency: $currency,
                helperText: "現值與成本會依這個幣別換算到主要幣別。"
            )
            .padding(20)

            ManualAssetFormDivider()

            ManualAssetFormFieldSection(
                title: "目前現值",
                icon: "dollarsign.circle.fill",
                accentColor: accentColor,
                trailing: currency.rawValue
            ) {
                AmountKeypadInputView(
                    text: $currentValue,
                    currency: currency,
                    accentColor: accentColor
                )
                .onChange(of: currentValue) { oldValue, newValue in
                    currentValue = sanitizedDecimalText(newValue, fallback: oldValue)
                    clearErrors()
                }
            }

            ManualAssetFormDivider()

            ManualAssetInclusionSection(
                isIncludedInTotalAssets: $isIncludedInTotalAssets,
                isIncludedInInvestments: $isIncludedInInvestments,
                accentColor: accentColor
            )

            if isIncludedInInvestments {
                ManualAssetFormDivider()

                ManualAssetFormFieldSection(
                    title: "成本",
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: accentColor,
                    trailing: "必填"
                ) {
                    AmountKeypadInputView(
                        text: $costBasis,
                        currency: currency,
                        accentColor: accentColor
                    )
                    .onChange(of: costBasis) { oldValue, newValue in
                        costBasis = sanitizedDecimalText(newValue, fallback: oldValue)
                        clearErrors()
                    }
                    costBasisErrorView
                    Text("納入投資時必填，用於計算損益與報酬率。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.leading, 4)
                }
                .id(FieldID.costBasis)
            }

            ManualAssetFormDivider()

            ManualAssetPurchaseDateSection(
                includesPurchaseDate: $includesPurchaseDate,
                purchaseDate: $purchaseDate,
                accentColor: accentColor
            )

            ManualAssetFormDivider()

            ManualAssetFormFieldSection(
                title: "備註",
                icon: "note.text",
                accentColor: accentColor,
                trailing: "可選"
            ) {
                TextField("備註", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(CustomTextFieldStyle())
            }
        }
        .addSheetFormCard()
    }

    @ViewBuilder
    private var errorMessageSection: some View {
        if let message = localErrorMessage ?? viewModel.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.lossRed)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.lossRed)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var costBasisErrorView: some View {
        if let message = costBasisErrorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.lossRed)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.lossRed)
            }
            .padding(.leading, 4)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func embeddedSaveButton(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            save(scrollProxy: scrollProxy)
        } label: {
            saveButtonLabel
        }
        .disabled(isSaveDisabled)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var sheetSaveButton: some View {
        Button {
            save(scrollProxy: nil)
        } label: {
            saveButtonLabel
        }
        .disabled(isSaveDisabled)
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
    }

    private var saveButtonLabel: some View {
        HStack(spacing: 8) {
            if viewModel.isSaving {
                ProgressView()
                    .tint(AppColors.actionForeground)
            } else {
                Image(systemName: isCreate ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 18))
            }
            Text(saveButtonTitle)
                .font(.headline)
        }
        .foregroundColor(AppColors.actionForeground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSaveDisabled ? AppColors.disabledBackground : accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func applyCreateDefaultsIfNeeded() {
        guard isCreate else { return }
        currency = BaseCurrencyManager.shared.baseCurrency
    }

    private func save(scrollProxy: ScrollViewProxy?) {
        clearErrors()
        guard let currentValueDecimal = Decimal(string: currentValue) else {
            localErrorMessage = "請輸入有效的現值"
            return
        }
        if isIncludedInInvestments {
            guard let parsedCost = Decimal(string: costBasis), parsedCost > 0 else {
                showCostBasisRequired(scrollProxy: scrollProxy)
                return
            }
        }
        let costBasisDecimal: Decimal?
        if costBasis.isEmpty {
            costBasisDecimal = nil
        } else if let parsed = Decimal(string: costBasis) {
            costBasisDecimal = parsed
        } else {
            localErrorMessage = "請輸入有效的成本"
            return
        }

        let formState = ManualAssetFormState(
            name: name,
            category: category,
            currency: currency,
            currentValue: currentValueDecimal,
            costBasis: costBasisDecimal,
            purchaseDate: includesPurchaseDate ? purchaseDate : nil,
            notes: notes,
            isIncludedInTotalAssets: isIncludedInTotalAssets,
            isIncludedInInvestments: isIncludedInInvestments
        )

        Task {
            let succeeded: Bool
            switch mode {
            case .create(let userId):
                do {
                    let snapshot = try await PlusFeatureGate.loadSnapshot(userId: userId)
                    guard PlusFeatureGate.shouldBypassLimits(isPlusActive: subscriptionManager.isPlusActive)
                            || snapshot.activeAccountCount < PlusFreeLimits.maxAccounts else {
                        localErrorMessage = PlusFeatureGate.message(for: .accountLimitReached)
                        return
                    }
                } catch {
                    localErrorMessage = "無法驗證 Free 上限：\(error.localizedDescription)"
                    return
                }
                succeeded = await viewModel.createAsset(from: formState, userId: userId)
            case .edit(let asset, let syncCreationValuation):
                succeeded = await viewModel.updateAsset(
                    id: asset.id,
                    formState: formState,
                    userId: asset.userId,
                    syncCreationValuation: syncCreationValuation
                )
            }
            if succeeded {
                onSaved()
                if chrome == .sheet {
                    dismiss()
                }
            } else {
                localErrorMessage = viewModel.errorMessage
            }
        }
    }

    private func showCostBasisRequired(scrollProxy: ScrollViewProxy?) {
        costBasisErrorMessage = "納入投資時，請填寫大於 0 的成本。"
        guard let scrollProxy else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            scrollProxy.scrollTo(FieldID.costBasis, anchor: .center)
        }
    }

    private func clearErrors() {
        localErrorMessage = nil
        costBasisErrorMessage = nil
        viewModel.errorMessage = nil
    }

    private func sanitizedDecimalText(_ text: String, fallback: String) -> String {
        let filtered = text.filter { $0.isNumber || $0 == "." }
        guard filtered.filter({ $0 == "." }).count <= 1 else { return fallback }
        return filtered
    }
}
