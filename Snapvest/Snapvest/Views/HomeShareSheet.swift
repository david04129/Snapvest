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
        currency: Currency
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
                if let previewImage, let config = renderConfig {
                    HomeShareActivityView(
                        image: previewImage,
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
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            shareActionButton(
                title: "儲存到相簿",
                systemImage: "square.and.arrow.down",
                isPrimary: true,
                showsProgress: isSaving
            ) {
                saveToPhotoLibrary()
            }

            shareActionButton(
                title: "分享到其他 App",
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
            HStack(spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .tint(isPrimary ? .white : .appPrimary)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(isPrimary ? .white : (canUseImage ? .appPrimary : .secondaryText))
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isPrimary
                        ? (canUseImage ? Color.appPrimary : Color.secondaryText.opacity(0.35))
                        : Color.cardBackground
                )
        }
        .overlay {
            if !isPrimary {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(canUseImage ? Color.appPrimary.opacity(0.45) : Color.separator, lineWidth: 1)
            }
        }
        .disabled(!canUseImage || isSaving || isRendering)
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("選擇要分享的圖表")
                .font(.headline)
                .foregroundColor(.primaryText)

            ForEach(HomeShareChartKind.allCases) { kind in
                let available = baseConfig.isAvailable(kind)
                VStack(spacing: 8) {
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
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)

                    if available, selectedKinds.contains(kind) {
                        shareOptions(for: kind)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func shareOptions(for kind: HomeShareChartKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        title: "群組",
                        icon: "square.grid.2x2.fill",
                        isActive: sharePieIsGroupingEnabled
                    ) {
                        sharePieIsGroupingEnabled = true
                    }
                    AssetsFilterChipButton(
                        title: "明細",
                        icon: "list.bullet",
                        isActive: !sharePieIsGroupingEnabled
                    ) {
                        sharePieIsGroupingEnabled = false
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
        VStack(alignment: .leading, spacing: 8) {
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
                .font(.headline)
                .foregroundColor(.primaryText)

            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(
                            HomeShareImageBuilder.canvasWidth / HomeShareImageBuilder.canvasHeight,
                            contentMode: .fit
                        )
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
