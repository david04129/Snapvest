//
//  PlusFeatureGate.swift
//  Snapvest
//
//  Walleaf Plus 功能鎖與 Free 上限攔截
//

import Foundation

enum PlusGateBlockReason: Equatable {
    case plusFeatureRequired
    case holdingLimitReached
    case complianceModeNoBuy
}

enum PlusGateDecision: Equatable {
    case allowed
    case blocked(PlusGateBlockReason)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

@MainActor
enum PlusFeatureGate {
    static func shouldBypassLimits(isPlusActive: Bool) -> Bool {
        isPlusActive || DemoModeManager.shared.isEnabled
    }

    static func canUseBackupRestore(isPlusActive: Bool) -> Bool {
        shouldBypassLimits(isPlusActive: isPlusActive)
    }

    static func canUseImport(isPlusActive: Bool) -> Bool {
        shouldBypassLimits(isPlusActive: isPlusActive)
    }

    static func canUsePrivacyLock(isPlusActive: Bool) -> Bool {
        shouldBypassLimits(isPlusActive: isPlusActive)
    }

    static func requiresFullLiquidationSell(
        snapshot: PortfolioLimitSnapshot,
        isPlusActive: Bool
    ) -> Bool {
        guard !shouldBypassLimits(isPlusActive: isPlusActive) else { return false }
        return snapshot.requiresFullLiquidationSell
    }

    static func canCreateAccount(
        accountType: AccountType,
        snapshot: PortfolioLimitSnapshot,
        isPlusActive: Bool
    ) -> PlusGateDecision {
        _ = accountType
        _ = snapshot
        guard !shouldBypassLimits(isPlusActive: isPlusActive) else { return .allowed }
        return .allowed
    }

    static func canBuy(
        assetType: AssetType,
        symbol: String,
        snapshot: PortfolioLimitSnapshot,
        isPlusActive: Bool
    ) -> PlusGateDecision {
        guard !shouldBypassLimits(isPlusActive: isPlusActive) else { return .allowed }

        if snapshot.isOverFreeHoldingLimits {
            return .blocked(.complianceModeNoBuy)
        }

        let holdingKey = SubscriptionComplianceState.holdingKey(assetType: assetType, symbol: symbol)
        let isExistingHolding = snapshot.holdingKeys.contains(holdingKey)

        if !isExistingHolding,
           snapshot.distinctHoldingCount >= PlusFreeLimits.maxDistinctHoldings {
            return .blocked(.holdingLimitReached)
        }

        return .allowed
    }

    static func canOpenBuyFlow(
        assetType: AssetType?,
        snapshot: PortfolioLimitSnapshot,
        isPlusActive: Bool
    ) -> PlusGateDecision {
        _ = assetType
        guard !shouldBypassLimits(isPlusActive: isPlusActive) else { return .allowed }

        if snapshot.isOverFreeHoldingLimits {
            return .blocked(.complianceModeNoBuy)
        }

        return .allowed
    }

    static func loadSnapshot(userId: String) async throws -> PortfolioLimitSnapshot {
        try await loadSnapshot(userId: userId, dataService: MockDataService.shared)
    }

    static func loadSnapshot(
        userId: String,
        dataService: DataServiceProtocol
    ) async throws -> PortfolioLimitSnapshot {
        async let accounts = dataService.fetchAccounts(userId: userId)
        async let holdings = dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
        async let manualAssets = dataService.fetchManualAssets(userId: userId)
        return SubscriptionComplianceState.snapshot(
            accounts: try await accounts,
            holdings: try await holdings,
            manualAssets: try await manualAssets
        )
    }

    static func message(for reason: PlusGateBlockReason) -> String {
        switch reason {
        case .plusFeatureRequired:
            return "此功能需要 Walleaf Plus。"
        case .holdingLimitReached:
            return "Free 方案最多 \(PlusFreeLimits.maxDistinctHoldings) 檔持股。你仍可加碼既有標的；若要新增第 \(PlusFreeLimits.maxDistinctHoldings + 1) 檔，請訂閱 Plus。"
        case .complianceModeNoBuy:
            return "目前持股超出 Free 上限（\(PlusFreeLimits.maxDistinctHoldings) 檔），只能全數賣出清倉，無法買入。訂閱 Plus 或賣至合規後即可恢復買入。"
        }
    }
}
