//
//  ManualAssetDetailView.swift
//  Snapvest
//
//  Detail and edit surface for local-only other assets.
//

import SwiftUI

struct ManualAssetDetailView: View {
    let asset: ManualAsset
    @ObservedObject var viewModel: ManualAssetsViewModel
    let baseCurrency: Currency
    let twdPerBaseCurrency: Decimal
    let twdRateByCurrency: [Currency: Decimal]

    @Environment(\.dismiss) private var dismiss
    @State private var displayAsset: ManualAsset
    @State private var showingRenameSheet = false
    @State private var showingUpdateValueSheet = false
    @State private var isDetailsExpanded = false

    init(
        asset: ManualAsset,
        viewModel: ManualAssetsViewModel,
        baseCurrency: Currency,
        twdPerBaseCurrency: Decimal,
        twdRateByCurrency: [Currency: Decimal]
    ) {
        self.asset = asset
        self.viewModel = viewModel
        self.baseCurrency = baseCurrency
        self.twdPerBaseCurrency = twdPerBaseCurrency
        self.twdRateByCurrency = twdRateByCurrency
        _displayAsset = State(initialValue: asset)
    }

    private var accentColor: Color { .stockUSColor }

    private var currentValueTWD: Decimal {
        ManualAssetMetrics.valueTWD(asset: displayAsset, rates: twdRateByCurrency) ?? displayAsset.currentValue
    }

    private var currentValueBase: Decimal {
        twdPerBaseCurrency > 0 ? currentValueTWD / twdPerBaseCurrency : currentValueTWD
    }

    private var gainLossTWD: Decimal? {
        ManualAssetMetrics.gainLossTWD(asset: displayAsset, rates: twdRateByCurrency)
    }

