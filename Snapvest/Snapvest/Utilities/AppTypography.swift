//
//  AppTypography.swift
//  Snapvest
//
//  統一字級 tokens（方向 A）
//

import SwiftUI

extension Font {
    /// 頁首英雄數字：淨資產、帳戶總額、首頁主卡
    static let snapAmountHero = Font.system(size: 28, weight: .bold)
    /// 次英雄：列表輔助大數字
    static let snapAmountSecondary = Font.system(size: 26, weight: .bold)
    /// 個股英雄區「每股現價」
    static let snapStockPriceHero = Font.system(size: 32, weight: .bold)
    /// 表單參考現價數字
    static let snapReferencePrice = Font.system(size: 20, weight: .semibold)
    /// 指標格 MetricTile
    static let snapAmountTile = Font.system(size: 20, weight: .bold)
    /// 列表主金額：持股、交易、分類總額
    static let snapAmountRow = Font.system(size: 17, weight: .bold)
}
