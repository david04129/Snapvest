//
//  HomePrivacyManager.swift
//  Snapvest
//
//  首頁金額隱私模式（UserDefaults 持久化）
//

import SwiftUI
import Combine

// MARK: - Environment

private struct HomeAmountsHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 首頁是否隱藏金額（僅 HomeView 子樹注入）
    var homeAmountsHidden: Bool {
        get { self[HomeAmountsHiddenKey.self] }
        set { self[HomeAmountsHiddenKey.self] = newValue }
    }
}

// MARK: - 格式化

enum HomeAmountPrivacyFormat {
    static let masked = "••••••"

    static func currency(_ amount: Decimal, currency: Currency, hidden: Bool) -> String {
        hidden ? masked : amount.formatted(currency: currency)
    }

    static func tradePrice(_ amount: Decimal, currency: Currency, hidden: Bool) -> String {
        hidden ? masked : amount.formattedTradePrice(currency: currency)
    }

    static func quantity(_ amount: Decimal, hidden: Bool, fractionDigits: Int = 4) -> String {
        hidden ? masked : amount.formatted(fractionDigits: fractionDigits)
    }
}

// MARK: - Manager

@MainActor
final class HomePrivacyManager: ObservableObject {
    static let shared = HomePrivacyManager()
    private static let storageKey = "snapvest.isHomeAmountHidden"

    /// true = 隱藏首頁金額，僅顯示比例等
    @Published private(set) var isAmountHidden: Bool {
        didSet {
            UserDefaults.standard.set(isAmountHidden, forKey: Self.storageKey)
        }
    }

    private init() {
        isAmountHidden = UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    func toggleAmountHidden() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isAmountHidden.toggle()
        }
    }
}
