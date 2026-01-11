# 跨帳戶合併持股設計討論

## 1. 現有的 AssetPriceSnapshot（價格快照）

### 目前包含的資料：
```swift
struct AssetPriceSnapshot {
    let assetType: AssetType      // 資產類型
    let symbol: String            // 股票代號
    var name: String?             // 股票名稱（顯示用）
    var currency: Currency        // 貨幣
    
    // 價格資料
    var currentPrice: Decimal?    // 當前價格
    var previousPrice: Decimal?   // 上一次價格（容錯備份）
    var currentPriceDate: Date?   // 當前價格日期
    var previousPriceDate: Date?  // 上一次價格日期
    
    // 時間戳記
    var lastUpdated: Date         // 快照最後更新時間
    var lastSuccessfulUpdate: Date? // 最後一次成功獲取價格的時間
}
```

### 用途：
- **統一價格來源**：所有帳戶共享同一個價格快照
- **避免重複 API 調用**：同一股票只需要一個價格
- **容錯備份**：如果 currentPrice 更新失敗，使用 previousPrice

---

## 2. 跨帳戶合併持股快照（需要新增）

### 需求分析：

當使用者**新增一筆買入交易**時，需要：
1. 跨帳戶合併同一股票（GOOG 在 A 帳戶 5 股 + B 帳戶 10 股 = 15 股）
2. 計算合併後的加權平均成本
3. 計算合併後的市值、損益（需要結合 AssetPriceSnapshot）
4. 快速顯示類別總覽、所有持股列表

### 問題討論：

#### 方案 A：新增 AggregatedHoldingSnapshot（推薦）

```swift
/// 跨帳戶合併持股快照（每個使用者每檔股票一個快照）
struct AggregatedHoldingSnapshot: Identifiable, Codable, Equatable {
    /// 唯一識別（使用 userId + assetType + symbol）
    var id: String {
        "\(userId)_\(assetType.rawValue)_\(symbol)"
    }
    
    let userId: String            // 使用者ID
    let assetType: AssetType      // 資產類型
    let symbol: String            // 股票代號
    
    // 基本資訊
    var name: String?             // 股票名稱（顯示用，從 AssetPriceSnapshot 同步）
    var currency: Currency        // 貨幣（從 AssetPriceSnapshot 同步）
    
    // 合併後的持股資訊（跨帳戶）
    var totalQuantity: Decimal    // 總數量（跨帳戶合併）
    var weightedAverageCost: Decimal  // 加權平均成本（跨帳戶）
    var totalCost: Decimal        // 總成本（totalQuantity * weightedAverageCost）
    
    // 來源帳戶資訊（用於詳細頁面的 FIFO 批次顯示）
    var sourceAccountIds: [String]  // 持有的帳戶ID列表
    
    // 時間戳記
    var lastUpdated: Date         // 快照最後更新時間
    var lastTransactionDate: Date? // 最後一筆交易日期（用於驗證快照是否完整）
    var version: Int              // 版本號（用於樂觀鎖定）
    
    /// 計算總成本（原幣）
    var totalCostInOriginalCurrency: Decimal {
        totalQuantity * weightedAverageCost
    }
}
```

**優點**：
- ✅ 獨立的快照結構，與 AccountSnapshot 分離
- ✅ 可以直接用於類別總覽、所有持股列表
- ✅ 結合 AssetPriceSnapshot 可以快速計算市值、損益
- ✅ 可以儲存 sourceAccountIds 用於詳細頁面

**缺點**：
- ❌ 需要額外的儲存空間
- ❌ 需要維護一致性（當交易變動時更新）

#### 方案 B：動態計算（不推薦）

每次需要時從 AccountSnapshot.holdings 重新計算合併。

**缺點**：
- ❌ 性能較差（每次都要遍歷所有帳戶）
- ❌ 無法快速顯示

---

## 3. FIFO 批次詳細資訊（用於詳細頁面）

### ⚠️ 重要設計確認：

**FIFO 計算是分帳戶的，不是跨帳戶合併的！**

- ✅ 類別總覽、所有持股列表：**跨帳戶合併顯示**（使用 `AggregatedHoldingSnapshot`）
- ✅ 詳細頁面的 FIFO 批次：**按帳戶分組顯示**（每個帳戶獨立計算 FIFO）

