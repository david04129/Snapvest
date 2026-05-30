//
//  PortfolioAllocationChartView.swift
//  Snapvest
//
//  首頁圓餅圖：總資產 / 投資組合 / 所有細項
//

import SwiftUI
import Charts

// MARK: - 圓餅圖數據項
struct PieChartDataItem: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let marketValue: Decimal
    let color: Color
    
    init(symbol: String, name: String, marketValue: Decimal, color: Color) {
        self.id = symbol
        self.symbol = symbol
        self.name = name
        self.marketValue = marketValue
        self.color = color
    }

    var value: Double {
        NSDecimalNumber(decimal: marketValue).doubleValue
    }
}

enum PieChartDisplayMode: String, CaseIterable, Identifiable {
    case totalAssets = "總資產"
    case portfolio = "投資組合"
    case allDetails = "所有細項"
    
    var id: String { rawValue }
}

enum PortfolioPieChartBuilder {
    /// 總資產：五大類
    static func totalAssetsItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        let rate = inputs.usdToTwdRate
        var tw: Decimal = 0, us: Decimal = 0, crypto: Decimal = 0
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)
        for h in inputs.aggregatedHoldings {
            guard let mv = HoldingChartMetrics.marketValueTWD(holding: h, priceMap: priceMap, rate: rate) else { continue }
            switch h.assetType {
            case .stockTW: tw += mv
            case .stockUS: us += mv
            case .crypto: crypto += mv
            case .cash: break
            }
        }
        let investmentSegments: [(String, String, Decimal)] = [
            ("stock_us", "美股", us),
            ("stock_tw", "台股", tw),
            ("crypto", "加密貨幣", crypto),
            ("manual_assets", "其他資產", inputs.totalManualAssetsTWD)
        ]
        let investmentItems = investmentSegments.filter { $0.2 > 0 }.map {
            PieChartDataItem(
                symbol: $0.0,
                name: $0.1,
                marketValue: $0.2,
                color: HoldingChartMetrics.chartColor(forItemId: $0.0, inputs: inputs)
            )
        }
        return cashItems(inputs: inputs) + investmentItems
    }

    /// 投資組合：各檔持股（不含現金）
    static func portfolioItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        holdingItems(inputs: inputs, includeCash: false, includeManualAssets: true, onlyInvestmentManualAssets: true)
    }
    
    /// 所有細項：現金 + 各檔持股
    static func allDetailsItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        holdingItems(inputs: inputs, includeCash: true, includeManualAssets: true, onlyInvestmentManualAssets: false)
    }
    
    static func denominator(mode: PieChartDisplayMode, inputs: PieChartInputs, totalAssets: Decimal, totalInvestments: Decimal) -> Decimal {
        let itemSum = sumOfItems(mode: mode, inputs: inputs)
        if itemSum > 0 {
            return itemSum
        }
        switch mode {
        case .totalAssets, .allDetails:
            return totalAssets
        case .portfolio:
            return totalInvestments
        }
    }
    
    static func items(
        mode: PieChartDisplayMode,
        inputs: PieChartInputs
    ) -> [PieChartDataItem] {
        switch mode {
        case .totalAssets: return totalAssetsItems(inputs: inputs)
        case .portfolio: return portfolioItems(inputs: inputs)
        case .allDetails: return allDetailsItems(inputs: inputs)
        }
    }
    
    private static func sumOfItems(mode: PieChartDisplayMode, inputs: PieChartInputs) -> Decimal {
        items(mode: mode, inputs: inputs).reduce(0) { $0 + $1.marketValue }
    }
    
    private static func cashItems(inputs: PieChartInputs) -> [PieChartDataItem] {
        Currency.baseCurrencyOptions.compactMap { currency in
            guard let amount = inputs.cashByCurrency[currency],
                  amount > 0,
                  let marketValue = inputs.cashValueInTWD(currency: currency, amount: amount),
                  marketValue > 0 else {
                return nil
            }
            let itemId = PieChartGroupingEngine.cashItemId(for: currency)
            return PieChartDataItem(
                symbol: itemId,
                name: cashDisplayName(for: currency),
                marketValue: marketValue,
                color: HoldingChartMetrics.chartColor(forItemId: itemId, inputs: inputs)
            )
        }
    }
    private static func cashDisplayName(for currency: Currency) -> String {
        switch currency {
        case .TWD: return "台幣"
        case .USD: return "美金"
        default: return currency.displayName
        }
    }
    private static func holdingItems(
        inputs: PieChartInputs,
        includeCash: Bool,
        includeManualAssets: Bool = false,
        onlyInvestmentManualAssets: Bool = false
    ) -> [PieChartDataItem] {
        let rate = inputs.usdToTwdRate
        var result: [PieChartDataItem] = []
        if includeCash {
            result.append(contentsOf: cashItems(inputs: inputs))
        }
        let priceMap = HoldingChartMetrics.priceMap(from: inputs.assetPriceSnapshots)
        var stockRows: [(AggregatedHoldingSnapshot, Decimal)] = []
        for h in inputs.aggregatedHoldings {
            guard h.assetType != .cash,
                  let mv = HoldingChartMetrics.marketValueTWD(holding: h, priceMap: priceMap, rate: rate) else { continue }
            stockRows.append((h, mv))
        }
        stockRows.sort { $0.1 > $1.1 }
        for row in stockRows {
            let h = row.0
            let displayName: String
            if h.assetType == .stockTW {
                displayName = SymbolListService.displayName(
                    assetType: h.assetType,
                    symbol: h.symbol,
                    storedName: h.name
                )
            } else {
                displayName = h.symbol
            }
            let itemId = "\(h.assetType.rawValue)_\(h.symbol)"
            result.append(PieChartDataItem(
                symbol: itemId,
                name: displayName,
                marketValue: row.1,
                color: HoldingChartMetrics.colorForHolding(h, inputs: inputs)
            ))
        }
        guard includeManualAssets else { return result }

        let manualAssets = onlyInvestmentManualAssets
            ? inputs.investmentManualAssets
            : inputs.includedManualAssets
        let manualRows = manualAssets.compactMap { asset -> (ManualAsset, Decimal)? in
            guard let valueTWD = ManualAssetMetrics.valueTWD(asset: asset, rates: inputs.twdRateByCurrency),
                  valueTWD > 0 else { return nil }
            return (asset, valueTWD)
        }
        .sorted { $0.1 > $1.1 }
        for row in manualRows {
            let itemId = ManualAssetMetrics.itemId(for: row.0)
            result.append(PieChartDataItem(
                symbol: itemId,
                name: row.0.name,
                marketValue: row.1,
                color: HoldingChartMetrics.chartColor(forItemId: itemId, inputs: inputs)
            ))
        }
        return result
    }
}

