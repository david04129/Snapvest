//
//  SnapvestBrandMark.swift
//  Snapvest
//
//  統一品牌 Logo（與 LaunchSplashView 相同）；日後換正式 Logo 只需改此檔。
//

import SwiftUI

enum SnapvestBrand {
    static let logoImageName = "SnapvestLogo"
    static let appName = "Walleaf"
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
        Image(SnapvestBrand.logoImageName)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
    }

    private var brandWordmark: some View {
        Text(SnapvestBrand.appName)
            .font(.system(size: wordmarkSize, weight: .bold))
            .foregroundColor(.primaryText)
    }
}