**原因**：使用者賣出時需要選擇從哪個帳戶賣出，所以 FIFO 必須分帳戶計算。

### 詳細頁面結構：

```
持股詳細頁面
├── 頂部：跨帳戶合併總覽
│   ├── 總數量（跨帳戶合併）
│   ├── 加權平均成本（跨帳戶）
│   ├── 總市值（跨帳戶）
│   └── 總未實現損益（跨帳戶）
│
└── 底部：按帳戶分組的 FIFO 批次表格
    ├── 帳戶A（國泰證券）
    │   ├── 批次1：5股，均價176.50，損益...
    │   └── 批次2：10股，均價191.80，損益...
    │
    └── 帳戶B（元大證券）
        └── 批次1：20股，均價179.56，損益...
```

### 方案：動態計算（推薦）

詳細頁面需要時，從 Transaction 重新計算 FIFO 批次，**按帳戶分組**。

```swift
/// FIFO 批次（用於詳細頁面顯示，動態計算，分帳戶）
struct FIFOLot: Identifiable {
    let id: String              // Transaction ID（買入交易的 ID）
    let accountId: String       // 帳戶ID（重要：用於分組）
    let accountName: String     // 券商名稱（Account.name）
    let buyDate: Date          // 買入日期
    var remainingQuantity: Decimal  // 剩餘數量（該帳戶的 FIFO 計算後）
    var costPerUnit: Decimal   // 單位成本（Transaction.totalAmountWithFee / Transaction.quantity）
    
    // 計算屬性（需要 currentPrice）
    var marketValue: Decimal?   // 市值 = remainingQuantity * currentPrice
    var gainLoss: Decimal?      // 未實現損益 = marketValue - (remainingQuantity * costPerUnit)
    var returnRate: Decimal?    // 報酬率 = (gainLoss / (remainingQuantity * costPerUnit)) * 100
}

/// 按帳戶分組的 FIFO 批次
struct FIFOLotsByAccount: Identifiable {
    let accountId: String
    let accountName: String
    var lots: [FIFOLot]
    
    var id: String { accountId }
}
```

**計算方法**：
```swift
// 在 HoldingCalculator 或新建服務
static func calculateFIFOLotsByAccount(
    symbol: String,
    assetType: AssetType,
    transactions: [Transaction],  // 所有帳戶的交易
    accounts: [Account],
    currentPrice: Decimal?
) -> [FIFOLotsByAccount]  // 返回按帳戶分組的批次
```

**計算邏輯**：
1. 過濾出該股票的所有買入/賣出交易
2. 按 `accountId` 分組
3. 對每個帳戶的交易，獨立計算 FIFO 批次（使用該帳戶的交易記錄）
4. 返回按帳戶分組的批次列表

**優點**：
- ✅ 不需要額外儲存空間
- ✅ 資料總是準確（從交易記錄計算）
- ✅ 符合賣出邏輯（分帳戶選擇）
- ✅ 維護簡單

**缺點**：
- ⚠️ 每次打開詳細頁面需要計算（但計算量不大，可接受）

---

## 4. 需要討論的問題

### Q1: AggregatedHoldingSnapshot 需要儲存哪些資料？

**目前建議**：
- ✅ 基本資訊：userId, assetType, symbol, name, currency
- ✅ 合併資訊：totalQuantity, weightedAverageCost, totalCost
- ✅ 來源帳戶：sourceAccountIds（用於快速知道哪些帳戶持有）
- ❓ 是否需要儲存市值、損益？
  - **建議**：不需要，因為需要 currentPrice，而 currentPrice 會變動
  - 市值、損益應該動態計算：結合 AggregatedHoldingSnapshot + AssetPriceSnapshot

### Q2: 更新時機

**新增/編輯/刪除交易時**：
1. 更新 AccountSnapshot（該帳戶的快照）
2. 更新 AggregatedHoldingSnapshot（跨帳戶合併快照）
3. 如果新增股票，建立 AssetPriceSnapshot（如果不存在）

### Q3: FIFO 計算範圍

**重要確認**：FIFO 計算是**分帳戶**的，不是跨帳戶合併的！

