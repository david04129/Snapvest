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
    /// 管理／投資分頁類別總覽主金額（較子列 17pt 更大）
    static let snapOverviewAmount = Font.system(size: 19, weight: .bold)
    /// 管理／投資分頁類別總覽標題
    static let snapOverviewText = Font.system(size: 19, weight: .bold)
    /// 首頁圖表列右側數字（績效圖、圓餅圖明細）
    static let snapChartRowValue = Font.system(size: 13, weight: .semibold)
    /// 環形占比圈內百分比（不隨系統字級放大）
    static let snapRingPercent = Font.system(size: 11, weight: .semibold, design: .rounded)
}

extension View {
    /// 限制動態字級上限，避免緊湊列版面換行（投資類別卡等）。
    func snapCappedDynamicTypeSize(_ size: DynamicTypeSize = .xLarge) -> some View {
        dynamicTypeSize(...size)
    }

    /// 環形內百分比：固定字級，不跟隨無障礙字級放大。
    func snapRingPercentFixedSize() -> some View {
        dynamicTypeSize(.medium)
    }

    /// 首頁摘要卡：資料灌入時不播放數字／環形縮放動畫。
    func snapHomeSummaryMetricStyle() -> some View {
        transaction { transaction in
            transaction.animation = nil
        }
    }
}

enum SnapOverviewBarMetrics {
    static let overviewWidth: CGFloat = 6
    static let detailWidth: CGFloat = 4
    /// 總覽列空間不足時，標題／金額可縮至約此比例（不換行）
    static let minScaleFactor: CGFloat = 0.82
}

extension View {
    /// 類別總覽標題或金額：單行；空間不夠時縮小字級，不折行。
    func snapOverviewFittingLine(minScale: CGFloat = SnapOverviewBarMetrics.minScaleFactor) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
    }
}
