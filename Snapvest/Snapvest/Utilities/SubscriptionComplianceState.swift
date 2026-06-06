//
//  SubscriptionComplianceState.swift
//  Snapvest
//
//  Free 方案上限與合規狀態計算
//

import Foundation

enum PlusFreeLimits {
    static let maxAccounts = 3
    static let maxDistinctHoldings = 5
}

struct PortfolioLimitSnapshot: Equatable {
    let activeAccountCount: Int
    let distinctHoldingCount: Int
    let investmentAccountTypes: Set<AccountType>
    let holdingAssetTypes: Set<AssetType>
    let holdingKeys: Set<String>

    var isOverFreeAccountLimit: Bool {
        activeAccountCount > PlusFreeLimits.maxAccounts
    }

    /// 持股 >5 檔，或跨多種投資市場
    var isOverFreeHoldingLimits: Bool {
        distinctHoldingCount > PlusFreeLimits.maxDistinctHoldings
            || holdingAssetTypes.count > 1
    }

    var requiresFullLiquidationSell: Bool {
        isOverFreeHoldingLimits
    }
}

enum SubscriptionComplianceState {
    static func snapshot(
        accounts: [Account],
        holdings: [AggregatedHoldingSnapshot]
    ) -> PortfolioLimitSnapshot {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeHoldings = holdings.filter {
            $0.totalQuantity > 0 && $0.assetType != .cash
        }

        let investmentTypes = Set(
            activeAccounts
                .filter { $0.accountType.category == .investment }
                .map(\.accountType)
        )

        let holdingTypes = Set(activeHoldings.map(\.assetType))
        let holdingKeys = Set(activeHoldings.map { holdingKey(assetType: $0.assetType, symbol: $0.symbol) })

        return PortfolioLimitSnapshot(
            activeAccountCount: activeAccounts.count,
            distinctHoldingCount: activeHoldings.count,
            investmentAccountTypes: investmentTypes,
            holdingAssetTypes: holdingTypes,
            holdingKeys: holdingKeys
        )
    }

    static func holdingKey(assetType: AssetType, symbol: String) -> String {
        "\(assetType.rawValue)_\(symbol.uppercased())"
    }
}
