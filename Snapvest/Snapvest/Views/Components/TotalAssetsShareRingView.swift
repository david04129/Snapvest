//
//  TotalAssetsShareRingView.swift
//  Snapvest
//
//  佔比環形圖：圈內固定字級顯示百分比；環尺寸固定不隨系統字級放大。
//

import SwiftUI

/// 進度弧線繪製方式（現金卡為反向區段）。
enum PercentageRingTrimStyle {
    case clockwiseFromTop
    case counterclockwiseTail
}

struct AdaptivePercentageRingView: View {
    let sharePercent: Decimal
    let accentColor: Color
    var trimStyle: PercentageRingTrimStyle = .clockwiseFromTop

    private let ringSize: CGFloat
    private let lineWidth: CGFloat
    private let animatesProgressChanges: Bool

    init(
        sharePercent: Decimal,
        accentColor: Color,
        trimStyle: PercentageRingTrimStyle = .clockwiseFromTop,
        ringSize: CGFloat = 50,
        lineWidth: CGFloat = 7,
        animatesProgressChanges: Bool = true
    ) {
        self.sharePercent = sharePercent
        self.accentColor = accentColor
        self.trimStyle = trimStyle
        self.ringSize = ringSize
        self.lineWidth = lineWidth
        self.animatesProgressChanges = animatesProgressChanges
    }

    private var progress: CGFloat {
        let clamped = min(max(NSDecimalNumber(decimal: sharePercent).doubleValue, 0), 100)
        return CGFloat(clamped / 100)
    }

    private var percentLabel: String {
        "\(sharePercent.formatted(fractionDigits: 1))%"
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(accentColor.opacity(0.15), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            progressRingStroke

            Text(percentLabel)
                .font(.snapRingPercent)
                .monospacedDigit()
                .foregroundColor(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, max(4, ringSize * 0.1))
                .snapRingPercentFixedSize()
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityLabel("佔比 \(percentLabel)")
        .animation(animatesProgressChanges ? .default : nil, value: sharePercent)
    }

    @ViewBuilder
    private var progressRingStroke: some View {
        let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        switch trimStyle {
        case .clockwiseFromTop:
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(accentColor, style: strokeStyle)
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(Angle.degrees(-90))
        case .counterclockwiseTail:
            Circle()
                .trim(from: 1.0 - progress, to: 1.0)
                .stroke(accentColor, style: strokeStyle)
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(Angle.degrees(-90))
        }
    }
}

struct TotalAssetsShareRingView: View {
    let sharePercent: Decimal
    let accentColor: Color

    var body: some View {
        AdaptivePercentageRingView(
            sharePercent: sharePercent,
            accentColor: accentColor,
            ringSize: 44,
            lineWidth: 5
        )
    }
}

/// 子列左側：依管理頁切換顯示幣別 icon 或占比環。
struct ManagementRowLeadingIndicator: View {
    let currency: Currency
    let accentColor: Color
    let sharePercent: Decimal
    var onToggleDisplayMode: (() -> Void)? = nil

    @Environment(\.managementShareDisplayMode) private var displayMode

    var body: some View {
        if let onToggleDisplayMode {
            indicator
                .frame(minWidth: 44, alignment: .center)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        onToggleDisplayMode()
                    }
                )
                .accessibilityAddTraits(.isButton)
        } else {
            indicator
                .frame(minWidth: 44, alignment: .center)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch displayMode {
        case .currencyIcon:
            CurrencyIconBadge(currency: currency, tint: accentColor)
        case .shareRing:
            TotalAssetsShareRingView(sharePercent: sharePercent, accentColor: accentColor)
        }
    }
}
