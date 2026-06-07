//
//  SettingsView.swift
//  Snapvest
//
//  使用者可見的設定頁骨架
//

import SwiftUI
import StoreKit
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var privacyLock = PrivacyLockManager.shared
    @ObservedObject private var baseCurrency = BaseCurrencyManager.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var comingSoonFeature: SettingsComingSoonFeature?
    @State private var isPaywallPresented = false
    @State private var privacyLockSettingsMessage: String?
    @State private var isBaseCurrencySheetPresented = false
    @State private var isPreparingBackup = false
    @State private var isBackupExporterPresented = false
    @State private var backupExportDocument = BackupDocument()
    @State private var backupExportFilename = "Walleaf-Backup"
    @State private var isBackupImporterPresented = false
    @State private var pendingBackupRestore: WalleafBackupFile?
    @State private var isRestoreConfirmationPresented = false
    @State private var isRestoringBackup = false
    @State private var backupStatusMessage: String?
    @State private var isBackupRestoreLoadingVisible = false
    @State private var backupRestoreLoadingTitle = ""
    @State private var backupRestoreLoadingMessage = ""
    @State private var editingCustomForDarkMode: Bool = false
    @State private var themeCustomCopyMessage: String?
    @State private var isAboutSheetPresented = false
    #if DEBUG
    @State private var isValidatingSnapshots = false
    @State private var snapshotValidationMessage: String?
    @State private var isImportingPreviousClose = false
    @State private var previousCloseImportMessage: String?
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    plusCard
                    
                    settingsSection(title: "顯示") {
                        themeModeRow

                        if AppFeatureFlags.showsThemeStylePicker {
                            Divider()
                                .padding(.leading, 56)

                            themeStyleRow
                            themeCustomSection
                        }

                        Divider()
                            .padding(.leading, 56)

                        marketColorConventionRow

                        Divider()
                            .padding(.leading, 56)

                        baseCurrencyRow
                    }
                    
                    settingsSection(title: "使用教學") {
                        NavigationLink {
                            UsageTutorialsHubView(onDismissSettings: { dismiss() })
                        } label: {
                            usageTutorialsEntryRow
                        }
                        .buttonStyle(.plain)
                        .tint(.primaryText)
                    }

                    #if DEBUG
                    if AppFeatureFlags.showsDeveloperSettings {
                        settingsSection(title: "開發") {
                            snapshotConsistencyRow

                            Divider()
                                .padding(.leading, 56)

                            importPreviousCloseRow
                        }
                    }
                    #endif
                    
                    settingsSection(title: "隱私與安全") {
                        privacyLockRow
                    }

                    settingsSection(title: "備份與還原") {
                        backupExportRow

                        Divider()
                            .padding(.leading, 56)

                        backupRestoreRow
                    }

                    settingsSection(title: "其他") {
                        aboutAppRow

                        Divider()
                            .padding(.leading, 56)

                        contactSupportRow

                        Divider()
                            .padding(.leading, 56)

                        fiveStarReviewRow
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
            .fullScreenCover(isPresented: $isPaywallPresented) {
                WalleafPlusPaywallView()
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
            .alert(
                "匯入昨日收盤價",
                isPresented: Binding(
                    get: { previousCloseImportMessage != nil },
                    set: { if !$0 { previousCloseImportMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(previousCloseImportMessage ?? "")
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
            .sheet(isPresented: $isAboutSheetPresented) {
                AboutAppSheet(version: appVersionText)
            }
            .fileExporter(
                isPresented: $isBackupExporterPresented,
                document: backupExportDocument,
                contentType: .json,
                defaultFilename: backupExportFilename
            ) { result in
                switch result {
                case .success:
                    backupStatusMessage = "備份檔已建立。若你選擇 iCloud Drive 位置，檔案會保存在自己的 iCloud。請妥善保管備份檔。"
                case .failure(let error):
                    backupStatusMessage = "備份失敗：\(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $isBackupImporterPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleBackupImport(result)
            }
            .alert("還原將取代目前資料？", isPresented: $isRestoreConfirmationPresented) {
                Button("取消", role: .cancel) {
                    pendingBackupRestore = nil
                }
                Button("仍要還原", role: .destructive) {
                    Task { await restorePendingBackup() }
                }
            } message: {
                Text(restoreConfirmationMessage)
            }
            .alert(
                "備份與還原",
                isPresented: Binding(
                    get: { backupStatusMessage != nil },
                    set: { if !$0 { backupStatusMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(backupStatusMessage ?? "")
            }
            .alert(
                "自訂配色",
                isPresented: Binding(
                    get: { themeCustomCopyMessage != nil },
                    set: { if !$0 { themeCustomCopyMessage = nil } }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(themeCustomCopyMessage ?? "")
            }
            .onAppear {
                editingCustomForDarkMode = theme.isDarkMode
            }
            .onChange(of: theme.isDarkMode) { _, _ in
                editingCustomForDarkMode = theme.isDarkMode
            }
            .onChange(of: theme.isCustomThemeActive) { _, isActive in
                if isActive {
                    editingCustomForDarkMode = theme.isDarkMode
                }
            }
            .overlay {
                if isBackupRestoreLoadingVisible {
                    OperationLoadingOverlay(
                        title: backupRestoreLoadingTitle,
                        message: backupRestoreLoadingMessage
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isBackupRestoreLoadingVisible)
        }
    }
    
    private var plusCard: some View {
        Button {
            isPaywallPresented = true
        } label: {
            VStack(alignment: .leading, spacing: subscriptionManager.isPlusActive ? 14 : 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Walleaf Plus")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(plusCardForeground)
                            plusCardBadge
                        }
                        
                        Text(subscriptionManager.isPlusActive
                            ? WalleafPlusPaywallL10n.settingsCardDescriptionSubscribed
                            : WalleafPlusPaywallL10n.settingsCardDescription)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(plusCardSecondaryForeground)
                    }
                    
                    Spacer(minLength: 12)
                    
                    plusCardIcon
                }
                
                if !subscriptionManager.isPlusActive {
                    HStack {
                        Text(WalleafPlusPaywallL10n.settingsCardSubtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(plusCardSecondaryForeground)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(plusCardChevronColor)
                    }
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

    @ViewBuilder
    private var plusCardBadge: some View {
        if subscriptionManager.isPlusActive {
            Text("PLUS")
            .font(.system(size: 11, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.18))
            .clipShape(Capsule())
        } else {
            Text("PLUS")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.appPrimary.opacity(0.16))
                .clipShape(Capsule())
        }
    }

    private var plusCardIcon: some View {
        Group {
            if subscriptionManager.isPlusActive {
                settingsPlusLogo
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                }
            }
        }
    }

    private var settingsPlusLogo: some View {
        ZStack(alignment: .topTrailing) {
            Image(SnapvestBrand.logoImageName)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)

            settingsLogoPlusBadge
                .offset(x: 5, y: -5)
        }
    }

    private var settingsLogoPlusBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#8BE06A"), Color.appPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                .frame(width: 24, height: 24)

            SettingsRoundedPlusMark(color: .white, armLength: 9, armThickness: 2)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
    }
    
    private var plusCardBackground: some ShapeStyle {
        if subscriptionManager.isPlusActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "#17324A"),
                        Color(hex: "#2F6F73"),
                        Color(hex: "#79D2B6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(hex: "#B7E99A"),
                    Color(hex: "#7ED957"),
                    Color(hex: "#F2C078")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var plusCardForeground: Color {
        subscriptionManager.isPlusActive ? .white : .primaryText
    }

    private var plusCardSecondaryForeground: Color {
        subscriptionManager.isPlusActive ? .white.opacity(0.82) : .primaryText.opacity(0.7)
    }

    private var plusCardChevronColor: Color {
        subscriptionManager.isPlusActive ? .white.opacity(0.65) : .primaryText.opacity(0.55)
    }

    private var plusCardIconBackground: Color {
        subscriptionManager.isPlusActive ? Color.black.opacity(0.24) : Color.white.opacity(0.16)
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
    
    private var themeStyleRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                    .frame(width: 28, alignment: .center)

                Text("風格")
                    .font(.body)
                    .foregroundColor(.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            VStack(spacing: 10) {
                ForEach(ThemeStyleID.allCases) { style in
                    ThemeStyleOptionCard(
                        style: style,
                        isSelected: !theme.isCustomThemeActive && theme.selectedStyle == style,
                        isDarkMode: theme.isDarkMode
                    ) {
                        theme.setStyle(style)
                    }
                }

                ThemeCustomStyleOptionCard(
                    isSelected: theme.isCustomThemeActive,
                    isDarkMode: theme.isDarkMode,
                    lightOverrides: theme.customOverrides(forDarkMode: false),
                    darkOverrides: theme.customOverrides(forDarkMode: true),
                    baseStyle: theme.selectedStyle
                ) {
                    theme.activateCustomTheme()
                    editingCustomForDarkMode = theme.isDarkMode
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, theme.isCustomThemeActive ? 10 : 13)
        }
    }

    @ViewBuilder
    private var themeCustomSection: some View {
        if theme.isCustomThemeActive {
            themeCustomEditor
        }
    }

    private var themeCustomEditor: some View {
        let basePalette = ThemeStyleCatalog.palette(
            style: theme.selectedStyle,
            isDarkMode: editingCustomForDarkMode
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ThemeCustomModeChip(
                    title: "淺色自訂",
                    isSelected: !editingCustomForDarkMode
                ) {
                    editingCustomForDarkMode = false
                    theme.setDarkMode(false)
                }
                ThemeCustomModeChip(
                    title: "深色自訂",
                    isSelected: editingCustomForDarkMode
                ) {
                    editingCustomForDarkMode = true
                    theme.setDarkMode(true)
                }
            }
            .padding(.horizontal, 14)

            VStack(spacing: 6) {
                ThemeCustomColorGroupHeader(title: "背景")
                ThemeCustomColorPickerRow(
                    label: "主背景",
                    color: customColorBinding(
                        \.mainBackground,
                        fallback: basePalette.mainBackground,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "卡片",
                    color: customColorBinding(
                        \.cardBackground,
                        fallback: basePalette.cardBackground,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "次層",
                    color: customColorBinding(
                        \.secondaryBackground,
                        fallback: basePalette.secondaryBackground,
                        editingDark: editingCustomForDarkMode
                    )
                )

                ThemeCustomColorGroupHeader(title: "品牌")
                    .padding(.top, 6)
                ThemeCustomColorPickerRow(
                    label: "主色",
                    color: customColorBinding(
                        \.appPrimary,
                        fallback: basePalette.appPrimary,
                        editingDark: editingCustomForDarkMode
                    )
                )

                ThemeCustomColorGroupHeader(title: "投資類別")
                    .padding(.top, 6)
                ThemeCustomColorPickerRow(
                    label: "台股",
                    color: customColorBinding(
                        \.stockTW,
                        fallback: basePalette.stockTWColor,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "美股",
                    color: customColorBinding(
                        \.stockUS,
                        fallback: basePalette.stockUSColor,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "加密",
                    color: customColorBinding(
                        \.crypto,
                        fallback: basePalette.cryptoColor,
                        editingDark: editingCustomForDarkMode
                    )
                )

                ThemeCustomColorGroupHeader(title: "首頁大類")
                    .padding(.top, 6)
                ThemeCustomColorPickerRow(
                    label: "淨資產",
                    color: customColorBinding(
                        \.homeNetWorth,
                        fallback: basePalette.homeNetWorthAccent,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "投資資產",
                    color: customColorBinding(
                        \.homeInvestments,
                        fallback: basePalette.homeInvestmentsAccent,
                        editingDark: editingCustomForDarkMode
                    )
                )
                ThemeCustomColorPickerRow(
                    label: "現金",
                    color: customColorBinding(
                        \.homeCash,
                        fallback: basePalette.homeCashAccent,
                        editingDark: editingCustomForDarkMode
                    )
                )
            }
            .padding(.horizontal, 14)

            HStack(spacing: 10) {
                Button {
                    theme.clearCustomOverrides(isDarkMode: editingCustomForDarkMode)
                } label: {
                    Text("清除此模式")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    copyCustomThemeDescription()
                } label: {
                    Text("複製設定說明")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.appPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 13)
        }
    }

    private func customColorBinding(
        _ keyPath: WritableKeyPath<ThemeCustomColorOverrides, String?>,
        fallback: Color,
        editingDark: Bool
    ) -> Binding<Color> {
        Binding(
            get: {
                let overrides = theme.customOverrides(forDarkMode: editingDark)
                return overrides.color(for: keyPath) ?? fallback
            },
            set: { newColor in
                theme.setCustomColor(newColor, for: keyPath, isDarkMode: editingDark)
            }
        )
    }

    private func copyCustomThemeDescription() {
        let text = theme.exportCustomColorDescription(editingDarkMode: editingCustomForDarkMode)
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        themeCustomCopyMessage = "已複製到剪貼簿。可貼給開發或 AI 說明想要的配色。"
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
            icon: MarketDirectionSymbol.systemName(isUp: true),
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
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text("主要幣別")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Spacer(minLength: 12)

                BaseCurrencyDisplayLabel(
                    currency: baseCurrency.baseCurrency,
                    style: .filled
                )

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var aboutAppRow: some View {
        Button {
            isAboutSheetPresented = true
        } label: {
            settingsRowContent(
                icon: "info.circle.fill",
                iconColor: .appPrimary,
                title: "關於",
                value: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var contactSupportRow: some View {
        Button {
            openSupportEmail()
        } label: {
            settingsRowContent(
                icon: "envelope.fill",
                iconColor: .appPrimary,
                title: "聯繫我們",
                value: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var fiveStarReviewRow: some View {
        Button {
            requestAppReview()
        } label: {
            settingsRowContent(
                icon: "star.fill",
                iconColor: .appPrimary,
                title: "五星好評",
                value: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func openSupportEmail() {
        let subject = "Walleaf 使用問題"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:\(SettingsExternalLinks.supportEmail)?subject=\(encodedSubject)") else { return }
        openURL(url)
    }

    private func requestAppReview() {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        #endif
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

    private var backupExportRow: some View {
        Button {
            guard PlusFeatureGate.canUseBackupRestore(isPlusActive: subscriptionManager.isPlusActive) else {
                isPaywallPresented = true
                return
            }
            Task { await exportBackup() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("備份到 iCloud Drive")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Text("匯出帳戶、交易、其他資產、走勢點與偏好")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                if isPreparingBackup {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    Text("備份")
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
        .disabled(isPreparingBackup || isRestoringBackup)
    }

    private var backupRestoreRow: some View {
        Button {
            guard PlusFeatureGate.canUseBackupRestore(isPlusActive: subscriptionManager.isPlusActive) else {
                isPaywallPresented = true
                return
            }
            isBackupImporterPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("從備份還原")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Text("選取備份檔；還原會完全取代目前本機資料")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                if isRestoringBackup {
                    ProgressView()
                        .tint(.appPrimary)
                } else {
                    Text("還原")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.lossRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.lossRed.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPreparingBackup || isRestoringBackup)
    }
    
    private var usageTutorialsEntryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 30, height: 30)
                .background(Color.appPrimary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("教學與示範模式")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primaryText)

                Text("功能導覽、操作教學與沙盒體驗")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
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

    private var importPreviousCloseRow: some View {
        Button {
            Task { await runPreviousCloseImport() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("匯入昨日收盤價")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)

                    Text("從雲端 history 對齊各持股日漲跌基準昨收")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                if isImportingPreviousClose {
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
        .disabled(isImportingPreviousClose)
    }

    @MainActor
    private func runPreviousCloseImport() async {
        guard !isImportingPreviousClose else { return }
        isImportingPreviousClose = true
        let result = await PreviousCloseImportService.importForPortfolio(userId: AppUser.id)
        isImportingPreviousClose = false
        previousCloseImportMessage = result.summaryMessage
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
        if !privacyLock.isEnabled {
            guard PlusFeatureGate.canUsePrivacyLock(isPlusActive: subscriptionManager.isPlusActive) else {
                isPaywallPresented = true
                return
            }
        }

        let result = await privacyLock.setEnabled(!privacyLock.isEnabled)
        if case .failure(let message) = result {
            privacyLockSettingsMessage = message
        }
    }

    private var restoreConfirmationMessage: String {
        guard let pendingBackupRestore else {
            return "還原後，這台裝置上的現有資料會被移除，並以備份檔內容完全取代（不會合併）。若你仍需要目前的資料，請先匯出一份新備份。"
        }
        return """
        備份建立時間：\(formatBackupDate(pendingBackupRestore.createdAt))

        還原後，這台裝置上的現有資料會被移除，並以備份檔內容完全取代（不會合併）。

        將被取代的內容包含：帳戶、交易、持股、其他資產、走勢圖與偏好設定。

        若你仍需要目前的資料，請先「匯出備份」再繼續。
        """
    }

    private func exportBackup() async {
        guard !isPreparingBackup else { return }
        isPreparingBackup = true
        defer { isPreparingBackup = false }

        do {
            try await runBackupRestoreOperation(
                title: "正在準備備份…",
                message: "匯出帳戶、交易與偏好設定"
            ) {
                let backup = try BackupService.makeBackup(userId: AppUser.id)
                backupExportDocument = BackupDocument(data: try BackupService.encode(backup))
                backupExportFilename = BackupService.defaultFilename(createdAt: backup.createdAt)
                isBackupExporterPresented = true
            }
        } catch {
            backupStatusMessage = "備份失敗：\(error.localizedDescription)"
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            pendingBackupRestore = try BackupService.decodeBackup(from: url)
            isRestoreConfirmationPresented = true
        } catch {
            backupStatusMessage = "讀取備份失敗：\(error.localizedDescription)"
        }
    }

    private func restorePendingBackup() async {
        guard let pendingBackupRestore else { return }
        isRestoringBackup = true
        defer {
            isRestoringBackup = false
            self.pendingBackupRestore = nil
        }

        do {
            try await runBackupRestoreOperation(
                title: "正在還原備份…",
                message: "完成後會自動顯示備份中的資料"
            ) {
                try await BackupService.restore(pendingBackupRestore, to: AppUser.id)
            }
            backupStatusMessage = "還原完成。首頁、帳戶與資產資料已重新整理。"
        } catch {
            backupStatusMessage = "還原失敗：\(error.localizedDescription)"
        }
    }

    private func runBackupRestoreOperation(
        title: String,
        message: String,
        operation: () async throws -> Void
    ) async rethrows {
        backupRestoreLoadingTitle = title
        backupRestoreLoadingMessage = message
        isBackupRestoreLoadingVisible = true
        let start = ContinuousClock.now

        do {
            try await operation()
        } catch {
            await MinimumDurationLoading.waitIfNeeded(since: start)
            isBackupRestoreLoadingVisible = false
            throw error
        }

        await MinimumDurationLoading.waitIfNeeded(since: start)
        isBackupRestoreLoadingVisible = false
    }

    private func formatBackupDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter.string(from: date)
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
        value: String?,
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
            
            if let value, !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
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
    @State private var isInfoAlertPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Currency.baseCurrencyOptions, id: \.self) { currency in
                        Button {
                            onSelect(currency)
                        } label: {
                            HStack(spacing: 12) {
                                BaseCurrencyDisplayLabel(
                                    currency: currency,
                                    style: selectedCurrency == currency ? .filled : .subtle
                                )

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
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isInfoAlertPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .foregroundColor(.appPrimary)
                    .accessibilityLabel("主要幣別說明")
                }
            }
            .alert("主要幣別說明", isPresented: $isInfoAlertPresented) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("選擇主要幣別後，首頁、帳戶總額與資產總覽會用當下可用的匯率，將各資產與外幣金額換算成你選擇的主要幣別顯示。原始幣別與原幣金額仍會保留。")
            }
        }
    }
}

private struct BaseCurrencyDisplayLabel: View {
    let currency: Currency
    var style: CurrencyCodeChip.Style

    var body: some View {
        HStack(spacing: 8) {
            CurrencyCodeChip(
                currency: currency,
                tint: currency.chipTintColor,
                style: style
            )

            Text(currency.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum SettingsExternalLinks {
    static let supportEmail = "support@walleafapp.com"
    static let privacyPolicyURL = URL(string: "https://walleafapp.com/privacy/")!
    static let termsURL = URL(string: "https://walleafapp.com/terms/")!
    static let disclaimerURL = URL(string: "https://walleafapp.com/disclaimer/")!
}

private struct AboutAppSheet: View {
    let version: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(SnapvestBrand.logoImageName)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.separator.opacity(0.45), lineWidth: 1)
                            }

                        VStack(spacing: 4) {
                            Text(SnapvestBrand.appName)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.primaryText)
                            Text("版本 \(version)")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section {
                    legalLinkRow(
                        title: "隱私權政策",
                        subtitle: "了解 Walleaf 如何處理資料與隱私",
                        url: SettingsExternalLinks.privacyPolicyURL
                    )
                    legalLinkRow(
                        title: "服務條款",
                        subtitle: "使用 Walleaf 與 Walleaf Plus 的條款",
                        url: SettingsExternalLinks.termsURL
                    )
                    legalLinkRow(
                        title: "免責聲明",
                        subtitle: "報價、匯率與投資資訊準確性說明",
                        url: SettingsExternalLinks.disclaimerURL
                    )
                } footer: {
                    Text("正式上架前，請先將上述連結換成已公開且可開啟的政策頁面網址。")
                }
            }
            .navigationTitle("關於")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
    }

    private func legalLinkRow(title: String, subtitle: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 配色風格選項

private struct ThemeCustomStyleOptionCard: View {
    let isSelected: Bool
    let isDarkMode: Bool
    let lightOverrides: ThemeCustomColorOverrides
    let darkOverrides: ThemeCustomColorOverrides
    let baseStyle: ThemeStyleID
    let action: () -> Void

    private var previewColors: (stockTW: Color, stockUS: Color, crypto: Color) {
        let overrides = isDarkMode ? darkOverrides : lightOverrides
        let base = ThemeStyleCatalog.palette(style: baseStyle, isDarkMode: isDarkMode)
        let resolved = ThemeStyleCatalog.applying(custom: overrides, to: base, isDarkMode: isDarkMode)
        return (resolved.stockTWColor, resolved.stockUSColor, resolved.cryptoColor)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自訂配色")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text("套用你的淺色／深色自訂色")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    ThemeStyleSwatch(color: previewColors.stockTW, label: "台股")
                    ThemeStyleSwatch(color: previewColors.stockUS, label: "美股")
                    ThemeStyleSwatch(color: previewColors.crypto, label: "加密")
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .appPrimary : .tertiaryText)
            }
            .padding(12)
            .background(Color.secondaryBackground.opacity(isSelected ? 0.85 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.appPrimary.opacity(0.55) : Color.separator.opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeStyleOptionCard: View {
    let style: ThemeStyleID
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void

    private var preview: (stockTW: Color, stockUS: Color, crypto: Color) {
        style.previewAssetColors(isDarkMode: isDarkMode)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primaryText)
                    Text(style.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    ThemeStyleSwatch(color: preview.stockTW, label: "台股")
                    ThemeStyleSwatch(color: preview.stockUS, label: "美股")
                    ThemeStyleSwatch(color: preview.crypto, label: "加密")
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .appPrimary : .tertiaryText)
            }
            .padding(12)
            .background(Color.secondaryBackground.opacity(isSelected ? 0.85 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.appPrimary.opacity(0.55) : Color.separator.opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeStyleSwatch: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(Color.primaryText.opacity(0.12), lineWidth: 1)
                }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondaryText)
        }
    }
}

// MARK: - 自訂配色列

private struct ThemeCustomModeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? AppColors.actionForeground : .primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appPrimary : Color.secondaryBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeCustomColorGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }
}

private struct ThemeCustomColorPickerRow: View {
    let label: String
    @Binding var color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.separator.opacity(0.5), lineWidth: 1)
                }

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primaryText)

            Spacer(minLength: 8)

            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsRoundedPlusMark: View {
    var color: Color
    var armLength: CGFloat
    var armThickness: CGFloat

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: armLength, height: armThickness)
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: armThickness, height: armLength)
        }
        .shadow(color: color.opacity(0.18), radius: 1, x: 0, y: 0.5)
    }
}
