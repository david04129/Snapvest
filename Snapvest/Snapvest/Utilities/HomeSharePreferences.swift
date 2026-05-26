//
//  HomeSharePreferences.swift
//  Snapvest
//
//  記住使用者上次勾選的分享圖表項目
//

import Foundation

enum HomeSharePreferences {
    private static func storageKey(userId: String) -> String {
        "homeShareSelectedChartKinds_\(userId)"
    }

    static func loadSelectedKinds(userId: String = AppUser.id) -> Set<HomeShareChartKind>? {
        guard let rawValues = UserDefaults.standard.stringArray(
            forKey: storageKey(userId: userId)
        ) else {
            return nil
        }
        let kinds = rawValues.compactMap { HomeShareChartKind(rawValue: $0) }
        guard !kinds.isEmpty else { return nil }
        return Set(kinds)
    }

    static func saveSelectedKinds(_ kinds: Set<HomeShareChartKind>, userId: String = AppUser.id) {
        let rawValues = HomeShareChartKind.allCases
            .filter { kinds.contains($0) }
            .map(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: storageKey(userId: userId))
    }
}