- ✅ 類別總覽、所有持股列表：跨帳戶合併（使用 `AggregatedHoldingSnapshot`）
- ✅ 詳細頁面 FIFO 批次：按帳戶分組（每個帳戶獨立計算 FIFO）
- ✅ 賣出時：使用者選擇帳戶，從該帳戶的 FIFO 批次賣出

**原因**：使用者賣出時需要選擇從哪個帳戶賣出，所以 FIFO 必須分帳戶計算。

### Q4: 與現有結構的關係

```
AssetPriceSnapshot (統一價格)
    ↓ (提供 currentPrice)
AggregatedHoldingSnapshot (跨帳戶合併持股)
    ↓ (結合計算)
顯示：市值、損益、圓餅圖等

AccountSnapshot (帳戶快照)
    ↓ (用於詳細頁面)
FIFOLot (動態計算)
    ↓ (結合 AssetPriceSnapshot.currentPrice)
顯示：詳細頁面的 FIFO 批次表格
```

---

## 4. 資料流程圖

```
使用者新增買入交易（台積電，A帳戶，5股）
  ↓
1. 更新 AccountSnapshot（A帳戶）
   - A帳戶的 holdings 更新（台積電 5股）
  ↓
2. 更新 AggregatedHoldingSnapshot（跨帳戶合併）
   - 如果已經存在（B帳戶也有台積電），合併計算
   - totalQuantity = A帳戶數量 + B帳戶數量
   - weightedAverageCost = 加權平均
   - sourceAccountIds = [A帳戶ID, B帳戶ID]
   - 如果不存在，建立新的 AggregatedHoldingSnapshot
  ↓
3. 建立 AssetPriceSnapshot（如果不存在，等後端更新價格）
  ↓
4. 更新 UserHoldingsSnapshot（加入新的 symbol）

---

顯示類別總覽：
  ↓
讀取 AggregatedHoldingSnapshot（跨帳戶合併）
  ↓
結合 AssetPriceSnapshot.currentPrice
  ↓
計算：市值、損益、百分比

---

顯示詳細頁面：
  ↓
讀取 AggregatedHoldingSnapshot（跨帳戶合併總覽）
  ↓
動態計算 FIFO 批次（按帳戶分組）
  ↓
1. 過濾該股票的所有交易（所有帳戶）
2. 按 accountId 分組
3. 每個帳戶獨立計算 FIFO 批次
4. 結合 AssetPriceSnapshot.currentPrice 計算損益
  ↓
顯示：
- 頂部：跨帳戶合併總覽
- 底部：按帳戶分組的 FIFO 批次表格
```

## 5. 建議的實作方案

### 推薦方案：新增 AggregatedHoldingSnapshot

1. **新增 AggregatedHoldingSnapshot 結構**（儲存跨帳戶合併資訊）
2. **新增 FIFOLot 結構**（動態計算，用於詳細頁面）
3. **新增計算方法**：
   - `calculateAggregatedHoldings(userId:accounts:accountSnapshots:) -> [AggregatedHoldingSnapshot]`
   - `calculateFIFOLots(userId:symbol:assetType:transactions:accounts:currentPrice:) -> [FIFOLot]`
4. **更新 DataService**：新增 AggregatedHoldingSnapshot 的 CRUD 方法
5. **更新交易流程**：新增/編輯/刪除交易時，更新 AggregatedHoldingSnapshot

---

## 6. 待確認問題

1. **AggregatedHoldingSnapshot 是否需要儲存市值、損益？**
   - ✅ 確認：不需要（動態計算，結合 AssetPriceSnapshot.currentPrice）

2. **是否需要儲存 FIFO 批次到快照？**
   - ✅ 確認：不需要（動態計算，分帳戶計算）

3. **sourceAccountIds 是否足夠，還是需要更多資訊？**
   - ✅ 確認：足夠（用於快速知道哪些帳戶持有）

4. **更新頻率**：每次交易變動都更新，還是批量更新？
   - ✅ 確認：每次交易變動都更新（確保資料即時性）

5. **FIFO 計算範圍**：
   - ✅ 確認：**分帳戶計算**（不是跨帳戶合併）
   - ✅ 詳細頁面：按帳戶分組顯示 FIFO 批次
   - ✅ 賣出時：使用者選擇帳戶，從該帳戶的 FIFO 批次賣出
