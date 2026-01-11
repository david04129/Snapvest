//
//  AssetsView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import Charts

struct AssetsView: View {
    @StateObject private var viewModel = AssetsViewModel()
    @State private var userId: String = "test-user-id"
    @State private var selectedSort: SortOption = .totalAssets
    @State private var selectedHolding: HoldingNavigationItem?
    
    enum SortOption: String, CaseIterable {
        case totalAssets = "總資產由高到低"
        case todayPL = "今日損益由高到低"
    }
    
    // 用於 NavigationDestination 的包裝結構
    struct HoldingNavigationItem: Identifiable, Hashable {
        let id: String // 使用 aggregatedHolding.id
        let aggregatedHolding: AggregatedHoldingSnapshot
        let assetPriceSnapshot: AssetPriceSnapshot?
        let totalAssets: Decimal
        let totalInvestments: Decimal
        
        // Hashable 實現（使用 id 作為 hash）
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        // Equatable 實現（使用 id 比較）
        static func == (lhs: HoldingNavigationItem, rhs: HoldingNavigationItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("載入中...")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        // 台股卡片
                        AssetCategoryCardView(
                            assetType: .stockTW,
                            aggregatedHoldings: viewModel.aggregatedHoldings.filter { $0.assetType == .stockTW },
                            assetPriceSnapshots: viewModel.assetPriceSnapshots,
                            viewModel: viewModel,
                            onHoldingTap: navigateToHoldingDetail
                        )
                        
                        // 美股卡片
                        AssetCategoryCardView(
                            assetType: .stockUS,
                            aggregatedHoldings: viewModel.aggregatedHoldings.filter { $0.assetType == .stockUS },
                            assetPriceSnapshots: viewModel.assetPriceSnapshots,
                            viewModel: viewModel,
                            onHoldingTap: navigateToHoldingDetail
                        )
                        
                        // 加密貨幣卡片
                        AssetCategoryCardView(
                            assetType: .crypto,
                            aggregatedHoldings: viewModel.aggregatedHoldings.filter { $0.assetType == .crypto },
                            assetPriceSnapshots: viewModel.assetPriceSnapshots,
                            viewModel: viewModel,
                            onHoldingTap: navigateToHoldingDetail
                        )
                        
                        // Phase 3 - 所有持股列表
                        AllHoldingsSection(
                            aggregatedHoldings: viewModel.aggregatedHoldings,
                            assetPriceSnapshots: viewModel.assetPriceSnapshots,
                            totalAssets: viewModel.totalAssets,
                            totalInvestments: viewModel.totalInvestments,
                            onHoldingTap: navigateToHoldingDetail
                        )
                    }
                }
                .padding()
            }
            .background(Color.mainBackground)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                customHeaderBarWithAddButton(icon: "chart.bar.fill", title: "資產", addButtonText: "新增資產", addButtonAction: {
                    // TODO: 新增資產的功能
                })
            }
            .refreshable {
                await viewModel.loadData(userId: userId)
            }
            .task {
                await viewModel.loadData(userId: userId)
            }
            .navigationDestination(item: $selectedHolding) { item in
                HoldingDetailView(
                    aggregatedHolding: item.aggregatedHolding,
                    assetPriceSnapshot: item.assetPriceSnapshot,
                    totalAssets: item.totalAssets,
                    totalInvestments: item.totalInvestments
                )
            }
        }
    }
    
    // MARK: - 導航到持股詳細頁面
    private func navigateToHoldingDetail(_ holding: AggregatedHoldingSnapshot) {
        let priceSnapshot = viewModel.assetPriceSnapshots.first { snapshot in
            snapshot.symbol == holding.symbol && snapshot.assetType == holding.assetType
        }
        
        selectedHolding = HoldingNavigationItem(
            id: holding.id,
            aggregatedHolding: holding,
            assetPriceSnapshot: priceSnapshot,
            totalAssets: viewModel.totalAssets,
            totalInvestments: viewModel.totalInvestments
        )
    }
    
    // MARK: - 自定義標題欄（帶新增按鈕）
    private func customHeaderBarWithAddButton(icon: String, title: String, addButtonText: String, addButtonAction: @escaping () -> Void) -> some View {
        HStack {
            // 左側：ICON + 標題
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            // 右側：新增按鈕 + 使用者頭像
            HStack(spacing: 12) {
                Button(action: addButtonAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(addButtonText)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                }
                
                Button(action: {
                    // TODO: 點擊後的功能
                }) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(.appPrimary)
                                .font(.caption)
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.mainBackground)
    }
}

