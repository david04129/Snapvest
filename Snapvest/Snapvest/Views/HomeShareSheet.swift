//
//  HomeShareSheet.swift
//  Snapvest
//
//  首頁圖表分享：勾選項目、合成長圖、儲存相簿或系統分享
//

import SwiftUI
import UIKit

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
    let twdPerBaseCurrency: Decimal

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var pieGroupingStore = PieChartGroupingStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKinds: Set<HomeShareChartKind> = []
    @State private var hasLoadedSharePreferences = false
    @State private var previewImage: UIImage?
    @State private var isRendering = false
    @State private var isUpdatingPreview = false
    @State private var previewFade: CGFloat = 1
    @State private var previewRenderGeneration = 0
    @State private var previewZoomResetToken = 0
    @State private var isSaving = false
    @State private var showActivitySheet = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var shareHideAmounts = false
    @State private var shareTrendMetricMode: TrendMetricMode
    @State private var shareTrendTimeRange: DateRangePreset
    @State private var shareTrendCustomStart: Date
    @State private var shareTrendCustomEnd: Date
    @State private var sharePieMode: PieChartDisplayMode
    @State private var sharePieIsGroupingEnabled: Bool
    @State private var sharePieShowsLegend = true
    @State private var sharePieShowsSliceLabels = true
    @State private var sharePerformanceMode: PerformanceDisplayMode
    @State private var activeShareCustomDateField: CustomDatePickerField?

    init(
        trendPoints: Binding<[TrendChartPoint]>,
        trendMetricMode: TrendMetricMode,
        trendTimeRange: DateRangePreset,
        trendCustomStart: Date,
        trendCustomEnd: Date,
        pieInputs: PieChartInputs?,
        pieMode: PieChartDisplayMode,
        totalAssets: Decimal,
        totalInvestments: Decimal,
        performanceMode: PerformanceDisplayMode,
        currency: Currency,
        twdPerBaseCurrency: Decimal
    ) {
        _trendPoints = trendPoints
        self.trendMetricMode = trendMetricMode
        self.trendTimeRange = trendTimeRange
        self.trendCustomStart = trendCustomStart
        self.trendCustomEnd = trendCustomEnd
        self.pieInputs = pieInputs
        self.pieMode = pieMode
        self.totalAssets = totalAssets
        self.totalInvestments = totalInvestments
        self.performanceMode = performanceMode
        self.currency = currency
        self.twdPerBaseCurrency = twdPerBaseCurrency
        _shareHideAmounts = State(initialValue: HomePrivacyManager.shared.isAmountHidden)
        _shareTrendMetricMode = State(initialValue: trendMetricMode)
        _shareTrendTimeRange = State(initialValue: trendTimeRange)
        _shareTrendCustomStart = State(initialValue: trendCustomStart)
        _shareTrendCustomEnd = State(initialValue: trendCustomEnd)
        _sharePieMode = State(initialValue: pieMode)
        _sharePieIsGroupingEnabled = State(initialValue: PieChartGroupingStore.shared.isGroupingEnabled)
        _sharePerformanceMode = State(initialValue: performanceMode)
    }

    private var baseConfig: HomeShareRenderConfig {
        HomeShareRenderConfig(
            hideAmounts: shareHideAmounts,
            isDarkMode: theme.isDarkMode,
            currency: currency,
            twdPerBaseCurrency: twdPerBaseCurrency,
            generatedAt: Date(),
            includeTrend: false,
            trendPoints: trendPoints,
            trendMetricMode: shareTrendMetricMode,
            trendTimeRange: shareTrendTimeRange,
            trendCustomStart: shareTrendCustomStart,
            trendCustomEnd: shareTrendCustomEnd,
            includePie: false,
            pieInputs: pieInputs,
            pieMode: sharePieMode,
            pieIsGroupingEnabled: sharePieIsGroupingEnabled,
            pieShowsLegend: sharePieShowsLegend,
            pieShowsSliceLabels: sharePieShowsSliceLabels,
            pieExpandedGroupIds: pieGroupingStore.expandedLegendGroupIds,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments,
            includePerformance: false,
            performanceMode: sharePerformanceMode
        )
    }

    private var renderConfig: HomeShareRenderConfig? {
        guard !selectedKinds.isEmpty else { return nil }
        return HomeShareRenderConfig(
            hideAmounts: shareHideAmounts,
            isDarkMode: theme.isDarkMode,
            currency: currency,
            twdPerBaseCurrency: twdPerBaseCurrency,
            generatedAt: Date(),
            includeTrend: selectedKinds.contains(.trend),
            trendPoints: trendPoints,
            trendMetricMode: shareTrendMetricMode,
            trendTimeRange: shareTrendTimeRange,
            trendCustomStart: shareTrendCustomStart,
            trendCustomEnd: shareTrendCustomEnd,
            includePie: selectedKinds.contains(.pie),
            pieInputs: pieInputs,
            pieMode: sharePieMode,
            pieIsGroupingEnabled: sharePieIsGroupingEnabled,
            pieShowsLegend: sharePieShowsLegend,
            pieShowsSliceLabels: sharePieShowsSliceLabels,
            pieExpandedGroupIds: pieGroupingStore.expandedLegendGroupIds,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments,
            includePerformance: selectedKinds.contains(.performance),
            performanceMode: sharePerformanceMode
        )
    }
    
    private var sharePieGroupingDisplayMode: PieChartGroupingDisplayMode {
        sharePieIsGroupingEnabled ? .grouped : .ungrouped
    }

    private var previewRefreshToken: String {
        [
            "selected=\(selectedKinds.map(\.rawValue).sorted().joined(separator: ","))",
            "hide=\(shareHideAmounts)",
            "trendMetric=\(shareTrendMetricMode.rawValue)",
            "trendRange=\(shareTrendTimeRange.rawValue)",
            "trendStart=\(shareTrendCustomStart.timeIntervalSince1970)",
            "trendEnd=\(shareTrendCustomEnd.timeIntervalSince1970)",
            "pieMode=\(sharePieMode.rawValue)",
            "pieGrouping=\(sharePieIsGroupingEnabled)",
            "pieLegend=\(sharePieShowsLegend)",
            "pieLabels=\(sharePieShowsSliceLabels)",
            "expanded=\(pieGroupingStore.expandedLegendGroupIds.sorted().joined(separator: ","))",
            "performance=\(sharePerformanceMode.rawValue)",
            "dark=\(theme.isDarkMode)",
            "points=\(trendPoints.count)"
        ].joined(separator: "|")
    }

    private static let settingsPanelMaxHeight: CGFloat = 240
    private static let panelCornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
            shareTopBar

            previewSection
                .homeSharePanelChrome(cornerRadius: Self.panelCornerRadius)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            chartSelectionPanel
                .homeSharePanelChrome(cornerRadius: Self.panelCornerRadius)
                .padding(.horizontal, 16)

            shareActionBar
                .padding(.horizontal, 16)
        }
        .safeAreaPadding(.top, 4)
        .safeAreaPadding(.bottom, 8)
        .background(Color.mainBackground.ignoresSafeArea())
        .onAppear {
            loadSharePreferencesIfNeeded()
            syncSelectionToAvailable()
            refreshPreview()
        }
        .onChange(of: selectedKinds) { _, newValue in
            HomeSharePreferences.saveSelectedKinds(newValue)
        }
        .onChange(of: previewRefreshToken) { _, _ in
            syncSelectionToAvailable()
            refreshPreview()
        }
        .sheet(isPresented: $showActivitySheet) {
            if let config = renderConfig {
                HomeShareActivityView(
                    image: HomeShareImageBuilder.render(config: config) ?? previewImage ?? UIImage(),
                    shareText: HomeShareMessageBuilder.shareText(config: config)
                ) {
                    showActivitySheet = false
                }
            }
        }
        .sheet(item: $activeShareCustomDateField) { field in
            WheelDatePickerSheet(
                title: field.title,
                selection: field == .start ? $shareTrendCustomStart : $shareTrendCustomEnd,
                earliestDate: earliestShareTrendDate,
                onDone: {
                    normalizeShareCustomRange()
                    activeShareCustomDateField = nil
                }
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var shareTopBar: some View {
        HStack {
            Spacer(minLength: 0)
            closeButton
        }
        .padding(.horizontal, 16)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondaryText)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .accessibilityLabel("關閉")
    }

    private var chartSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選擇要分享的圖表")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    privacyHint
                    chartSelectionList
                }
            }
            .frame(maxHeight: Self.settingsPanelMaxHeight)
        }
        .padding(12)
    }

    private var shareActionBar: some View {
        HStack(spacing: 10) {
            shareActionButton(
                title: "儲存到相簿",
                systemImage: "square.and.arrow.down",
                isPrimary: true,
                showsProgress: isSaving
            ) {
                saveToPhotoLibrary()
            }

            shareActionButton(
                title: "分享",
                systemImage: "square.and.arrow.up",
                isPrimary: false,
                showsProgress: false
            ) {
                openSystemShare()
            }
        }
    }

    private func shareActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        showsProgress: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsProgress {
                    ProgressView()
                        .tint(isPrimary ? .white : .appPrimary)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(isPrimary ? .white : (canUseImage ? .appPrimary : .secondaryText))
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isPrimary
                        ? (canUseImage ? Color.appPrimary : Color.secondaryText.opacity(0.35))
                        : Color.cardBackground
                )
        }
        .overlay {
            if !isPrimary {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(canUseImage ? Color.appPrimary.opacity(0.45) : Color.separator, lineWidth: 1)
            }
        }
        .disabled(!canUseImage || isSaving || isRendering)
    }

    private var chartSelectionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(HomeShareChartKind.allCases) { kind in
                let available = baseConfig.isAvailable(kind)
                VStack(spacing: 0) {
                    Button {
                        guard available else { return }
                        toggle(kind)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: kind.iconName)
                                .font(.system(size: 15))
                                .foregroundColor(available ? .appPrimary : .secondaryText)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(kind.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(available ? .primaryText : .secondaryText)
                                Text(available ? baseConfig.subtitle(for: kind) : "尚無資料")
                                    .font(.caption2)
                                    .foregroundColor(.secondaryText)
                            }

                            Spacer(minLength: 6)

                            Image(systemName: selectedKinds.contains(kind) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    available
                                        ? (selectedKinds.contains(kind) ? .appPrimary : .secondaryText)
                                        : .secondaryText.opacity(0.35)
                                )
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .disabled(!available)

                    if available, selectedKinds.contains(kind) {
                        Divider()
                            .padding(.horizontal, 10)

                        shareOptions(for: kind)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appPrimary.opacity(0.07))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.appPrimary.opacity(0.24), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if available, selectedKinds.contains(kind) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.appPrimary.opacity(0.32), lineWidth: 1)
                    }
                }
            }
        }
    }

    private var privacyHint: some View {
        Button {
            withAnimation(ChartMotion.switchQuick) {
                shareHideAmounts.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: shareHideAmounts ? "eye.slash" : "eye")
                    .foregroundColor(.appPrimary)
                Text(shareHideAmounts ? "分享圖將隱藏具體金額" : "分享圖將包含金額")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Spacer()
                Text(shareHideAmounts ? "已隱藏" : "顯示中")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appPrimary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func shareOptions(for kind: HomeShareChartKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch kind {
            case .trend:
                shareOptionLabel("指標")
                ChartSegmentedControl(
                    options: TrendMetricMode.allCases,
                    selection: $shareTrendMetricMode,
                    label: { $0.rawValue },
                    fontSize: 12
                )
                shareOptionLabel("時間")
                ChartSegmentedControl(
                    options: [.sevenDays, .oneMonth, .threeMonths, .oneYear, .all, .custom],
                    selection: $shareTrendTimeRange,
                    label: { $0.rawValue },
                    fontSize: 12
                )
                if shareTrendTimeRange == .custom {
                    shareCustomDateRangeControls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            case .pie:
                shareOptionLabel("圓餅圖")
                ChartSegmentedControl(
                    options: PieChartDisplayMode.allCases,
                    selection: $sharePieMode,
                    label: { $0.rawValue },
                    fontSize: 12
                )
                shareOptionLabel("顯示方式")
                HStack(spacing: 8) {
                    AssetsFilterChipButton(
                        title: sharePieGroupingDisplayMode.label,
                        icon: sharePieGroupingDisplayMode.chipIcon,
                        isActive: true
                    ) {
                        withAnimation(ChartMotion.switchQuick) {
                            sharePieIsGroupingEnabled.toggle()
                        }
                    }
                    AssetsFilterChipButton(
                        title: "清單",
                        icon: "list.bullet.rectangle",
                        isActive: sharePieShowsLegend
                    ) {
                        sharePieShowsLegend.toggle()
                    }
                    AssetsFilterChipButton(
                        title: "圖標",
                        icon: "tag.fill",
                        isActive: sharePieShowsSliceLabels
                    ) {
                        sharePieShowsSliceLabels.toggle()
                    }
                    Spacer(minLength: 0)
                }
            case .performance:
                shareOptionLabel("績效")
                ChartSegmentedControl(
                    options: PerformanceDisplayMode.allCases,
                    selection: $sharePerformanceMode,
                    label: { $0.rawValue },
                    fontSize: 12
                )
            }
        }
    }

    private func shareOptionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondaryText)
    }

    private var shareCustomDateRangeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            CustomDateRangeBar(
                startDate: shareTrendCustomStart,
                endDate: shareTrendCustomEnd,
                onStartTapped: { activeShareCustomDateField = .start },
                onEndTapped: { activeShareCustomDateField = .end }
            )
            
            Text("自訂區間會套用在這次分享圖，不會改變首頁走勢圖設定。")
                .font(.caption2)
                .foregroundColor(.tertiaryText)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("預覽")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primaryText)

            ZStack {
                Color.secondaryBackground.opacity(0.45)

                if let previewImage {
                    HomeShareZoomableImageView(image: previewImage)
                        .id(previewZoomResetToken)
                        .opacity(previewFade)
                        .animation(.easeInOut(duration: 0.28), value: previewFade)

                    if isUpdatingPreview {
                        Color.mainBackground.opacity(0.42)
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.appPrimary)
                    }
                } else if isRendering {
                    ProgressView("產生分享圖…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("請至少選擇一項有資料的圖表")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.28), value: isUpdatingPreview)
        }
        .padding(12)
    }

    private var canShare: Bool {
        guard let config = renderConfig else { return false }
        return config.selectedKinds.contains { config.isAvailable($0) }
    }

    private var canUseImage: Bool {
        canShare && previewImage != nil
    }
    
    private var earliestShareTrendDate: Date {
        trendPoints.map(\.date).min()
            ?? Calendar.current.date(byAdding: .day, value: -120, to: Date())
            ?? Date()
    }

    private func loadSharePreferencesIfNeeded() {
        guard !hasLoadedSharePreferences else { return }
        hasLoadedSharePreferences = true
        if let saved = HomeSharePreferences.loadSelectedKinds() {
            selectedKinds = saved
        } else {
            selectedKinds = [.trend, .pie, .performance]
        }
    }

    private func syncSelectionToAvailable() {
        let available = Set(HomeShareChartKind.allCases.filter { baseConfig.isAvailable($0) })
        selectedKinds = selectedKinds.intersection(available)
        if selectedKinds.isEmpty {
            selectedKinds = available
        }
        HomeSharePreferences.saveSelectedKinds(selectedKinds)
    }

    private func toggle(_ kind: HomeShareChartKind) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedKinds.contains(kind) {
                selectedKinds.remove(kind)
            } else {
                selectedKinds.insert(kind)
            }
            HomeSharePreferences.saveSelectedKinds(selectedKinds)
        }
    }
    
    private func normalizeShareCustomRange() {
        if shareTrendCustomStart > shareTrendCustomEnd {
            swap(&shareTrendCustomStart, &shareTrendCustomEnd)
        }
    }

    private func refreshPreview() {
        guard let config = renderConfig, canShare else {
            previewRenderGeneration += 1
            previewImage = nil
            previewZoomResetToken += 1
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

            let image = HomeShareImageBuilder.renderPreview(config: config)
            guard generation == previewRenderGeneration else { return }

            previewImage = image
            previewZoomResetToken += 1
            withAnimation(.easeInOut(duration: 0.3)) {
                previewFade = 1
            }
            isRendering = false
            isUpdatingPreview = false
        }
    }

    private func saveToPhotoLibrary() {
        guard let config = renderConfig else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            guard let exportImage = HomeShareImageBuilder.render(config: config) else {
                alertTitle = "無法儲存"
                alertMessage = "分享圖產生失敗，請稍後再試。"
                showAlert = true
                return
            }
            do {
                try await PhotoLibrarySaver.saveImage(exportImage)
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
        guard canUseImage else { return }
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

// MARK: - 面板外框

private struct HomeSharePanelChromeModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.separator.opacity(0.42), lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appPrimary)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
    }
}

