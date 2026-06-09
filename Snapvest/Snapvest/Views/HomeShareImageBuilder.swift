//
//  HomeShareImageBuilder.swift
//  Snapvest
//
//  將選取的圖表合成一張分享長圖（垂直堆疊）
//

import SwiftUI
import UIKit

enum HomeShareImageBuilder {
    /// 邏輯畫布寬（pt）
    static let canvasWidth: CGFloat = 390
    static let headerSectionHeight: CGFloat = 68
    static let footerSectionHeight: CGFloat = 72
    static let footerSectionHeightWithPrivacyNote: CGFloat = 86
    static let chartsSectionSpacing: CGFloat = 16

    /// 輸出像素倍率（與裝置螢幕無關，確保相簿內每張分享圖解析度一致）
    static let exportScale: CGFloat = 3

    @MainActor
    static func renderPreview(config: HomeShareRenderConfig) -> UIImage? {
        let content = HomeShareCompositeView(config: config)
            .frame(width: canvasWidth)
            .fixedSize(horizontal: true, vertical: true)
            .background(Color.mainBackground)
            .transaction { $0.animation = nil }

        let renderer = ImageRenderer(content: content)
        renderer.isOpaque = true
        renderer.scale = exportScale
        return renderer.uiImage
    }

    @MainActor
    static func render(config: HomeShareRenderConfig) -> UIImage? {
        renderPreview(config: config)
    }
}

// MARK: - 合成內容

private struct HomeShareCompositeView: View {
    let config: HomeShareRenderConfig

    private var footerHeight: CGFloat {
        config.hideAmounts
            ? HomeShareImageBuilder.footerSectionHeightWithPrivacyNote
            : HomeShareImageBuilder.footerSectionHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            shareHeader
                .padding(.horizontal, 20)
                .frame(height: HomeShareImageBuilder.headerSectionHeight, alignment: .top)

            VStack(spacing: HomeShareImageBuilder.chartsSectionSpacing) {
                if config.includeTrend, config.isAvailable(.trend) {
                    HomeTrendChartShareCard(config: config)
                }
                if config.includePie, config.isAvailable(.pie) {
                    HomePieChartShareCard(config: config)
                }
                if config.includePerformance, config.isAvailable(.performance) {
                    HomePerformanceChartShareCard(config: config)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            shareFooter
                .padding(.horizontal, 20)
                .frame(minHeight: footerHeight, alignment: .bottom)
        }
        .frame(width: HomeShareImageBuilder.canvasWidth)
        .background(Color.mainBackground)
        .environment(\.homeAmountsHidden, config.hideAmounts)
        .preferredColorScheme(config.isDarkMode ? .dark : .light)
    }

    private var shareHeader: some View {
        HStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                SnapvestBrandMark(
                    iconSize: 36,
                    wordmarkSize: 24,
                    spacing: 10,
                    layout: .horizontal
                )
                Text("隨手開啟，掌握資產的成長")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var shareFooter: some View {
        VStack(spacing: 6) {
            Divider()
            Text(formattedDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
            HStack(spacing: 6) {
                Image(SnapvestBrand.logoImageName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("\(SnapvestBrand.appName)｜隨手開啟，掌握資產的成長")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
            if config.hideAmounts {
                Text("金額已隱藏")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appPrimary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: config.generatedAt)
    }
}

// MARK: - Activity Sheet

struct HomeShareActivityView: UIViewControllerRepresentable {
    let image: UIImage
    let shareText: String
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [shareText, image],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
