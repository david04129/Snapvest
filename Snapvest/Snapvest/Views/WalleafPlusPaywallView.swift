//
//  WalleafPlusPaywallView.swift
//  Snapvest
//
//  Walleaf Plus 訂閱頁
//

import StoreKit
import SwiftUI

@MainActor
struct WalleafPlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var theme = ThemeManager.shared

    @State private var selectedPlan: PaywallPlan = .yearly

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
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 22) {
                    heroSection

                    if subscriptionManager.isPlusActive {
                        subscribedBanner
                    }

                    comparisonSection

                    planPickerSection
                    purchaseSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }
            .background(paywallPageBackground.ignoresSafeArea())

            closeButton
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

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondaryText)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 14)
        .padding(.trailing, 20)
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

    private var heroSection: some View {
        VStack(spacing: 18) {
            logoWithPlusBadge
                .padding(.top, 4)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Walleaf")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.primaryText)
                    plusChip
                }

                Text(WalleafPlusPaywallL10n.heroSubtitle)
                    .font(.body.weight(.medium))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    private var logoWithPlusBadge: some View {
        ZStack(alignment: .topTrailing) {
            appIconView

            logoPlusBadge
                .offset(x: 6, y: -6)
        }
    }

    private var logoPlusBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#8BE06A"), Color.appPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.mainBackground, lineWidth: 2.5)
                .frame(width: 28, height: 28)

            PaywallRoundedPlusMark(color: .white, armLength: 10, armThickness: 2.2)
        }
        .shadow(color: Color.appPrimary.opacity(0.28), radius: 6, x: 0, y: 3)
    }

    private var appIconView: some View {
        Image(SnapvestBrand.logoImageName)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondaryBackground.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: AppColors.shadowMedium.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    private var plusChip: some View {
        Text("PLUS")
            .font(.system(size: 12, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#7ED957"), Color.appPrimary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.appPrimary.opacity(0.35), radius: 6, x: 0, y: 3)
    }

    private var subscribedBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#7ED957"), Color.appPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 6) {
                Text("Walleaf")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                plusChip
                Text(WalleafPlusPaywallL10n.plusActiveEnabled)
                    .font(.headline)
                    .foregroundColor(.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.appPrimary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appPrimary.opacity(0.28), lineWidth: 1)
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(WalleafPlusPaywallL10n.comparisonTitle)
                .font(.headline)
                .foregroundColor(.primaryText)

            VStack(spacing: 0) {
                comparisonHeaderRow

                ForEach(Array(comparisonRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 46)
                            .opacity(theme.isDarkMode ? 0.22 : 0.35)
                    }
                    comparisonDataRow(row)
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.secondaryBackground, lineWidth: 1)
            }
        }
    }

    private var comparisonHeaderRow: some View {
        HStack(spacing: 0) {
            Text(WalleafPlusPaywallL10n.comparisonFeature)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(WalleafPlusPaywallL10n.comparisonFree)
                .font(.caption.weight(.semibold))
                .foregroundColor(.tertiaryText)
                .frame(width: 68, alignment: .center)

            Text(WalleafPlusPaywallL10n.comparisonPlus)
                .font(.caption.weight(.bold))
                .foregroundColor(.appPrimary)
                .frame(width: 72, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.secondaryBackground.opacity(theme.isDarkMode ? 0.35 : 0.45))
    }

    private func comparisonDataRow(_ row: ComparisonRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: row.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appPrimary.opacity(0.9))
                    .frame(width: 20, alignment: .center)

                Text(row.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            comparisonFreeCell(row)
                .frame(width: 68, alignment: .center)

            comparisonPlusCell(row)
                .frame(width: 72, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func comparisonFreeCell(_ row: ComparisonRow) -> some View {
        if row.freeValue == WalleafPlusPaywallL10n.notIncluded {
            Text("—")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.tertiaryText.opacity(0.55))
        } else {
            Text(row.freeValue)
                .font(.caption.weight(.medium))
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
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appPrimary)
        } else {
            Text(row.plusValue)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Plans

    private var planPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WalleafPlusPaywallL10n.choosePlan)
                .font(.headline)
                .foregroundColor(.primaryText)

            if subscriptionManager.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(WalleafPlusPaywallL10n.loadingPlans)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(PaywallPlan.allCases) { plan in
                    planCard(for: plan)
                }
            }
        }
    }

    private func planCard(for plan: PaywallPlan) -> some View {
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appPrimary : Color.tertiaryText.opacity(0.5), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                    Text(planTitle(for: plan, product: product))
                        .font(.headline)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)

                    if isCurrentPlan {
                        Text(WalleafPlusPaywallL10n.currentPlanBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.14))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    } else if isScheduled {
                        Text(WalleafPlusPaywallL10n.scheduledPlanBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.85))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 4)

                    Text(product?.displayPrice ?? "—")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                let subtitle = planSubtitle(for: plan)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .padding(.leading, 34)
                }

                if isYearly {
                    yearlyPlanMetaLine
                }
            }
            .padding(16)
            .background(isSelected ? Color.appPrimary.opacity(0.08) : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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

    private var yearlyPlanMetaLine: some View {
        HStack(spacing: 6) {
            if yearlyHasIntroOffer && !subscriptionManager.isPlusActive {
                Label(WalleafPlusPaywallL10n.freeTrial7Days, systemImage: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appPrimary)
                    .lineLimit(1)
            }

            Text(WalleafPlusPaywallL10n.perMonth(yearlyEquivalentMonthlyPriceText))
                .font(.caption.weight(.medium))
                .foregroundColor(.secondaryText)
                .lineLimit(1)

            Text("·")
                .font(.caption)
                .foregroundColor(.tertiaryText)

            Text(monthlyAnnualTotalText)
                .font(.caption.weight(.medium))
                .foregroundColor(.tertiaryText)
                .strikethrough(true, color: .tertiaryText)
                .lineLimit(1)
        }
        .padding(.leading, 34)
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchaseSelectedPlan() }
            } label: {
                Group {
                    if subscriptionManager.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.appPrimary.opacity(0.28), radius: 10, x: 0, y: 5)
            .disabled(isPurchaseDisabled)

            if !subscriptionManager.isPlusActive {
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    Group {
                        if subscriptionManager.isRestoring {
                            ProgressView()
                        } else {
                            Text(WalleafPlusPaywallL10n.restorePurchases)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundColor(.appPrimary)
                .disabled(subscriptionManager.isRestoring || subscriptionManager.isPurchasing)
            }
        }
    }

    private var isPurchaseDisabled: Bool {
        selectedProduct == nil
            || subscriptionManager.isPurchasing
            || subscriptionManager.isLoadingProducts
            || isSelectedPlanCurrent
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
            if yearlyHasIntroOffer {
                return WalleafPlusPaywallL10n.startFreeTrial
            }
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
            selectedPlan = .monthly
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

    private func planSubtitle(for plan: PaywallPlan) -> String {
        if isScheduledPlan(plan) {
            if let renewalDate = subscriptionManager.plusRenewalDate {
                return WalleafPlusPaywallL10n.scheduledPlanSubtitle(on: renewalDate)
            }
            return WalleafPlusPaywallL10n.scheduledPlanSubtitle
        }

        if isActivePlan(plan) {
            return WalleafPlusPaywallL10n.currentPlanSubtitle
        }

        switch plan {
        case .yearly:
            if subscriptionManager.isPlusActive, isActivePlan(.monthly) {
                return WalleafPlusPaywallL10n.switchToYearlyHint
            }
            if yearlyHasIntroOffer {
                return WalleafPlusPaywallL10n.yearlySubtitleTrial
            }
            return ""
        case .monthly:
            if subscriptionManager.isPlusActive, isActivePlan(.yearly) {
                return WalleafPlusPaywallL10n.switchToMonthlyHint
            }
            return WalleafPlusPaywallL10n.monthlySubtitle
        }
    }

    private func purchaseSelectedPlan() async {
        guard let product = selectedProduct, !isSelectedPlanCurrent else { return }
        let wasPlus = subscriptionManager.isPlusActive
        let succeeded = await subscriptionManager.purchase(product)
        if succeeded, !wasPlus {
            dismiss()
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
