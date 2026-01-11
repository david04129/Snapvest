# 資產分頁需求分析 - 資料結構評估

## 需求總結

### 1. 三個類別總覽卡片（台股、美股、加密貨幣）
- **縮合狀態**：總市值（台幣）、總未實現損益及％數（>0%綠色，<0%紅色，=0%黑色）
- **展開狀態**：圓餅圖（各持股佔該類別總市值的比例）、持股列表（可選顏色）
- **顏色**：台股藍色、美股綠色、加密貨幣黃橘色

### 2. 所有持股卡片列表
- 跨類別顯示所有持股
- 卡片顏色依類別：台股藍色、美股綠色、加密貨幣黃橘色
- 點擊進入詳細頁面

### 3. 持股詳細頁面
- 跨帳戶合併的同一股票資訊
- FIFO 批次表格：券商、買入日、數量、均價、損益、報酬率
- 今日漲跌（不考慮匯率變動）
- 損益來源分析（市價損益、匯率損益）

### 4. 顏色選擇
- 每個持股（跨帳戶合併後的 symbol）可以選擇顏色
- 顏色應用於圓餅圖和持股列表

---

## 現有資料結構分析

### ✅ 已有的資料

1. **`Holding` 模型**
   - `id`, `accountId`, `assetType`, `symbol`, `name`, `quantity`, `averageCost`, `currency`
   - ✅ 有基本持股資訊

2. **`HoldingSnapshot` 模型**
   - `holding`, `currentPrice`, `marketValue`, `unrealizedGainLoss`, `unrealizedGainLossPercent`
   - ✅ 有價格和損益資訊

3. **`Transaction` 模型**
   - `accountId`, `assetType`, `symbol`, `quantity`, `price`, `transactionDate`, `exchangeRate`
   - ✅ 有交易記錄，可用於 FIFO 計算

4. **`Account` 模型**
   - `id`, `name`（帳戶名稱，可用作「券商」）
   - ✅ 有帳戶資訊

5. **`HoldingCalculator.calculateHoldings`**
   - ✅ 可以計算持股（但目前是按帳戶分開的）

### ❌ 缺少的資料/功能

1. **跨帳戶合併持股**
   - ⚠️ **問題**：目前 `HoldingCalculator.calculateHoldings` 的 key 是 "assetType_symbol"，但每個 Holding 仍然有 accountId
   - ⚠️ **問題**：實際上每個帳戶的同一股票是分開計算的
   - ✅ **解決方案**：需要新增一個方法來合併跨帳戶的同一股票

2. **顏色偏好儲存**
   - ❌ **缺少**：目前沒有顏色欄位
   - ✅ **解決方案**：使用 `UserDefaults` 儲存 `[String: Color]`（key: "assetType_symbol"）

3. **FIFO 批次詳細資訊（用於詳細頁面）**
   - ⚠️ **問題**：目前 `HoldingLot`（private struct）只有 `quantity`, `costPerUnit`, `transactionDate`
   - ⚠️ **問題**：詳細頁面需要顯示：券商（Account.name）、買入日、數量、均價、損益、報酬率
   - ✅ **解決方案**：
     - 方案 A：擴展 `HoldingLot` 並公開（但這會改變現有邏輯）
     - 方案 B：在詳細頁面時，從 Transaction 重新計算 FIFO 批次（推薦）

4. **今日漲跌計算**
   - ❌ **缺少**：目前只有 `currentPrice`，沒有 `previousPrice` 或歷史價格
   - ⚠️ **問題**：無法計算今日漲跌（需要昨天的收盤價）
   - ✅ **解決方案**：
     - 方案 A：使用 `AssetPriceSnapshot.previousPrice`（如果有）
     - 方案 B：暫時無法顯示今日漲跌（等價格快照系統完成）

5. **匯率損益計算**
   - ⚠️ **問題**：需要知道買入時的匯率和當前匯率
   - ⚠️ **問題**：`Transaction.exchangeRate` 存在，但需要當前匯率
   - ✅ **解決方案**：使用模擬匯率（目前 USD 1:32 TWD）

---

## 需要新增/修改的內容

### 1. 新增：跨帳戶合併持股的方法

```swift
// 在 HoldingCalculator 或新建一個服務
static func aggregateHoldingsAcrossAccounts(
    holdings: [HoldingSnapshot],
    transactions: [Transaction],
    accounts: [Account]
) -> [AggregatedHolding]
```

### 2. 新增：AggregatedHolding 結構