// MARK: - 首頁圓餅圖區塊
struct HomePieChartSection: View {
    let inputs: PieChartInputs?
    let totalAssets: Decimal
    let totalInvestments: Decimal
    let currency: Currency
    let twdPerBaseCurrency: Decimal
    
    @Binding var mode: PieChartDisplayMode
    @ObservedObject var groupingStore: PieChartGroupingStore
    @State private var selectedId: String?
    @State private var selectedMemberIds: Set<String> = []
    @State private var renamingGroupId: UUID?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var pendingDissolveGroupId: UUID?
    @State private var showDissolveGroupAlert = false
    @State private var isGroupingTransitioning = false
    @State private var groupingToggleUnlockTask: Task<Void, Never>?
    /// 每次群組化切換後遞增，強制 Chart 乾淨重建（避免 morph 崩潰）
    @State private var pieChartRevision = 0
    /// 方案 C：點群組標題 ＋ 後，勾選群組外個股再「加入」
    @State private var addToGroupId: UUID?
    @State private var selectionEditCategory: PieChartGroupEditCategory?
    private var supportsGrouping: Bool {
        PieChartGroupingModeSupport.supportsGroupingUI(mode: mode)
    }

    private var isEditingGroups: Bool {
        groupingStore.isEditingGroups
    }
    
    private var baseItems: [PieChartDataItem] {
        guard let inputs else { return [] }
        return PieChartGroupingModeSupport.effectiveBaseItems(
            mode: mode,
            inputs: inputs,
            isGroupingEnabled: isGroupingEnabled
        )
    }
    
    /// 持久化清理用：所有細項粒度下可群組的 id
    private var allValidGroupableIds: Set<String> {
        guard let inputs else { return [] }
        return Set(
            PortfolioPieChartBuilder.allDetailsItems(inputs: inputs)
                .filter { PieChartGroupableItem.isGroupable(itemId: $0.id, mode: .allDetails) }
                .map(\.id)
        )
    }

    /// 目前分頁編輯時可勾選的 id
    private var editableGroupableIds: Set<String> {
        guard let inputs else { return [] }
        return Set(
            PortfolioPieChartBuilder.items(mode: mode, inputs: inputs)
                .filter { PieChartGroupableItem.isGroupable(itemId: $0.id, mode: mode) }
                .map(\.id)
        )
    }
    
    private var activeGroups: [PieChartItemGroup] {
        groupingStore.groups
    }
    
    private var isGroupingEnabled: Bool {
        groupingStore.isGroupingEnabled
    }
    
    private var displayItems: [PieChartDataItem] {
        PieChartGroupingEngine.applyGroups(
            baseItems: baseItems,
            groups: activeGroups,
            mode: mode,
            isGroupingEnabled: isGroupingEnabled
        )
    }
    
    private var legendRows: [PieChartLegendRow] {
        PieChartGroupingEngine.legendRows(
            baseItems: baseItems,
            displayItems: displayItems,
            groups: activeGroups,
            mode: mode,
            isGroupingEnabled: isGroupingEnabled
        )
    }
    
