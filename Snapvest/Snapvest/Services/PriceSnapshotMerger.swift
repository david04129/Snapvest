//
//  PriceSnapshotMerger.swift
//  Snapvest
//
//  合併遠端股價與本機快照：僅更新 current；trusted 昨收不被 DB 滾動覆寫。
//

import Foundation

enum PriceSnapshotMerger {
    /// 將遠端快照與本機既有快照合併（更新 current，保留 trusted previous）
    static func merge(incoming: AssetPriceSnapshot, existing: AssetPriceSnapshot?) -> AssetPriceSnapshot {
        guard let candidate = incoming.currentPrice ?? incoming.previousPrice else {
            if let existing, existing.hasValidPrice { return existing }
            return incoming
        }

        if let existing, existing.hasValidPrice {
            guard candidate > 0 else { return existing }
            return buildAccepted(
                incoming: incoming,
                existing: existing,
                candidate: candidate
            )
        }

        guard candidate > 0 else {
            if let existing, existing.hasValidPrice { return existing }
            return incoming
        }

        return normalizedFirstAccept(incoming: incoming, candidate: candidate)
    }

    /// 批次合併（Supabase 拉價後統一處理）
    static func mergeIncoming(
        _ incoming: [AssetPriceSnapshot],
        dataService: DataServiceProtocol
    ) async -> [AssetPriceSnapshot] {
        var merged: [AssetPriceSnapshot] = []
        merged.reserveCapacity(incoming.count)
        for snapshot in incoming {
            let existing = try? await dataService.fetchAssetPriceSnapshot(
                assetType: snapshot.assetType,
                symbol: snapshot.symbol
            )
            merged.append(mergePreservingDailyReference(incoming: snapshot, existing: existing))
        }
        return merged
    }

    static func mergePreservingDailyReference(
        incoming: AssetPriceSnapshot,
        existing: AssetPriceSnapshot?
    ) -> AssetPriceSnapshot {
        merge(incoming: incoming, existing: existing)
    }

    // MARK: - Builders

    private static func buildAccepted(
        incoming: AssetPriceSnapshot,
        existing: AssetPriceSnapshot,
        candidate: Decimal
    ) -> AssetPriceSnapshot {
        let previous = resolvedPreviousFields(incoming: incoming, existing: existing)
        return AssetPriceSnapshot(
            assetType: incoming.assetType,
            symbol: incoming.symbol,
            name: incoming.name ?? existing.name,
            currency: incoming.currency,
            currentPrice: candidate,
            previousPrice: previous.price,
            currentCloseDate: incoming.currentCloseDate ?? existing.currentCloseDate,
            currentUpdatedAt: incoming.currentUpdatedAt ?? existing.currentUpdatedAt ?? Date(),
            previousCloseDate: previous.closeDate,
            previousUpdatedAt: previous.updatedAt,
            currentPriceSource: incoming.currentPriceSource ?? existing.currentPriceSource,
            previousPriceSource: previous.source,
            priceKind: incoming.priceKind ?? existing.priceKind
        )
    }

    private struct ResolvedPrevious {
        let price: Decimal?
        let closeDate: Date?
        let updatedAt: Date?
        let source: String?
    }

    /// 盤中 sync 只更新 current；前收以 batch 依 history 算出的 incoming 為準，忽略 DB 滾動 previous。
    private static func resolvedPreviousFields(
        incoming: AssetPriceSnapshot,
        existing: AssetPriceSnapshot
    ) -> ResolvedPrevious {
        if DailyReferenceCloseResolver.isHistoryBackedPreviousSource(incoming.previousPriceSource),
           let price = incoming.previousPrice,
           price > 0 {
            return ResolvedPrevious(
                price: price,
                closeDate: incoming.previousCloseDate,
                updatedAt: incoming.previousUpdatedAt,
                source: incoming.previousPriceSource
            )
        }

        if let trusted = DailyReferenceCloseResolver.trustedSnapshotReference(from: existing) {
            return ResolvedPrevious(
                price: trusted.price,
                closeDate: trusted.closeDate,
                updatedAt: existing.previousUpdatedAt,
                source: existing.previousPriceSource
            )
        }

        if DailyReferenceCloseResolver.isTrustedPreviousSource(incoming.previousPriceSource),
           let price = incoming.previousPrice,
           price > 0 {
            return ResolvedPrevious(
                price: price,
                closeDate: incoming.previousCloseDate,
                updatedAt: incoming.previousUpdatedAt,
                source: incoming.previousPriceSource
            )
        }

        return ResolvedPrevious(price: nil, closeDate: nil, updatedAt: nil, source: nil)
    }

    private static func normalizedFirstAccept(incoming: AssetPriceSnapshot, candidate: Decimal) -> AssetPriceSnapshot {
        let trustedPrevious = DailyReferenceCloseResolver.isTrustedPreviousSource(incoming.previousPriceSource)
            ? incoming.previousPrice
            : nil
        let keepsPrevious = trustedPrevious != nil && trustedPrevious != candidate
        return AssetPriceSnapshot(
            assetType: incoming.assetType,
            symbol: incoming.symbol,
            name: incoming.name,
            currency: incoming.currency,
            currentPrice: candidate,
            previousPrice: keepsPrevious ? trustedPrevious : nil,
            currentCloseDate: incoming.currentCloseDate ?? incoming.currentUpdatedAt ?? Date(),
            currentUpdatedAt: incoming.currentUpdatedAt ?? Date(),
            previousCloseDate: keepsPrevious ? incoming.previousCloseDate : nil,
            previousUpdatedAt: keepsPrevious ? incoming.previousUpdatedAt : nil,
            currentPriceSource: incoming.currentPriceSource,
            previousPriceSource: keepsPrevious ? incoming.previousPriceSource : nil,
            priceKind: incoming.priceKind
        )
    }
}
