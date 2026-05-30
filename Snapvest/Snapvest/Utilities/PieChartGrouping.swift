//
//  PieChartGrouping.swift
//  Snapvest
//
//  首頁圓餅圖自訂群組：持久化、合併 slice、績效圖聚合
//

import SwiftUI
import Combine

// MARK: - Models

struct PieChartItemGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var memberItemIds: [String]
}

enum PieChartGroupingDisplayMode: String, Codable {
    case grouped = "群組化"
    case ungrouped = "非群組化"

    /// 簡潔 chip 文案（rawValue 仍用於持久化）
    var label: String {
        switch self {
        case .grouped: return "群組"
        case .ungrouped: return "明細"
        }
    }

    var toggled: PieChartGroupingDisplayMode {
        self == .grouped ? .ungrouped : .grouped
    }

    var chipIcon: String {
        switch self {
        case .grouped: return "square.grid.2x2.fill"
        case .ungrouped: return "list.bullet"
        }
    }
}

enum PieChartGroupEditCategory: String, CaseIterable {
    case cash = "現金類"
    case investment = "投資類"

    var sectionTitle: String { rawValue }

    func contains(itemId: String) -> Bool {
        switch self {
        case .cash: return PieChartGroupingEngine.isCashItemId(itemId)
        case .investment: return !PieChartGroupingEngine.isCashItemId(itemId)
        }
    }
}

enum PieChartGroupableItem {
    private static let categoryIds: Set<String> = ["stock_us", "stock_tw", "crypto"]

    static func isGroupable(itemId: String, mode: PieChartDisplayMode) -> Bool {
        if categoryIds.contains(itemId) { return false }
        switch mode {
        case .totalAssets:
            return PieChartGroupingEngine.isCashItemId(itemId)
        case .portfolio, .allDetails:
            return true
        }
    }

    static func editCategory(forItemId itemId: String) -> PieChartGroupEditCategory? {
        if PieChartGroupingEngine.isCashItemId(itemId) { return .cash }
        if categoryIds.contains(itemId) { return nil }
        return .investment
    }

    static func editCategory(for group: PieChartItemGroup) -> PieChartGroupEditCategory? {
        let categories = Set(
            group.memberItemIds.compactMap { editCategory(forItemId: $0) }
        )
        guard categories.count == 1, let only = categories.first else { return nil }
        return only
    }
}

enum PieChartGroupingModeSupport {
    /// 三種圓餅分頁皆支援群組化 chip
    static func supportsGroupingUI(mode: PieChartDisplayMode) -> Bool { true }

    /// 群組化時用於合併的底層 slice（總資產維持五大類，僅現金可群組）
    static func effectiveBaseItems(
        mode: PieChartDisplayMode,
        inputs: PieChartInputs,
        isGroupingEnabled: Bool
    ) -> [PieChartDataItem] {
        guard isGroupingEnabled else {
            return PortfolioPieChartBuilder.items(mode: mode, inputs: inputs)
        }
        switch mode {
        case .totalAssets:
            return PortfolioPieChartBuilder.totalAssetsItems(inputs: inputs)
        case .allDetails:
            return PortfolioPieChartBuilder.allDetailsItems(inputs: inputs)
        case .portfolio:
            return PortfolioPieChartBuilder.portfolioItems(inputs: inputs)
        }
    }

    /// 績效圖是否套用群組聚合（總資產分頁永遠逐檔）
    static func appliesGroupingToPerformance(pieMode: PieChartDisplayMode, isGroupingEnabled: Bool) -> Bool {
        isGroupingEnabled && pieMode != .totalAssets
    }

    static func performanceRows(
        inputs: PieChartInputs,
        groups: [PieChartItemGroup],
        pieMode: PieChartDisplayMode,
        isGroupingEnabled: Bool
    ) -> [HoldingPerformanceRow] {
        if appliesGroupingToPerformance(pieMode: pieMode, isGroupingEnabled: isGroupingEnabled),
           !groups.isEmpty {
            return PieChartGroupingEngine.groupedPerformanceRows(inputs: inputs, groups: groups)
        }
        return HoldingChartMetrics.performanceRows(inputs: inputs)
    }

