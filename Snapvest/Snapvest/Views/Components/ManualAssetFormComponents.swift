//
//  ManualAssetFormComponents.swift
//  Snapvest
//
//  其他資產表單共用區塊（新增／編輯 sheet）。
//

import SwiftUI

// MARK: - 類別選擇

struct ManualAssetCategoryDropdownField: View {
    @Binding var selectedCategory: ManualAssetCategory
    let tint: Color

    @State private var showingCategoryPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(tint)
                Text("資產類別")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
            }

            Button {
                showingCategoryPicker = true
            } label: {
                HStack(spacing: 10) {
                    Text(selectedCategory.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: 44)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCategoryPicker) {
                ManualAssetCategorySelectionSheet(
                    selectedCategory: $selectedCategory,
                    tint: tint
                )
                .snapFormSheetChrome()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct ManualAssetCategorySelectionSheet: View {
    @Binding var selectedCategory: ManualAssetCategory
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ManualAssetCategory.allCases) { category in
                        categoryRow(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color.mainBackground)
            .navigationTitle("資產類別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .background(Color.mainBackground)
    }

    private func categoryRow(_ category: ManualAssetCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText.opacity(0.7))
                }
            }
            .padding(14)
            .background(isSelected ? tint.opacity(0.10) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.36) : Color.separator.opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 表單區塊

struct ManualAssetFormFieldSection<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    var trailing: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                if let trailing {
                    Text("(\(trailing))")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            content
        }
        .padding(20)
    }
}

struct ManualAssetFormDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 20)
    }
}

struct ManualAssetInclusionSection: View {
    @Binding var isIncludedInTotalAssets: Bool
    @Binding var isIncludedInInvestments: Bool
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isIncludedInTotalAssets) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("納入總資產")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    Text("會進首頁總資產、淨資產與總資產圓餅圖。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .tint(accentColor)

            Toggle(isOn: $isIncludedInInvestments) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("納入投資")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isIncludedInTotalAssets ? .primaryText : .secondaryText)
                    Text("會進投資組合、績效圖；需要成本才能計算報酬率。")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .tint(accentColor)
            .disabled(!isIncludedInTotalAssets)
            .opacity(isIncludedInTotalAssets ? 1 : 0.55)
        }
        .padding(20)
    }
}

struct ManualAssetPurchaseDateSection: View {
    @Binding var includesPurchaseDate: Bool
    @Binding var purchaseDate: Date
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $includesPurchaseDate) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(accentColor)
                    Text("購買日期")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    Text("(可選)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .tint(accentColor)

            if includesPurchaseDate {
                CardView {
                    SnapTappableDateField(date: $purchaseDate, sheetTitle: "購買日期")
                }
            }
        }
        .padding(20)
    }
}

struct ManualAssetFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
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
}

// MARK: - 幣別下拉（新增／編輯其他資產共用）

struct CurrencyDropdownField: View {
    let title: String
    let icon: String
    let color: Color
    let options: [Currency]
    @Binding var selectedCurrency: Currency
    var helperText: String?
    @State private var showingCurrencyPicker = false

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

            Button {
                showingCurrencyPicker = true
            } label: {
                HStack(spacing: 10) {
                    CurrencyCodeChip(currency: selectedCurrency, tint: color)

                    Text(selectedCurrency.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(minHeight: 44)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencySelectionSheet(
                    title: title,
                    options: options,
                    selectedCurrency: $selectedCurrency,
                    tint: color
                )
                .snapFormSheetChrome()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }

            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(.leading, 4)
            }
        }
    }
}

struct CurrencySelectionSheet: View {
    let title: String
    let options: [Currency]
    @Binding var selectedCurrency: Currency
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    selectedSummary

                    VStack(spacing: 10) {
                        ForEach(options, id: \.self) { currency in
                            currencyRow(currency)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color.mainBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .background(Color.mainBackground)
    }

    private var selectedSummary: some View {
        HStack(spacing: 12) {
            CurrencyIconBadge(currency: selectedCurrency, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text("目前選擇")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(selectedCurrency.settingsDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }

    private func currencyRow(_ currency: Currency) -> some View {
        let isSelected = selectedCurrency == currency
        return Button {
            selectedCurrency = currency
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CurrencyIconBadge(currency: currency, tint: isSelected ? tint : .secondaryText)

                VStack(alignment: .leading, spacing: 3) {
                    Text(currency.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(currency.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText.opacity(0.7))
                }
            }
            .padding(14)
            .background(isSelected ? tint.opacity(0.10) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.36) : Color.separator.opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 新增／編輯 sheet 共用外觀

struct AddSheetHeroCard: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                }

                Spacer(minLength: 0)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.separator.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

private struct AddSheetFormCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.separator.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
            .padding(.horizontal)
    }
}

extension View {
    func addSheetFormCard() -> some View {
        modifier(AddSheetFormCardModifier())
    }
}
