//
//  ManualAssetValuationHistoryView.swift
//  Snapvest
//
//  其他資產現值紀錄（詳情預覽與完整列表，版型對齊帳戶交易紀錄）。
//

import SwiftUI

// MARK: - 列表列（交易紀錄同款卡片）

struct ManualAssetValuationHistoryListRowView: View {
    let entry: ManualAssetValuationHistoryEntry
    @Binding var isExpanded: Bool
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    private let accentColor = Color.manualAssetColor

    private var signedDeltaText: String {
        let absAmount = abs(entry.displayDelta)
        let formatted = absAmount.formatted(currency: entry.currency, showSymbol: false)
        if entry.displayDelta > 0 { return "+ \(formatted)" }
        if entry.displayDelta < 0 { return "- \(formatted)" }
        return formatted
    }

    private var deltaColor: Color {
        if entry.displayDelta > 0 { return .profitGreen }
        if entry.displayDelta < 0 { return .lossRed }
        return .secondaryText
    }

    private var hasExpandableNotes: Bool {
        entry.trimmedNotes != nil
    }

    var body: some View {
        Group {
            if hasExpandableNotes, let detail = entry.trimmedNotes {
                cardContent {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        detailSection(detail)
                    } label: {
                        rowHeader()
                    }
                    .tint(.secondaryText)
                }
            } else {
                cardContent {
                    rowHeader()
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete, !entry.isCreation {
                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("刪除")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.actionForeground)
                    .frame(width: 70, height: 70)
                    .background(AppColors.actionDestructiveBackground)
                }
                .tint(AppColors.actionDestructiveBackground)
            }

            Button(action: onEdit) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                    Text("編輯")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppColors.actionForeground)
                .frame(width: 70, height: 70)
                .background(AppColors.actionEditBackground)
            }
            .tint(AppColors.actionEditBackground)
        }
    }

    @ViewBuilder
    private func cardContent<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
                    .frame(width: 4)
            }
            .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }

    private func rowHeader() -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)

                if !hasExpandableNotes, let notes = entry.trimmedNotes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(signedDeltaText)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(deltaColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("現值 \(entry.valueAtRecord.formatted(currency: entry.currency, showSymbol: false))")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .contentShape(Rectangle())
    }

    private func detailSection(_ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("明細")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
            Text(detail)
                .font(.caption)
                .foregroundColor(.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 詳情預覽用精簡列

struct ManualAssetValuationHistoryRowView: View {
    let entry: ManualAssetValuationHistoryEntry
    var showsChevron: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            ManualAssetValuationHistoryListRowView(
                entry: entry,
                isExpanded: .constant(false),
                onEdit: { onTap?() },
                onDelete: nil
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .allowsHitTesting(onTap != nil)
    }
}

// MARK: - 完整列表

struct ManualAssetValuationHistoryView: View {
    let asset: ManualAsset
    @ObservedObject var viewModel: ManualAssetsViewModel
    let onAssetUpdated: (ManualAsset) -> Void

    @State private var entries: [ManualAssetValuationHistoryEntry] = []
    @State private var displayAsset: ManualAsset
    @State private var isLoading = true
    @State private var expandedEntryId: String?
    @State private var entryPendingDelete: ManualAssetValuationHistoryEntry?
    @State private var showDeleteConfirmation = false
    @State private var deleteErrorMessage: String?
    @State private var showDeleteError = false
    @State private var editingEntry: ManualAssetValuationHistoryEntry?

    private let accentColor = Color.manualAssetColor

    private struct ValuationDayGroup: Identifiable {
        let day: Date
        let entries: [ManualAssetValuationHistoryEntry]
        var id: Date { day }
    }

    private var dayGroups: [ValuationDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            ValuationDayGroup(
                day: day,
                entries: grouped[day]!.sorted { $0.date > $1.date }
            )
        }
    }

    init(
        asset: ManualAsset,
        viewModel: ManualAssetsViewModel,
        onAssetUpdated: @escaping (ManualAsset) -> Void
    ) {
        self.asset = asset
        self.viewModel = viewModel
        self.onAssetUpdated = onAssetUpdated
        _displayAsset = State(initialValue: asset)
    }

    var body: some View {
        Group {
            if isLoading && entries.isEmpty {
                loadingView
            } else if entries.isEmpty {
                emptyStateView
            } else {
                valuationsListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.mainBackground)
        .navigationTitle("現值紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
        .task { await reload() }
        .alert("刪除現值紀錄？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { entryPendingDelete = nil }
            Button("刪除", role: .destructive) {
                guard let entry = entryPendingDelete else { return }
                entryPendingDelete = nil
                Task { await performDelete(entry) }
            }
        } message: {
            Text("刪除後會依最新一筆紀錄更新目前現值。")
        }
        .alert("無法刪除", isPresented: $showDeleteError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "請稍後再試")
        }
        .sheet(item: $editingEntry) { entry in
            if entry.isCreation {
                ManualAssetFormView(
                    viewModel: viewModel,
                    mode: .edit(asset: displayAsset, syncCreationValuation: true),
                    chrome: .sheet,
                    onCancel: { editingEntry = nil },
                    onSaved: {
                        editingEntry = nil
                        Task { await reload() }
                    }
                )
            } else {
                ManualAssetUpdateValueView(
                    asset: displayAsset,
                    viewModel: viewModel,
                    editingValuation: entry.valuation
                ) { updated in
                    displayAsset = updated
                    onAssetUpdated(updated)
                    editingEntry = nil
                    Task { await reload() }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入中...")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.secondaryText)
            Text("尚無現值紀錄")
                .font(.headline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var assetSummaryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayAsset.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                Text(displayAsset.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer(minLength: 8)
            Text("\(entries.count) 筆")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: AppColors.shadowMedium, radius: 6, x: 0, y: 2)
    }

    private var valuationsListView: some View {
        List {
            Section {
                assetSummaryHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(dayGroups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        ManualAssetValuationHistoryListRowView(
                            entry: entry,
                            isExpanded: expansionBinding(for: entry),
                            onEdit: { editingEntry = entry },
                            onDelete: entry.isCreation ? nil : {
                                entryPendingDelete = entry
                                showDeleteConfirmation = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    TransactionDateSectionHeader(date: group.day, count: group.entries.count)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.mainBackground)
    }

    private func expansionBinding(for entry: ManualAssetValuationHistoryEntry) -> Binding<Bool> {
        Binding(
            get: { expandedEntryId == entry.id },
            set: { isExpanded in
                expandedEntryId = isExpanded ? entry.id : nil
            }
        )
    }

    @MainActor
    private func reload() async {
        isLoading = true
        defer { isLoading = false }

        let valuations = await viewModel.loadValuations(assetId: displayAsset.id)
        entries = ManualAssetValuationHistoryBuilder.entries(from: valuations)

        if let refreshed = viewModel.assets.first(where: { $0.id == displayAsset.id }) {
            displayAsset = refreshed
            onAssetUpdated(refreshed)
        }
    }

    @MainActor
    private func performDelete(_ entry: ManualAssetValuationHistoryEntry) async {
        let succeeded = await viewModel.deleteManualAssetValuation(
            asset: displayAsset,
            valuation: entry.valuation
        )
        if succeeded {
            await reload()
        } else {
            deleteErrorMessage = viewModel.errorMessage
            showDeleteError = true
        }
    }
}

// MARK: - 詳情預覽區塊（方案 A）

struct ManualAssetValuationHistoryPreviewSection: View {
    let asset: ManualAsset
    let entries: [ManualAssetValuationHistoryEntry]
    let isLoading: Bool
    let onViewAll: () -> Void
    let onSelectEntry: (ManualAssetValuationHistoryEntry) -> Void

    private static let previewLimit = 4
    private let accentColor = Color.manualAssetColor

    private var previewEntries: [ManualAssetValuationHistoryEntry] {
        Array(entries.prefix(Self.previewLimit))
    }

    var body: some View {
        AccountSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("現值紀錄")
                        .font(.headline)
                        .foregroundColor(.primaryText)

                    Spacer(minLength: 8)

                    if !entries.isEmpty {
                        Text("共 \(entries.count) 筆")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondaryText)
                    }
                }

                if isLoading && entries.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("載入中…")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if entries.isEmpty {
                    Text("尚無現值紀錄。點下方「更新現值」後會顯示歷程。")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 10) {
                        ForEach(previewEntries) { entry in
                            Button {
                                onSelectEntry(entry)
                            } label: {
                                ManualAssetValuationHistoryListRowView(
                                    entry: entry,
                                    isExpanded: .constant(false),
                                    onEdit: { onSelectEntry(entry) },
                                    onDelete: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if entries.count > Self.previewLimit {
                        viewAllButton(title: "查看全部 \(entries.count) 筆")
                    } else if entries.count > 1 {
                        viewAllButton(title: "查看完整列表")
                    }
                }
            }
        }
    }

    private func viewAllButton(title: String) -> some View {
        Button(action: onViewAll) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
