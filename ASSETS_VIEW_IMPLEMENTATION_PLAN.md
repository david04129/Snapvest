# 資產分頁實作計劃

## 1. 設計確認總結

### ✅ 已確認的設計決策：

1. **市值、損益不存快照**（動態計算）
   - 快照只儲存原幣資料（數量、成本）
   - 市值、損益 = `AggregatedHoldingSnapshot` + `AssetPriceSnapshot.currentPrice` + `ExchangeRate.currentRate`

2. **跨幣交易匯率儲存**（已存在於 Transaction.exchangeRate）
   - `Transaction.exchangeRate`：交易時的匯率（固定值，不會變）
   - 用於計算買入成本、損益來源分析

3. **FIFO 批次採用快照模式**
   - 儲存在 `AggregatedHoldingSnapshot.fifoLotsByAccount`
   - 分帳戶計算（不是跨帳戶合併）

4. **快照更新時機**
   - 交易變動時：更新相關快照
   - 匯率/價格更新：不需要更新持股快照（只更新價格/匯率快照）

---

## 2. 需要新增的資料結構

### 2.1 AggregatedHoldingSnapshot（跨帳戶合併持股快照）

**檔案**：`Snapvest/Snapvest/Models/AggregatedHoldingSnapshot.swift`（新建）

```swift
import Foundation

/// 跨帳戶合併持股快照（每個使用者每檔股票一個快照）
struct AggregatedHoldingSnapshot: Identifiable, Codable, Equatable {
    /// 唯一識別（使用 userId + assetType + symbol）
    var id: String {
        "\(userId)_\(assetType.rawValue)_\(symbol)"
    }
    
    let userId: String
    let assetType: AssetType
    let symbol: String
    
    // 基本資訊（從 AssetPriceSnapshot 同步）
    var name: String?
    var currency: Currency
    
    // 合併後的持股資訊（原幣，不依賴價格/匯率）
    var totalQuantity: Decimal       // 總數量（跨帳戶合併）
    var weightedAverageCost: Decimal // 加權平均成本（原幣）
    var totalCost: Decimal           // 總成本（原幣，totalQuantity * weightedAverageCost）
    
    // 來源帳戶資訊
    var sourceAccountIds: [String]   // 持有的帳戶ID列表
    
    // FIFO 批次快照（按帳戶分組）
    var fifoLotsByAccount: [FIFOLotsByAccountSnapshot]
    
    // 時間戳記
    var lastUpdated: Date
    var lastTransactionDate: Date?
    var version: Int
    
    init(
        userId: String,
        assetType: AssetType,
        symbol: String,
        name: String? = nil,
        currency: Currency,
        totalQuantity: Decimal,
        weightedAverageCost: Decimal,
        totalCost: Decimal,
        sourceAccountIds: [String] = [],
        fifoLotsByAccount: [FIFOLotsByAccountSnapshot] = [],
        lastUpdated: Date = Date(),
        lastTransactionDate: Date? = nil,
        version: Int = 1
    ) {
        self.userId = userId
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.currency = currency
        self.totalQuantity = totalQuantity
        self.weightedAverageCost = weightedAverageCost
        self.totalCost = totalCost
        self.sourceAccountIds = sourceAccountIds
        self.fifoLotsByAccount = fifoLotsByAccount
        self.lastUpdated = lastUpdated
        self.lastTransactionDate = lastTransactionDate
        self.version = version
    }
}
```

### 2.2 FIFOLotsByAccountSnapshot（按帳戶分組的 FIFO 批次快照）

**檔案**：`Snapvest/Snapvest/Models/AggregatedHoldingSnapshot.swift`（同一檔案）

```swift
/// 按帳戶分組的 FIFO 批次快照
struct FIFOLotsByAccountSnapshot: Identifiable, Codable, Equatable {
    let accountId: String
    let accountName: String
    var lots: [FIFOLotSnapshot]
    
    var id: String { accountId }
    
    init(accountId: String, accountName: String, lots: [FIFOLotSnapshot] = []) {
        self.accountId = accountId
        self.accountName = accountName
        self.lots = lots
    }
}
```

### 2.3 FIFOLotSnapshot（FIFO 批次快照）

**檔案**：`Snapvest/Snapvest/Models/AggregatedHoldingSnapshot.swift`（同一檔案）

