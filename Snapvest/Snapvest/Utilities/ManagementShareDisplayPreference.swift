//
//  ManagementShareDisplayPreference.swift
//  Snapvest
//
//  管理分頁：子列左側顯示幣別 icon 或總資產占比環。
//

import SwiftUI

enum ManagementShareDisplayMode: String, Codable, CaseIterable, Identifiable {
    case currencyIcon
    case shareRing

    var id: String { rawValue }

    var chipTitle: String {
        switch self {
        case .currencyIcon: return "幣別"
        case .shareRing: return "占比"
        }
    }

    var chipIcon: String {
        switch self {
        case .currencyIcon: return "dollarsign.circle.fill"
        case .shareRing: return "chart.pie.fill"
        }
    }
}

struct ManagementShareDisplayPreference {
    private static let key = "managementShareDisplayMode"

    static func get() -> ManagementShareDisplayMode {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let mode = ManagementShareDisplayMode(rawValue: raw) else {
            return .currencyIcon
        }
        return mode
    }

    static func set(_ mode: ManagementShareDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }
}

private struct ManagementShareDisplayModeKey: EnvironmentKey {
    static let defaultValue: ManagementShareDisplayMode = ManagementShareDisplayPreference.get()
}

extension EnvironmentValues {
    var managementShareDisplayMode: ManagementShareDisplayMode {
        get { self[ManagementShareDisplayModeKey.self] }
        set { self[ManagementShareDisplayModeKey.self] = newValue }
    }
}