    static func prependsCashInGroupedChart(mode: PieChartDisplayMode) -> Bool {
        mode == .allDetails || mode == .totalAssets
    }
}

enum PieChartGroupingEngine {
    static func cashItemId(for currency: Currency) -> String {
        "\(currency.rawValue.lowercased())_cash"
    }

    static func isCashItemId(_ itemId: String) -> Bool {
        itemId.hasSuffix("_cash")
    }

    static func isItemInAnyGroup(_ itemId: String, groups: [PieChartItemGroup]) -> Bool {
        groups.contains { $0.memberItemIds.contains(itemId) }
    }

    static func groupSliceId(_ groupId: UUID) -> String {
        "group_\(groupId.uuidString)"
    }

    static func groupUUID(from sliceId: String) -> UUID? {
        UUID(uuidString: sliceId.replacingOccurrences(of: "group_", with: ""))
    }

    /// 預設名稱（方案 C）：2 檔用頓號；3 檔以上用「第一名 等 N 檔」
    /// 固定 id → 色票，切換群組化／模式時避免 Chart 插值造成顏色閃爍
    static func stableColorScale(
        baseItems: [PieChartDataItem],
        groups: [PieChartItemGroup]
    ) -> [String: Color] {
        var scale = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0.color) })
        let itemById = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0) })
        for group in groups {
            let members = group.memberItemIds.compactMap { itemById[$0] }
            guard members.count >= 2,
                  let lead = members.max(by: { $0.marketValue < $1.marketValue }) else { continue }
            scale[groupSliceId(group.id)] = lead.color
        }
        return scale
    }

    /// 新建群組預設名稱：群組1、群組2…（同類別內跳過已佔用編號）
    static func nextSequentialGroupName(
        existingGroups: [PieChartItemGroup],
        category: PieChartGroupEditCategory
    ) -> String {
        let prefix = "群組"
        let sameCategory = existingGroups.filter {
            PieChartGroupableItem.editCategory(for: $0) == category
        }
        var index = 1
        while sameCategory.contains(where: { $0.name == "\(prefix)\(index)" }) {
            index += 1
        }
        return "\(prefix)\(index)"
    }

    static func sanitizeGroups(
        _ groups: [PieChartItemGroup],
        validGroupableIds: Set<String>
    ) -> [PieChartItemGroup] {
        var consumed = Set<String>()
        var result: [PieChartItemGroup] = []
        for group in groups {
            var members = group.memberItemIds.filter {
                validGroupableIds.contains($0) && !consumed.contains($0)
            }
            members = membersMatchingSingleEditCategory(members)
            guard members.count >= 2 else { continue }
            members.forEach { consumed.insert($0) }
            var updated = group
            updated.memberItemIds = members.sorted()
            result.append(updated)
        }
        return result
    }

    /// 群組內僅保留同一編輯類別（現金／投資），不可混用
    static func membersMatchingSingleEditCategory(_ memberIds: [String]) -> [String] {
        guard let first = memberIds.first,
              let category = PieChartGroupableItem.editCategory(forItemId: first) else {
            return []
        }
        return memberIds.filter { category.contains(itemId: $0) }
    }

    static func applyGroups(
        baseItems: [PieChartDataItem],
        groups: [PieChartItemGroup],
        mode: PieChartDisplayMode,
        isGroupingEnabled: Bool
    ) -> [PieChartDataItem] {
        guard isGroupingEnabled, !groups.isEmpty else {
            return baseItems
        }

        let itemById = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0) })
        var consumed = Set<String>()
        var result: [PieChartDataItem] = []

        if PieChartGroupingModeSupport.prependsCashInGroupedChart(mode: mode) {
            let cashItems = baseItems
                .filter { isCashItemId($0.id) }
                .sorted { $0.marketValue > $1.marketValue }
            for item in cashItems {
                guard !isItemInAnyGroup(item.id, groups: groups) else { continue }
                result.append(item)
                consumed.insert(item.id)
            }
        }

        for group in groups {
            let members = group.memberItemIds.compactMap { itemById[$0] }
            guard members.count >= 2 else { continue }
            members.forEach { consumed.insert($0.id) }
            let totalValue = members.reduce(Decimal.zero) { $0 + $1.marketValue }
            let lead = members.max(by: { $0.marketValue < $1.marketValue }) ?? members[0]
            result.append(
                PieChartDataItem(
                    symbol: groupSliceId(group.id),
                    name: group.name,
                    marketValue: totalValue,
                    color: lead.color
                )
            )
        }

        let ungrouped = baseItems
            .filter { !consumed.contains($0.id) }
            .sorted { $0.marketValue > $1.marketValue }
        result.append(contentsOf: ungrouped)
        return result
    }

    /// 總資產／所有細項圖例：現金類在上、投資類在下
    static func usesLegendCategorySections(mode: PieChartDisplayMode) -> Bool {
        mode == .allDetails || mode == .totalAssets
    }

    static func legendSectionCategory(forItemId itemId: String, mode: PieChartDisplayMode) -> PieChartGroupEditCategory? {
        guard usesLegendCategorySections(mode: mode) else { return nil }
        return isCashItemId(itemId) ? .cash : .investment
    }

    static func legendRows(
        baseItems: [PieChartDataItem],
        displayItems: [PieChartDataItem],
        groups: [PieChartItemGroup],
        mode: PieChartDisplayMode,
        isGroupingEnabled: Bool
    ) -> [PieChartLegendRow] {
        if !isGroupingEnabled || groups.isEmpty {
            return flatRows(baseItems: baseItems, mode: mode)
        }
        if usesLegendCategorySections(mode: mode) {
            return groupedLegendRowsByCategory(
                baseItems: baseItems,
                displayItems: displayItems,
                groups: groups,
                mode: mode
            )
        }
        return groupedLegendRowsPortfolio(
            baseItems: baseItems,
            displayItems: displayItems,
            groups: groups,
            mode: mode
        )
    }

    private static func groupedLegendRowsByCategory(
        baseItems: [PieChartDataItem],
        displayItems: [PieChartDataItem],
        groups: [PieChartItemGroup],
        mode: PieChartDisplayMode
    ) -> [PieChartLegendRow] {
        let itemById = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0) })
        let displayById = Dictionary(uniqueKeysWithValues: displayItems.map { ($0.id, $0) })
        let groupedDisplayIds = Set(groups.map { groupSliceId($0.id) })
        let consumed = Set(groups.flatMap(\.memberItemIds))

        var cashGroups: [(row: PieChartLegendRow, value: Decimal)] = []
        var invGroups: [(row: PieChartLegendRow, value: Decimal)] = []

        for group in groups {
            let members = group.memberItemIds.compactMap { itemById[$0] }
            guard members.count >= 2,
                  let display = displayById[groupSliceId(group.id)] else { continue }
            let row = PieChartLegendRow.group(
                id: display.id,
                groupId: group.id,
                name: group.name,
                color: display.color,
                marketValue: display.marketValue,
                members: members.sorted { $0.marketValue > $1.marketValue }
            )
            switch PieChartGroupableItem.editCategory(for: group) {
            case .cash:
                cashGroups.append((row, display.marketValue))
            case .investment, .none:
                invGroups.append((row, display.marketValue))
            }
        }

        var cashSingles: [PieChartLegendRow] = []
        var invSingles: [PieChartLegendRow] = []
        let singles = baseItems
            .filter { !consumed.contains($0.id) && !groupedDisplayIds.contains($0.id) }
            .sorted { $0.marketValue > $1.marketValue }

        for item in singles {
            let row = PieChartLegendRow.single(
                item,
                groupable: PieChartGroupableItem.isGroupable(itemId: item.id, mode: mode)
            )
            switch legendSectionCategory(forItemId: item.id, mode: mode) {
            case .cash: cashSingles.append(row)
            case .investment, .none: invSingles.append(row)
            }
        }

        cashGroups.sort { $0.value > $1.value }
        invGroups.sort { $0.value > $1.value }

        return cashGroups.map(\.row)
            + cashSingles
            + invGroups.map(\.row)
            + invSingles
    }

    private static func groupedLegendRowsPortfolio(
        baseItems: [PieChartDataItem],
        displayItems: [PieChartDataItem],
        groups: [PieChartItemGroup],
        mode: PieChartDisplayMode
    ) -> [PieChartLegendRow] {
        let itemById = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0) })
        let displayById = Dictionary(uniqueKeysWithValues: displayItems.map { ($0.id, $0) })
        let groupedDisplayIds = Set(groups.map { groupSliceId($0.id) })
        let consumed = Set(groups.flatMap(\.memberItemIds))

        var groupRows: [(row: PieChartLegendRow, value: Decimal)] = []
        for group in groups {
            let members = group.memberItemIds.compactMap { itemById[$0] }
            guard members.count >= 2,
                  let display = displayById[groupSliceId(group.id)] else { continue }
            groupRows.append((
                .group(
                    id: display.id,
                    groupId: group.id,
                    name: group.name,
                    color: display.color,
                    marketValue: display.marketValue,
                    members: members.sorted { $0.marketValue > $1.marketValue }
                ),
                display.marketValue
            ))
        }
        groupRows.sort { $0.value > $1.value }

        let singles = baseItems
            .filter { !consumed.contains($0.id) && !groupedDisplayIds.contains($0.id) }
            .sorted { $0.marketValue > $1.marketValue }
            .map {
                PieChartLegendRow.single(
                    $0,
                    groupable: PieChartGroupableItem.isGroupable(itemId: $0.id, mode: mode)
                )
            }

        return groupRows.map(\.row) + singles
    }

    private static func flatRows(baseItems: [PieChartDataItem], mode: PieChartDisplayMode) -> [PieChartLegendRow] {
        let ordered: [PieChartDataItem]
        switch mode {
        case .portfolio:
            ordered = baseItems.sorted { $0.marketValue > $1.marketValue }
        case .allDetails, .totalAssets:
            let cash = baseItems
                .filter { isCashItemId($0.id) }
                .sorted { $0.marketValue > $1.marketValue }
            let investment = baseItems
                .filter { !isCashItemId($0.id) }
                .sorted { $0.marketValue > $1.marketValue }
            ordered = cash + investment
        }
        return ordered.map {
            .single($0, groupable: PieChartGroupableItem.isGroupable(itemId: $0.id, mode: mode))
        }
    }

    static func groupedPerformanceRows(
        inputs: PieChartInputs,
        groups: [PieChartItemGroup]
    ) -> [HoldingPerformanceRow] {
        let baseRows = HoldingChartMetrics.performanceRows(inputs: inputs)
        guard !groups.isEmpty else { return baseRows }

        let rowById = Dictionary(uniqueKeysWithValues: baseRows.map { ($0.id, $0) })
        var consumed = Set<String>()
        var result: [HoldingPerformanceRow] = []

        let rate = inputs.usdToTwdRate

        for group in groups {
            let memberRows: [HoldingPerformanceRow] = group.memberItemIds.compactMap { rowById[$0] }
            // 至少 2 檔有績效資料才合併；未達標者不消耗，避免小持倉從績效圖消失
            guard memberRows.count >= 2 else { continue }

            var totalGain = Decimal.zero
            var totalCost = Decimal.zero
            var leadRow = memberRows[0]

            for row in memberRows {
                totalGain += row.unrealizedGainLossTWD
                totalCost += performanceCostBasis(for: row, inputs: inputs, rate: rate)
                if abs(row.gainLossDouble) >= abs(leadRow.gainLossDouble) {
                    leadRow = row
                }
                consumed.insert(row.id)
            }

            let returnPct: Decimal = totalCost > 0 ? (totalGain / totalCost) * 100 : 0
            result.append(
                HoldingPerformanceRow(
                    id: groupSliceId(group.id),
                    displayName: group.name,
                    unrealizedGainLossTWD: totalGain,
                    returnPercent: returnPct,
                    color: leadRow.color,
                    costBasisTWD: totalCost
                )
            )
        }

        let ungrouped = baseRows.filter { !consumed.contains($0.id) }
        result.append(contentsOf: ungrouped)
        return result.sorted {
            NSDecimalNumber(decimal: $0.unrealizedGainLossTWD).doubleValue >
            NSDecimalNumber(decimal: $1.unrealizedGainLossTWD).doubleValue
        }
    }

    /// 由績效列反推或從持股取得成本，供群組加權報酬率
    private static func performanceCostBasis(
        for row: HoldingPerformanceRow,
        inputs: PieChartInputs,
        rate: Decimal
    ) -> Decimal {
        if let costBasisTWD = row.costBasisTWD {
            return costBasisTWD
        }
        if let holding = inputs.aggregatedHoldings.first(where: {
            $0.assetType != .cash && "\($0.assetType.rawValue)_\($0.symbol)" == row.id
        }),
           let costTWD = HoldingChartMetrics.totalCostTWD(holding: holding, rate: rate) {
            return costTWD
        }
        let pct = NSDecimalNumber(decimal: row.returnPercent).doubleValue
        guard pct != 0 else { return 0 }
        return row.unrealizedGainLossTWD / Decimal(pct / 100)
    }
}