```swift
/// FIFO 批次快照（儲存在 AggregatedHoldingSnapshot 中）
struct FIFOLotSnapshot: Identifiable, Codable, Equatable {
    let id: String              // Transaction ID（買入交易的 ID）
    let accountId: String       // 帳戶ID
    let accountName: String     // 券商名稱（Account.name）
    let buyDate: Date          // 買入日期
    var remainingQuantity: Decimal  // 剩餘數量（FIFO 計算後）
    var costPerUnit: Decimal   // 單位成本（原幣，Transaction.totalAmountWithFee / Transaction.quantity）
    var currency: Currency     // 貨幣
    var exchangeRate: Decimal? // 買入時的匯率（跨幣交易時使用，固定值）
    
    init(
        id: String,
        accountId: String,
        accountName: String,
        buyDate: Date,
        remainingQuantity: Decimal,
        costPerUnit: Decimal,
        currency: Currency,
        exchangeRate: Decimal? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.accountName = accountName
        self.buyDate = buyDate
        self.remainingQuantity = remainingQuantity
        self.costPerUnit = costPerUnit
        self.currency = currency
        self.exchangeRate = exchangeRate
    }
    
    /// 總成本（原幣）
    var totalCost: Decimal {
        remainingQuantity * costPerUnit
    }
}
```

---

## 3. 需要新增的服務方法

### 3.1 DataService 擴展（AggregatedHoldingSnapshot CRUD）

**檔案**：`Snapvest/Snapvest/Services/DataService.swift`

```swift
protocol DataServiceProtocol {
    // ... 現有方法 ...
    
    // 跨帳戶合併持股快照
    func fetchAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws -> AggregatedHoldingSnapshot?
    func fetchAggregatedHoldingSnapshots(userId: String, assetType: AssetType?) async throws -> [AggregatedHoldingSnapshot]
    func saveAggregatedHoldingSnapshot(_ snapshot: AggregatedHoldingSnapshot) async throws
    func deleteAggregatedHoldingSnapshot(userId: String, assetType: AssetType, symbol: String) async throws
}
```

### 3.2 HoldingCalculator 擴展（計算 AggregatedHoldingSnapshot）

**檔案**：`Snapvest/Snapvest/Services/HoldingCalculator.swift`

```swift
extension HoldingCalculator {
    /// 計算跨帳戶合併持股快照（從所有 AccountSnapshot 合併）
    static func calculateAggregatedHoldings(
        userId: String,
        accountSnapshots: [AccountSnapshot],
        accounts: [Account],
        assetPriceSnapshots: [AssetPriceSnapshot]
    ) -> [AggregatedHoldingSnapshot]
    
    /// 計算單一股票的跨帳戶合併快照
    static func calculateAggregatedHolding(
        userId: String,
        assetType: AssetType,
        symbol: String,
        accountSnapshots: [AccountSnapshot],
        accounts: [Account],
        assetPriceSnapshot: AssetPriceSnapshot?,
        transactions: [Transaction]
    ) -> AggregatedHoldingSnapshot?
}
```

---

## 4. 需要新增的 UI 組件

### 4.1 類別總覽卡片（展開/縮合）

**檔案**：`Snapvest/Snapvest/Views/AssetsView.swift`

- 縮合狀態：總市值（台幣）、總未實現損益及％數
- 展開狀態：圓餅圖（各持股佔該類別總市值的比例）、持股列表
- 顏色：台股藍色、美股綠色、加密貨幣黃橘色

### 4.2 所有持股列表（新增切換按鈕）

**檔案**：`Snapvest/Snapvest/Views/AssetsView.swift`

- 標題旁邊新增切換按鈕：「總資產佔比」/「總投資佔比」
- 按鈕設計：美觀優化（使用 CardView 或 Toggle 樣式）
- 圓圈比例圖：
  - 選擇「總資產佔比」時：顯示該股票市值佔總資產的佔比
  - 選擇「總投資佔比」時：顯示該股票市值佔總投資的佔比

### 4.3 持股詳細頁面

**檔案**：`Snapvest/Snapvest/Views/HoldingDetailView.swift`（新建）

- 頂部：跨帳戶合併總覽（總數量、加權平均成本、總市值、總未實現損益）
- 底部：按帳戶分組的 FIFO 批次表格
- 損益來源分析（市價損益、匯率損益）
- 買入/賣出按鈕（暫時為佔位符）

---

## 5. 需要新增的 UserDefaults 管理

### 5.1 顏色偏好管理

**檔案**：`Snapvest/Snapvest/Utilities/HoldingColorPreferences.swift`（新建）

```swift
import SwiftUI

struct HoldingColorPreferences {
    private static let key = "holdingColorPreferences"
    
    static func getColor(for symbol: String, assetType: AssetType) -> Color {
        // 從 UserDefaults 讀取
        // 如果沒有，返回預設顏色（依 assetType）
    }
    
    static func setColor(_ color: Color, for symbol: String, assetType: AssetType) {
        // 儲存到 UserDefaults
    }
}
```

### 5.2 佔比顯示偏好

**檔案**：`Snapvest/Snapvest/Utilities/HoldingRatioPreference.swift`（新建）

