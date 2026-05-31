//
//  MarketDirectionSymbol.swift
//  Snapvest
//

import Foundation

/// 漲跌方向 SF Symbol（上／下三角，非買賣或收支箭頭）。
enum MarketDirectionSymbol {
    static func systemName(isUp: Bool) -> String {
        isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
    }

    static func systemName(for change: Decimal) -> String {
        systemName(isUp: change >= 0)
    }
}
