//
//  AppFeatureFlags.swift
//  Snapvest
//
//  產品功能開關（隱藏 UI 時仍保留實作，方便日後重新開放）。
//

import Foundation

enum AppFeatureFlags {
    /// 設定頁「風格／自訂配色」；關閉時固定使用沉穩理財。
    static let showsThemeStylePicker = false

    /// 設定頁「開發」區塊（DEBUG 建置亦隱藏）。
    static let showsDeveloperSettings = false
}