```swift
enum HoldingRatioType: String, Codable {
    case totalAssets = "totalAssets"    // 總資產佔比
    case totalInvestments = "totalInvestments"  // 總投資佔比
}

struct HoldingRatioPreference {
    private static let key = "holdingRatioPreference"
    
    static func get() -> HoldingRatioType {
        // 從 UserDefaults 讀取，預設為 totalAssets
    }
    
    static func set(_ type: HoldingRatioType) {
        // 儲存到 UserDefaults
    }
}
```

---

## 6. 需要修改的檔案

### 6.1 新建檔案

1. `Snapvest/Snapvest/Models/AggregatedHoldingSnapshot.swift`
2. `Snapvest/Snapvest/Views/HoldingDetailView.swift`
3. `Snapvest/Snapvest/Utilities/HoldingColorPreferences.swift`
4. `Snapvest/Snapvest/Utilities/HoldingRatioPreference.swift`

### 6.2 修改檔案

1. `Snapvest/Snapvest/Services/DataService.swift`
   - 新增 AggregatedHoldingSnapshot CRUD 方法

2. `Snapvest/Snapvest/Services/HoldingCalculator.swift`
   - 新增計算 AggregatedHoldingSnapshot 的方法

3. `Snapvest/Snapvest/Views/AssetsView.swift`
   - 重構類別總覽卡片（展開/縮合）
   - 新增所有持股列表的切換按鈕
   - 新增圓圈比例圖顯示邏輯

4. `Snapvest/Snapvest/ViewModels/PortfolioViewModel.swift`（如果需要的話）
   - 新增計算總資產、總投資的方法

---

## 7. 實作順序建議

### Phase 1: 資料結構和服務（基礎）
1. ✅ 新增 `AggregatedHoldingSnapshot` 相關結構
2. ✅ 擴展 `DataService`（AggregatedHoldingSnapshot CRUD）
3. ✅ 擴展 `HoldingCalculator`（計算方法）
4. ✅ 新增 `HoldingColorPreferences`（UserDefaults）
5. ✅ 新增 `HoldingRatioPreference`（UserDefaults）

### Phase 2: 類別總覽卡片（UI）
6. ✅ 重構 `AssetCategoryCardView`（展開/縮合）
7. ✅ 實作圓餅圖（SwiftUI Chart）
8. ✅ 實作顏色選擇功能

### Phase 3: 所有持股列表（UI）
9. ✅ 新增切換按鈕（總資產佔比/總投資佔比）
10. ✅ 實作圓圈比例圖顯示邏輯
11. ✅ 更新持股卡片樣式（顏色、比例圖）

### Phase 4: 詳細頁面（UI）
12. ✅ 新建 `HoldingDetailView`
13. ✅ 實作跨帳戶合併總覽
14. ✅ 實作 FIFO 批次表格（按帳戶分組）
15. ✅ 實作損益來源分析
16. ✅ 新增買入/賣出按鈕（佔位符）

### Phase 5: 整合和測試
17. ✅ 整合所有功能
18. ✅ 測試快照更新邏輯
19. ✅ 測試 UI 互動

---

## 8. 注意事項

1. **跨幣交易匯率**：
   - 使用 `Transaction.exchangeRate`（交易時的匯率，固定值）
   - 儲存在 `FIFOLotSnapshot.exchangeRate`（跨幣交易時）

2. **快照更新時機**：
   - 交易變動時：更新相關快照
   - 匯率/價格更新：不需要更新持股快照（只更新價格/匯率快照）

3. **FIFO 批次**：
   - 分帳戶計算（不是跨帳戶合併）
   - 儲存在快照中（不是動態計算）

4. **市值、損益**：
   - 不儲存在快照中（動態計算）
   - 需要：`AggregatedHoldingSnapshot` + `AssetPriceSnapshot.currentPrice` + `ExchangeRate.currentRate`

---

## 9. 待確認問題

1. ✅ **市值、損益不存快照**（確認）
2. ✅ **跨幣交易匯率儲存**（確認：使用 Transaction.exchangeRate）
3. ✅ **FIFO 批次採用快照模式**（確認）
4. ✅ **快照更新時機**（確認：匯率/價格更新不需要更新持股快照）
5. ✅ **所有持股列表切換按鈕**（確認：總資產佔比/總投資佔比）

---

## 10. 總結

### 主要改動：
1. 新增 `AggregatedHoldingSnapshot` 結構（跨帳戶合併持股快照）
2. 新增 FIFO 批次快照結構（分帳戶儲存）
3. 擴展 `DataService` 和 `HoldingCalculator`（新增方法）
4. 重構 `AssetsView`（類別總覽卡片、所有持股列表）
5. 新建 `HoldingDetailView`（詳細頁面）
6. 新增 UserDefaults 管理（顏色偏好、佔比偏好）

### 預估工作量：
- 資料結構和服務：2-3 小時
- 類別總覽卡片 UI：2-3 小時
- 所有持股列表 UI：2-3 小時
- 詳細頁面 UI：3-4 小時
- 整合和測試：1-2 小時

**總計**：約 10-15 小時
