# 快照更新策略討論

## 1. FIFO 批次快照設計

### 需求確認：
- ✅ FIFO 批次也要採用快照模式儲存（不是動態計算）
- ✅ 所有資料都從快照讀取，不需要即時計算

### FIFO 批次快照結構：

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
    
    // 注意：不儲存市值、損益（需要 currentPrice，動態計算）
}

/// 跨帳戶合併持股快照（更新設計）
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
    var fifoLotsByAccount: [FIFOLotsByAccountSnapshot]  // 按帳戶分組的 FIFO 批次
    
    // 時間戳記
    var lastUpdated: Date
    var lastTransactionDate: Date?
    var version: Int
}

/// 按帳戶分組的 FIFO 批次快照
struct FIFOLotsByAccountSnapshot: Identifiable, Codable, Equatable {
    let accountId: String
    let accountName: String
    var lots: [FIFOLotSnapshot]  // 該帳戶的 FIFO 批次列表
    
    var id: String { accountId }
}
```

**關鍵設計決策**：
- ✅ 儲存：持股數量、成本（原幣）、FIFO 批次（原幣）
- ❌ 不儲存：市值、損益（需要 currentPrice，動態計算）

---

## 2. 快照更新時機討論

### 2.1 需要更新快照的操作

#### ✅ 需要更新快照的操作：

1. **買入股票**
   - 更新 `AccountSnapshot`（該帳戶）
   - 更新 `AggregatedHoldingSnapshot`（跨帳戶合併）
   - 更新 `UserHoldingsSnapshot`（加入新的 symbol）
   - 建立 `AssetPriceSnapshot`（如果不存在）

2. **賣出股票**
   - 更新 `AccountSnapshot`（該帳戶）
   - 更新 `AggregatedHoldingSnapshot`（跨帳戶合併，更新 FIFO 批次）
   - 如果全部賣完，從 `UserHoldingsSnapshot` 移除 symbol

3. **收入/支出**
   - 更新 `AccountSnapshot`（該帳戶的現金餘額）

4. **轉帳**
   - 更新 `AccountSnapshot`（轉出帳戶、轉入帳戶的現金餘額）

5. **編輯交易記錄**
   - 重新計算受影響的快照
   - 更新 `AccountSnapshot`（相關帳戶）
   - 更新 `AggregatedHoldingSnapshot`（如果涉及持股）

6. **刪除交易記錄**
   - 重新計算受影響的快照
   - 更新 `AccountSnapshot`（相關帳戶）
   - 更新 `AggregatedHoldingSnapshot`（如果涉及持股）

7. **新增/刪除帳戶**
   - 建立/刪除 `AccountSnapshot`

8. **新增/編輯/刪除負債**
   - 更新 `AccountSnapshot`（債務帳戶）

---

### 2.2 不需要更新快照的操作

#### ❓ 問題：更新匯率/價格是否需要更新所有快照？

**分析**：

1. **匯率更新**（例如：USD to TWD 從 32 → 33）
   - **影響的資料**：
     - ✅ 市值（台幣計價）：會改變
     - ✅ 損益（台幣計價）：會改變
     - ❌ 持股數量：不變
     - ❌ 成本（原幣）：不變
     - ❌ FIFO 批次（原幣）：不變
   
   - **快照儲存的資料**：
     - `AggregatedHoldingSnapshot` 儲存：`totalQuantity`, `weightedAverageCost`, `totalCost`（原幣）
     - `FIFOLotSnapshot` 儲存：`remainingQuantity`, `costPerUnit`（原幣）
   
   - **結論**：
     - ❌ **不需要更新快照**（因為快照只儲存原幣資料）
     - ✅ 市值、損益動態計算：`AggregatedHoldingSnapshot` + `AssetPriceSnapshot.currentPrice` + `ExchangeRate.currentRate`

2. **價格更新**（例如：GOOG 從 $150 → $155）
   - **影響的資料**：
     - ✅ 市值：會改變
     - ✅ 損益：會改變
     - ❌ 持股數量：不變
     - ❌ 成本：不變
     - ❌ FIFO 批次：不變
   
   - **快照儲存的資料**：
     - `AggregatedHoldingSnapshot` 儲存：`totalQuantity`, `weightedAverageCost`, `totalCost`（原幣）
     - `FIFOLotSnapshot` 儲存：`remainingQuantity`, `costPerUnit`（原幣）
   
   - **結論**：
     - ❌ **不需要更新快照**（因為快照只儲存原幣資料）
     - ✅ 市值、損益動態計算：`AggregatedHoldingSnapshot` + `AssetPriceSnapshot.currentPrice` + `ExchangeRate.currentRate`

---

## 3. 快照更新策略總結

### 原則：
- ✅ **快照儲存**：不依賴價格/匯率的資料（數量、成本、原幣）
- ✅ **動態計算**：依賴價格/匯率的資料（市值、損益、台幣計價）

### 需要更新快照的時機：

| 操作 | AccountSnapshot | AggregatedHoldingSnapshot | UserHoldingsSnapshot | AssetPriceSnapshot |
|------|----------------|---------------------------|---------------------|-------------------|
| 買入股票 | ✅ | ✅ | ✅ | ✅ (如果不存在) |
| 賣出股票 | ✅ | ✅ | ✅ (如果全部賣完) | ❌ |
| 收入/支出 | ✅ | ❌ | ❌ | ❌ |
| 轉帳 | ✅ | ❌ | ❌ | ❌ |
| 編輯交易 | ✅ | ✅ (如果涉及持股) | ✅ (如果涉及持股) | ❌ |
| 刪除交易 | ✅ | ✅ (如果涉及持股) | ✅ (如果涉及持股) | ❌ |
| 新增/刪除帳戶 | ✅ | ❌ | ❌ | ❌ |
| 新增/編輯/刪除負債 | ✅ | ❌ | ❌ | ❌ |
| **更新匯率** | ❌ | ❌ | ❌ | ❌ |
| **更新價格** | ❌ | ❌ | ❌ | ✅ (只更新價格快照) |

### 不需要更新快照的時機：

- ✅ **更新匯率**：不影響快照（快照只儲存原幣資料）
- ✅ **更新價格**：不影響持股快照（只更新 `AssetPriceSnapshot`）
  - 市值、損益動態計算：`快照資料` + `AssetPriceSnapshot.currentPrice` + `ExchangeRate.currentRate`

---

## 4. 資料讀取流程

### 類別總覽/所有持股列表：

```
1. 讀取 AggregatedHoldingSnapshot（快照）
   ↓
