//
//  HomeShareSheet.swift
//  Snapvest
//
//  首頁圖表分享：勾選項目、合成長圖、儲存相簿或系統分享
//

import SwiftUI

struct HomeShareSheet: View {
    @Binding var trendPoints: [TrendChartPoint]
    let trendMetricMode: TrendMetricMode
    let trendTimeRange: DateRangePreset
    let trendCustomStart: Date
    let trendCustomEnd: Date
    let pieInputs: PieChartInputs?
    let pieMode: PieChartDisplayMode
    let totalAssets: Decimal
    let totalInvestments: Decimal
    let performanceMode: PerformanceDisplayMode
    let currency: Currency

    @ObservedObject private var privacy = HomePrivacyManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKinds: Set<HomeShareChartKind> = [.trend, .pie, .performance]
    @State private var previewImage: UIImage?
    @State private var isRendering = false
    @State private var isUpdatingPreview = false
    @State private var previewFade: CGFloat = 1
    @State private var previewRenderGeneration = 0
    @State private var isSaving = false
    @State private var showActivitySheet = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var baseConfig: HomeShareRenderConfig {
        HomeShareRenderConfig(
            hideAmounts: privacy.isAmountHidden,
            isDarkMode: theme.isDarkMode,
            currency: currency,
            generatedAt: Date(),
            includeTrend: false,
            trendPoints: trendPoints,
            trendMetricMode: trendMetricMode,
            trendTimeRange: trendTimeRange,
            trendCustomStart: trendCustomStart,
            trendCustomEnd: trendCustomEnd,
            includePie: false,
            pieInputs: pieInputs,
            pieMode: pieMode,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments,
            includePerformance: false,
            performanceMode: performanceMode
        )
    }

    private var renderConfig: HomeShareRenderConfig? {
        guard !selectedKinds.isEmpty else { return nil }
        return HomeShareRenderConfig(
            hideAmounts: privacy.isAmountHidden,
            isDarkMode: theme.isDarkMode,
            currency: currency,
            generatedAt: Date(),
            includeTrend: selectedKinds.contains(.trend),
            trendPoints: trendPoints,
            trendMetricMode: trendMetricMode,
            trendTimeRange: trendTimeRange,
            trendCustomStart: trendCustomStart,
            trendCustomEnd: trendCustomEnd,
            includePie: selectedKinds.contains(.pie),
            pieInputs: pieInputs,
            pieMode: pieMode,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments,
            includePerformance: selectedKinds.contains(.performance),
            performanceMode: performanceMode
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        selectionSection
                        privacyHint
                        previewSection
                    }
                    .padding()
                }

                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .background(Color.mainBackground)
            }
            .background(Color.mainBackground)
            .navigationTitle("分享投資組合")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                syncSelectionToAvailable()
                refreshPreview()
            }
            .onChange(of: trendPoints.count) { _, _ in
                syncSelectionToAvailable()
                refreshPreview()
            }
            .onChange(of: selectedKinds) { _, _ in refreshPreview() }
            .onChange(of: privacy.isAmountHidden) { _, _ in refreshPreview() }
            .onChange(of: theme.isDarkMode) { _, _ in refreshPreview() }
            .sheet(isPresented: $showActivitySheet) {
                if let previewImage {
                    HomeShareActivityView(image: previewImage) {
                        showActivitySheet = false
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveToPhotoLibrary) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("儲存到相簿")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .background(canUseImage ? Color.appPrimary : Color.secondaryText.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(!canUseImage || isSaving || isRendering)

            Button(action: openSystemShare) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享到其他 App")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundColor(canUseImage ? .appPrimary : .secondaryText)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(canUseImage ? Color.appPrimary.opacity(0.45) : Color.separator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(!canUseImage || isSaving || isRendering)
        }
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("選擇要分享的圖表")
                .font(.headline)
                .foregroundColor(.primaryText)

            ForEach(HomeShareChartKind.allCases) { kind in
                let available = baseConfig.isAvailable(kind)
                Button {
                    guard available else { return }
                    toggle(kind)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.iconName)
                            .font(.system(size: 18))
                            .foregroundColor(available ? .appPrimary : .secondaryText)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(available ? .primaryText : .secondaryText)
                            Text(available ? baseConfig.subtitle(for: kind) : "尚無資料")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }

                        Spacer()

                        Image(systemName: selectedKinds.contains(kind) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(
                                available
                                    ? (selectedKinds.contains(kind) ? .appPrimary : .secondaryText)
                                    : .secondaryText.opacity(0.35)
                            )
                    }
                    .padding(14)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!available)
            }
        }
    }

    private var privacyHint: some View {
        HStack(spacing: 8) {
            Image(systemName: privacy.isAmountHidden ? "eye.slash" : "eye")
                .foregroundColor(.appPrimary)
            Text(privacy.isAmountHidden ? "目前為隱藏金額模式，分享圖將不含具體金額" : "目前為正常顯示，分享圖將包含金額")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("預覽")
                .font(.headline)
                .foregroundColor(.primaryText)

            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
                        .opacity(previewFade)

                    if isUpdatingPreview {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.mainBackground.opacity(0.42))
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.appPrimary)
                    }
                } else if isRendering {
                    ProgressView("產生分享圖…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    Text("請至少選擇一項有資料的圖表")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: isUpdatingPreview)
            .animation(.easeInOut(duration: 0.28), value: previewFade)
        }
    }

    private var canShare: Bool {
        guard let config = renderConfig else { return false }
        return config.selectedKinds.contains { config.isAvailable($0) }
    }

    private var canUseImage: Bool {
        canShare && previewImage != nil
    }

    private func syncSelectionToAvailable() {
        let available = Set(HomeShareChartKind.allCases.filter { baseConfig.isAvailable($0) })
        selectedKinds = selectedKinds.intersection(available)
        if selectedKinds.isEmpty {
            selectedKinds = available
        }
    }

    private func toggle(_ kind: HomeShareChartKind) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedKinds.contains(kind) {
                selectedKinds.remove(kind)
            } else {
                selectedKinds.insert(kind)
            }
        }
    }

    private func refreshPreview() {
        guard let config = renderConfig, canShare else {
            previewRenderGeneration += 1
            previewImage = nil
            isRendering = false
            isUpdatingPreview = false
            previewFade = 1
            return
        }

        previewRenderGeneration += 1
        let generation = previewRenderGeneration
        let hadPreview = previewImage != nil

        if hadPreview {
            isUpdatingPreview = true
        } else {
            isRendering = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard generation == previewRenderGeneration else { return }

            if hadPreview {
                withAnimation(.easeOut(duration: 0.16)) {
                    previewFade = 0.62
                }
            }

            await Task.yield()
            guard generation == previewRenderGeneration else { return }

            let image = HomeShareImageBuilder.render(config: config)
            guard generation == previewRenderGeneration else { return }

            previewImage = image
            withAnimation(.easeInOut(duration: 0.3)) {
                previewFade = 1
            }
            isRendering = false
            isUpdatingPreview = false
        }
    }

    private func saveToPhotoLibrary() {
        guard let previewImage else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await PhotoLibrarySaver.saveImage(previewImage)
                alertTitle = "已儲存"
                alertMessage = "分享圖已加入相簿。"
                showAlert = true
            } catch {
                alertTitle = "無法儲存"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func openSystemShare() {
        guard previewImage != nil else { return }
        showActivitySheet = true
    }
}

struct HomeShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.appPrimary.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("分享圖表")
    }
}
