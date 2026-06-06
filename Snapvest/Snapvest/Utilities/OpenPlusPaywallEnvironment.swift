//
//  OpenPlusPaywallEnvironment.swift
//  Snapvest
//
//  各 Tab 合規橫幅等共用 Paywall 入口
//

import SwiftUI

private struct OpenPlusPaywallKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openPlusPaywall: () -> Void {
        get { self[OpenPlusPaywallKey.self] }
        set { self[OpenPlusPaywallKey.self] = newValue }
    }
}