2. 讀取 AssetPriceSnapshot.currentPrice（價格快照）
   ↓
3. 讀取 ExchangeRate.currentRate（匯率快照）
   ↓
4. 動態計算：
   - 市值（台幣）= totalQuantity * currentPrice * currentRate
   - 損益（台幣）= 市值 - (totalCost * currentRate)
   - 損益百分比 = (損益 / (totalCost * currentRate)) * 100
```

### 詳細頁面：

```
1. 讀取 AggregatedHoldingSnapshot（快照，包含 FIFO 批次）
   ↓
2. 讀取 AssetPriceSnapshot.currentPrice（價格快照）
   ↓
3. 讀取 ExchangeRate.currentRate（匯率快照）
   ↓
4. 動態計算（每個 FIFO 批次）：
   - 市值（台幣）= remainingQuantity * currentPrice * currentRate
   - 損益（台幣）= 市值 - (remainingQuantity * costPerUnit * currentRate)
   - 報酬率 = (損益 / (remainingQuantity * costPerUnit * currentRate)) * 100
```

---

## 5. 建議的實作方案

### 原則：
1. ✅ 快照儲存：不依賴價格/匯率的資料（原幣）
2. ✅ 動態計算：依賴價格/匯率的資料（台幣計價）
3. ✅ 更新匯率/價格：只更新價格/匯率快照，不需要更新持股快照

### 優點：
- ✅ 性能好：讀取快照快，不需要重新計算
- ✅ 更新少：匯率/價格變動不需要更新大量快照
- ✅ 資料準確：市值、損益使用最新價格/匯率

### 缺點：
- ⚠️ 顯示時需要讀取多個快照（持股快照 + 價格快照 + 匯率快照）
- ⚠️ 但這個缺點可以接受（讀取快照比重新計算快得多）

---

## 6. 待確認問題

1. **FIFO 批次快照的結構是否合適？**
   - ✅ 儲存：accountId, accountName, buyDate, remainingQuantity, costPerUnit, currency
   - ❌ 不儲存：市值、損益（動態計算）

2. **匯率/價格更新是否需要更新所有快照？**
   - ✅ 結論：**不需要**（快照只儲存原幣資料）

3. **更新策略是否合適？**
   - ✅ 交易變動：更新相關快照
   - ✅ 匯率/價格變動：只更新價格/匯率快照，不更新持股快照
   - ✅ 市值、損益：動態計算
