//
//  ManualAssetMetrics.swift
//  Snapvest
//
//  Local-only valuation helpers for manual assets.
//

import Foundation

enum ManualAssetMetrics {
    static func itemId(for asset: ManualAsset) -> String {
        "manual_asset_\(asset.id)"
    }

    static func valueTWD(asset: ManualAsset, rates: [Currency: Decimal]) -> Decimal? {
        convertToTWD(asset.currentValue, currency: asset.currency, rates: rates)
    }

    static func costTWD(asset: ManualAsset, rates: [Currency: Decimal]) -> Decimal? {
        guard let costBasis = asset.costBasis else { return nil }
        return convertToTWD(costBasis, currency: asset.currency, rates: rates)
    }

    static func gainLossTWD(asset: ManualAsset, rates: [Currency: Decimal]) -> Decimal? {
        guard let value = valueTWD(asset: asset, rates: rates),
              let cost = costTWD(asset: asset, rates: rates) else {
            return nil
        }
        return value - cost
    }

    static func returnPercent(asset: ManualAsset, rates: [Currency: Decimal]) -> Decimal? {
        guard let gainLoss = gainLossTWD(asset: asset, rates: rates),
              let cost = costTWD(asset: asset, rates: rates),
              cost > 0 else {
            return nil
        }
        return (gainLoss / cost) * 100
    }

    private static func convertToTWD(_ amount: Decimal, currency: Currency, rates: [Currency: Decimal]) -> Decimal? {
        if currency == .TWD { return amount }
        guard let rate = rates[currency], rate > 0 else { return nil }
        return amount * rate
    }
}