private extension View {
    func homeSharePanelChrome(cornerRadius: CGFloat) -> some View {
        modifier(HomeSharePanelChromeModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 預覽縮放（雙指 pinch，與相簿看照片相同）

private struct HomeShareZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> HomeShareZoomScrollView {
        let scrollView = HomeShareZoomScrollView()
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = true
        scrollView.isMultipleTouchEnabled = true
        scrollView.pinchGestureRecognizer?.isEnabled = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        scrollView.onBoundsChange = { [weak coordinator = context.coordinator] size in
            coordinator?.updateImageLayout(for: size)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: HomeShareZoomScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: HomeShareZoomScrollView?
        weak var imageView: UIImageView?
        private var lastLayoutKey: String?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func updateImageLayout(for boundsSize: CGSize) {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            guard boundsSize.width > 0, boundsSize.height > 0,
                  image.size.width > 0, image.size.height > 0 else { return }

            let layoutKey = "\(Int(boundsSize.width))x\(Int(boundsSize.height))-\(Int(image.size.width))x\(Int(image.size.height))"
            guard layoutKey != lastLayoutKey else { return }
            lastLayoutKey = layoutKey

            imageView.transform = .identity
            imageView.frame = CGRect(origin: .zero, size: image.size)

            let widthScale = boundsSize.width / image.size.width
            let heightScale = boundsSize.height / image.size.height
            let minScale = min(widthScale, heightScale)

            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = max(minScale * 4, minScale + 0.01)
            scrollView.setZoomScale(minScale, animated: false)
            scrollView.contentOffset = .zero
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame

            frame.origin.x = frame.width < boundsSize.width
                ? (boundsSize.width - frame.width) / 2
                : 0
            frame.origin.y = frame.height < boundsSize.height
                ? (boundsSize.height - frame.height) / 2
                : 0

            imageView.frame = frame
        }
    }
}

private final class HomeShareZoomScrollView: UIScrollView {
    var onBoundsChange: ((CGSize) -> Void)?
    private var lastNotifiedBoundsSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 0, size.height > 0, size != lastNotifiedBoundsSize else { return }
        lastNotifiedBoundsSize = size
        onBoundsChange?(size)
    }
}
