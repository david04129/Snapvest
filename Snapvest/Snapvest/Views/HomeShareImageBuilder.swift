//
//  HomeShareImageBuilder.swift
//  Snapvest
//
//  將選取的圖表合成一張分享長圖
//

import SwiftUI
import UIKit

enum HomeShareImageBuilder {
    /// 邏輯畫布寬（pt）
    static let canvasWidth: CGFloat = 390
    /// 邏輯畫布高（pt），固定 9:16；內容過多時等比縮小塞入，不裁切
    static let canvasHeight: CGFloat = 760

    /// 頂部留白（全螢幕瀏覽時保護 Logo 區）
    static let topSafeInset: CGFloat = 56
    static let headerBrandHeight: CGFloat = 72
    static let headerSectionHeight: CGFloat = topSafeInset + headerBrandHeight
    static let footerSectionHeight: CGFloat = 72
    static let chartsSectionSpacing: CGFloat = 16

    /// 輸出像素倍率（與裝置螢幕無關，確保相簿內每張分享圖解析度一致）
    static let exportScale: CGFloat = 3

    static var exportPixelSize: CGSize {
        CGSize(width: canvasWidth * exportScale, height: canvasHeight * exportScale)
    }

    @MainActor
    static func render(config: HomeShareRenderConfig) -> UIImage? {
        let intrinsicContent = HomeShareCompositeView(config: config)
            .frame(width: canvasWidth)
            .fixedSize(horizontal: true, vertical: true)
            .background(Color.mainBackground)
            .transaction { $0.animation = nil }

        let intrinsicRenderer = ImageRenderer(content: intrinsicContent)
        intrinsicRenderer.isOpaque = true
        intrinsicRenderer.scale = exportScale
        guard let intrinsicImage = intrinsicRenderer.uiImage else { return nil }

        let fittedContent = HomeShareFittedCanvasView(
            image: intrinsicImage,
            isDarkMode: config.isDarkMode
        )
        .frame(width: canvasWidth, height: canvasHeight)
        .background(Color.mainBackground)
        .transaction { $0.animation = nil }

        let fittedRenderer = ImageRenderer(content: fittedContent)
        fittedRenderer.isOpaque = true
        fittedRenderer.scale = exportScale
        return fittedRenderer.uiImage
    }
}

/// 固定畫布：將內容等比縮放至完整可見（不裁切）
private struct HomeShareFittedCanvasView: View {
    let image: UIImage
    let isDarkMode: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: HomeShareImageBuilder.canvasWidth,
                    maxHeight: HomeShareImageBuilder.canvasHeight,
                    alignment: .top
                )
            Spacer(minLength: 0)
        }
        .frame(width: HomeShareImageBuilder.canvasWidth, height: HomeShareImageBuilder.canvasHeight, alignment: .top)
        .background(Color.mainBackground)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 合成內容（自然高度，供縮放前渲染）

private struct HomeShareCompositeView: View {
    let config: HomeShareRenderConfig

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
                .padding(.vertical, 16)
                .frame(minHeight: HomeShareImageBuilder.footerSectionHeight, alignment: .bottom)
        }
        .frame(width: HomeShareImageBuilder.canvasWidth)
        .background(Color.mainBackground)
        .environment(\.homeAmountsHidden, config.hideAmounts)
        .preferredColorScheme(config.isDarkMode ? .dark : .light)
    }

    private var shareHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: HomeShareImageBuilder.topSafeInset)
            HStack(spacing: 0) {
                SnapvestBrandMark(
                    iconSize: 40,
                    wordmarkSize: 28,
                    spacing: 12,
                    layout: .horizontal
                )
                Spacer(minLength: 0)
            }
            .frame(height: HomeShareImageBuilder.headerBrandHeight, alignment: .leading)
        }
    }

    private var shareFooter: some View {
        VStack(spacing: 6) {
            Divider()
            Text(formattedDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
            Text("僅供個人記錄 · \(SnapvestBrand.appName)")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
            if config.hideAmounts {
                Text("金額已隱藏")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: config.generatedAt)
    }
}

// MARK: - Activity Sheet

struct HomeShareActivityView: UIViewControllerRepresentable {
    let image: UIImage
    let shareText: String
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 僅傳文字 + UIImage；勿再加檔案 URL，否則 LINE 等會收到兩張圖
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