enum PieChartLegendRow: Identifiable {
    case single(PieChartDataItem, groupable: Bool)
    case group(id: String, groupId: UUID, name: String, color: Color, marketValue: Decimal, members: [PieChartDataItem])

    var id: String {
        switch self {
        case .single(let item, _): return item.id
        case .group(let id, _, _, _, _, _): return id
        }
    }
}

// MARK: - Persistence

@MainActor
final class PieChartGroupingStore: ObservableObject {
    static let shared = PieChartGroupingStore()

    @Published private(set) var groups: [PieChartItemGroup] = []
    @Published var displayMode: PieChartGroupingDisplayMode = .ungrouped
    /// 圓餅圖明細群組收合狀態（首頁與分享圖共用）
    @Published var expandedLegendGroupIds: Set<String> = []
    /// 編輯群組中：首頁需先結束編輯才能操作其他區塊
    @Published var isEditingGroups = false

    private var userId: String = AppUser.id
    private var isUsingTransientDemoDefaults = false

    var isGroupingEnabled: Bool { displayMode == .grouped }

    func setEditingGroups(_ editing: Bool) {
        isEditingGroups = editing
    }

    private init() {
        reload(for: AppUser.id)
    }

    func reload(for userId: String) {
        self.userId = userId
        isUsingTransientDemoDefaults = false
        groups = Self.loadGroups(userId: userId)
        displayMode = Self.loadDisplayMode(userId: userId)
        expandedLegendGroupIds = Self.loadExpandedLegendGroupIds(userId: userId)
    }
    
