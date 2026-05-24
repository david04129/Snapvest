//
//  HomeShareImageBuilder.swift
//  Snapvest
//
//  將選取的圖表合成一張分享長圖
//

import SwiftUI
import UIKit

enum HomeShareImageBuilder {
    static let canvasWidth: CGFloat = 390

    @MainActor
    static func render(config: HomeShareRenderConfig) -> UIImage? {
        let content = HomeShareCompositeView(config: config)
            .frame(width: canvasWidth)
            .background(Color.mainBackground)

        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    /// 從目前 window scene 取得螢幕 scale（避免使用已 deprecated 的 UIScreen.main）
    private static var displayScale: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen.scale
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .screen.scale
            ?? 3.0
    }
}

// MARK: - 合成長圖

private struct HomeShareCompositeView: View {
    let config: HomeShareRenderConfig

    var body: some View {
        VStack(spacing: 0) {
            shareHeader
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            VStack(spacing: 16) {
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
            .padding(.bottom, 20)

            shareFooter
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(Color.mainBackground)
        .environment(\.homeAmountsHidden, config.hideAmounts)
        .preferredColorScheme(config.isDarkMode ? .dark : .light)
    }

    private var shareHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SnapvestBrandMark(
                    iconSize: 28,
                    wordmarkSize: 20,
                    spacing: 10,
                    layout: .horizontal
                )
                Text("投資組合分享")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
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
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [image]
        if let fileURL = Self.writeTemporaryPNG(image) {
            items.append(fileURL)
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    private static func writeTemporaryPNG(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Snapvest-share-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
