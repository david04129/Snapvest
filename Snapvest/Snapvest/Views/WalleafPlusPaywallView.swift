//
//  WalleafPlusPaywallView.swift
//  Snapvest
//
//  Walleaf Plus 訂閱頁
//

import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct WalleafPlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var theme = ThemeManager.shared

    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var isClosingAfterInitialPurchase = false

    private enum PaywallPlan: String, CaseIterable, Identifiable {
        case yearly
        case monthly

        var id: String { rawValue }
    }

    private struct ComparisonRow: Identifiable {
        let id: String
        let title: String
        let freeValue: String
        let plusValue: String
        let isUnlimitedHighlight: Bool
        let systemImage: String
    }

    private var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(
                id: "accounts",
                title: WalleafPlusPaywallL10n.rowAccounts,
                freeValue: WalleafPlusPaywallL10n.freeAccounts,
                plusValue: WalleafPlusPaywallL10n.plusUnlimited,
                isUnlimitedHighlight: true,
                systemImage: "building.columns.fill"
            ),
            ComparisonRow(
                id: "holdings",
                title: WalleafPlusPaywallL10n.rowHoldings,
                freeValue: WalleafPlusPaywallL10n.freeHoldings,
                plusValue: WalleafPlusPaywallL10n.plusUnlimited,
                isUnlimitedHighlight: true,
                systemImage: "chart.bar.fill"
            ),
            ComparisonRow(
                id: "markets",
                title: WalleafPlusPaywallL10n.rowMarkets,
                freeValue: WalleafPlusPaywallL10n.freeMarkets,
                plusValue: WalleafPlusPaywallL10n.plusMarkets,
                isUnlimitedHighlight: true,
                systemImage: "globe.asia.australia.fill"
            ),
            ComparisonRow(
                id: "backup",
                title: WalleafPlusPaywallL10n.rowBackup,
                freeValue: WalleafPlusPaywallL10n.notIncluded,
                plusValue: WalleafPlusPaywallL10n.included,
                isUnlimitedHighlight: false,
                systemImage: "externaldrive.fill.badge.icloud"
            ),
            ComparisonRow(
                id: "import",
                title: WalleafPlusPaywallL10n.rowImport,
                freeValue: WalleafPlusPaywallL10n.notIncluded,
                plusValue: WalleafPlusPaywallL10n.included,
                isUnlimitedHighlight: false,
                systemImage: "square.and.arrow.down.on.square.fill"
            ),
            ComparisonRow(
                id: "faceid",
                title: WalleafPlusPaywallL10n.rowFaceID,
                freeValue: WalleafPlusPaywallL10n.notIncluded,
                plusValue: WalleafPlusPaywallL10n.included,
                isUnlimitedHighlight: false,
                systemImage: "faceid"
            ),
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 800
            let rawDetailsContentWidth = proxy.size.width - 40
            let detailsContentWidth = rawDetailsContentWidth.isFinite && rawDetailsContentWidth > 1
                ? rawDetailsContentWidth
                : 1
            let showsSubscribedContent = subscriptionManager.isPlusActive && !isClosingAfterInitialPurchase

            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        firstScreenContent(compact: isCompact, showsSubscribedContent: showsSubscribedContent)
                            .frame(minHeight: proxy.size.height, alignment: .top)

                        subscriptionDetailsSection(contentWidth: detailsContentWidth)
                            .padding(.horizontal, 20)
                            .padding(.top, showsSubscribedContent ? 16 : -84)
                            .padding(.bottom, showsSubscribedContent ? 44 : 120)
                    }
                    .frame(width: proxy.size.width)
                }
                .scrollIndicators(.hidden)
                .background(paywallPageBackground.ignoresSafeArea())

                if !subscriptionManager.isPlusActive && !isClosingAfterInitialPurchase {
                    fixedContinueButton(compact: isCompact)
                }

                closeButton(compact: isCompact)
            }
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.refreshEntitlements()
            syncSelectedPlan(with: subscriptionManager.activePlusProductID, pendingID: subscriptionManager.pendingPlusProductID)
        }
        .onChange(of: subscriptionManager.activePlusProductID) { _, productID in
            syncSelectedPlan(with: productID)
        }
        .onChange(of: subscriptionManager.pendingPlusProductID) { _, pendingID in
            syncSelectedPlan(with: subscriptionManager.activePlusProductID, pendingID: pendingID)
        }
        .alert(
            WalleafPlusPaywallL10n.subscriptionAlertTitle,
            isPresented: Binding(
                get: { subscriptionManager.statusMessage != nil },
                set: { if !$0 { subscriptionManager.statusMessage = nil } }
            )
        ) {
            Button(WalleafPlusPaywallL10n.alertOK, role: .cancel) {}
        } message: {
            Text(subscriptionManager.statusMessage ?? "")
        }
    }

    private func firstScreenContent(compact: Bool, showsSubscribedContent: Bool) -> some View {
        VStack(spacing: 0) {
            heroSection(compact: compact)

            Spacer(minLength: compact ? 5 : 8)

            if showsSubscribedContent {
                subscribedBanner(compact: compact)
                Spacer(minLength: compact ? 8 : 14)
            }

            comparisonSection(compact: compact)

            Spacer(minLength: compact ? 6 : 10)

            if showsSubscribedContent {
                subscribedManagementSection(compact: compact)
                Spacer(minLength: compact ? 6 : 10)
                subscribedContactSection(compact: compact)
            } else {
                planPickerSection(compact: compact)
            }

            Spacer(minLength: compact ? 4 : 8)

            Color.clear
                .frame(height: showsSubscribedContent ? (compact ? 8 : 12) : (compact ? 104 : 116))
        }
        .padding(.horizontal, compact ? 16 : 20)
        .padding(.top, compact ? 28 : 34)
    }

    private func closeButton(compact: Bool) -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundColor(.secondaryText)
                .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, compact ? 10 : 14)
        .padding(.trailing, compact ? 14 : 20)
        .accessibilityLabel(
            subscriptionManager.isPlusActive
                ? WalleafPlusPaywallL10n.done
                : WalleafPlusPaywallL10n.close
        )
    }

    // MARK: - Background

    private var paywallPageBackground: some View {
        ZStack {
            Color.mainBackground
            LinearGradient(
                colors: [
                    Color.appPrimary.opacity(theme.isDarkMode ? 0.10 : 0.07),
                    Color.clear,
                    Color(hex: "#F2C078").opacity(theme.isDarkMode ? 0.06 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Hero

    private func heroSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            logoWithPlusBadge(compact: compact)
                .padding(.top, compact ? 0 : 2)

            VStack(spacing: compact ? 4 : 6) {
                HStack(spacing: 9) {
                    Text("Walleaf")
                        .font(.system(size: compact ? 29 : 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.primaryText)
                    plusChip(compact: compact)
                }

                Text(WalleafPlusPaywallL10n.heroSubtitle)
                    .font((compact ? Font.callout : Font.callout).weight(.medium))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(compact ? 1 : 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, compact ? 6 : 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func logoWithPlusBadge(compact: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            appIconView(compact: compact)

            logoPlusBadge(compact: compact)
                .offset(x: compact ? 4 : 6, y: compact ? -4 : -6)
        }
    }

    private func logoPlusBadge(compact: Bool) -> some View {
        let badgeSize: CGFloat = compact ? 25 : 29
        let cornerRadius: CGFloat = compact ? 8 : 9

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#8BE06A"), Color.appPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: badgeSize, height: badgeSize)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.mainBackground, lineWidth: compact ? 2 : 2.5)
                .frame(width: badgeSize, height: badgeSize)

            PaywallRoundedPlusMark(
                color: .white,
                armLength: compact ? 9 : 10,
                armThickness: compact ? 2 : 2.2
            )
        }
        .shadow(color: Color.appPrimary.opacity(0.28), radius: compact ? 4 : 6, x: 0, y: 3)
    }

    private func appIconView(compact: Bool) -> some View {
        let size: CGFloat = compact ? 58 : 68
        let cornerRadius: CGFloat = compact ? 16 : 18

        return Image(SnapvestBrand.logoImageName)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.secondaryBackground.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: AppColors.shadowMedium.opacity(0.25), radius: compact ? 5 : 8, x: 0, y: 4)
    }

    private func plusChip(compact: Bool = false) -> some View {
        Text("PLUS")
            .font(.system(size: compact ? 11 : 12, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 9 : 10)
            .padding(.vertical, compact ? 5 : 6)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#7ED957"), Color.appPrimary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.appPrimary.opacity(0.35), radius: compact ? 4 : 6, x: 0, y: 3)
    }

    private func subscribedBanner(compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 20 : 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#7ED957"), Color.appPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 6) {
                Text("Walleaf")
                    .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
                    .foregroundColor(.primaryText)
                plusChip(compact: compact)
                Text(WalleafPlusPaywallL10n.plusActiveEnabled)
                    .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
                    .foregroundColor(.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 13)
        .background(Color.appPrimary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .stroke(Color.appPrimary.opacity(0.28), lineWidth: 1)
        }
    }

    private func subscribedManagementSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Text(WalleafPlusPaywallL10n.currentPlanTitle)
                .font((compact ? Font.headline : Font.headline).weight(.bold))
                .foregroundColor(.primaryText)

            VStack(alignment: .leading, spacing: compact ? 12 : 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: currentPlanIconName)
                        .font(.system(size: compact ? 20 : 23, weight: .semibold))
                        .foregroundColor(.appPrimary)
                        .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                        .background(Color.appPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous))

                    VStack(alignment: .leading, spacing: compact ? 7 : 9) {
                        HStack(spacing: 8) {
                            Text(currentPlanDisplayName)
                                .font((compact ? Font.title3 : Font.title2).weight(.bold))
                                .foregroundColor(.primaryText)

                            if let pendingPlanDisplayName {
                                planStatusBadge(WalleafPlusPaywallL10n.scheduledPlanBadge, filled: true, compact: compact)
                                Text(pendingPlanDisplayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                        if let renewalText {
                            Text(renewalText)
                                .font((compact ? Font.subheadline : Font.callout).weight(.medium))
                                .foregroundColor(.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Text(subscribedPlanExplanation)
                    .font((compact ? Font.subheadline : Font.callout).weight(.medium))
                    .foregroundColor(.secondaryText)
                    .lineSpacing(compact ? 3 : 4)
                    .fixedSize(horizontal: false, vertical: true)

                if canUpgradeMonthlyToYearly {
                    yearlyUpgradeInlineCard(compact: compact)
                }
            }
            .padding(compact ? 14 : 16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                    .stroke(Color.secondaryBackground, lineWidth: 1)
            }
            .frame(minHeight: subscribedManagementMinHeight(compact: compact), alignment: .top)
        }
    }

    private func subscribedContactSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Text(WalleafPlusPaywallL10n.contactSectionTitle)
                .font((compact ? Font.headline : Font.headline).weight(.bold))
                .foregroundColor(.primaryText)

            VStack(spacing: 0) {
                contactActionRow(
                    icon: "star.fill",
                    title: WalleafPlusPaywallL10n.supportWithReviewTitle,
                    subtitle: WalleafPlusPaywallL10n.supportWithReviewSubtitle,
                    compact: compact
                ) {
                    AppExternalActions.requestAppReview()
                }

                Divider()
                    .padding(.leading, compact ? 48 : 54)
                    .opacity(theme.isDarkMode ? 0.22 : 0.35)

                contactActionRow(
                    icon: "envelope.fill",
                    title: WalleafPlusPaywallL10n.contactUsTitle,
                    subtitle: WalleafPlusPaywallL10n.contactUsSubtitle,
                    compact: compact
                ) {
                    openSupportEmail()
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                    .stroke(Color.secondaryBackground, lineWidth: 1)
            }
        }
    }

    private func contactActionRow(
        icon: String,
        title: String,
        subtitle: String,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: compact ? 10 : 12) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
                    .background(Color.appPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font((compact ? Font.subheadline : Font.subheadline).weight(.semibold))
                        .foregroundColor(.primaryText)

                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 10 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subscribedManagementMinHeight(compact: Bool) -> CGFloat {
        if canUpgradeMonthlyToYearly {
            return compact ? 160 : 180
        }
        return compact ? 128 : 148
    }

    private func yearlyUpgradeInlineCard(compact: Bool) -> some View {
        Button {
            selectedPlan = .yearly
            Task { await purchaseSelectedPlan() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(WalleafPlusPaywallL10n.switchToYearly)
                        .font((compact ? Font.subheadline : Font.headline).weight(.bold))
                        .foregroundColor(.primaryText)

                    Text(WalleafPlusPaywallL10n.applePlanChangeNotice)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(subscriptionManager.yearlyProduct?.displayPrice ?? "—")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.appPrimary)
                    .lineLimit(1)
            }
            .padding(compact ? 12 : 14)
            .background(Color.appPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                    .stroke(Color.appPrimary.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.yearlyProduct == nil || subscriptionManager.isPurchasing)
    }

    // MARK: - Comparison

    private func comparisonSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Text(WalleafPlusPaywallL10n.comparisonTitle)
                .font((compact ? Font.headline : Font.headline).weight(.bold))
                .foregroundColor(.primaryText)

            VStack(spacing: 0) {
                comparisonHeaderRow(compact: compact)

                ForEach(Array(comparisonRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                            .padding(.leading, compact ? 38 : 46)
                            .opacity(theme.isDarkMode ? 0.22 : 0.35)
                    }
                    comparisonDataRow(row, compact: compact)
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous))
            .overlay {
                comparisonTableOverlay(compact: compact)
            }
        }
    }

    private func comparisonHeaderRow(compact: Bool) -> some View {
        HStack(spacing: 0) {
            Text(WalleafPlusPaywallL10n.comparisonFeature)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(WalleafPlusPaywallL10n.comparisonFree)
                .font(.caption.weight(.semibold))
                .foregroundColor(.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(WalleafPlusPaywallL10n.comparisonPlus)
                .font(.caption.weight(.bold))
                .foregroundColor(.appPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, comparisonRowVerticalPadding(compact: compact))
        .background(Color.secondaryBackground.opacity(theme.isDarkMode ? 0.35 : 0.45))
    }

    private func comparisonDataRow(_ row: ComparisonRow, compact: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: compact ? 7 : 9) {
                Image(systemName: row.systemImage)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundColor(.appPrimary.opacity(0.9))
                    .frame(width: compact ? 17 : 20, alignment: .center)

                Text(row.title)
                    .font((compact ? Font.subheadline : Font.subheadline).weight(.semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            comparisonFreeCell(row)
                .frame(maxWidth: .infinity, alignment: .center)

            comparisonPlusCell(row)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, comparisonRowVerticalPadding(compact: compact))
    }

    private func comparisonRowVerticalPadding(compact: Bool) -> CGFloat {
        if subscriptionManager.isPlusActive {
            return compact ? 10 : 12
        }
        return compact ? 7 : 9
    }

    private func comparisonTableOverlay(compact: Bool) -> some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = compact ? 10 : 14
            let contentWidth = max(geometry.size.width - horizontalPadding * 2, 1)
            let columnWidth = contentWidth / 3
            let highlightWidth = columnWidth + (compact ? 8 : 10)
            let highlightHeight = max(geometry.size.height - (compact ? 8 : 10), 1)
            let highlightCenterX = horizontalPadding + columnWidth * 2.5

            ZStack {
                RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                    .stroke(Color.secondaryBackground, lineWidth: 1)

                if subscriptionManager.isPlusActive {
                    RoundedRectangle(cornerRadius: compact ? 13 : 15, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.72), lineWidth: 2)
                        .frame(width: highlightWidth, height: highlightHeight)
                        .position(x: highlightCenterX, y: geometry.size.height / 2)
                }
            }
        }
    }

    @ViewBuilder
    private func comparisonFreeCell(_ row: ComparisonRow) -> some View {
        if row.freeValue == WalleafPlusPaywallL10n.notIncluded {
            Text("—")
                .font(.caption.weight(.semibold))
                .foregroundColor(.tertiaryText.opacity(0.55))
        } else {
            Text(row.freeValue)
                .font(.caption.weight(.semibold))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func comparisonPlusCell(_ row: ComparisonRow) -> some View {
        if row.plusValue == WalleafPlusPaywallL10n.included {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.appPrimary)
        } else {
            Text(row.plusValue)
                .font(.caption.weight(.black))
                .foregroundColor(.appPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Plans

    private func planPickerSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Text(WalleafPlusPaywallL10n.choosePlan)
                .font((compact ? Font.headline : Font.headline).weight(.bold))
                .foregroundColor(.primaryText)

            if subscriptionManager.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(WalleafPlusPaywallL10n.loadingPlans)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, compact ? 4 : 8)
            } else {
                ForEach(PaywallPlan.allCases) { plan in
                    planCard(for: plan, compact: compact)
                }
            }
        }
    }

    private func planCard(for plan: PaywallPlan, compact: Bool) -> some View {
        let product = product(for: plan)
        let isSelected = selectedPlan == plan
        let isYearly = plan == .yearly
        let isCurrentPlan = isActivePlan(plan)
        let isScheduled = isScheduledPlan(plan)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedPlan = plan
            }
        } label: {
            HStack(alignment: .center, spacing: compact ? 10 : 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appPrimary : Color.tertiaryText.opacity(0.5), lineWidth: 2)
                        .frame(width: compact ? 22 : 24, height: compact ? 22 : 24)
                    if isSelected {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: compact ? 12 : 13, height: compact ? 12 : 13)
                    }
                }

                VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                    HStack(spacing: 6) {
                        Text(planTitle(for: plan, product: product))
                            .font((compact ? Font.headline : Font.headline).weight(.bold))
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if isCurrentPlan {
                            planStatusBadge(WalleafPlusPaywallL10n.currentPlanBadge, filled: false, compact: compact)
                        } else if isScheduled {
                            planStatusBadge(WalleafPlusPaywallL10n.scheduledPlanBadge, filled: true, compact: compact)
                        }
                    }

                    // Hide annual free-trial copy until the App Store Connect offer is approved.
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(product?.displayPrice ?? "—")
                    .font((compact ? Font.title3 : Font.title3).weight(.bold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, compact ? 13 : 15)
            .padding(.vertical, compact ? 12 : 14)
            .frame(minHeight: compact ? 78 : 84)
            .background(isSelected ? Color.appPrimary.opacity(0.08) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                    .stroke(
                        isCurrentPlan || isScheduled
                            ? Color.appPrimary.opacity(0.45)
                            : (isSelected ? Color.appPrimary : Color.secondaryBackground),
                        lineWidth: isSelected || isCurrentPlan || isScheduled ? 2 : 1
                    )
            }
            .shadow(color: isYearly && isSelected ? Color.appPrimary.opacity(0.14) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(product == nil && !subscriptionManager.isLoadingProducts)
    }

    private func planStatusBadge(_ title: String, filled: Bool, compact: Bool) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundColor(filled ? .white : .appPrimary)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(filled ? Color.appPrimary.opacity(0.85) : Color.appPrimary.opacity(0.14))
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func fixedContinueButton(compact: Bool) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                Button {
                    Task { await handlePrimaryButtonTap() }
                } label: {
                    ZStack {
                        if subscriptionManager.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(primaryButtonTitle)
                                .font(.headline.weight(.bold))
                        }
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: compact ? 54 : 58)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .shadow(color: Color.appPrimary.opacity(0.28), radius: 14, x: 0, y: 7)
                .disabled(isPrimaryButtonDisabled)
                .padding(.horizontal, compact ? 20 : 24)
                .padding(.top, 14)
                .padding(.bottom, compact ? 18 : 24)
            }
            .background(paywallBottomBarBackground)
        }
        .ignoresSafeArea(.keyboard)
    }

    private var paywallBottomBarBackground: some View {
        ZStack(alignment: .top) {
            Color.mainBackground
                .opacity(0.98)
                .ignoresSafeArea(edges: .bottom)

            LinearGradient(
                colors: [
                    Color.mainBackground.opacity(0),
                    Color.mainBackground.opacity(0.96),
                    Color.mainBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 34)
            .offset(y: -34)
        }
    }

    private func subscriptionDetailsSection(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("訂閱說明")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primaryText)
                    .frame(width: contentWidth, alignment: .leading)

                subscriptionExplanationText(width: contentWidth)
            }
            .frame(width: contentWidth, alignment: .leading)

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                HStack(spacing: 8) {
                    if subscriptionManager.isRestoring {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(WalleafPlusPaywallL10n.restorePurchases)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundColor(.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .background(Color.appPrimary.opacity(0.10))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.appPrimary.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isRestoring || subscriptionManager.isPurchasing)

            if subscriptionManager.isPlusActive {
                Button {
                    Task { await subscriptionManager.showManageSubscriptions() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(WalleafPlusPaywallL10n.manageSubscription)
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 38)
                    .background(Color.appPrimary.opacity(0.07))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.appPrimary.opacity(0.18), lineWidth: 1)
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(subscriptionManager.isPurchasing)
                .padding(.top, -8)
            }

            HStack(spacing: 8) {
                detailsLinkButton("服務條款") {
                    openURL(AppExternalLinks.termsURL)
                }
                separatorDot
                detailsLinkButton("隱私政策") {
                    openURL(AppExternalLinks.privacyPolicyURL)
                }
                separatorDot
                detailsLinkButton("聯絡我們") {
                    openSupportEmail()
                }
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: contentWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func detailsLinkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundColor(.secondaryText)
            .underline()
    }

    private var separatorDot: some View {
        Text("·")
            .foregroundColor(.tertiaryText)
    }

    private func openSupportEmail() {
        if let url = AppExternalLinks.supportEmailURL() {
            openURL(url)
        }
    }

    private func subscriptionExplanationText(width: CGFloat) -> some View {
        Text("""
        完成確認後，Apple 會透過您的 App Store 帳戶處理付款。
        訂閱會依所選週期自動續訂，續訂費用通常會在到期前 24 小時內扣款。
        您可以隨時到 App Store 的訂閱管理取消；取消後，既有資料仍會保留。
        若遇到訂閱或恢復購買問題，請透過 App 內支援聯繫我們。
        """)
            .font(.footnote.weight(.medium))
            .foregroundColor(.secondaryText)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(width: width, alignment: .leading)
    }

    private var isPurchaseDisabled: Bool {
        selectedProduct == nil
            || subscriptionManager.isPurchasing
            || subscriptionManager.isLoadingProducts
            || isSelectedPlanCurrent
    }

    private var isPrimaryButtonDisabled: Bool {
        if subscriptionManager.isPlusActive {
            if canUpgradeMonthlyToYearly {
                return subscriptionManager.yearlyProduct == nil
                    || subscriptionManager.isPurchasing
                    || subscriptionManager.isLoadingProducts
            }
            return subscriptionManager.isPurchasing
        }
        return isPurchaseDisabled
    }

    // MARK: - Pricing helpers

    private var monthlyAnnualTotalText: String {
        if let monthly = subscriptionManager.monthlyProduct {
            return formattedAnnualTotal(from: monthly)
        }
        return formatTWD(720)
    }

    private var yearlyEquivalentMonthlyPriceText: String {
        if let yearly = subscriptionManager.yearlyProduct,
           let perMonth = monthlyEquivalent(from: yearly) {
            return perMonth
        }
        return formatTWD(33)
    }

    private func formattedAnnualTotal(from monthly: StoreProduct) -> String {
        guard let amount = decimalPrice(from: monthly) else {
            return WalleafPlusPaywallL10n.monthlyTimesTwelve
        }
        return formatTWD(amount * 12)
    }

    private func monthlyEquivalent(from yearly: StoreProduct) -> String? {
        guard let amount = decimalPrice(from: yearly) else { return nil }
        let perMonth = (amount as NSDecimalNumber).doubleValue / 12.0
        let roundedUp = Decimal(ceil(perMonth))
        return formatTWD(roundedUp)
    }

    private func decimalPrice(from product: StoreProduct) -> Decimal? {
        product.price as Decimal
    }

    private func formatTWD(_ amount: Decimal) -> String {
        let number = amount as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = WalleafPlusPaywallL10n.priceLocale
        formatter.currencyCode = "TWD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "NT$\(number.intValue)"
    }

    // MARK: - Purchase

    private var selectedProduct: StoreProduct? {
        product(for: selectedPlan)
    }

    private var primaryButtonTitle: String {
        if subscriptionManager.isPlusActive {
            if canUpgradeMonthlyToYearly {
                return WalleafPlusPaywallL10n.switchToYearly
            }
            return WalleafPlusPaywallL10n.manageSubscription
        }
        return WalleafPlusPaywallL10n.continueButton
    }

    private var purchaseButtonTitle: String {
        guard selectedProduct != nil else { return WalleafPlusPaywallL10n.cannotLoadPlans }

        if isSelectedPlanCurrent {
            if isScheduledPlan(selectedPlan) {
                return WalleafPlusPaywallL10n.scheduledPlanButton
            }
            return WalleafPlusPaywallL10n.currentPlanButton
        }

        if subscriptionManager.isPlusActive {
            switch selectedPlan {
            case .yearly: return WalleafPlusPaywallL10n.switchToYearly
            case .monthly: return WalleafPlusPaywallL10n.switchToMonthly
            }
        }

        switch selectedPlan {
        case .yearly:
            // Hide annual free-trial CTA until the App Store Connect offer is approved.
            return WalleafPlusPaywallL10n.subscribeYearly
        case .monthly:
            return WalleafPlusPaywallL10n.subscribeMonthly
        }
    }

    private var isSelectedPlanCurrent: Bool {
        guard subscriptionManager.isPlusActive else { return false }
        return isActivePlan(selectedPlan) || isScheduledPlan(selectedPlan)
    }

    private func isActivePlan(_ plan: PaywallPlan) -> Bool {
        guard let activeID = subscriptionManager.activePlusProductID else { return false }
        switch plan {
        case .monthly: return activeID == PlusProductID.monthly
        case .yearly: return activeID == PlusProductID.yearly
        }
    }

    private func isScheduledPlan(_ plan: PaywallPlan) -> Bool {
        guard let pendingID = subscriptionManager.pendingPlusProductID else { return false }
        switch plan {
        case .monthly: return pendingID == PlusProductID.monthly
        case .yearly: return pendingID == PlusProductID.yearly
        }
    }

    private var canUpgradeMonthlyToYearly: Bool {
        subscriptionManager.isPlusActive
            && subscriptionManager.activePlusProductID == PlusProductID.monthly
            && subscriptionManager.pendingPlusProductID != PlusProductID.yearly
    }

    private var currentPlanDisplayName: String {
        switch subscriptionManager.activePlusProductID {
        case PlusProductID.monthly:
            return WalleafPlusPaywallL10n.planMonthly
        case PlusProductID.yearly:
            return WalleafPlusPaywallL10n.planYearly
        default:
            return WalleafPlusPaywallL10n.plusActiveEnabled
        }
    }

    private var pendingPlanDisplayName: String? {
        switch subscriptionManager.pendingPlusProductID {
        case PlusProductID.monthly:
            return WalleafPlusPaywallL10n.planMonthly
        case PlusProductID.yearly:
            return WalleafPlusPaywallL10n.planYearly
        default:
            return nil
        }
    }

    private var currentPlanIconName: String {
        subscriptionManager.activePlusProductID == PlusProductID.yearly
            ? "calendar.badge.checkmark"
            : "calendar"
    }

    private var renewalText: String? {
        guard let date = subscriptionManager.plusRenewalDate else { return nil }
        return WalleafPlusPaywallL10n.renewalDateText(date)
    }

    private var subscribedPlanExplanation: String {
        if canUpgradeMonthlyToYearly {
            return WalleafPlusPaywallL10n.monthlySubscribedExplanation
        }
        if subscriptionManager.activePlusProductID == PlusProductID.yearly {
            return WalleafPlusPaywallL10n.yearlySubscribedExplanation
        }
        return WalleafPlusPaywallL10n.genericSubscribedExplanation
    }

    private func syncSelectedPlan(with activeProductID: String?, pendingID: String? = nil) {
        guard subscriptionManager.isPlusActive else {
            selectedPlan = .yearly
            return
        }

        if let pendingID, PlusProductID.all.contains(pendingID) {
            switch pendingID {
            case PlusProductID.yearly:
                selectedPlan = .yearly
            case PlusProductID.monthly:
                selectedPlan = .monthly
            default:
                break
            }
            return
        }

        switch activeProductID {
        case PlusProductID.monthly:
            selectedPlan = .yearly
        case PlusProductID.yearly:
            selectedPlan = .yearly
        default:
            selectedPlan = .yearly
        }
    }

    private var yearlyHasIntroOffer: Bool {
        subscriptionManager.yearlyProduct?.subscription?.introductoryOffer != nil
    }

    private func product(for plan: PaywallPlan) -> StoreProduct? {
        switch plan {
        case .monthly: return subscriptionManager.monthlyProduct
        case .yearly: return subscriptionManager.yearlyProduct
        }
    }

    private func planTitle(for plan: PaywallPlan, product: StoreProduct?) -> String {
        if let displayName = product?.displayName, !displayName.isEmpty {
            return displayName
        }
        switch plan {
        case .yearly: return WalleafPlusPaywallL10n.planYearly
        case .monthly: return WalleafPlusPaywallL10n.planMonthly
        }
    }

    private func purchaseSelectedPlan() async {
        guard let product = selectedProduct, !isSelectedPlanCurrent else { return }
        let wasPlus = subscriptionManager.isPlusActive
        let shouldCloseOnSuccess = !wasPlus
        if shouldCloseOnSuccess {
            isClosingAfterInitialPurchase = true
        }
        let succeeded = await subscriptionManager.purchase(product)
        if succeeded, shouldCloseOnSuccess {
            subscriptionManager.statusMessage = nil
            dismiss()
        } else if shouldCloseOnSuccess {
            isClosingAfterInitialPurchase = false
        }
    }

    private func handlePrimaryButtonTap() async {
        guard subscriptionManager.isPlusActive else {
            await purchaseSelectedPlan()
            return
        }

        if canUpgradeMonthlyToYearly {
            selectedPlan = .yearly
            await purchaseSelectedPlan()
        } else {
            await subscriptionManager.showManageSubscriptions()
        }
    }
}

/// 圓角十字，比 SF Symbol `plus` 更柔和、與 App icon 風格一致。
private struct PaywallRoundedPlusMark: View {
    var color: Color
    var armLength: CGFloat
    var armThickness: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(color)
                .frame(width: armLength, height: armThickness)
            Capsule()
                .fill(color)
                .frame(width: armThickness, height: armLength)
        }
    }
}