```swift
struct AggregatedHolding: Identifiable {
    let id: String  // "assetType_symbol"
    let assetType: AssetType
    let symbol: String
    var name: String?
    var totalQuantity: Decimal
    var weightedAverageCost: Decimal  // 跨帳戶加權平均成本
    var currentPrice: Decimal?
    var marketValue: Decimal?  // 當前市值（原幣）
    var marketValueTWD: Decimal?  // 當前市值（台幣）
    var totalCost: Decimal  // 總成本（原幣）
    var totalCostTWD: Decimal  // 總成本（台幣）
    var unrealizedGainLoss: Decimal?  // 未實現損益（台幣）
    var unrealizedGainLossPercent: Decimal?  // 未實現損益百分比
    var holdings: [HoldingSnapshot]  // 來自各帳戶的持股
}
```

### 3. 新增：FIFO 批次詳細資訊結構

```swift
struct FIFOLot: Identifiable {
    let id: String  // Transaction ID
    let accountId: String
    let accountName: String  // 券商名稱
    let buyDate: Date
    let quantity: Decimal
    let costPerUnit: Decimal
    let currentPrice: Decimal?
    var marketValue: Decimal?  // quantity * currentPrice
    var gainLoss: Decimal?  // 未實現損益
    var returnRate: Decimal?  // 報酬率
}
```

### 4. 新增：顏色偏好管理

```swift
// 使用 UserDefaults 儲存
struct HoldingColorPreferences {
    static let key = "holdingColorPreferences"
    
    static func getColor(for symbol: String, assetType: AssetType) -> Color {
        // 從 UserDefaults 讀取
        // 如果沒有，返回預設顏色（依 assetType）
    }
    
    static func setColor(_ color: Color, for symbol: String, assetType: AssetType) {
        // 儲存到 UserDefaults
    }
}
```

### 5. 新增：計算 FIFO 批次的方法（用於詳細頁面）

```swift
// 在 HoldingCalculator 或新建一個服務
static func calculateFIFOLots(
    symbol: String,
    assetType: AssetType,
    transactions: [Transaction],
    accounts: [Account],
    currentPrice: Decimal?
) -> [FIFOLot]
```

### 6. 修改：類別總覽計算

需要按 assetType 過濾並合併持股，然後計算：
- 總市值（台幣）
- 總未實現損益（台幣）
- 總未實現損益百分比

### 7. 新增：匯率轉換輔助方法

```swift
// 使用模擬匯率
static let mockUSDTOTWDRate: Decimal = 32

static func convertToTWD(amount: Decimal, from currency: Currency) -> Decimal {
    switch currency {
    case .TWD: return amount
    case .USD: return amount * mockUSDTOTWDRate
    default: return amount  // 暫時不轉換其他貨幣
    }
}
```

---

## 實作優先順序

### Phase 1: 基礎功能（必須）
1. ✅ 跨帳戶合併持股（`AggregatedHolding`）
2. ✅ 類別總覽計算（按 assetType 分組）
3. ✅ 匯率轉換（模擬匯率）
4. ✅ 基本的類別卡片 UI（縮合狀態）

### Phase 2: 展開功能
5. ✅ 圓餅圖（SwiftUI Chart）
6. ✅ 顏色選擇（UserDefaults）
7. ✅ 持股列表（展開狀態）

### Phase 3: 詳細頁面
8. ✅ FIFO 批次計算（用於詳細頁面）
9. ✅ 詳細頁面 UI
10. ✅ 損益來源分析（市價損益、匯率損益）

### Phase 4: 今日漲跌（可選，等價格快照系統完成）
11. ⏳ 今日漲跌計算（需要 `previousPrice`）

---

## 總結

### ✅ 可以滿足的需求
- ✅ 基本持股資訊（數量、成本、市值）
- ✅ 未實現損益計算
- ✅ 跨帳戶合併（需要新增方法）
- ✅ 匯率轉換（使用模擬匯率）
- ✅ 類別總覽（需要按 assetType 分組）
- ✅ FIFO 批次計算（需要從 Transaction 重新計算）
- ✅ 顏色選擇（使用 UserDefaults）

### ⚠️ 暫時無法滿足的需求
- ⏳ 今日漲跌（需要 `previousPrice`，等價格快照系統完成）

### 🔧 需要新增的內容
1. `AggregatedHolding` 結構
2. `FIFOLot` 結構
3. 跨帳戶合併持股的方法
4. 計算 FIFO 批次的方法（用於詳細頁面）
5. 顏色偏好管理（UserDefaults）
6. 匯率轉換輔助方法
