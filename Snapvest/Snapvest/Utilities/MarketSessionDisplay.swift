//
//  MarketSessionDisplay.swift
//  Snapvest
//
//  盤中／收盤 Chip：依 market-status 的交易日與 regular session（不顯示休市）。
//

import Foundation

enum MarketSessionDisplay {
    enum SessionChip: String {
        case intraday = "盤中"
        case close = "收盤"
    }

    static func sessionChip(
        assetType: AssetType,
        marketStatus: MarketStatusSnapshot?
    ) -> SessionChip? {
        switch assetType {
        case .cash:
            return nil
        case .crypto:
            return .intraday
        case .stockTW, .stockUS:
            guard let marketStatus else { return .close }
            let market = assetType == .stockTW ? marketStatus.tw : marketStatus.us
            return market.isRegularSession ? .intraday : .close
        }
    }

    static func categorySessionChip(
        assetType: AssetType,
        marketStatus: MarketStatusSnapshot?
    ) -> SessionChip? {
        sessionChip(assetType: assetType, marketStatus: marketStatus)
    }
}
