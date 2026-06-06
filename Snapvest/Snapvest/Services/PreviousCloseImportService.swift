//
//  PreviousCloseImportService.swift
//  Snapvest
//
//  從 asset_price_history 匯入各持股「日漲跌基準」昨收至本機快照。
//

import Foundation

struct PreviousCloseImportResult: Sendable, Equatable {
    let holdingSymbolCount: Int
    let updatedSymbolCount: Int

    var summaryMessage: String {
        if holdingSymbolCount == 0 {
            return "目前沒有持股可匯入昨收。"
        }
        if updatedSymbolCount == 0 {
            return "已查詢 \(holdingSymbolCount) 檔持股，但無法從雲端 history 寫入昨收。請確認網路與股價資料。"
        }
        return "已更新 \(updatedSymbolCount) / \(holdingSymbolCount) 檔持股的昨收。"
    }
}

enum PreviousCloseImportService {
    @MainActor
    @discardableResult
    static func importForPortfolio(
        userId: String,
        dataService: DataServiceProtocol? = nil
    ) async -> PreviousCloseImportResult {
        let resolvedDataService = dataService ?? MockDataService.shared

        let symbols = await PortfolioSymbolCollector.holdingSymbols(
            userId: userId,
            dataService: resolvedDataService
        )
        guard !symbols.isEmpty else {
            return PreviousCloseImportResult(holdingSymbolCount: 0, updatedSymbolCount: 0)
        }

        let updated = await DailyPreviousCloseSync.apply(
            for: symbols,
            dataService: resolvedDataService
        )
        if updated > 0 {
            resolvedDataService.persistLocalStore(for: userId)
            DailyPriceHistoryCache.invalidate()
            NotificationCenter.default.post(name: .snapshotsDidUpdate, object: nil)
        }

        return PreviousCloseImportResult(
            holdingSymbolCount: symbols.count,
            updatedSymbolCount: updated
        )
    }
}