    private var denominator: Decimal {
        guard let inputs else { return totalAssets }
        return PortfolioPieChartBuilder.denominator(
            mode: mode,
            inputs: inputs,
            totalAssets: totalAssets,
            totalInvestments: totalInvestments
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pieChartHeader
            
            ChartSegmentedControl(
                options: PieChartDisplayMode.allCases,
                selection: $mode,
                label: { $0.rawValue },
                fontSize: 12,
                isInteractionEnabled: !isEditingGroups
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onChange(of: mode) { _, _ in
                guard !isEditingGroups else { return }
                addToGroupId = nil
                selectionEditCategory = nil
                selectedMemberIds.removeAll()
                pickLargest()
            }
            
            if displayItems.isEmpty {
                Text("尚無可顯示的資料")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                Group {
                    PortfolioDonutChart(
                        data: displayItems,
                        denominator: denominator,
                        selectedId: $selectedId,
                        displayMode: mode,
                        displayCurrency: currency,
                        twdPerDisplayCurrency: twdPerBaseCurrency,
                        isGroupingEnabled: isGroupingEnabled,
                        allowsSelection: !isGroupingTransitioning && !isEditingGroups
                    )
                    .id("pie-\(pieChartRevision)-\(isGroupingEnabled)")
                    .opacity(isGroupingTransitioning ? 0.88 : 1)
                    .animation(ChartMotion.switchQuick, value: isGroupingTransitioning)
                    .padding(.vertical, 4)
                    
                    if isGroupingEnabled {
                        pieGroupingToolbar
                    }
                    
                    PortfolioGroupedAllocationLegend(
                        rows: legendRows,
                        displayMode: mode,
                        denominator: denominator,
                        displayCurrency: currency,
                        twdPerDisplayCurrency: twdPerBaseCurrency,
                        selectedId: $selectedId,
                        isGroupingEnabled: isGroupingEnabled,
                        isEditingGroups: isEditingGroups,
                        selectedMemberIds: $selectedMemberIds,
                        expandedGroupIds: Binding(
                            get: { groupingStore.expandedLegendGroupIds },
                            set: { groupingStore.setExpandedLegendGroupIds($0) }
                        ),
                        addToGroupId: $addToGroupId,
                        selectionEditCategory: $selectionEditCategory,
                        onRenameGroup: beginRename,
                        onRequestDissolveGroup: requestDissolveGroup,
                        onRemoveMember: removeMemberFromGroup,
                        onToggleAddToGroup: toggleAddToGroup,
                        onToggleMemberSelection: toggleMemberSelection,
                        suppressLayoutAnimation: isGroupingTransitioning
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .allowsHitTesting(!isGroupingTransitioning)
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColors.shadowMedium, radius: 8, x: 0, y: 2)
        .onAppear {
            refreshGroupingState()
            syncSelectionAfterDisplayChange()
        }
        .onChange(of: inputs?.aggregatedHoldings.count) { _, _ in
            refreshGroupingState()
            syncSelectionAfterDisplayChange()
        }
        .onChange(of: mode) { _, _ in
            refreshGroupingState()
            syncSelectionAfterDisplayChange()
        }
        .onDisappear {
            groupingToggleUnlockTask?.cancel()
            groupingStore.setEditingGroups(false)
        }
        .alert("編輯群組名稱", isPresented: $showRenameAlert) {
            TextField("群組名稱", text: $renameText)
            Button("取消", role: .cancel) {
                renamingGroupId = nil
            }
            Button("儲存") {
                saveRename()
            }
        }
        .alert("解除群組？", isPresented: $showDissolveGroupAlert) {
            Button("取消", role: .cancel) {
                pendingDissolveGroupId = nil
            }
            Button("解除群組", role: .destructive) {
                confirmDissolveGroup()
            }
        } message: {
            if let pendingDissolveGroupId,
               let group = activeGroups.first(where: { $0.id == pendingDissolveGroupId }) {
                Text("「\(group.name)」將解散，其中的項目會恢復為未分組。")
            }
        }
    }
    
    private var pieGroupingToolbar: some View {
        VStack(alignment: .trailing, spacing: 8) {
            AssetsFilterChipButton(
                title: isEditingGroups ? "結束編輯" : "編輯群組",
                icon: isEditingGroups ? "checkmark" : "square.and.pencil",
                isActive: true
            ) {
                withAnimation(ChartMotion.switchSpring) {
                    let entering = !isEditingGroups
                    groupingStore.setEditingGroups(entering)
                    if entering {
                        expandAllGroups()
                        selectedMemberIds.removeAll()
                        addToGroupId = nil
                        selectionEditCategory = nil
                    } else {
                        selectedMemberIds.removeAll()
                        addToGroupId = nil
                        selectionEditCategory = nil
                    }
                }
            }
            
            if isEditingGroups {
                groupSelectionActionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var groupEditStatusHint: String {
        if mode == .totalAssets {
            if let addToGroupId,
               let group = activeGroups.first(where: { $0.id == addToGroupId }) {
                return "已選定「\(group.name)」· 勾選台幣或美金後按加入"
            }
            return "總資產僅可群組現金；勾選台幣與美金後按組合"
        }
        if let addToGroupId,
           let group = activeGroups.first(where: { $0.id == addToGroupId }) {
            let section = PieChartGroupableItem.editCategory(for: group)?.sectionTitle ?? ""
            return "已選定「\(group.name)」· 在\(section)勾選要加入的項目"
        }
        if let selectionEditCategory {
            return "正在編輯\(selectionEditCategory.sectionTitle)：勾選 2 項以上可組合，或點 ＋ 加入群組"
        }
        return "現金類與投資類分開群組；請在任一區塊勾選或點 ＋"
    }
    
    private var groupSelectionActionBar: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(groupEditStatusHint)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            HStack(spacing: 8) {
                Text("已選 \(selectedMemberIds.count) 項")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                
                if let addToGroupId {
                    let canAdd = !selectedMemberIds.isEmpty
                    AssetsFilterChipButton(
                        title: "加入",
                        icon: "plus",
                        isActive: canAdd
                    ) {
                        addSelectedMembers(to: addToGroupId)
                    }
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.45)
                } else {
                    let canCombine = selectedMemberIds.count >= 2
                    AssetsFilterChipButton(
                        title: "組合",
                        icon: "square.stack.3d.up.fill",
                        isActive: canCombine
                    ) {
                        createGroupFromSelection()
                    }
                    .disabled(!canCombine)
                    .opacity(canCombine ? 1 : 0.45)
                }
            }
        }
    }
    
    private func refreshGroupingState() {
        guard supportsGrouping else { return }
        groupingStore.sanitize(validGroupableIds: allValidGroupableIds)
        let groupedIds = Set(activeGroups.flatMap(\.memberItemIds))
        selectedMemberIds = selectedMemberIds
            .intersection(editableGroupableIds.subtracting(groupedIds))
        if let selectionEditCategory {
            selectedMemberIds = Set(
                selectedMemberIds.filter { selectionEditCategory.contains(itemId: $0) }
            )
            if selectedMemberIds.isEmpty {
                self.selectionEditCategory = nil
            }
        }
        if let addToGroupId,
           let group = activeGroups.first(where: { $0.id == addToGroupId }),
           let groupCategory = PieChartGroupableItem.editCategory(for: group),
           selectionEditCategory != groupCategory {
            self.addToGroupId = nil
        }
        pruneExpandedGroups()
    }

    private func toggleMemberSelection(_ itemId: String) {
        guard let itemCategory = PieChartGroupableItem.editCategory(forItemId: itemId) else { return }
        if let addToGroupId,
           let group = activeGroups.first(where: { $0.id == addToGroupId }),
           let groupCategory = PieChartGroupableItem.editCategory(for: group),
           groupCategory != itemCategory {
            return
        }
        if let locked = selectionEditCategory, locked != itemCategory {
            return
        }

        if selectedMemberIds.contains(itemId) {
            selectedMemberIds.remove(itemId)
            if selectedMemberIds.isEmpty {
                selectionEditCategory = nil
            }
        } else {
            if selectedMemberIds.isEmpty {
                selectionEditCategory = itemCategory
            }
            selectedMemberIds.insert(itemId)
        }
    }
    
    /// 群組化 chip：先鎖定 → 延後換資料 → 重建 Chart，避免 Swift Charts morph 崩潰
    private func requestGroupingDisplayModeToggle() {
        guard !isGroupingTransitioning else { return }
        isGroupingTransitioning = true
        groupingToggleUnlockTask?.cancel()
        
        groupingToggleUnlockTask = Task { @MainActor in
            try? await Task.sleep(for: ChartMotion.groupingToggleLeadIn)
            guard !Task.isCancelled else { return }
            
            groupingStore.toggleDisplayMode()
            if !isGroupingEnabled {
                groupingStore.setEditingGroups(false)
                selectedMemberIds.removeAll()
                groupingStore.clearExpandedLegendGroups()
                addToGroupId = nil
                selectionEditCategory = nil
            }
            pieChartRevision += 1
            syncSelectionAfterDisplayChange()
            
            try? await Task.sleep(for: ChartMotion.groupingToggleCooldown)
            guard !Task.isCancelled else { return }
            isGroupingTransitioning = false
        }
    }
    
    private func syncSelectionAfterDisplayChange() {
        let items = displayItems
        guard !items.isEmpty else {
            selectedId = nil
            return
        }
        if let selectedId, items.contains(where: { $0.id == selectedId }) {
            return
        }
        selectedId = items.max(by: { $0.value < $1.value })?.id
    }
    
    private func expandAllGroups() {
        groupingStore.expandAllLegendGroups(groupIds: activeGroups.map(\.id))
    }
    
    private func pruneExpandedGroups() {
        let valid = Set(activeGroups.map { PieChartGroupingEngine.groupSliceId($0.id) })
        groupingStore.pruneExpandedLegendGroups(validSliceIds: valid)
    }
    
    private func pickLargest() {
        syncSelectionAfterDisplayChange()
    }

    private func createGroupFromSelection() {
        let groupedIds = Set(activeGroups.flatMap(\.memberItemIds))
        let members = baseItems.filter {
            selectedMemberIds.contains($0.id) && !groupedIds.contains($0.id)
        }
        guard members.count >= 2,
              let category = selectionEditCategory
                ?? members.compactMap({ PieChartGroupableItem.editCategory(forItemId: $0.id) }).first
        else { return }
        let memberIds = members.map(\.id).filter { category.contains(itemId: $0) }
        guard memberIds.count >= 2 else { return }
        let group = PieChartItemGroup(
            id: UUID(),
            name: PieChartGroupingEngine.nextSequentialGroupName(
                existingGroups: activeGroups,
                category: category
            ),
            memberItemIds: memberIds.sorted()
        )
        var updated = activeGroups
        updated.append(group)
        groupingStore.updateGroups(updated)
        selectedMemberIds.removeAll()
        addToGroupId = nil
        selectionEditCategory = nil
        selectedId = PieChartGroupingEngine.groupSliceId(group.id)
        expandAllGroups()
        refreshGroupingState()
    }
    
    private func toggleAddToGroup(_ groupId: UUID) {
        guard let group = activeGroups.first(where: { $0.id == groupId }),
              let groupCategory = PieChartGroupableItem.editCategory(for: group) else { return }
        withAnimation(ChartMotion.switchSpring) {
            if addToGroupId == groupId {
                addToGroupId = nil
                if selectedMemberIds.isEmpty {
                    selectionEditCategory = nil
                }
            } else {
                addToGroupId = groupId
                selectionEditCategory = groupCategory
                selectedMemberIds = Set(
                    selectedMemberIds.filter { groupCategory.contains(itemId: $0) }
                )
                groupingStore.insertExpandedLegendGroup(
                    sliceId: PieChartGroupingEngine.groupSliceId(groupId)
                )
            }
        }
    }
    
    private func addSelectedMembers(to groupId: UUID) {
        guard let group = activeGroups.first(where: { $0.id == groupId }),
              let groupCategory = PieChartGroupableItem.editCategory(for: group) else { return }
        let groupedIds = Set(activeGroups.flatMap(\.memberItemIds))
        let toAdd = selectedMemberIds.filter {
            groupCategory.contains(itemId: $0)
                && allValidGroupableIds.contains($0)
                && !groupedIds.contains($0)
        }
        guard !toAdd.isEmpty else { return }
        var groups = activeGroups
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        var memberIds = Set(groups[index].memberItemIds)
        toAdd.forEach { memberIds.insert($0) }
        groups[index].memberItemIds = memberIds.sorted()
        withAnimation(ChartMotion.pieMorphSpring) {
            groupingStore.updateGroups(groups)
            selectedMemberIds.removeAll()
            addToGroupId = nil
            selectionEditCategory = nil
            refreshGroupingState()
            selectedId = PieChartGroupingEngine.groupSliceId(groupId)
            expandAllGroups()
        }
    }
    
    private func beginRename(_ groupId: UUID) {
        guard let group = activeGroups.first(where: { $0.id == groupId }) else { return }
        renamingGroupId = groupId
        renameText = group.name
        showRenameAlert = true
    }
    
    private func saveRename() {
        guard let groupId = renamingGroupId else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var groups = activeGroups
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].name = trimmed
        groupingStore.updateGroups(groups)
        renamingGroupId = nil
    }
    
    private func requestDissolveGroup(_ groupId: UUID) {
        pendingDissolveGroupId = groupId
        showDissolveGroupAlert = true
    }
    
    private func confirmDissolveGroup() {
        guard let groupId = pendingDissolveGroupId else { return }
        pendingDissolveGroupId = nil
        dissolveGroup(groupId)
    }
    
    private func dissolveGroup(_ groupId: UUID) {
        var groups = activeGroups
        groups.removeAll { $0.id == groupId }
        groupingStore.updateGroups(groups)
        groupingStore.removeExpandedLegendGroup(
            sliceId: PieChartGroupingEngine.groupSliceId(groupId)
        )
        if addToGroupId == groupId {
            addToGroupId = nil
            if selectedMemberIds.isEmpty {
                selectionEditCategory = nil
            }
        }
        pickLargest()
    }
    
    private func removeMemberFromGroup(groupId: UUID, memberId: String) {
        var groups = activeGroups
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].memberItemIds.removeAll { $0 == memberId }
        if groups[index].memberItemIds.count <= 1 {
            groups.remove(at: index)
        }
        groupingStore.updateGroups(groups)
        refreshGroupingState()
        pickLargest()
    }
    
    private var pieChartHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("圓餅圖")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primaryText)
                Text(" · ")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText)
                Text(mode.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.appPrimary)
                CurrencyCodeChip(currency: currency)
            }
            Spacer(minLength: 8)
            if supportsGrouping {
                AssetsFilterChipButton(
                    title: groupingStore.displayMode.label,
                    icon: groupingStore.displayMode.chipIcon,
                    isActive: true
                ) {
                    requestGroupingDisplayModeToggle()
                }
                .disabled(isGroupingTransitioning || isEditingGroups)
                .opacity(isGroupingTransitioning || isEditingGroups ? 0.45 : 1)
                .animation(ChartMotion.switchQuick, value: isGroupingTransitioning)
                .animation(ChartMotion.switchQuick, value: isEditingGroups)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .animation(ChartMotion.switchSpring, value: mode)
        .animation(ChartMotion.switchSpring, value: isEditingGroups)
    }
}

