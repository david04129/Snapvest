//
//  ManualAssetValuationHistoryBuilder.swift
//  Snapvest
//
//  其他資產現值紀錄列表（建立 + 历次更新）顯示用資料。
//

import Foundation

struct ManualAssetValuationHistoryEntry: Identifiable, Equatable {
    let valuation: ManualAssetValuation
    let isCreation: Bool
    let displayDelta: Decimal

    var id: String { valuation.id }

    var title: String {
        isCreation ? "建立" : "更新現值"
    }

    var date: Date { valuation.valuationDate }

    var currency: Currency { valuation.currency }

    var valueAtRecord: Decimal { valuation.value }

    var trimmedNotes: String? {
        guard let notes = valuation.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty,
              !isCreation else {
            return nil
        }
        return notes
    }
}

enum ManualAssetValuationHistoryBuilder {
    /// 依日期由新到舊排序，並計算每筆相對上一筆的變動量。
    static func entries(from valuations: [ManualAssetValuation]) -> [ManualAssetValuationHistoryEntry] {
        let sortedAsc = valuations.sorted { $0.valuationDate < $1.valuationDate }
        var previousValue: Decimal = 0
        var built: [ManualAssetValuationHistoryEntry] = []

        for valuation in sortedAsc {
            let isCreation = valuation.notes == ManualAssetValuation.creationRecordNote
            let delta = valuation.value - previousValue
            previousValue = valuation.value
            built.append(
                ManualAssetValuationHistoryEntry(
                    valuation: valuation,
                    isCreation: isCreation,
                    displayDelta: delta
                )
            )
        }

        return built.sorted { $0.date > $1.date }
    }
}
