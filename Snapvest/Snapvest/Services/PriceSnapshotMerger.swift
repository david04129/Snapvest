//
//  PriceSnapshotMerger.swift
//  Snapvest
//
//  合併遠端股價與本機快照：驗證後更新 current，舊 current 降為 previous。
//

import Foundation

enum PriceSnapshotMerger {
    /// 單日允許最大變動比例（100%）
    static let maxDailyChangeRatio: Decimal = 1
    
    /// 將遠端快照與本機既有快照合併（保留上一筆備援）
    static func merge(incoming: AssetPriceSnapshot, existing: AssetPriceSnapshot?) -> AssetPriceSnapshot {
        guard let candidate = incoming.currentPrice ?? incoming.previousPrice else {
            if let existing, existing.hasValidPrice { return existing }
            return incoming
        }
        
        if let existing, existing.hasValidPrice, let reference = existing.displayPrice {
            guard isValidCandidate(candidate, referencePrice: reference) else {
                #if DEBUG
                print("[PriceSnapshotMerger] rejected \(incoming.assetType.rawValue)/\(incoming.symbol): candidate=\(candidate) ref=\(reference)")
                #endif
                return existing
            }
            return buildAccepted(
                incoming: incoming,
                existing: existing,
                candidate: candidate,
                candidateDate: incoming.currentCloseDate ?? incoming.currentUpdatedAt ?? Date()
            )
        }
        
        guard candidate > 0 else {
            if let existing, existing.hasValidPrice { return existing }
            return incoming
        }
        
        if let incomingPrevious = incoming.previousPrice,
           incomingPrevious > 0,
           incoming.currentPrice != nil,
           !isValidMutation(from: incomingPrevious, to: candidate) {
            #if DEBUG
            print("[PriceSnapshotMerger] rejected first ingest spike \(incoming.symbol)")
            #endif
            if let existing, existing.hasValidPrice { return existing }
            return snapshotUsingPreviousOnly(from: incoming, previous: incomingPrevious)
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
    
    // MARK: - Validation
    
    private static func isValidCandidate(_ candidate: Decimal, referencePrice: Decimal) -> Bool {
        guard candidate > 0 else { return false }
        guard referencePrice > 0 else { return true }
        return isValidMutation(from: referencePrice, to: candidate)
    }
    
    private static func isValidMutation(from reference: Decimal, to candidate: Decimal) -> Bool {
        guard reference > 0, candidate > 0 else { return false }
        return changeRatio(from: reference, to: candidate) <= maxDailyChangeRatio
    }
    
    private static func changeRatio(from reference: Decimal, to candidate: Decimal) -> Decimal {
        let diff = candidate - reference
        let absDiff = diff < 0 ? -diff : diff
        return absDiff / reference
    }
    
    // MARK: - Builders
    
    private static func buildAccepted(
        incoming: AssetPriceSnapshot,
        existing: AssetPriceSnapshot,
        candidate: Decimal,
        candidateDate: Date
    ) -> AssetPriceSnapshot {
        AssetPriceSnapshot(
            assetType: incoming.assetType,
            symbol: incoming.symbol,
            name: incoming.name ?? existing.name,
            currency: incoming.currency,
            currentPrice: candidate,
            previousPrice: existing.currentPrice ?? existing.previousPrice,
            currentCloseDate: incoming.currentCloseDate ?? existing.currentCloseDate,
            currentUpdatedAt: incoming.currentUpdatedAt ?? existing.currentUpdatedAt ?? Date(),
            previousCloseDate: existing.currentCloseDate ?? existing.previousCloseDate,
            previousUpdatedAt: existing.currentUpdatedAt ?? existing.previousUpdatedAt,
            currentPriceSource: incoming.currentPriceSource ?? existing.currentPriceSource,
            previousPriceSource: existing.currentPriceSource ?? existing.previousPriceSource
        )
    }
    
    private static func normalizedFirstAccept(incoming: AssetPriceSnapshot, candidate: Decimal) -> AssetPriceSnapshot {
        AssetPriceSnapshot(
            assetType: incoming.assetType,
            symbol: incoming.symbol,
            name: incoming.name,
            currency: incoming.currency,
            currentPrice: candidate,
            previousPrice: incoming.previousPrice != candidate ? incoming.previousPrice : nil,
            currentCloseDate: incoming.currentCloseDate ?? incoming.currentUpdatedAt ?? Date(),
            currentUpdatedAt: incoming.currentUpdatedAt ?? Date(),
            previousCloseDate: incoming.previousCloseDate,
            previousUpdatedAt: incoming.previousUpdatedAt,
            currentPriceSource: incoming.currentPriceSource,
            previousPriceSource: incoming.previousPriceSource
        )
    }
    
    private static func snapshotUsingPreviousOnly(from incoming: AssetPriceSnapshot, previous: Decimal) -> AssetPriceSnapshot {
        AssetPriceSnapshot(
            assetType: incoming.assetType,
            symbol: incoming.symbol,
            name: incoming.name,
            currency: incoming.currency,
            currentPrice: previous,
            previousPrice: nil,
            currentCloseDate: incoming.previousCloseDate ?? incoming.previousUpdatedAt,
            currentUpdatedAt: incoming.currentUpdatedAt ?? Date(),
            previousCloseDate: nil,
            previousUpdatedAt: nil,
            currentPriceSource: incoming.currentPriceSource,
            previousPriceSource: incoming.previousPriceSource
        )
    }

    /// 合併時保留遠端 previous（昨收），僅在本地尚無有效 previous 時採用。
    static func mergePreservingDailyReference(
        incoming: AssetPriceSnapshot,
        existing: AssetPriceSnapshot?
    ) -> AssetPriceSnapshot {
        let merged = merge(incoming: incoming, existing: existing)
        guard let existing else { return merged }
        guard let incomingPrevious = incoming.previousPrice, incomingPrevious > 0 else {
            return merged
        }
        let useIncomingPrevious: Bool = {
            guard let existingPrevious = existing.previousPrice, existingPrevious > 0,
                  let existingDate = existing.previousCloseDate,
                  let incomingDate = incoming.previousCloseDate else {
                return true
            }
            return incomingDate >= existingDate
        }()
        guard useIncomingPrevious else { return merged }
        return AssetPriceSnapshot(
            assetType: merged.assetType,
            symbol: merged.symbol,
            name: merged.name,
            currency: merged.currency,
            currentPrice: merged.currentPrice,
            previousPrice: incomingPrevious,
            currentCloseDate: merged.currentCloseDate,
            currentUpdatedAt: merged.currentUpdatedAt,
            previousCloseDate: incoming.previousCloseDate ?? merged.previousCloseDate,
            previousUpdatedAt: incoming.previousUpdatedAt ?? merged.previousUpdatedAt,
            currentPriceSource: merged.currentPriceSource,
            previousPriceSource: incoming.previousPriceSource ?? merged.previousPriceSource,
            priceKind: merged.priceKind
        )
    }
}
