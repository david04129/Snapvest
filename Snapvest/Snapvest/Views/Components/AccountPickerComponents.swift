//
//  AccountPickerComponents.swift
//  Snapvest
//
//  表單帳戶選擇：與 CurrencyDropdownField／交易表單一致的觸發列與 Sheet 列表。
//

import SwiftUI

// MARK: - 觸發列

struct AccountPickerTriggerField: View {
    let placeholder: String
    let selectedAccount: Account?
    var subtitle: String? = nil
    var tint: Color = .appPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let account = selectedAccount {
                    CurrencyCodeChip(
                        currency: account.currency,
                        tint: account.accountType.color,
                        style: .filled
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                } else {
                    Text(placeholder)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondaryText)
                }

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
    }
}

// MARK: - 選擇 Sheet

struct AccountSelectionSheet: View {
    let title: String
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    var subtitle: (Account) -> String = { $0.accountType.displayName }
    var tint: Color = .appPrimary

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let selectedAccount {
                        selectedSummary(selectedAccount)
                    }

                    if accounts.isEmpty {
                        Text("尚無可選帳戶")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(accounts) { account in
                                accountRow(account)
                            }
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

    private func selectedSummary(_ account: Account) -> some View {
        HStack(spacing: 12) {
            CurrencyIconBadge(currency: account.currency, tint: account.accountType.color)

            VStack(alignment: .leading, spacing: 3) {
                Text("目前選擇")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                Text(subtitle(account))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
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

    private func accountRow(_ account: Account) -> some View {
        let isSelected = selectedAccount?.id == account.id
        return Button {
            selectedAccount = account
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CurrencyIconBadge(
                    currency: account.currency,
                    tint: isSelected ? account.accountType.color : .secondaryText
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(account.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(subtitle(account))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(account.accountType.color)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText.opacity(0.7))
                }
            }
            .padding(14)
            .background(isSelected ? account.accountType.color.opacity(0.10) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? account.accountType.color.opacity(0.36) : Color.separator.opacity(0.35),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
