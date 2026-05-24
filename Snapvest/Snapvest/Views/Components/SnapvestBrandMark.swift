//
//  SnapvestBrandMark.swift
//  Snapvest
//
//  統一品牌 Logo（與 LaunchSplashView 相同）；日後換正式 Logo 只需改此檔。
//

import SwiftUI

enum SnapvestBrand {
    static let iconSystemName = "chart.pie.fill"
    static let appName = "Snapvest"
}

struct SnapvestBrandMark: View {
    enum Layout {
        case vertical
        case horizontal
    }

    var iconSize: CGFloat = 56
    var wordmarkSize: CGFloat = 34
    var spacing: CGFloat = 14
    var layout: Layout = .vertical
    var showsWordmark: Bool = true

    var body: some View {
        Group {
            switch layout {
            case .vertical:
                VStack(spacing: spacing) {
                    brandIcon
                    if showsWordmark { brandWordmark }
                }
            case .horizontal:
                HStack(spacing: spacing) {
                    brandIcon
                    if showsWordmark { brandWordmark }
                }
            }
        }
    }

    private var brandIcon: some View {
        Image(systemName: SnapvestBrand.iconSystemName)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(AppColors.appPrimary)
    }

    private var brandWordmark: some View {
        Text(SnapvestBrand.appName)
            .font(.system(size: wordmarkSize, weight: .bold))
            .foregroundColor(.primaryText)
    }
}
