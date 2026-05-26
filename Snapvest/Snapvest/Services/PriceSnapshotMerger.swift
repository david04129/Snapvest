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
                candidateDate: incoming.currentPriceDate ?? incoming.lastSuccessfulUpdate ?? Date()
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
            merged.append(merge(incoming: snapshot, existing: existing))
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
            currentPriceDate: candidateDate,
            previousPriceDate: existing.currentPriceDate ?? existing.previousPriceDate,
            lastUpdated: Date(),
            lastSuccessfulUpdate: Date(),
            priceSource: incoming.priceSource ?? existing.priceSource
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
            currentPriceDate: incoming.currentPriceDate ?? incoming.lastSuccessfulUpdate ?? Date(),
            previousPriceDate: incoming.previousPriceDate,
            lastUpdated: Date(),
            lastSuccessfulUpdate: Date(),
            priceSource: incoming.priceSource
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
            currentPriceDate: incoming.previousPriceDate ?? incoming.lastUpdated,
            previousPriceDate: nil,
            lastUpdated: Date(),
            lastSuccessfulUpdate: Date(),
            priceSource: incoming.priceSource
        )
    }
}
