//
//  SubscriptionManager.swift
//  Snapvest
//
//  Walleaf Plus 訂閱狀態（StoreKit 2）
//

import Combine
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// 避免與 Models/Transaction.swift 的 Transaction 同名衝突
typealias StoreTransaction = StoreKit.Transaction
typealias StoreProduct = StoreKit.Product

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var monthlyProduct: StoreProduct?
    @Published private(set) var yearlyProduct: StoreProduct?
    @Published private(set) var isPlusActive = false
    /// 目前有效的 Plus 訂閱 Product ID（`walleaf.plus.monthly` 或 `walleaf.plus.yearly`）
    @Published private(set) var activePlusProductID: String?
    /// 已排程、下個續訂週期生效的方案（crossgrade / downgrade）
    @Published private(set) var pendingPlusProductID: String?
    /// 目前訂閱週期結束／下次續訂時間（排程切換時顯示用）
    @Published private(set) var plusRenewalDate: Date?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var statusMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = Task { [weak self] in
            for await update in StoreTransaction.updates {
                guard let self else { continue }
                await self.handleTransactionUpdate(update)
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await StoreProduct.products(for: PlusProductID.all)
            monthlyProduct = products.first { $0.id == PlusProductID.monthly }
            yearlyProduct = products.first { $0.id == PlusProductID.yearly }

            if monthlyProduct == nil && yearlyProduct == nil {
                statusMessage = "無法載入訂閱方案。請確認 Xcode Scheme 已選 WalleafPlus.storekit。"
            }
        } catch {
            statusMessage = "載入訂閱方案失敗：\(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        let snapshot = await loadSubscriptionSnapshot()
        activePlusProductID = snapshot.currentProductID
        pendingPlusProductID = snapshot.pendingProductID
        plusRenewalDate = snapshot.renewalDate
        isPlusActive = snapshot.currentProductID != nil
    }

    private struct SubscriptionSnapshot {
        let currentProductID: String?
        let pendingProductID: String?
        let renewalDate: Date?
    }

    private func loadSubscriptionSnapshot() async -> SubscriptionSnapshot {
        var currentProductID: String?
        var pendingProductID: String?
        var renewalDate: Date?

        if let groupID = subscriptionGroupID {
            do {
                let statuses = try await Product.SubscriptionInfo.status(for: groupID)
                for status in statuses {
                    guard case .verified(let transaction) = status.transaction else { continue }
                    guard case .verified(let renewalInfo) = status.renewalInfo else { continue }

                    switch status.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                        let activeID: String
                        if PlusProductID.all.contains(renewalInfo.currentProductID) {
                            activeID = renewalInfo.currentProductID
                        } else if PlusProductID.all.contains(transaction.productID) {
                            activeID = transaction.productID
                        } else {
                            continue
                        }

                        currentProductID = activeID
                        renewalDate = renewalInfo.renewalDate ?? transaction.expirationDate

                        if renewalInfo.willAutoRenew,
                           let pendingID = renewalInfo.autoRenewPreference,
                           PlusProductID.all.contains(pendingID),
                           pendingID != activeID {
                            pendingProductID = pendingID
                        }
                    default:
                        continue
                    }
                }
            } catch {
                // 群組狀態讀取失敗時改走下方 fallback
            }
        }

        if pendingProductID == nil {
            pendingProductID = await pendingProductFromEntitlements(currentProductID: currentProductID)
        }

        if currentProductID == nil {
            currentProductID = await firstActiveEntitlementProductID()
        }

        return SubscriptionSnapshot(
            currentProductID: currentProductID,
            pendingProductID: pendingProductID,
            renewalDate: renewalDate
        )
    }

    private var subscriptionGroupID: String? {
        monthlyProduct?.subscription?.subscriptionGroupID
            ?? yearlyProduct?.subscription?.subscriptionGroupID
            ?? PlusProductID.subscriptionGroupID
    }

    /// crossgrade 排程時，有時 entitlements 會短暫同時出現月／年 product ID。
    private func pendingProductFromEntitlements(currentProductID: String?) async -> String? {
        var activeProductIDs: [String] = []

        for await result in StoreTransaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard PlusProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            let isValid = transaction.expirationDate.map { $0 > Date() } ?? true
            guard isValid else { continue }
            activeProductIDs.append(transaction.productID)
        }

        guard let currentProductID else { return nil }

        if currentProductID == PlusProductID.monthly,
           activeProductIDs.contains(PlusProductID.yearly) {
            return PlusProductID.yearly
        }
        if currentProductID == PlusProductID.yearly,
           activeProductIDs.contains(PlusProductID.monthly) {
            return PlusProductID.monthly
        }
        return nil
    }

    private func firstActiveEntitlementProductID() async -> String? {
        for await result in StoreTransaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard PlusProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            let isValid: Bool
            if let expirationDate = transaction.expirationDate {
                isValid = expirationDate > Date()
            } else {
                isValid = true
            }

            guard isValid else { continue }
            return transaction.productID
        }
        return nil
    }

    private func planChangeSucceeded(requestedProductID: String) -> Bool {
        activePlusProductID == requestedProductID || pendingPlusProductID == requestedProductID
    }

    func purchase(_ product: StoreProduct) async -> Bool {
        let hadPlusBeforePurchase = isPlusActive
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let storeTransaction = try verified(verification)
                await storeTransaction.finish()
                try? await AppStore.sync()
                await refreshEntitlements()

                if hadPlusBeforePurchase {
                    if planChangeSucceeded(requestedProductID: product.id) {
                        statusMessage = product.id == PlusProductID.yearly
                            ? WalleafPlusPaywallL10n.switchedToYearly
                            : WalleafPlusPaywallL10n.switchedToMonthly
                    } else {
                        try? await Task.sleep(for: .milliseconds(400))
                        try? await AppStore.sync()
                        await refreshEntitlements()
                        if planChangeSucceeded(requestedProductID: product.id) {
                            statusMessage = product.id == PlusProductID.yearly
                                ? WalleafPlusPaywallL10n.switchedToYearly
                                : WalleafPlusPaywallL10n.switchedToMonthly
                        } else {
                            statusMessage = WalleafPlusPaywallL10n.switchPlanNotApplied
                        }
                    }
                } else if isPlusActive {
                    statusMessage = WalleafPlusPaywallL10n.subscribedSuccess
                }
                return isPlusActive
            case .userCancelled:
                return false
            case .pending:
                statusMessage = "購買待處理，請稍後再確認訂閱狀態。"
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = "購買失敗：\(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        isRestoring = true
        statusMessage = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPlusActive
                ? "已恢復 Walleaf Plus 訂閱。"
                : "找不到可恢復的有效訂閱。"
        } catch {
            statusMessage = "恢復購買失敗：\(error.localizedDescription)"
        }
    }

    func showManageSubscriptions() async {
        guard let scene = activeWindowScene else {
            statusMessage = "無法開啟訂閱管理。"
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await refreshEntitlements()
        } catch {
            statusMessage = "無法開啟訂閱管理：\(error.localizedDescription)"
        }
    }

    private func handleTransactionUpdate(_ update: VerificationResult<StoreTransaction>) async {
        guard case .verified(let storeTransaction) = update else { return }
        await storeTransaction.finish()
        await refreshEntitlements()
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw SubscriptionStoreError.failedVerification
        }
    }

    private var activeWindowScene: UIWindowScene? {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        #else
        nil
        #endif
    }
}

private enum SubscriptionStoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "無法驗證購買交易。"
        }
    }
}