// MARK: - 細環甜甜圈
struct PortfolioDonutChart: View {
    let data: [PieChartDataItem]
    let denominator: Decimal
    @Binding var selectedId: String?
    var displayMode: PieChartDisplayMode = .totalAssets
    var displayCurrency: Currency = .TWD
    var twdPerDisplayCurrency: Decimal = 1
    var isGroupingEnabled: Bool = false
    var allowsSelection: Bool = true
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    
    private let chartSize: CGFloat = 228
    /// 環變瘦：內徑比例越大環越細
    private let innerRadiusRatio: CGFloat = 0.78
    /// 點擊判定比視覺環更寬，方便點中
    private let hitInnerRadiusRatio: CGFloat = 0.62
    private let hitOuterPadding: CGFloat = 18
    
    private var chartIdentity: String {
        "\(isGroupingEnabled)-" + data.map(\.id).joined(separator: "|")
    }
    
    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }
    
    private var selectedItem: PieChartDataItem? {
        guard let selectedId else { return nil }
        return data.first(where: { $0.id == selectedId })
    }

    private var displayCurrencyDivisor: Decimal {
        guard displayCurrency != .TWD,
              twdPerDisplayCurrency > 0 else {
            return 1
        }
        return twdPerDisplayCurrency
    }

    private func displayAmount(fromTWD amount: Decimal) -> Decimal {
        amount / displayCurrencyDivisor
    }
    
    var body: some View {
        ZStack {
            if data.isEmpty {
                Color.clear
                    .frame(width: chartSize, height: chartSize)
            } else {
                chartBody
            }
            
            if let selected = selectedItem ?? data.max(by: { $0.value < $1.value }) {
                VStack(spacing: 3) {
                    Text(selected.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    if !hideHomeAmounts {
                        CurrencyAmountLabel(
                            text: displayAmount(fromTWD: selected.marketValue).formatted(
                                currency: displayCurrency,
                                fractionDigits: displayCurrency == .TWD ? 0 : 2
                            ),
                            currency: displayCurrency,
                            font: .system(size: 16),
                            weight: .bold,
                            color: .primaryText
                        )
                        .monospacedDigit()
                    }
                    Text(percentageText(for: selected))
                        .font(.system(size: hideHomeAmounts ? 17 : 13, weight: .semibold))
                        .foregroundColor(selected.color)
                }
                .frame(width: chartSize * innerRadiusRatio * 1.2)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onChange(of: chartIdentity) { _, _ in
            if allowsSelection { pickLargestSliceIfNeeded() }
        }
        .onChange(of: allowsSelection) { _, enabled in
            if !enabled { selectedId = nil }
        }
    }
    
    private var chartBody: some View {
        Chart {
            ForEach(data) { item in
                let selected = selectedItem?.id == item.id
                sectorMark(for: item, selected: selected)
            }
        }
        .chartLegend(.hidden)
        .frame(width: chartSize, height: chartSize)
        .overlay {
            if allowsSelection {
                donutTouchOverlay
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .animation(ChartMotion.switchQuick, value: selectedId)
    }

    /// 自訂環帶手勢（比 chartAngleSelection 更好點中細環）
    private var donutTouchOverlay: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            selectItem(at: value.location, in: geometry.size)
                        }
                )
        }
    }
    
    @ChartContentBuilder
    private func sectorMark(for item: PieChartDataItem, selected: Bool) -> some ChartContent {
        SectorMark(
            angle: .value("配置", item.value),
            innerRadius: .ratio(innerRadiusRatio),
            outerRadius: .ratio(1.0),
            angularInset: 2.0
        )
        .foregroundStyle(item.color)
        .opacity(selected ? 1.0 : (selectedId == nil ? 1.0 : 0.42))
    }
    
    private func percentageText(for item: PieChartDataItem) -> String {
        let pct = (item.value / totalDouble) * 100
        return String(format: "%.2f%%", pct)
    }
    
    private func selectItem(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        let radius = min(size.width, size.height) / 2
        let hitInner = radius * hitInnerRadiusRatio
        let hitOuter = radius + hitOuterPadding
        guard distance >= hitInner, distance <= hitOuter else { return }

        let sum = data.reduce(0.0) { $0 + $1.value }
        guard sum > 0 else { return }

        var angleFromTop = atan2(dx, -dy) * 180 / .pi
        if angleFromTop < 0 { angleFromTop += 360 }

        var start: Double = 0
        for item in data {
            let span = max((item.value / sum) * 360, 0.5)
            if angleFromTop >= start, angleFromTop < start + span {
                selectedId = item.id
                return
            }
            start += span
        }
        selectedId = data.last?.id
    }

    private func pickLargestSliceIfNeeded() {
        guard selectedId == nil, let largest = data.max(by: { $0.value < $1.value }) else { return }
        selectedId = largest.id
    }
}

