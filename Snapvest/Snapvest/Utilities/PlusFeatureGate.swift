//
//  PlusFeatureGate.swift
//  Snapvest
//
//  Walleaf Plus 功能鎖與 Free 上限攔截
//

import Foundation

enum PlusGateBlockReason: Equatable {
    case plusFeatureRequired
    case accountLimitReached
    case singleInvestmentMarketRequired
    case holdingLimitReached
    case singleHoldingMarketRequired
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
        guard !shouldBypassLimits(isPlusActive: isPlusActive) else { return .allowed }

        if snapshot.activeAccountCount >= PlusFreeLimits.maxAccounts {
            return .blocked(.accountLimitReached)
        }

        if accountType.category == .investment,
           !snapshot.investmentAccountTypes.isEmpty,
           !snapshot.investmentAccountTypes.contains(accountType) {
            return .blocked(.singleInvestmentMarketRequired)
        }

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

        let key = SubscriptionComplianceState.holdingKey(assetType: assetType, symbol: symbol)
        let isNewDistinctHolding = !snapshot.holdingKeys.contains(key)

        if isNewDistinctHolding {
            if snapshot.distinctHoldingCount >= PlusFreeLimits.maxDistinctHoldings {
                return .blocked(.holdingLimitReached)
            }
            if !snapshot.holdingAssetTypes.isEmpty,
               !snapshot.holdingAssetTypes.contains(assetType) {
                return .blocked(.singleHoldingMarketRequired)
            }
        }

        return .allowed
    }

    static func loadSnapshot(
        userId: String,
        dataService: DataServiceProtocol = MockDataService.shared
    ) async throws -> PortfolioLimitSnapshot {
        async let accounts = dataService.fetchAccounts(userId: userId)
        async let holdings = dataService.fetchAggregatedHoldingSnapshots(userId: userId, assetType: nil)
        return SubscriptionComplianceState.snapshot(
            accounts: try await accounts,
            holdings: try await holdings
        )
    }

    static func message(for reason: PlusGateBlockReason) -> String {
        switch reason {
        case .plusFeatureRequired:
            return "此功能需要 Walleaf Plus。"
        case .accountLimitReached:
            return "Free 方案最多 \(PlusFreeLimits.maxAccounts) 個帳戶。訂閱 Plus 可建立更多帳戶。"
        case .singleInvestmentMarketRequired:
            return "Free 方案投資帳戶只能使用一種市場（台股、美股或加密擇一）。訂閱 Plus 可開啟多種市場。"
        case .holdingLimitReached:
            return "Free 方案最多 \(PlusFreeLimits.maxDistinctHoldings) 檔持股。訂閱 Plus 可持有更多標的。"
        case .singleHoldingMarketRequired:
            return "Free 方案持股需在同一投資市場。訂閱 Plus 可跨市場持有。"
        case .complianceModeNoBuy:
            return "目前持股超出 Free 上限，只能全數賣出清倉，無法買入。訂閱 Plus 或賣至合規後即可恢復買入。"
        }
    }
}