// MARK: - 資產類別卡片（新版本，使用 AggregatedHoldingSnapshot）
struct AssetCategoryCardView: View {
    let assetType: AssetType
    let aggregatedHoldings: [AggregatedHoldingSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    @ObservedObject var viewModel: AssetsViewModel
    let onHoldingTap: (AggregatedHoldingSnapshot) -> Void
    @State private var isExpanded: Bool = false
    @State private var showPieChart: Bool = false // 控制圓餅圖顯示（展開完成後才顯示）
    @State private var colorUpdateTrigger: UUID = UUID() // 用於觸發顏色重新計算
    
    // 計算屬性
    var categoryColor: Color {
        switch assetType {
        case .stockTW:
            return Color.stockTWColor // 使用14色中的深藍色
        case .stockUS:
            return Color.stockUSColor // 使用14色中的藍綠色
        case .crypto:
            return Color.cryptoColor // 使用14色中的深青綠色（較暗）
        case .cash:
            return Color.appPrimary // 預設
        }
    }
    
    /// 根據資產類型返回深色文字顏色
    private func textColorForAssetType(_ assetType: AssetType) -> Color {
        switch assetType {
        case .stockTW:
            return .stockTWDeepBlue
        case .stockUS:
            return .stockUSDeepGreen // 使用14色中的藍綠色
        case .crypto:
            return .cryptoDeepBrown // 使用14色中的深綠色
        case .cash:
            return .primaryText
        }
    }
    
    var categoryTitle: String {
        assetType.displayName
    }
    
    var categoryIcon: String {
        switch assetType {
        case .stockTW:
            return "chart.line.uptrend.xyaxis"
        case .stockUS:
            return "dollarsign.circle.fill"
        case .crypto:
            return "bitcoinsign.circle.fill"
        case .cash:
            return "banknote.fill"
        }
    }
    
    /// 生成漸變顏色（從深到淺）
    /// - Parameters:
    ///   - baseColor: 基礎顏色
    ///   - saturation: 飽和度比例（0.0 到 1.0，1.0 最深，0.0 最淺）
    /// - Returns: 調整後的顏色
    private func generateGradientColor(baseColor: Color, saturation: Double) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var currentSaturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getHue(&hue, saturation: &currentSaturation, brightness: &brightness, alpha: &alpha) {
            // 調整亮度：saturation 越低，亮度越高（顏色越淺）
            let adjustedBrightness = min(1.0, brightness + (1.0 - saturation) * 0.3)
            return Color(hue: Double(hue), saturation: Double(currentSaturation * saturation), brightness: adjustedBrightness, opacity: Double(alpha))
        }
        #endif
        // 如果無法獲取 HSB 值，使用簡化方案：調整透明度（但這不是最佳方案）
        return baseColor.opacity(0.5 + saturation * 0.5)
    }
    
