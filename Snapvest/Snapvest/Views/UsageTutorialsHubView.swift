//
//  UsageTutorialsHubView.swift
//  Snapvest
//
//  更多 → 使用教學：教學列表與示範模式
//

import SwiftUI

@MainActor
struct UsageTutorialsHubView: View {
    var onDismissSettings: () -> Void

    @ObservedObject private var demoMode = DemoModeManager.shared
    @State private var showingAddInvestmentTutorial = false
    @State private var showingImportTutorial = false
    @State private var showingBackupRestoreTutorial = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubSection {
                    demoModeRow

                    Divider()
                        .padding(.leading, 56)

                    walleafIntroRow

                    Divider()
                        .padding(.leading, 56)

                    tutorialRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "如何新增持倉",
                        subtitle: "從建立帳戶到新增第一筆持倉"
                    ) {
                        showingAddInvestmentTutorial = true
                    }

                    Divider()
                        .padding(.leading, 56)

                    tutorialRow(
                        icon: "square.and.arrow.down.on.square",
                        title: "如何批量匯入持倉",
                        subtitle: "用截圖與 AI 批量匯入成交或持倉"
                    ) {
                        showingImportTutorial = true
                    }

                    Divider()
                        .padding(.leading, 56)

                    tutorialRow(
                        icon: "externaldrive.fill.badge.icloud",
                        title: "如何備份與還原",
                        subtitle: "匯出備份檔、換機還原與注意事項"
                    ) {
                        showingBackupRestoreTutorial = true
                    }
                }
            }
            .padding(20)
        }
        .background(Color.mainBackground.ignoresSafeArea())
        .navigationTitle("使用教學")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddInvestmentTutorial) {
            AddInvestmentTutorialView {}
        }
        .sheet(isPresented: $showingImportTutorial) {
            TransactionImportTutorialView(accountType: .twdSecurities)
        }
        .sheet(isPresented: $showingBackupRestoreTutorial) {
            BackupRestoreTutorialView()
        }
    }

    private func hubSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

                    Text(demoMode.isEnabled ? "示範資料僅在記憶體中，不會寫入本機" : "用一組示範資料體驗完整功能（雲端股價）")
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

    private var walleafIntroRow: some View {
        Button {
            onDismissSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                OnboardingManager.shared.presentManually()
            }
        } label: {
            tutorialRowLabel(
                icon: "leaf.fill",
                title: "Walleaf 簡介",
                subtitle: "了解帳戶、紀錄與備份功能"
            )
        }
        .buttonStyle(.plain)
    }

    private func tutorialRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            tutorialRowLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func tutorialRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
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

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondaryText.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        UsageTutorialsHubView(onDismissSettings: {})
    }
}
