//
//  OpenSettingsEnvironment.swift
//  Snapvest
//
//  讓各 Tab 的 header 共用全域「更多」入口
//

import SwiftUI

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
