//
//  FreeLimitBlurEnvironment.swift
//  Snapvest
//
//  Free 超上限且非 Plus／示範模式時，對敏感數字／圖表／占比做視覺霧化（不阻擋點擊）
//

import SwiftUI

// MARK: - Policy

enum FreeLimitBlurPolicy {
    static func shouldBlurContent(isPlusActive: Bool, snapshot: PortfolioLimitSnapshot) -> Bool {
        guard !PlusFeatureGate.shouldBypassLimits(isPlusActive: isPlusActive) else { return false }
        return snapshot.isOverFreeLimits
    }
}

extension PortfolioLimitSnapshot {
    /// 帳戶或持股任一超出 Free 上限
    var isOverFreeLimits: Bool {
        isOverFreeAccountLimit || isOverFreeHoldingLimits
    }
}

// MARK: - Environment

enum FreeLimitBlurScope {
    case numbers
    case charts
    case pie
}

private struct FreeLimitBlurNumbersKey: EnvironmentKey {
    static let defaultValue = false
}

private struct FreeLimitBlurChartsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct FreeLimitBlurPieKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var freeLimitBlurNumbers: Bool {
        get { self[FreeLimitBlurNumbersKey.self] }
        set { self[FreeLimitBlurNumbersKey.self] = newValue }
    }

    var freeLimitBlurCharts: Bool {
        get { self[FreeLimitBlurChartsKey.self] }
        set { self[FreeLimitBlurChartsKey.self] = newValue }
    }

    var freeLimitBlurPie: Bool {
        get { self[FreeLimitBlurPieKey.self] }
        set { self[FreeLimitBlurPieKey.self] = newValue }
    }
}

// MARK: - Modifiers

private struct FreeLimitBlurModifier: ViewModifier {
    let scopes: [FreeLimitBlurScope]

    @Environment(\.freeLimitBlurNumbers) private var blurNumbers
    @Environment(\.freeLimitBlurCharts) private var blurCharts
    @Environment(\.freeLimitBlurPie) private var blurPie

    private var isActive: Bool {
        scopes.contains { scope in
            switch scope {
            case .numbers: blurNumbers
            case .charts: blurCharts
            case .pie: blurPie
            }
        }
    }

    func body(content: Content) -> some View {
        if isActive {
            content
                .blur(radius: 10)
                .allowsHitTesting(true)
        } else {
            content
        }
    }
}

extension View {
    func freeLimitBlurred(_ scopes: FreeLimitBlurScope...) -> some View {
        modifier(FreeLimitBlurModifier(scopes: scopes))
    }
}