    private var returnPercent: Decimal? {
        ManualAssetMetrics.returnPercent(asset: displayAsset, rates: twdRateByCurrency)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                metricsGrid
                detailsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.mainBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                SnapToolbarIconButton(icon: .back) { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameManualAssetSheet(
                asset: displayAsset,
                viewModel: viewModel
            ) { updated in
                displayAsset = updated
            }
        }
        .sheet(isPresented: $showingUpdateValueSheet) {
            ManualAssetUpdateValueView(
                asset: displayAsset,
                viewModel: viewModel
            ) { updated in
                displayAsset = updated
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayAsset.name)
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
                    .accessibilityLabel("重新命名其他資產")
                }

                Spacer()

                Text(displayAsset.category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                CurrencyIconBadge(
                    currency: displayAsset.currency,
                    tint: accentColor,
                    showsLabel: true,
                    labelTitle: "資產幣別"
                )
                .padding(.bottom, 4)

                CurrencyTitleLabel(
                    title: "目前現值",
                    currency: displayAsset.currency,
                    font: .caption,
                    weight: .regular,
                    color: .secondaryText,
                    chipTint: accentColor
                )
                CurrencyAmountLabel(
                    text: displayAsset.currentValue.formatted(currency: displayAsset.currency),
                    currency: displayAsset.currency,
                    font: .snapAmountHero,
                    weight: .bold,
                    color: .primaryText,
                    chipTint: accentColor
                )
                if displayAsset.currency != baseCurrency {
                    Text("≈ \(currentValueBase.formatted(currency: baseCurrency)) \(baseCurrency.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var metricsGrid: some View {
        if displayAsset.costBasis != nil {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                MetricTile(
                    title: "成本",
                    value: costAmountText,
                    currency: displayAsset.currency,
                    accentColor: accentColor
                )
                if let gainLossAmount {
                    MetricTile(
                        title: "未實現損益",
                        value: signedAmountText(gainLossAmount, currency: baseCurrency),
                        currency: baseCurrency,
                        valueColor: gainLossColor,
                        accentColor: accentColor
                    )
                }
                if let returnPercent {
                    MetricTile(
                        title: "報酬率",
                        value: signedPercentText(returnPercent),
                        valueColor: gainLossColor
                    )
                }
            }
        }
    }

    private var detailsCard: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDetailsExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text("詳細資訊")
                            .font(.headline)
                            .foregroundColor(.primaryText)

                        Spacer(minLength: 0)

                        Image(systemName: isDetailsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .frame(width: 24, height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isDetailsExpanded {
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.top, 8)

                        InfoRowWithoutIcon(label: "類別", value: displayAsset.category.displayName)

                        Divider()

                        currencyInfoRow

                        Divider()

                        InfoRowWithoutIcon(
                            label: "納入總資產",
                            value: displayAsset.isIncludedInTotalAssets ? "是" : "否"
                        )

                        Divider()

                        InfoRowWithoutIcon(
                            label: "納入投資",
                            value: displayAsset.isIncludedInInvestments ? "是" : "否"
                        )

                        Divider()

                        InfoRowWithoutIcon(
                            label: "更新日期",
                            value: displayAsset.currentValueUpdatedAt.formatted(date: .numeric, time: .omitted)
                        )

                        if let purchaseDate = displayAsset.purchaseDate {
                            Divider()
                            InfoRowWithoutIcon(
                                label: "購買日期",
                                value: purchaseDate.formatted(date: .numeric, time: .omitted)
                            )
                        }

                        if let notes = displayAsset.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !notes.isEmpty {
                            Divider()
                            InfoRowWithoutIcon(label: "備註", value: notes)
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var bottomActionBar: some View {
        Button {
            showingUpdateValueSheet = true
        } label: {
            Text("更新現值")
                .font(.headline)
                .foregroundColor(AppColors.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appPrimary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
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

    private var costAmountText: String {
        displayAsset.costBasis?.formatted(currency: displayAsset.currency) ?? ""
    }

    private var gainLossAmount: Decimal? {
        guard let gainLossTWD else { return nil }
        return twdPerBaseCurrency > 0 ? gainLossTWD / twdPerBaseCurrency : gainLossTWD
    }

    private var currencyInfoRow: some View {
        HStack {
            Text("幣別")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer()
            HStack(spacing: 6) {
                CurrencyCodeChip(currency: displayAsset.currency, tint: accentColor, style: .filled)
                Text(displayAsset.currency.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }
        }
    }

    private var gainLossColor: Color {
        Color.marketColor(for: gainLossTWD ?? 0)
    }

    private func signedAmountText(_ amount: Decimal, currency: Currency) -> String {
        let prefix = amount >= 0 ? "+" : ""
        return prefix + amount.formatted(currency: currency)
    }

    private func signedPercentText(_ percent: Decimal) -> String {
        let prefix = percent >= 0 ? "+" : ""
        return "\(prefix)\(percent.formatted(fractionDigits: 2))%"
    }
}

private struct RenameManualAssetSheet: View {
    let asset: ManualAsset
    @ObservedObject var viewModel: ManualAssetsViewModel
    let onSaved: (ManualAsset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    init(asset: ManualAsset, viewModel: ManualAssetsViewModel, onSaved: @escaping (ManualAsset) -> Void) {
        self.asset = asset
        self.viewModel = viewModel
        self.onSaved = onSaved
        _name = State(initialValue: asset.name)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName != asset.name && !viewModel.isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("其他資產名稱", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("同一類別下的其他資產名稱不可重複。")
                }

                if let message = errorMessage ?? viewModel.errorMessage {
                    Section {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.lossRed)
                    }
                }
            }
            .navigationTitle("重新命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .snapFormSheetChrome()
    }

    @MainActor
    private func save() async {
        var form = ManualAssetFormState(asset: asset)
        form.name = trimmedName
        let succeeded = await viewModel.updateAsset(id: asset.id, formState: form, userId: asset.userId)
        if succeeded {
            var updated = asset
            updated.name = trimmedName
            updated.updatedAt = Date()
            onSaved(updated)
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage
        }
    }
}

struct ManualAssetUpdateValueView: View {
    let asset: ManualAsset
    @ObservedObject var viewModel: ManualAssetsViewModel
    let editingValuation: ManualAssetValuation?
    let onSaved: (ManualAsset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newValueText: String
    @State private var valuationDate: Date
    @State private var notes: String
    @State private var errorMessage: String?

    init(
        asset: ManualAsset,
        viewModel: ManualAssetsViewModel,
        editingValuation: ManualAssetValuation? = nil,
        onSaved: @escaping (ManualAsset) -> Void
    ) {
        self.asset = asset
        self.viewModel = viewModel
        self.editingValuation = editingValuation
        self.onSaved = onSaved
        _newValueText = State(
            initialValue: (editingValuation?.value ?? asset.currentValue).formattedQuantityInput(maxFractionDigits: 2)
        )
        _valuationDate = State(initialValue: editingValuation?.valuationDate ?? Date())
        _notes = State(initialValue: editingValuation?.notes ?? "")
    }

    private var themeColor: Color { .appPrimary }

    private var newValue: Decimal? {
        Decimal(string: newValueText)
    }

    private var delta: Decimal? {
        guard let newValue else { return nil }
        return newValue - asset.currentValue
    }

    private var isValid: Bool {
        guard let newValue else { return false }
        if editingValuation != nil {
            return newValue >= 0 && !viewModel.isSaving
        }
        return newValue >= 0 && newValue != asset.currentValue && !viewModel.isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    currentAssetSection
                    amountSection
                    dateSection
                    notesSection
                    errorMessageSection
                }
            }
            .snapFormScrollDismissesKeyboard()
            .navigationTitle(editingValuation == nil ? "更新現值" : "編輯現值紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SnapToolbarIconButton(icon: .close) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    saveValue()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                        Text(viewModel.isSaving ? "更新中..." : "確認更新")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? themeColor : AppColors.disabledBackground)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
        }
        .snapFormSheetChrome()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "pencil.circle")
                        .font(.system(size: 24))
                        .foregroundColor(themeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("更新現值")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(editingValuation == nil ? "直接更新其他資產現值，系統會保存估值紀錄。" : "修改這筆其他資產估值紀錄。")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 8)
    }

    private var currentAssetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目前資產")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)

            CardView {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("目前現值：")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            CurrencyAmountLabel(
                                text: asset.currentValue.formatted(currency: asset.currency),
                                currency: asset.currency,
                                font: .caption,
                                weight: .semibold,
                                color: .secondaryText,
                                chipTint: themeColor
                            )
                        }
                    }
                    Spacer(minLength: 0)
                    CurrencyCodeChip(currency: asset.currency, tint: themeColor, style: .filled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("新的現值")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }

            AmountKeypadInputView(
                text: $newValueText,
                currency: asset.currency,
                accentColor: themeColor
            )
            .onChange(of: newValueText) { oldValue, newValue in
                handleValueChange(oldValue: oldValue, newValue: newValue)
            }

            valueChangeResultCard
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var valueChangeResultCard: some View {
        if let delta, delta != 0 {
            CardView {
                let absDelta = delta > 0 ? delta : -delta
                let amountColor: Color = delta > 0 ? .profitGreen : .lossRed
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(delta > 0 ? "資產增加" : "資產減少")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(amountColor)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(absDelta.formatted(currency: asset.currency))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(amountColor)
                        }
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("日期")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }

            VStack(alignment: .leading, spacing: 0) {
                SnapTappableDateField(
                    date: $valuationDate,
                    sheetTitle: "日期",
                    showsLeadingIcon: false
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.separator.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundColor(themeColor)
                Text("備註 (選填)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }

            CardView {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.secondaryText)
                        .padding(.top, 2)

                    TextField("例如：年度估值更新", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var errorMessageSection: some View {
        if let message = errorMessage ?? viewModel.errorMessage {
            CardView {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.lossRed)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.lossRed)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func handleValueChange(oldValue: String, newValue: String) {
        let filtered = newValue.filter { $0.isNumber || $0 == "." }
        if filtered != newValue {
            newValueText = filtered
        }
        if let value = Decimal(string: filtered), value < 0 {
            newValueText = oldValue.isEmpty ? "" : oldValue
        }
        validateInput()
    }

    private func validateInput() {
        errorMessage = nil
        guard let newValue = Decimal(string: newValueText), !newValueText.isEmpty else { return }
        if newValue < 0 {
            errorMessage = "現值不可為負數"
        } else if editingValuation == nil, newValue == asset.currentValue {
            errorMessage = "金額未變更"
        }
    }

    private func saveValue() {
        guard let newValue = Decimal(string: newValueText), newValue >= 0 else {
            validateInput()
            return
        }
        if editingValuation == nil, newValue == asset.currentValue {
            validateInput()
            return
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let succeeded: Bool
            if let editingValuation {
                succeeded = await viewModel.updateManualAssetValuation(
                    asset: asset,
                    valuation: editingValuation,
                    value: newValue,
                    valuationDate: valuationDate,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
            } else {
                succeeded = await viewModel.updateCurrentValue(
                    asset: asset,
                    currentValue: newValue,
                    valuationDate: valuationDate,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
            }
            if succeeded {
                var updated = asset
                updated.currentValue = newValue
                updated.currentValueUpdatedAt = valuationDate
                updated.updatedAt = Date()
                onSaved(updated)
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage
            }
        }
    }
}

struct ManualAssetEditSheet: View {
    enum Mode {
        case full
        case valueOnly
    }

    let asset: ManualAsset
    @ObservedObject var viewModel: ManualAssetsViewModel
    let mode: Mode
    var syncCreationValuation: Bool = false
    let onSaved: (ManualAsset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: ManualAssetCategory
    @State private var currency: Currency
    @State private var currentValue: String
    @State private var costBasis: String
    @State private var isIncludedInTotalAssets: Bool
    @State private var isIncludedInInvestments: Bool
    @State private var purchaseDate: Date
    @State private var includesPurchaseDate: Bool
    @State private var notes: String
    @State private var errorMessage: String?

    init(
        asset: ManualAsset,
        viewModel: ManualAssetsViewModel,
        mode: Mode,
        syncCreationValuation: Bool = false,
        onSaved: @escaping (ManualAsset) -> Void
    ) {
        self.asset = asset
        self.viewModel = viewModel
        self.mode = mode
        self.syncCreationValuation = syncCreationValuation
        self.onSaved = onSaved
        _name = State(initialValue: asset.name)
        _category = State(initialValue: asset.category)
        _currency = State(initialValue: asset.currency)
        _currentValue = State(initialValue: NSDecimalNumber(decimal: asset.currentValue).stringValue)
        _costBasis = State(initialValue: asset.costBasis.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        _isIncludedInTotalAssets = State(initialValue: asset.isIncludedInTotalAssets)
        _isIncludedInInvestments = State(initialValue: asset.isIncludedInInvestments)
        _purchaseDate = State(initialValue: asset.purchaseDate ?? Date())
        _includesPurchaseDate = State(initialValue: asset.purchaseDate != nil)
        _notes = State(initialValue: asset.notes ?? "")
    }

    private var title: String {
        mode == .valueOnly ? "更新現值" : "編輯其他資產"
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .full {
                    Section("基本資料") {
                        Picker("類別", selection: $category) {
                            ForEach(ManualAssetCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        TextField("名稱", text: $name)
                        Picker("幣別", selection: $currency) {
                            ForEach(Currency.baseCurrencyOptions, id: \.self) { currency in
                                Text(currency.rawValue).tag(currency)
                            }
                        }
                    }
                }

                Section(mode == .valueOnly ? "目前現值" : "估值") {
                    TextField("目前現值", text: $currentValue)
                        .keyboardType(.decimalPad)
                    if mode == .full {
                        Toggle("納入總資產", isOn: $isIncludedInTotalAssets)
                        Toggle("納入投資", isOn: $isIncludedInInvestments)
                            .disabled(!isIncludedInTotalAssets)
                        if isIncludedInInvestments {
                            TextField("成本（必填）", text: $costBasis)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                if mode == .full {
                    Section("其他") {
                        Toggle("填寫購買日期", isOn: $includesPurchaseDate)
                        if includesPurchaseDate {
                            DatePicker("購買日期", selection: $purchaseDate, displayedComponents: .date)
                        }
                        TextField("備註", text: $notes, axis: .vertical)
                    }
                }

                if let message = errorMessage ?? viewModel.errorMessage {
                    Section {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.lossRed)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: isIncludedInTotalAssets) { _, included in
                if !included { isIncludedInInvestments = false }
            }
            .onChange(of: isIncludedInInvestments) { _, included in
                if included { isIncludedInTotalAssets = true }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task { await save() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .snapFormSheetChrome()
    }

    @MainActor
    private func save() async {
        guard let value = Decimal(string: currentValue) else {
            errorMessage = "請輸入有效的現值"
            return
        }
        let parsedCost: Decimal?
        if costBasis.isEmpty {
            parsedCost = nil
        } else if let cost = Decimal(string: costBasis) {
            parsedCost = cost
        } else {
            errorMessage = "請輸入有效的成本"
            return
        }

        var form = ManualAssetFormState(asset: asset)
        if mode == .full {
            form.name = name
            form.category = category
            form.currency = currency
            form.costBasis = parsedCost
            form.purchaseDate = includesPurchaseDate ? purchaseDate : nil
            form.notes = notes
            form.isIncludedInTotalAssets = isIncludedInTotalAssets
            form.isIncludedInInvestments = isIncludedInInvestments
        }
        form.currentValue = value

        let succeeded = await viewModel.updateAsset(
            id: asset.id,
            formState: form,
            userId: asset.userId,
            syncCreationValuation: syncCreationValuation
        )
        if succeeded {
            var updated = try? form.makeAsset(userId: asset.userId, existing: asset)
            updated?.currentValue = value
            onSaved(updated ?? asset)
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage
        }
    }
}
