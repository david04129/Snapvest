//
//  SettingsView.swift
//  Snapvest
//
//  使用者可見的設定頁骨架
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var privacyLock = PrivacyLockManager.shared
    @ObservedObject private var demoMode = DemoModeManager.shared
    @ObservedObject private var baseCurrency = BaseCurrencyManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var comingSoonFeature: SettingsComingSoonFeature?
    @State private var privacyLockSettingsMessage: String?
    @State private var isBaseCurrencySheetPresented = false
    #if DEBUG
    @State private var isValidatingSnapshots = false
    @State private var snapshotValidationMessage: String?
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    plusCard
                    
                    settingsSection(title: "顯示") {
                        themeModeRow

                        Divider()
                            .padding(.leading, 56)

                        marketColorConventionRow

                        Divider()
                            .padding(.leading, 56)

                        baseCurrencyRow
                    }
                    
                    settingsSection(title: "體驗") {
                        demoModeRow
                    }

                    #if DEBUG
                    settingsSection(title: "開發") {
                        snapshotConsistencyRow
                    }
                    #endif
                    
                    settingsSection(title: "隱私與安全") {
                        privacyLockRow
                    }
                }
                .padding(20)
            }
            .background(Color.mainBackground.ignoresSafeArea())
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
            .alert(item: $comingSoonFeature) { feature in
                Alert(
                    title: Text(feature.title),
                    message: Text(feature.message),
                    dismissButton: .default(Text("知道了"))
                )
            }
            .alert(
                "隱私鎖",
                isPresented: Binding(
                    get: { privacyLockSettingsMessage != nil },
                    set: { if !$0 { privacyLockSettingsMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(privacyLockSettingsMessage ?? "")
            }
            #if DEBUG
            .alert(
                "快照一致性驗證",
                isPresented: Binding(
                    get: { snapshotValidationMessage != nil },
                    set: { if !$0 { snapshotValidationMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(snapshotValidationMessage ?? "")
            }
            #endif
            .sheet(isPresented: $isBaseCurrencySheetPresented) {
                BaseCurrencyPickerSheet(
                    selectedCurrency: baseCurrency.baseCurrency,
                    onSelect: { currency in
                        baseCurrency.setBaseCurrency(currency)
                        isBaseCurrencySheetPresented = false
                    }
                )
            }
        }
    }
    
    private var plusCard: some View {
        Button {
            comingSoonFeature = .subscription
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Walleaf Plus")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.primaryText)
                            Text("PLUS")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.appPrimary.opacity(0.16))
                                .clipShape(Capsule())
                        }
                        
                        Text("解鎖更多投資追蹤、分享與進階設定功能")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primaryText.opacity(0.78))
                    }
                    
                    Spacer(minLength: 12)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                }
                
                HStack {
                    Text("訂閱功能即將推出")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primaryText.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primaryText.opacity(0.55))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(plusCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(theme.isDarkMode ? 0.10 : 0.35), lineWidth: 1)
            }
            .shadow(color: AppColors.shadowMedium, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    private var plusCardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(hex: "#B7E99A"),
                Color(hex: "#7ED957"),
                Color(hex: "#F2C078")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.separator.opacity(0.45), lineWidth: 1)
            }
        }
    }
    
    private var themeModeRow: some View {
        settingsPillRow(
            icon: theme.isDarkMode ? "moon.fill" : "sun.max.fill",
            iconColor: .appPrimary,
            title: "深淺色模式"
        ) {
            SettingsPillOption(
                title: "淺色",
                isSelected: !theme.isDarkMode,
                selectedColor: .appPrimary,
                action: { theme.setDarkMode(false) }
            )
            SettingsPillOption(
                title: "深色",
                isSelected: theme.isDarkMode,
                selectedColor: .appPrimary,
                action: { theme.setDarkMode(true) }
            )
        }
    }
    
    private var marketColorConventionRow: some View {
        let upColor: Color = theme.isRedUpGreenDown ? .lossRed : .profitGreen
        
        return settingsPillRow(
            icon: "arrow.up",
            iconColor: upColor,
            title: "漲跌配色"
        ) {
            SettingsPillOption(
                title: "綠漲紅跌",
                isSelected: !theme.isRedUpGreenDown,
                selectedColor: upColor,
                action: { theme.setRedUpGreenDown(false) }
            )
            SettingsPillOption(
                title: "紅漲綠跌",
                isSelected: theme.isRedUpGreenDown,
                selectedColor: upColor,
                action: { theme.setRedUpGreenDown(true) }
            )
        }
    }
    
    private var baseCurrencyRow: some View {
        Button {
            isBaseCurrencySheetPresented = true
        } label: {
            settingsRowContent(
                icon: "dollarsign.circle.fill",
                iconColor: .appPrimary,
                title: "主要幣別",
                value: baseCurrency.baseCurrency.settingsDisplayName,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var privacyLockRow: some View {
        Button {
            Task { await togglePrivacyLock() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Face ID 解鎖")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    
                    Text("重新開啟或回到 App 時先驗證身分")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer(minLength: 12)
                
                if privacyLock.isAuthenticating {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    SettingsSwitchIndicator(isOn: privacyLock.isEnabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(privacyLock.isAuthenticating)
    }
    
    private var demoModeRow: some View {
        Button {
            Task {
                if demoMode.isEnabled {
                    await demoMode.exitDemoMode()
                } else {
                    await demoMode.enterDemoMode()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("示範模式")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(demoMode.isEnabled ? "目前正在使用本機沙盒資料" : "用一組示範資料體驗完整功能")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer(minLength: 12)
                
                if demoMode.isSwitching {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    Text(demoMode.isEnabled ? "退出" : "進入")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(demoMode.isEnabled ? .lossRed : .appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background((demoMode.isEnabled ? Color.lossRed : Color.appPrimary).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(demoMode.isSwitching)
    }

    #if DEBUG
    private var snapshotConsistencyRow: some View {
        Button {
            Task { await runSnapshotConsistencyValidation() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("驗證快照一致性")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Text("比對目前局部快照與一次全量重算結果")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                if isValidatingSnapshots {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    Text("執行")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isValidatingSnapshots)
    }

    @MainActor
    private func runSnapshotConsistencyValidation() async {
        guard !isValidatingSnapshots else { return }
        isValidatingSnapshots = true
        let report = await MockDataService.shared.debugValidateSnapshotConsistency(userId: AppUser.id)
        isValidatingSnapshots = false
        snapshotValidationMessage = report.summary
    }
    #endif
    
    private func togglePrivacyLock() async {
        let result = await privacyLock.setEnabled(!privacyLock.isEnabled)
        if case .failure(let message) = result {
            privacyLockSettingsMessage = message
        }
    }
    
    private func settingsPillRow<Options: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder options: () -> Options
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 30, height: 30)
                    .background(iconColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                options()
            }
            .padding(4)
            .background(Color.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
    
    private func settingsComingSoonRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        feature: SettingsComingSoonFeature
    ) -> some View {
        Button {
            comingSoonFeature = feature
        } label: {
            settingsRowContent(
                icon: icon,
                iconColor: iconColor,
                title: title,
                value: value,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }
    
    private func settingsRowContent(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

private enum SettingsComingSoonFeature: Identifiable {
    case subscription
    
    var id: String {
        switch self {
        case .subscription: return "subscription"
        }
    }
    
    var title: String {
        switch self {
        case .subscription: return "Walleaf Plus 即將推出"
        }
    }
    
    var message: String {
        switch self {
        case .subscription:
            return "之後會在這裡加入訂閱與升級功能。"
        }
    }
}

private struct SettingsPillOption: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? AppColors.actionForeground : .secondaryText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? selectedColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSwitchIndicator: View {
    let isOn: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(isOn ? Color.appPrimary : Color.secondaryBackground)
            .frame(width: 50, height: 30)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .shadow(color: AppColors.shadowLow, radius: 2, x: 0, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.separator.opacity(isOn ? 0 : 0.5), lineWidth: 1)
            }
    }
}

private struct BaseCurrencyPickerSheet: View {
    let selectedCurrency: Currency
    let onSelect: (Currency) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Currency.baseCurrencyOptions, id: \.self) { currency in
                        Button {
                            onSelect(currency)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(currency.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primaryText)
                                    Text(currency.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }

                                Spacer()

                                if selectedCurrency == currency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("選擇總覽與折算金額使用的幣別")
                } footer: {
                    Text("原幣仍會保留；首頁、帳戶總額與資產總覽會逐步改用主要幣別顯示。")
                }
            }
            .navigationTitle("主要幣別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
    }
}