    func applyDemoDefaults() {
        isUsingTransientDemoDefaults = true
        groups = Self.demoDefaultGroups
        displayMode = .grouped
        expandedLegendGroupIds = Set(Self.demoDefaultGroups.map { PieChartGroupingEngine.groupSliceId($0.id) })
        isEditingGroups = false
    }

    func setExpandedLegendGroupIds(_ ids: Set<String>) {
        expandedLegendGroupIds = ids
        persistExpandedLegendGroupIds()
    }

    func expandAllLegendGroups(groupIds: [UUID]) {
        setExpandedLegendGroupIds(Set(groupIds.map { PieChartGroupingEngine.groupSliceId($0) }))
    }

    func pruneExpandedLegendGroups(validSliceIds: Set<String>) {
        let pruned = expandedLegendGroupIds.intersection(validSliceIds)
        guard pruned != expandedLegendGroupIds else { return }
        setExpandedLegendGroupIds(pruned)
    }

    func clearExpandedLegendGroups() {
        setExpandedLegendGroupIds([])
    }

    func removeExpandedLegendGroup(sliceId: String) {
        var ids = expandedLegendGroupIds
        ids.remove(sliceId)
        setExpandedLegendGroupIds(ids)
    }

    func insertExpandedLegendGroup(sliceId: String) {
        var ids = expandedLegendGroupIds
        ids.insert(sliceId)
        setExpandedLegendGroupIds(ids)
    }

