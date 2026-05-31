//
//  BaseCurrencyManager.swift
//  Snapvest
//
//  使用者主要幣別偏好：原幣仍保留，總覽與折算值使用主要幣別。
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class BaseCurrencyManager: ObservableObject {
    static let shared = BaseCurrencyManager()
    
    private static let storageKey = "walleaf.baseCurrency"
    
    @Published private(set) var baseCurrency: Currency {
        didSet {
            UserDefaults.standard.set(baseCurrency.rawValue, forKey: Self.storageKey)
        }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let currency = Currency(rawValue: raw) {
            baseCurrency = currency
        } else {
            baseCurrency = .TWD
        }
    }
    
    func setBaseCurrency(_ currency: Currency) {
        guard baseCurrency != currency else { return }
        baseCurrency = currency
    }
}

struct CurrencyRateTable {
    var twdPerCurrency: [Currency: Decimal]
    
    init(twdPerCurrency: [Currency: Decimal] = [:]) {
        var normalized = twdPerCurrency
        normalized[.TWD] = 1
        self.twdPerCurrency = normalized
    }
    
    func rate(from source: Currency, to target: Currency) -> Decimal? {
        guard source != target else { return 1 }
        guard let sourceToTWD = twdPerCurrency[source],
              let targetToTWD = twdPerCurrency[target],
              sourceToTWD > 0,
              targetToTWD > 0 else {
            return nil
        }
        return sourceToTWD / targetToTWD
    }
}

enum CurrencyConversionService {
    static func convert(_ amount: Decimal, from source: Currency, to target: Currency, rates: CurrencyRateTable) -> Decimal? {
        guard let rate = rates.rate(from: source, to: target) else { return nil }
        return amount * rate
    }
    
    static func rateTable(usdToTwdRate: Decimal?) -> CurrencyRateTable {
        var rates: [Currency: Decimal] = [.TWD: 1]
        if let usdToTwdRate, usdToTwdRate > 0 {
            rates[.USD] = usdToTwdRate
        }
        return CurrencyRateTable(twdPerCurrency: rates)
    }
}

extension Currency {
    static var baseCurrencyOptions: [Currency] {
        [.TWD, .USD, .AUD, .JPY, .EUR, .HKD, .CNY]
    }
    
    var settingsDisplayName: String {
        "\(displayName) \(rawValue)"
    }

    /// 設定／表單幣別 chip 色（不依賴當下圓餅圖配置）
    var chipTintColor: Color {
        switch self {
        case .TWD: return .allocationTwdCash
        case .USD: return .allocationUsdCash
        case .EUR: return .stockUSColor
        case .JPY: return .stockTWColor
        case .AUD: return .cryptoColor
        case .HKD: return .manualAssetColor
        case .CNY: return .homeInvestmentsAccent
        }
    }
}