    // 建立價格映射
    var priceMap: [String: AssetPriceSnapshot] {
        var map: [String: AssetPriceSnapshot] = [:]
        for snapshot in assetPriceSnapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            map[key] = snapshot
        }
        return map
    }
    
    // 計算總市值（台幣）
    var totalMarketValue: Decimal {
        // 使用即時匯率（未來從匯率服務獲取）
        let currentExchangeRate: Decimal = 32 // TODO: 從匯率服務獲取即時匯率
        var total: Decimal = 0
        
        for holding in aggregatedHoldings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            
            let marketValue = holding.totalQuantity * currentPrice
            
            // 使用即時匯率轉換為台幣
            if holding.currency == .TWD {
                total += marketValue
            } else if holding.currency == .USD {
                total += marketValue * currentExchangeRate
            }
        }
        
        return total
    }
    
    // 計算總成本（台幣）
    var totalCost: Decimal {
        // 注意：這裡應該使用購買時匯率，但為了簡化暫時使用即時匯率
        // TODO: 未來應該從 FIFOLotSnapshot.exchangeRate 計算準確的總成本（台幣）
        let currentExchangeRate: Decimal = 32 // TODO: 從匯率服務獲取即時匯率（臨時使用）
        var total: Decimal = 0
        
        for holding in aggregatedHoldings {
            // 轉換為台幣（注意：應該使用購買時匯率，但暫時使用即時匯率）
            if holding.currency == .TWD {
                total += holding.totalCost
            } else if holding.currency == .USD {
                total += holding.totalCost * currentExchangeRate
            }
        }
        
        return total
    }
    
    // 計算未實現損益（台幣）
    var unrealizedGainLoss: Decimal {
        totalMarketValue - totalCost
    }
    
    // 計算未實現損益百分比
    var unrealizedGainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (unrealizedGainLoss / totalCost) * 100
    }
    
    // 計算圓餅圖數據（每個持股的市值和比例）
    var pieChartData: [PieChartDataItem] {
        let _ = colorUpdateTrigger // 觸發重新計算
        // 使用即時匯率（未來從匯率服務獲取）
        let currentExchangeRate: Decimal = 32 // TODO: 從匯率服務獲取即時匯率
        var items: [PieChartDataItem] = []
        
        for holding in aggregatedHoldings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            
            let marketValue = holding.totalQuantity * currentPrice
            
            // 使用即時匯率轉換為台幣
            let marketValueTWD: Decimal
            if holding.currency == .TWD {
                marketValueTWD = marketValue
            } else if holding.currency == .USD {
                marketValueTWD = marketValue * currentExchangeRate
            } else {
                continue
            }
            
            // 獲取顯示名稱（台股用 name，其他用 symbol）
            let displayName: String
            if holding.assetType == .stockTW, let name = holding.name, !name.isEmpty {
                displayName = name
            } else {
                displayName = holding.symbol
            }
            
            items.append(PieChartDataItem(
                symbol: holding.symbol,
                name: displayName,
                marketValue: marketValueTWD,
                color: categoryColor // 暫時使用 categoryColor，後面會重新分配漸變顏色
            ))
        }
        
        // 按市值排序（從大到小）
        let sortedItems = items.sorted { $0.marketValue > $1.marketValue }
        
        // 為排序後的項目分配顏色（優先檢查自定義顏色，否則使用14色配色系統）
        var coloredItems: [PieChartDataItem] = []
        for (index, item) in sortedItems.enumerated() {
            // 優先檢查是否有自定義顏色（通過 UserDefaults 儲存的顏色）
            let keyString = "\(assetType.rawValue)_\(item.symbol)"
            let hasCustomColor = UserDefaults.standard.data(forKey: keyString) != nil
            
            // 如果有自定義顏色，使用自定義顏色；否則使用14色配色系統
            let finalColor: Color
            if hasCustomColor {
                finalColor = HoldingColorPreferences.getColor(for: item.symbol, assetType: assetType)
            } else {
                // 使用14色配色系統，從大到小輪流分配
                let colorIndex = index % Color.pieChartColors.count
                finalColor = Color.pieChartColors[colorIndex]
            }
            
            coloredItems.append(PieChartDataItem(
                symbol: item.symbol,
                name: item.name,
                marketValue: item.marketValue,
                color: finalColor
            ))
        }
        
        return coloredItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題欄（可點擊展開/縮合）
            Button(action: {
                if isExpanded {
                    // 縮合時，立即隱藏圓餅圖
                    showPieChart = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } else {
                    // 展開時，先展開內容，然後再顯示圓餅圖
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                    // 展開動畫完成後（約0.4秒），再開始圓餅圖動畫
                    Task {
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4秒
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            showPieChart = true
                        }
                    }
                }
            }) {
                HStack {
                    // 圖標
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: categoryIcon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryTitle)
                            .font(.headline)
                            .foregroundColor(textColorForAssetType(assetType))
                        
                        Text("\(aggregatedHoldings.count)檔")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    // 總市值和損益
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(totalMarketValue.formatted(currency: .TWD))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textColorForAssetType(assetType))
                        
                        HStack(spacing: 4) {
                            Image(systemName: unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text(unrealizedGainLoss.formatted(currency: .TWD))
                            Text("(\(unrealizedGainLossPercent.formatted(fractionDigits: 1))%)")
                        }
                        .font(.caption)
                        .foregroundColor(unrealizedGainLossPercent > 0 ? .profitGreen : (unrealizedGainLossPercent < 0 ? .lossRed : .primaryText))
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展開內容（Phase 2.3 和 2.4 會實作圓餅圖和持股列表）
            if isExpanded {
                VStack(spacing: 16) {
                    // Phase 2.3 - 圓餅圖（展開完成後才顯示並動畫）
                    if !pieChartData.isEmpty && showPieChart {
                        CategoryPieChart(data: pieChartData, totalMarketValue: totalMarketValue)
                            .frame(height: 200)
                            .padding(.vertical, 8)
                            .opacity(showPieChart ? 1 : 0)
                            .scaleEffect(showPieChart ? 1 : 0.8)
                    }
                    
                    // Phase 2.4 - 持股列表（帶顏色選擇）
                    CategoryHoldingsList(
                        pieChartData: pieChartData,
                        assetType: assetType,
                        totalMarketValue: totalMarketValue,
                        onColorChanged: {
                            // 顏色改變時觸發重新計算
                            colorUpdateTrigger = UUID()
                        },
                        onHoldingTap: { item in
                            // 找到對應的 AggregatedHoldingSnapshot 並導航
                            if let holding = aggregatedHoldings.first(where: { $0.symbol == item.symbol && $0.assetType == assetType }) {
                                onHoldingTap(holding)
                            }
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 圓餅圖數據項
struct PieChartDataItem: Identifiable {
    let id: String // symbol
    let symbol: String
    let name: String // 顯示名稱
    let marketValue: Decimal // 市值（台幣）
    let color: Color
    
    init(symbol: String, name: String, marketValue: Decimal, color: Color) {
        self.id = symbol
        self.symbol = symbol
        self.name = name
        self.marketValue = marketValue
        self.color = color
    }
    
    // 轉換為 Double（用於 Charts）
    var value: Double {
        NSDecimalNumber(decimal: marketValue).doubleValue
    }
}

// MARK: - 類別圓餅圖
struct CategoryPieChart: View {
    let data: [PieChartDataItem]
    let totalMarketValue: Decimal
    @State private var selectedItem: PieChartDataItem?
    @State private var selectedAngle: Double?
    @State private var pieChartRotation: Double = 0 // 圓餅圖旋轉角度（從0度開始）
    @State private var pieChartOpacity: Double = 0 // 圓餅圖透明度（從0開始）
    
    var body: some View {
        VStack(spacing: 12) {
            pieChartView
            selectedItemDetailView
        }
        .onAppear {
            initializeSelectedAngle()
            // 圓餅圖從0度開始像扇子一樣展開的動畫（更流暢）
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                pieChartRotation = 360
                pieChartOpacity = 1
            }
        }
    }
    
    // MARK: - 圓餅圖視圖
    private var pieChartView: some View {
        Chart {
            ForEach(data) { item in
                SectorMark(
                    angle: .value("市值", item.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(selectedItem?.id == item.id ? item.color.opacity(0.7) : item.color)
                .annotation(position: .overlay) {
                    if shouldShowLabel(for: item) {
                        Text(item.name)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 200)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { oldValue, newValue in
            handleAngleChange(newValue)
        }
        .opacity(pieChartOpacity)
        .rotationEffect(.degrees(pieChartRotation))
        .scaleEffect(pieChartOpacity) // 同時使用縮放效果讓動畫更流暢
    }
    
    // MARK: - 選中項目詳細信息視圖
    @ViewBuilder
    private var selectedItemDetailView: some View {
        if let selected = selectedItem {
            VStack(spacing: 6) {
                Text(selected.name)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                HStack(spacing: 12) {
                    Text(selected.marketValue.formatted(currency: .TWD))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(percentageText(for: selected))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cardBackground)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    // MARK: - 輔助方法
    /// 檢查是否應該顯示標籤
    private func shouldShowLabel(for item: PieChartDataItem) -> Bool {
        let totalDouble = NSDecimalNumber(decimal: totalMarketValue).doubleValue
        let ratio = item.value / totalDouble
        return ratio > 0.05
    }
    
    /// 計算百分比文字
    private func percentageText(for item: PieChartDataItem) -> String {
        let totalDouble = NSDecimalNumber(decimal: totalMarketValue).doubleValue
        let percentageDouble = (item.value / totalDouble * 100)
        let percentageDecimal = Decimal(percentageDouble)
        let formatted = percentageDecimal.formatted(fractionDigits: 1)
        return "(\(formatted)%)"
    }
    
    /// 處理角度變化
    private func handleAngleChange(_ angle: Double?) {
        if let angle = angle {
            updateSelectedItem(from: angle)
        } else {
            selectedItem = nil
        }
    }
    
    /// 初始化選中角度
    private func initializeSelectedAngle() {
        guard let selected = selectedItem,
              let index = data.firstIndex(where: { $0.id == selected.id }) else {
            return
        }
        
        var startAngle: Double = -90
        let totalDouble = NSDecimalNumber(decimal: totalMarketValue).doubleValue
        
        for i in 0..<index {
            let ratio = data[i].value / totalDouble
            startAngle += ratio * 360
        }
        
        let selectedRatio = selected.value / totalDouble
        selectedAngle = startAngle + (selectedRatio * 360 / 2)
    }
    
    /// 根據角度更新選中的項目
    private func updateSelectedItem(from angle: Double) {
        var normalizedAngle = angle
        // 正規化角度到 -90 到 270 之間
        while normalizedAngle < -90 {
            normalizedAngle += 360
        }
        while normalizedAngle >= 270 {
            normalizedAngle -= 360
        }
        
        let totalDouble = NSDecimalNumber(decimal: totalMarketValue).doubleValue
        var currentAngle: Double = -90
        
        for item in data {
            let ratio = item.value / totalDouble
            let itemSpan = ratio * 360
            if normalizedAngle >= currentAngle && normalizedAngle < currentAngle + itemSpan {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedItem = item
                }
                return
            }
            currentAngle += itemSpan
        }
        selectedItem = nil
    }
}

// MARK: - 統計行
struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primaryText
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 所有持股區塊（Phase 3）
struct AllHoldingsSection: View {
    let aggregatedHoldings: [AggregatedHoldingSnapshot]
    let assetPriceSnapshots: [AssetPriceSnapshot]
    let totalAssets: Decimal
    let totalInvestments: Decimal
    let onHoldingTap: (AggregatedHoldingSnapshot) -> Void
    
    @State private var ratioType: HoldingRatioType = HoldingRatioPreference.get()
    @State private var showOriginalCurrency: Bool = false // false = 台幣, true = 原幣
    
    // 計算所有持股的市值（台幣）
    var allHoldingsData: [AllHoldingItem] {
        // 使用即時匯率（未來從匯率服務獲取）
        // 注意：這裡應該使用與 AssetsViewModel 相同的即時匯率
        // 目前使用固定模擬值，未來需要統一從匯率服務獲取
        let currentExchangeRate: Decimal = 32 // TODO: 從匯率服務獲取即時匯率
        var items: [AllHoldingItem] = []
        var priceMap: [String: AssetPriceSnapshot] = [:]
        
        // 建立價格映射
        for snapshot in assetPriceSnapshots {
            let key = "\(snapshot.assetType.rawValue)_\(snapshot.symbol)"
            priceMap[key] = snapshot
        }
        
        for holding in aggregatedHoldings {
            let key = "\(holding.assetType.rawValue)_\(holding.symbol)"
            guard let priceSnapshot = priceMap[key],
                  let currentPrice = priceSnapshot.displayPrice else { continue }
            
            // 計算市值（原幣）
            let marketValue = holding.totalQuantity * currentPrice
            
            // 使用即時匯率轉換市值為台幣
            let marketValueTWD: Decimal
            if holding.currency == .TWD {
                marketValueTWD = marketValue
            } else if holding.currency == .USD {
                marketValueTWD = marketValue * currentExchangeRate
            } else {
                continue
            }
            
            // 計算總成本（台幣）
            // 注意：totalCost 在 AggregatedHoldingSnapshot 中已使用購買時匯率計算
            // 但這裡需要轉換為台幣顯示，所以需要知道購買時的匯率
            // 由於 AggregatedHoldingSnapshot.totalCost 已經是原幣的總成本，
            // 我們需要根據 FIFO lots 中的 exchangeRate 來轉換，或者使用即時匯率作為近似值
            // 為了準確性，應該使用購買時匯率，但為了簡化，暫時使用即時匯率
            // TODO: 未來應該從 FIFOLotSnapshot.exchangeRate 計算準確的總成本（台幣）
            let totalCostTWD: Decimal
            if holding.currency == .TWD {
                totalCostTWD = holding.totalCost
            } else if holding.currency == .USD {
                // 注意：這裡應該使用購買時匯率，但為了簡化暫時使用即時匯率
                // 未來需要從 FIFOLotSnapshot.exchangeRate 計算
                totalCostTWD = holding.totalCost * currentExchangeRate
            } else {
                continue
            }
            
            // 計算未實現損益（台幣）
            let unrealizedGainLoss = marketValueTWD - totalCostTWD
            
            // 計算未實現損益百分比
            let unrealizedGainLossPercent: Decimal = totalCostTWD > 0 ? (unrealizedGainLoss / totalCostTWD) * 100 : 0
            
            // 計算佔比（根據選擇的類型）
            let ratio: Decimal
            if ratioType == .totalAssets {
                ratio = totalAssets > 0 ? (marketValueTWD / totalAssets) * 100 : 0
            } else {
                ratio = totalInvestments > 0 ? (marketValueTWD / totalInvestments) * 100 : 0
            }
            
            // 獲取顯示名稱
            let displayName: String
            if holding.assetType == .stockTW, let name = holding.name, !name.isEmpty {
                displayName = name
            } else {
                displayName = holding.symbol
            }
            
            items.append(AllHoldingItem(
                aggregatedHolding: holding,
                displayName: displayName,
                marketValue: marketValueTWD,
                totalCost: totalCostTWD,
                unrealizedGainLoss: unrealizedGainLoss,
                unrealizedGainLossPercent: unrealizedGainLossPercent,
                ratio: ratio,
                currentPrice: currentPrice,
                currency: holding.currency
            ))
        }
        
        // 按市值排序（從大到小）
        return items.sorted { $0.marketValue > $1.marketValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題和切換按鈕
            HStack {
                Text("所有持股")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // 總資產/總投資佔比切換按鈕
                    Button(action: {
                        let newType: HoldingRatioType = ratioType == .totalAssets ? .totalInvestments : .totalAssets
                        ratioType = newType
                        HoldingRatioPreference.set(newType)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: ratioType == .totalAssets ? "chart.pie.fill" : "chart.bar.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(ratioType.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 台幣/原幣切換按鈕
                    Button(action: {
                        showOriginalCurrency.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showOriginalCurrency ? "arrow.triangle.2.circlepath" : "dollarsign.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(showOriginalCurrency ? "原幣" : "台幣")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            // 持股列表（使用 ratioType 和 displayCurrency 作為 id，確保切換時重新渲染）
            VStack(spacing: 12) {
                ForEach(allHoldingsData) { item in
                    AllHoldingCard(
                        item: item,
                        ratioType: ratioType,
                        showOriginalCurrency: showOriginalCurrency,
                        onTap: {
                            onHoldingTap(item.aggregatedHolding)
                        }
                    )
                }
            }
            .id("\(ratioType)_\(showOriginalCurrency)") // 當 ratioType 或 showOriginalCurrency 改變時，強制重新渲染
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 所有持股項目數據
struct AllHoldingItem: Identifiable {
    let id: String // 使用 aggregatedHolding 的 id
    let aggregatedHolding: AggregatedHoldingSnapshot
    let displayName: String
    let marketValue: Decimal // 市值（台幣）
    let totalCost: Decimal // 總成本（台幣）
    let unrealizedGainLoss: Decimal // 未實現損益（台幣）
    let unrealizedGainLossPercent: Decimal // 未實現損益百分比
    let ratio: Decimal // 佔比（根據選擇的類型）
    let currentPrice: Decimal // 當前價格（原幣）
    let currency: Currency // 原幣
    
    init(aggregatedHolding: AggregatedHoldingSnapshot,
         displayName: String,
         marketValue: Decimal,
         totalCost: Decimal,
         unrealizedGainLoss: Decimal,
         unrealizedGainLossPercent: Decimal,
         ratio: Decimal,
         currentPrice: Decimal,
         currency: Currency) {
        self.id = aggregatedHolding.id
        self.aggregatedHolding = aggregatedHolding
        self.displayName = displayName
        self.marketValue = marketValue
        self.totalCost = totalCost
        self.unrealizedGainLoss = unrealizedGainLoss
        self.unrealizedGainLossPercent = unrealizedGainLossPercent
        self.ratio = ratio
        self.currentPrice = currentPrice
        self.currency = currency
    }
}

// MARK: - 所有持股卡片
struct AllHoldingCard: View {
    let item: AllHoldingItem
    let ratioType: HoldingRatioType
    let showOriginalCurrency: Bool // false = 台幣, true = 原幣
    let onTap: () -> Void
    
    // 獲取固定顏色（根據資產類型，使用14色中的顏色）
    var holdingColor: Color {
        switch item.aggregatedHolding.assetType {
        case .stockTW:
            return Color.stockTWColor // 使用14色中的深藍色
        case .stockUS:
            return Color.stockUSColor // 使用14色中的藍綠色
        case .crypto:
            return Color.cryptoColor // 使用14色中的深青綠色（較暗）
        case .cash:
            return Color.appPrimary // 預設
        }
    }
    
    /// 根據資產類型返回文字顏色
    private func textColorForAssetType(_ assetType: AssetType) -> Color {
        switch assetType {
        case .stockTW:
            return .stockTWDeepBlue
        case .stockUS:
            return .stockUSDeepGreen // 使用14色中的藍綠色
        case .crypto:
            return .cryptoDeepBrown // 使用14色中的深綠色
        case .cash:
            return .primaryText
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 圓形比例圖標
                ZStack {
                    Circle()
                        .stroke(holdingColor.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, NSDecimalNumber(decimal: item.ratio / 100).doubleValue)))
                        .stroke(holdingColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(item.ratio.formatted(fractionDigits: 1))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                }
                
                // 持股信息（只顯示名稱）
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                        .foregroundColor(textColorForAssetType(item.aggregatedHolding.assetType))
                }
                
                Spacer()
                
                // 市值和損益（根據 showOriginalCurrency 顯示）
                VStack(alignment: .trailing, spacing: 4) {
                    // 根據 showOriginalCurrency 決定顯示台幣還是原幣
                    if showOriginalCurrency {
                        // 顯示原幣市值
                        let originalMarketValue = item.aggregatedHolding.totalQuantity * item.currentPrice
                        Text(originalMarketValue.formatted(currency: item.currency))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textColorForAssetType(item.aggregatedHolding.assetType))
                    } else {
                        Text(item.marketValue.formatted(currency: .TWD))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textColorForAssetType(item.aggregatedHolding.assetType))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: item.unrealizedGainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        if showOriginalCurrency {
                            // 顯示原幣損益
                            let originalCost = item.aggregatedHolding.totalCost
                            let originalMarketValue = item.aggregatedHolding.totalQuantity * item.currentPrice
                            let originalGainLoss = originalMarketValue - originalCost
                            let originalGainLossPercent: Decimal = originalCost > 0 ? (originalGainLoss / originalCost) * 100 : 0
                            Text(originalGainLoss.formatted(currency: item.currency))
                                .font(.caption)
                            Text("(\(originalGainLossPercent.formatted(fractionDigits: 1))%)")
                                .font(.caption)
                        } else {
                            Text(item.unrealizedGainLoss.formatted(currency: .TWD))
                                .font(.caption)
                            Text("(\(item.unrealizedGainLossPercent.formatted(fractionDigits: 1))%)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(item.unrealizedGainLoss >= 0 ? .profitGreen : .lossRed)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                // 左側色條
                HStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(holdingColor)
                        .frame(width: 4)
                    Spacer()
                }
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 類別持股列表（Phase 2.4）
struct CategoryHoldingsList: View {
    let pieChartData: [PieChartDataItem]
    let assetType: AssetType
    let totalMarketValue: Decimal
    let onColorChanged: () -> Void
    let onHoldingTap: (PieChartDataItem) -> Void
    @State private var selectedItemForColor: PieChartDataItem?
    @State private var isHoldingsExpanded: Bool = false
    @State private var holdingsHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題欄（包含展開/收起按鈕）
            HStack {
                Text("持股列表")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isHoldingsExpanded.toggle()
                    }
                }) {
                    Image(systemName: isHoldingsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondaryBackground)
            .cornerRadius(8)
            .padding(.bottom, 8)
            
            // 持股列表內容（可滾動，固定高度）
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(pieChartData) { item in
                            CategoryHoldingRow(
                                item: item,
                                assetType: assetType,
                                totalMarketValue: totalMarketValue,
                                isColorPickerVisible: selectedItemForColor?.id == item.id,
                                onColorCircleTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedItemForColor?.id == item.id {
                                            selectedItemForColor = nil
                                        } else {
                                            selectedItemForColor = item
                                        }
                                    }
                                },
                                onHoldingTap: {
                                    onHoldingTap(item)
                                },
                                onColorSelected: { color in
                                    HoldingColorPreferences.setColor(color, for: item.symbol, assetType: assetType)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedItemForColor = nil
                                    }
                                    // 通知父視圖顏色已改變
                                    onColorChanged()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 16)
                }
                
                // 收起時的漸層遮罩（不阻擋滑動）
                if !isHoldingsExpanded {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color.cardBackground],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                        .allowsHitTesting(false)
                    }
                    .frame(height: 200)
                }
            }
            .frame(height: holdingsHeight)
            .clipped()
            .onChange(of: isHoldingsExpanded) { _, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    holdingsHeight = newValue ? 600 : 200
                }
            }
            .onAppear {
                holdingsHeight = isHoldingsExpanded ? 600 : 200
            }
        }
    }
}

// MARK: - 類別持股行
struct CategoryHoldingRow: View {
    let item: PieChartDataItem
    let assetType: AssetType
    let totalMarketValue: Decimal
    let isColorPickerVisible: Bool
    let onColorCircleTap: () -> Void
    let onHoldingTap: () -> Void
    let onColorSelected: (Color) -> Void
    @State private var colorUpdateId: UUID = UUID() // 用於觸發顏色更新
    
    // 獲取當前顏色（優先使用自定義顏色，否則使用圓餅圖中的顏色）
    var currentColor: Color {
        let _ = colorUpdateId // 觸發重新計算
        // 優先檢查是否有自定義顏色
        let keyString = "\(assetType.rawValue)_\(item.symbol)"
        if UserDefaults.standard.data(forKey: keyString) != nil {
            return HoldingColorPreferences.getColor(for: item.symbol, assetType: assetType)
        }
        // 否則使用圓餅圖中的顏色
        return item.color
    }
    
    // 預定義顏色選項（14色配色系統）
    private let colorOptions: [ColorOption] = [
        ColorOption(id: 0, color: Color.blue1),           // #0D2235
        ColorOption(id: 1, color: Color.blue2),           // #132A42
        ColorOption(id: 2, color: Color.blue3),           // #1B3C59
        ColorOption(id: 3, color: Color.blue4),           // #1D4C6A
        ColorOption(id: 4, color: Color.blueGreen1),      // #1F6A8A
        ColorOption(id: 5, color: Color.blueGreen2),      // #2A87A6
        ColorOption(id: 6, color: Color.blueGreen3),     // #36A2C6
        ColorOption(id: 7, color: Color.blueGreen4),      // #5FBBD5
        ColorOption(id: 8, color: Color.green1),           // #8AC0B3
        ColorOption(id: 9, color: Color.green2),           // #4CA19E
        ColorOption(id: 10, color: Color.green3),          // #358077
        ColorOption(id: 11, color: Color.green4),         // #1F6E5F
        ColorOption(id: 12, color: Color.green5),         // #1B4D3E
        ColorOption(id: 13, color: Color.bluePale)        // #DBEBF1
    ]
    
    struct ColorOption: Identifiable {
        let id: Int
        let color: Color
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 顏色圓圈（可點擊，更小）
                Button(action: onColorCircleTap) {
                    Circle()
                        .fill(currentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(isColorPickerVisible ? Color.appPrimary : Color.primary.opacity(0.2), lineWidth: isColorPickerVisible ? 2.5 : 1)
                        )
                        .padding(2) // 添加內邊距避免邊框被切
                }
                .buttonStyle(PlainButtonStyle())
                
                // 持股信息（可點擊導航）- 大字比例，小字金額
                Button(action: onHoldingTap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .foregroundColor(.primaryText) // 持股列表卡片字體顏色為黑色
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            // 大字顯示比例
                            Text(percentageText(for: item))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primaryText) // 持股列表卡片字體顏色為黑色
                            
                            // 小字顯示金額
                            Text(item.marketValue.formatted(currency: .TWD))
                                .font(.caption)
                                .foregroundColor(.primaryText) // 持股列表卡片字體顏色為黑色
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
            
            // 顏色選擇器（內聯顯示）
            if isColorPickerVisible {
                InlineColorPicker(
                    currentColor: currentColor,
                    colorOptions: colorOptions,
                    onColorSelected: { color in
                        // 保存自定義顏色
                        HoldingColorPreferences.setColor(color, for: item.symbol, assetType: assetType)
                        // 觸發顏色更新
                        colorUpdateId = UUID()
                        // 通知父視圖顏色已改變
                        onColorSelected(color)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    /// 計算百分比文字（不包含括號）
    private func percentageText(for item: PieChartDataItem) -> String {
        let totalDouble = NSDecimalNumber(decimal: totalMarketValue).doubleValue
        let percentageDouble = (item.value / totalDouble * 100)
        let percentageDecimal = Decimal(percentageDouble)
        let formatted = percentageDecimal.formatted(fractionDigits: 1)
        return "\(formatted)%"
    }
    
    /// 根據資產類型返回文字顏色
    private func textColorForAssetType(_ assetType: AssetType) -> Color {
        switch assetType {
        case .stockTW:
            return .stockTWDeepBlue
        case .stockUS:
            return .stockUSDeepGreen
        case .crypto:
            return .cryptoDeepBrown
        case .cash:
            return .primaryText
        }
    }
}

// MARK: - 內聯顏色選擇器
struct InlineColorPicker: View {
    let currentColor: Color
    let colorOptions: [CategoryHoldingRow.ColorOption]
    let onColorSelected: (Color) -> Void
    
    var body: some View {
        // 顏色選項（水平排列）
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(colorOptions) { option in
                    Button(action: {
                        onColorSelected(option.color)
                    }) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 24, height: 24) // 更小的圓圈
                            .overlay(
                                Circle()
                                    .stroke(isSelected(option.color) ? Color.appPrimary : Color.clear, lineWidth: 2.5)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                            .padding(2) // 添加內邊距避免邊框被切
                            .shadow(color: isSelected(option.color) ? option.color.opacity(0.3) : .clear, radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
        )
    }
    
    /// 檢查顏色是否被選中（用於顯示邊框）
    private func isSelected(_ color: Color) -> Bool {
        #if canImport(UIKit)
        let uiCurrent = UIColor(currentColor)
        let uiColor = UIColor(color)
        
        var currentRed: CGFloat = 0, currentGreen: CGFloat = 0, currentBlue: CGFloat = 0, currentAlpha: CGFloat = 0
        var colorRed: CGFloat = 0, colorGreen: CGFloat = 0, colorBlue: CGFloat = 0, colorAlpha: CGFloat = 0
        
        if uiCurrent.getRed(&currentRed, green: &currentGreen, blue: &currentBlue, alpha: &currentAlpha) &&
           uiColor.getRed(&colorRed, green: &colorGreen, blue: &colorBlue, alpha: &colorAlpha) {
            return abs(currentRed - colorRed) < 0.01 &&
                   abs(currentGreen - colorGreen) < 0.01 &&
                   abs(currentBlue - colorBlue) < 0.01
        }
        #endif
        return false
    }
}

// MARK: - 顏色選擇器 Sheet
struct ColorPickerSheet: View {
    let symbol: String
    let assetType: AssetType
    let currentColor: Color
    let onColorSelected: (Color) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: Color
    
    // 預定義顏色選項（使用 Identifiable 結構）
    struct ColorOption: Identifiable {
        let id: Int
        let color: Color
    }
    
    let colorOptions: [ColorOption] = [
        ColorOption(id: 0, color: Color.blue1),           // #0D2235
        ColorOption(id: 1, color: Color.blue2),           // #132A42
        ColorOption(id: 2, color: Color.blue3),           // #1B3C59
        ColorOption(id: 3, color: Color.blue4),           // #1D4C6A
        ColorOption(id: 4, color: Color.blueGreen1),      // #1F6A8A
        ColorOption(id: 5, color: Color.blueGreen2),      // #2A87A6
        ColorOption(id: 6, color: Color.blueGreen3),     // #36A2C6
        ColorOption(id: 7, color: Color.blueGreen4),      // #5FBBD5
        ColorOption(id: 8, color: Color.green1),           // #8AC0B3
        ColorOption(id: 9, color: Color.green2),           // #4CA19E
        ColorOption(id: 10, color: Color.green3),          // #358077
        ColorOption(id: 11, color: Color.green4),         // #1F6E5F
        ColorOption(id: 12, color: Color.green5),         // #1B4D3E
        ColorOption(id: 13, color: Color.bluePale)        // #DBEBF1
    ]
    
    init(symbol: String, assetType: AssetType, currentColor: Color, onColorSelected: @escaping (Color) -> Void) {
        self.symbol = symbol
        self.assetType = assetType
        self.currentColor = currentColor
        self.onColorSelected = onColorSelected
        self._selectedColor = State(initialValue: currentColor)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 標題
                VStack(spacing: 8) {
                    Text("選擇顏色")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text(symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding(.top, 24)
                
                // 當前顏色預覽
                VStack(spacing: 12) {
                    Text("當前選擇")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                        )
                }
                .padding(.vertical, 16)
                
                // 顏色選項網格
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                        ForEach(colorOptions) { option in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedColor = option.color
                                }
                            }) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected(option.color) ? Color.appPrimary : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: isSelected(option.color) ? option.color.opacity(0.3) : .clear, radius: 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // 確認按鈕
                Button(action: {
                    onColorSelected(selectedColor)
                    dismiss()
                }) {
                    Text("確認")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.mainBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
    }
    
    /// 檢查顏色是否被選中
    private func isSelected(_ color: Color) -> Bool {
        // 通過比較 RGB 值來判斷
        #if canImport(UIKit)
        let uiSelected = UIColor(selectedColor)
        let uiColor = UIColor(color)
        
        var selectedRed: CGFloat = 0, selectedGreen: CGFloat = 0, selectedBlue: CGFloat = 0, selectedAlpha: CGFloat = 0
        var colorRed: CGFloat = 0, colorGreen: CGFloat = 0, colorBlue: CGFloat = 0, colorAlpha: CGFloat = 0
        
        if uiSelected.getRed(&selectedRed, green: &selectedGreen, blue: &selectedBlue, alpha: &selectedAlpha) &&
           uiColor.getRed(&colorRed, green: &colorGreen, blue: &colorBlue, alpha: &colorAlpha) {
            return abs(selectedRed - colorRed) < 0.01 &&
                   abs(selectedGreen - colorGreen) < 0.01 &&
                   abs(selectedBlue - colorBlue) < 0.01
        }
        #endif
        return false
    }
}

#Preview {
    AssetsView()
}