    func updateGroups(_ newGroups: [PieChartItemGroup]) {
        groups = newGroups
        persistGroups()
    }

    func sanitize(validGroupableIds: Set<String>) {
        let cleaned = PieChartGroupingEngine.sanitizeGroups(groups, validGroupableIds: validGroupableIds)
        guard cleaned != groups else { return }
        groups = cleaned
        persistGroups()
    }

    func toggleDisplayMode() {
        displayMode = displayMode.toggled
        persistDisplayMode()
    }

    private func persistGroups() {
        guard !isUsingTransientDemoDefaults else { return }
        let key = Self.groupsStorageKey(userId: userId)
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persistDisplayMode() {
        guard !isUsingTransientDemoDefaults else { return }
        UserDefaults.standard.set(displayMode.rawValue, forKey: Self.displayModeStorageKey(userId: userId))
    }

    private static func groupsStorageKey(userId: String) -> String {
        "pieChartGroups_\(userId)"
    }
    
    private static var demoDefaultGroups: [PieChartItemGroup] {
        [
            PieChartItemGroup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "現金部位",
                memberItemIds: ["twd_cash", "usd_cash"]
            ),
            PieChartItemGroup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "指數 ETF",
                memberItemIds: ["stock_tw_0050", "stock_us_VOO"]
            ),
            PieChartItemGroup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "台股權值",
                memberItemIds: ["stock_tw_2330", "stock_tw_2317"]
            ),
            PieChartItemGroup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                name: "美股科技",
                memberItemIds: ["stock_us_AAPL", "stock_us_NVDA", "stock_us_MSFT"]
            ),
            PieChartItemGroup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                name: "加密資產",
                memberItemIds: ["crypto_BTC", "crypto_ETH", "crypto_USDT"]
            )
        ]
    }

    private static func displayModeStorageKey(userId: String) -> String {
        "pieChartGroupingDisplay_\(userId)"
    }

    private static func expandedLegendStorageKey(userId: String) -> String {
        "pieChartExpandedLegend_\(userId)"
    }

    private func persistExpandedLegendGroupIds() {
        guard !isUsingTransientDemoDefaults else { return }
        UserDefaults.standard.set(
            Array(expandedLegendGroupIds),
            forKey: Self.expandedLegendStorageKey(userId: userId)
        )
    }

    private static func loadExpandedLegendGroupIds(userId: String) -> Set<String> {
        let key = expandedLegendStorageKey(userId: userId)
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(stored)
    }

    private static func loadDisplayMode(userId: String) -> PieChartGroupingDisplayMode {
        guard let raw = UserDefaults.standard.string(forKey: displayModeStorageKey(userId: userId)),
              let mode = PieChartGroupingDisplayMode(rawValue: raw) else {
            return .ungrouped
        }
        return mode
    }

    private static func loadGroups(userId: String) -> [PieChartItemGroup] {
        let key = groupsStorageKey(userId: userId)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PieChartItemGroup].self, from: data) {
            return decoded
        }
        return migrateLegacyGroups(userId: userId)
    }

    private static func migrateLegacyGroups(userId: String) -> [PieChartItemGroup] {
        var merged: [PieChartItemGroup] = []
        for legacyMode in [PieChartDisplayMode.portfolio, PieChartDisplayMode.allDetails] {
            let legacyKey = "pieChartGroups_\(userId)_\(legacyMode.rawValue)"
            guard let data = UserDefaults.standard.data(forKey: legacyKey),
                  let legacy = try? JSONDecoder().decode([PieChartItemGroup].self, from: data) else { continue }
            for group in legacy where !merged.contains(where: { $0.id == group.id }) {
                merged.append(group)
            }
        }
        if !merged.isEmpty,
           let data = try? JSONEncoder().encode(merged) {
            UserDefaults.standard.set(data, forKey: groupsStorageKey(userId: userId))
        }
        return merged
    }
}
