//
//  FormInteraction.swift
//  Snapvest
//
//  表單列最小觸控區與整列可點範圍。
//

import SwiftUI

extension View {
    /// 表單輸入列：至少 44pt 高、整列矩形皆可點（TextField／Picker／Button 標籤）
    func snapFormFieldTapTarget(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: .infinity, minHeight: 44, alignment: alignment)
            .contentShape(Rectangle())
    }
}