// MARK: - 圖例（含群組）
struct PortfolioGroupedAllocationLegend: View {
    let rows: [PieChartLegendRow]
    let displayMode: PieChartDisplayMode
    let denominator: Decimal
    var displayCurrency: Currency = .TWD
    var twdPerDisplayCurrency: Decimal = 1
    @Binding var selectedId: String?
    let isGroupingEnabled: Bool
    let isEditingGroups: Bool
    @Binding var selectedMemberIds: Set<String>
    @Binding var expandedGroupIds: Set<String>
    @Binding var addToGroupId: UUID?
    @Binding var selectionEditCategory: PieChartGroupEditCategory?
    let onRenameGroup: (UUID) -> Void
    let onRequestDissolveGroup: (UUID) -> Void
    let onRemoveMember: (UUID, String) -> Void
    let onToggleAddToGroup: (UUID) -> Void
    let onToggleMemberSelection: (String) -> Void
    var suppressLayoutAnimation: Bool = false
    var showsGroupActions: Bool = true
    
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    
    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }

    private var displayCurrencyDivisor: Decimal {
        guard displayCurrency != .TWD,
              twdPerDisplayCurrency > 0 else {
            return 1
        }
        return twdPerDisplayCurrency
    }

    private func displayAmount(fromTWD amount: Decimal) -> Decimal {
        amount / displayCurrencyDivisor
    }
    
    private struct FlatLegendRow: Identifiable {
        enum Kind {
            case single(PieChartDataItem, groupable: Bool)
            case groupHeader(id: String, groupId: UUID, name: String, color: Color, marketValue: Decimal)
            case groupMember(groupId: UUID, member: PieChartDataItem)
        }
        let id: String
        let kind: Kind
        var editSection: PieChartGroupEditCategory?
    }

    private enum LegendDisplayBlock: Identifiable {
        case single(FlatLegendRow)
        case group(header: FlatLegendRow, members: [FlatLegendRow], accentColor: Color)

        var id: String {
            switch self {
            case .single(let row): return row.id
            case .group(let header, _, _): return "group-card-\(header.id)"
            }
        }
    }

    private func buildDisplayBlocks(from rows: [FlatLegendRow]) -> [LegendDisplayBlock] {
        var blocks: [LegendDisplayBlock] = []
        var index = 0
        while index < rows.count {
            let row = rows[index]
            if case .groupHeader(_, _, _, let color, _) = row.kind {
                var members: [FlatLegendRow] = []
                index += 1
                while index < rows.count, case .groupMember = rows[index].kind {
                    members.append(rows[index])
                    index += 1
                }
                blocks.append(.group(header: row, members: members, accentColor: color))
            } else {
                blocks.append(.single(row))
                index += 1
            }
        }
        return blocks
    }
    
    private var flatRows: [FlatLegendRow] {
        var result: [FlatLegendRow] = []
        for row in rows {
            switch row {
            case .single(let item, let groupable):
                let section = PieChartGroupableItem.editCategory(forItemId: item.id)
                    ?? PieChartGroupingEngine.legendSectionCategory(forItemId: item.id, mode: displayMode)
                result.append(FlatLegendRow(
                    id: item.id,
                    kind: .single(item, groupable: groupable),
                    editSection: section
                ))
            case .group(let id, let groupId, let name, let color, let marketValue, let members):
                let section = PieChartGroupableItem.editCategory(
                    for: PieChartItemGroup(id: groupId, name: name, memberItemIds: members.map(\.id))
                )
                result.append(FlatLegendRow(
                    id: id,
                    kind: .groupHeader(id: id, groupId: groupId, name: name, color: color, marketValue: marketValue),
                    editSection: section
                ))
                if shouldExpandGroupMembers(id: id) {
                    for member in members {
                        result.append(FlatLegendRow(
                            id: "\(id)_\(member.id)",
                            kind: .groupMember(groupId: groupId, member: member),
                            editSection: section
                        ))
                    }
                }
            }
        }
        return result
    }

    private var usesCategorySections: Bool {
        PieChartGroupingEngine.usesLegendCategorySections(mode: displayMode)
    }

    private var categorySections: [(PieChartGroupEditCategory, [FlatLegendRow])] {
        var buckets: [PieChartGroupEditCategory: [FlatLegendRow]] = [:]
        for row in flatRows {
            guard let section = row.editSection else { continue }
            buckets[section, default: []].append(row)
        }
        return PieChartGroupEditCategory.allCases.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }
    
    private var legendLayoutKey: String {
        flatRows.map(\.id).joined(separator: "|")
    }

    private var displayBlocks: [LegendDisplayBlock] {
        buildDisplayBlocks(from: flatRows)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if usesCategorySections {
                ForEach(categorySections, id: \.0) { section, sectionRows in
                    if isEditingGroups {
                        editSectionBlock(section: section, rows: sectionRows)
                    } else {
                        browseSectionBlock(section: section, rows: sectionRows)
                    }
                }
            } else if isEditingGroups {
                ForEach(categorySections, id: \.0) { section, sectionRows in
                    editSectionBlock(section: section, rows: sectionRows)
                }
            } else {
                ForEach(displayBlocks) { block in
                    legendDisplayBlock(block)
                }
            }
        }
        .animation(suppressLayoutAnimation ? nil : ChartMotion.pieMorphSpring, value: legendLayoutKey)
    }

    @ViewBuilder
    private func legendDisplayBlock(_ block: LegendDisplayBlock) -> some View {
        switch block {
        case .single(let row):
            legendRow(row)
        case .group(let header, let members, let accentColor):
            groupLegendCard(header: header, members: members, accentColor: accentColor)
        }
    }

    @ViewBuilder
    private func browseSectionBlock(
        section: PieChartGroupEditCategory,
        rows: [FlatLegendRow]
    ) -> some View {
        categorySectionBlock(section: section, rows: rows, dimmed: false)
    }

    @ViewBuilder
    private func editSectionBlock(
        section: PieChartGroupEditCategory,
        rows: [FlatLegendRow]
    ) -> some View {
        let isLocked = selectionEditCategory != nil && selectionEditCategory != section
        categorySectionBlock(section: section, rows: rows, dimmed: isLocked)
    }

    @ViewBuilder
    private func categorySectionBlock(
        section: PieChartGroupEditCategory,
        rows: [FlatLegendRow],
        dimmed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.sectionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)
                .padding(.top, 4)
            ForEach(buildDisplayBlocks(from: rows)) { block in
                legendDisplayBlock(block)
            }
        }
        .opacity(dimmed ? 0.42 : 1)
    }

    @ViewBuilder
    private func groupLegendCard(
        header: FlatLegendRow,
        members: [FlatLegendRow],
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            legendRow(header, inGroupCard: true)
            if !members.isEmpty {
                Divider()
                    .padding(.leading, memberRowIndent + 12)
                ForEach(members) { memberRow in
                    if case .groupMember(let groupId, let member) = memberRow.kind {
                        memberRowContent(groupId: groupId, member: member, inGroupCard: true)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.separator.opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 6)
        }
    }
    
    @ViewBuilder
    private func legendRow(_ row: FlatLegendRow, inGroupCard: Bool = false) -> some View {
        switch row.kind {
        case .single(let item, let groupable):
            singleRow(item: item, groupable: groupable)
        case .groupHeader(let id, let groupId, let name, let color, let marketValue):
            groupHeaderRow(
                id: id,
                groupId: groupId,
                name: name,
                color: color,
                marketValue: marketValue,
                editSection: row.editSection,
                inGroupCard: inGroupCard
            )
        case .groupMember(let groupId, let member):
            memberRowContent(groupId: groupId, member: member, inGroupCard: inGroupCard)
        }
    }
    
    /// 群組化瀏覽：依 expandedGroupIds 收合；編輯群組：一律展開並顯示移除
    private func shouldExpandGroupMembers(id: String) -> Bool {
        guard isGroupingEnabled else { return false }
        if isEditingGroups { return true }
        return expandedGroupIds.contains(id)
    }
    
    private var memberRowIndent: CGFloat {
        isEditingGroups ? 24 : 28
    }
    
    @ViewBuilder
    private func singleRow(item: PieChartDataItem, groupable: Bool) -> some View {
        let pct = (NSDecimalNumber(decimal: item.marketValue).doubleValue / totalDouble) * 100
        let isSelected = selectedId == item.id
        let isChecked = selectedMemberIds.contains(item.id)
        let canSelect = isEditingGroups && canSelectInEdit(itemId: item.id, groupable: groupable)
        
        Button {
            if canSelect {
                onToggleMemberSelection(item.id)
            } else {
                withAnimation(ChartMotion.switchSpring) {
                    selectedId = item.id
                }
            }
        } label: {
            rowContent(
                color: item.color,
                title: item.name,
                pct: pct,
                marketValue: item.marketValue,
                isSelected: isSelected && !isEditingGroups,
                isBold: isSelected,
                showsCheckbox: isEditingGroups,
                isChecked: isChecked,
                checkboxEnabled: canSelect
            )
        }
        .buttonStyle(.plain)
        .disabled(isEditingGroups && !canSelect)
    }

    private func canSelectInEdit(itemId: String, groupable: Bool) -> Bool {
        guard groupable,
              let itemCategory = PieChartGroupableItem.editCategory(forItemId: itemId) else {
            return false
        }
        if let selectionEditCategory, selectionEditCategory != itemCategory {
            return false
        }
        return true
    }
    
    @ViewBuilder
    private func groupHeaderRow(
        id: String,
        groupId: UUID,
        name: String,
        color: Color,
        marketValue: Decimal,
        editSection: PieChartGroupEditCategory?,
        inGroupCard: Bool
    ) -> some View {
        let pct = (NSDecimalNumber(decimal: marketValue).doubleValue / totalDouble) * 100
        let isSelected = selectedId == id
        let isAddTarget = addToGroupId == groupId
        
        Group {
            if isEditingGroups, isGroupingEnabled {
                HStack(spacing: 8) {
                    groupHeaderEditContent(
                        color: color,
                        name: name,
                        pct: pct,
                        marketValue: marketValue,
                        groupId: groupId,
                        editSection: editSection
                    )
                }
            } else {
                Button {
                    withAnimation(ChartMotion.switchSpring) {
                        if isGroupingEnabled {
                            var ids = expandedGroupIds
                            if ids.contains(id) {
                                ids.remove(id)
                            } else {
                                ids.insert(id)
                            }
                            expandedGroupIds = ids
                        }
                        selectedId = id
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isGroupingEnabled {
                            Image(systemName: expandedGroupIds.contains(id) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondaryText)
                                .frame(width: 16)
                        }
                        rowContent(
                            color: color,
                            title: name,
                            pct: pct,
                            marketValue: marketValue,
                            isSelected: isSelected,
                            isBold: isSelected,
                            showsCheckbox: false,
                            isChecked: false,
                            checkboxEnabled: false
                        )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, inGroupCard ? 0 : (isAddTarget ? 4 : 0))
        .padding(.vertical, inGroupCard ? 0 : (isAddTarget ? 4 : 0))
        .background {
            if !inGroupCard {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isAddTarget ? AppColors.appPrimary.opacity(0.1) : Color.clear)
            }
        }
        .animation(ChartMotion.switchQuick, value: isAddTarget)
    }

    @ViewBuilder
    private func groupHeaderEditContent(
        color: Color,
        name: String,
        pct: Double,
        marketValue: Decimal,
        groupId: UUID,
        editSection: PieChartGroupEditCategory?
    ) -> some View {
        let isAddTarget = addToGroupId == groupId
        
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primaryText)
                .lineLimit(1)
            Button {
                onRenameGroup(groupId)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("編輯群組名稱")
            
            Spacer(minLength: 4)
            valueColumn(pct: pct, marketValue: marketValue)
            
            if showsGroupActions, let editSection,
               selectionEditCategory == nil || selectionEditCategory == editSection {
                Button {
                    onToggleAddToGroup(groupId)
                } label: {
                    Image(systemName: isAddTarget ? "plus.circle.fill" : "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(isAddTarget ? AppColors.appPrimary : .secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAddTarget ? "取消加入此群組" : "加入項目至此群組")
                
                Button {
                    onRequestDissolveGroup(groupId)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.lossRed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("解除群組")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func memberRowContent(groupId: UUID, member: PieChartDataItem, inGroupCard: Bool = false) -> some View {
        let pct = (NSDecimalNumber(decimal: member.marketValue).doubleValue / totalDouble) * 100
        HStack(spacing: 12) {
            Spacer().frame(width: memberRowIndent)
            Circle().fill(member.color).frame(width: 10, height: 10)
            Text(member.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primaryText)
            Spacer()
            if isEditingGroups, isGroupingEnabled {
                valueColumn(pct: pct, marketValue: member.marketValue)
                Button("移除") {
                    onRemoveMember(groupId, member.id)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.lossRed)
            } else {
                valueColumn(pct: pct, marketValue: member.marketValue)
            }
        }
        .padding(.horizontal, inGroupCard ? 4 : 12)
        .padding(.vertical, inGroupCard ? 10 : 12)
        .frame(minHeight: inGroupCard ? 44 : 48)
        .background {
            if !inGroupCard {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primaryText.opacity(0.03))
            }
        }
    }
    
    @ViewBuilder
    private func rowContent(
        color: Color,
        title: String,
        pct: Double,
        marketValue: Decimal,
        isSelected: Bool,
        isBold: Bool,
        showsCheckbox: Bool,
        isChecked: Bool,
        checkboxEnabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            if showsCheckbox {
                selectionIndicator(isOn: isChecked, enabled: checkboxEnabled)
            }
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 15, weight: isBold ? .semibold : .regular))
                .foregroundColor(.primaryText)
            Spacer()
            valueColumn(pct: pct, marketValue: marketValue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground(isSelected: isSelected))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    @ViewBuilder
    private func selectionIndicator(isOn: Bool, enabled: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundColor(enabled ? (isOn ? AppColors.appPrimary : .secondaryText) : .secondaryText.opacity(0.35))
            .frame(width: 22)
    }
    
    @ViewBuilder
    private func valueColumn(pct: Double, marketValue: Decimal) -> some View {
        let displayAmount = displayAmount(fromTWD: marketValue)
        let fractionDigits = displayCurrency == .TWD ? 0 : 2
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.2f%%", pct))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primaryText)
            if !hideHomeAmounts {
                CurrencyAmountLabel(
                    text: displayAmount.formatted(
                        currency: displayCurrency,
                        fractionDigits: fractionDigits
                    ),
                    currency: displayCurrency,
                    font: .system(size: 12),
                    weight: .regular,
                    color: .secondaryText
                )
                .frame(maxWidth: 120, alignment: .trailing)
            }
        }
    }
    
    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.primaryText.opacity(0.06) : Color.clear)
    }
    
}

// MARK: - 圖例（分享／無群組編輯時）
struct PortfolioAllocationLegend: View {
    let data: [PieChartDataItem]
    let denominator: Decimal
    @Binding var selectedId: String?
    let mode: PieChartDisplayMode
    
    @Environment(\.homeAmountsHidden) private var hideHomeAmounts
    
    private var totalDouble: Double {
        max(NSDecimalNumber(decimal: denominator).doubleValue, 0.001)
    }
    
    private var orderedRows: [PieChartDataItem] {
        switch mode {
        case .totalAssets:
            let order = ["twd_cash", "usd_cash", "stock_us", "stock_tw", "crypto"]
            return order.compactMap { id in data.first(where: { $0.id == id }) }
        case .portfolio:
            return data.sorted { $0.marketValue > $1.marketValue }
        case .allDetails:
            let cash = data.filter { $0.id == "twd_cash" || $0.id == "usd_cash" }
            let stocks = data.filter { $0.id != "twd_cash" && $0.id != "usd_cash" }
                .sorted { $0.marketValue > $1.marketValue }
            return cash + stocks
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(orderedRows) { item in
                legendRow(item: item)
            }
        }
    }
    
    private func legendRow(item: PieChartDataItem) -> some View {
        let pct = (NSDecimalNumber(decimal: item.marketValue).doubleValue / totalDouble) * 100
        let isSelected = selectedId == item.id
        return Button {
            withAnimation(ChartMotion.switchSpring) {
                selectedId = item.id
            }
        } label: {
            HStack(spacing: 12) {
                Circle().fill(item.color).frame(width: 10, height: 10)
                Text(item.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primaryText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f%%", pct))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                    if !hideHomeAmounts {
                        Text(item.marketValue.formatted(currency: .TWD, fractionDigits: 0))
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.primaryText.opacity(0.06) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
