# 資料結構驗證文件

## 資料模型總覽

### 核心實體關係圖
```
User (使用者)
  ├── Account (帳戶) - 一對多
  │   ├── Transaction (交易) - 一對多
  │   ├── Holding (持股) - 一對多
  │   └── Liability (負債) - 一對多
  │
  └── Snapshot (快照) - 一對多

Price (價格) - 獨立表，透過 assetType + symbol 關聯
ExchangeRate (匯率) - 獨立表，透過 fromCurrency + toCurrency 關聯
```

## 1. 資料模型檢查清單

### ✅ User (使用者)
**檔案**: `Models/User.swift`
- [x] id: String (UUID)
- [x] email: String
- [x] displayName: String? (可選)
- [x] createdAt: Date
- [x] updatedAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**資料庫對應**: `users` 表
- ✅ 所有欄位都有對應

### ✅ Account (帳戶)
**檔案**: `Models/Account.swift`
- [x] id: String (UUID)
- [x] userId: String (外鍵 → User.id)
- [x] name: String
- [x] type: AssetType (enum)
- [x] currency: Currency (enum)
- [x] createdAt: Date
- [x] updatedAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**資料庫對應**: `accounts` 表
- ✅ 所有欄位都有對應
- ✅ 外鍵關係正確 (user_id → users.id)

**關聯**:
- 一個 User 可以有多個 Account
- 一個 Account 可以有多個 Transaction
- 一個 Account 可以有多個 Holding
- 一個 Account 可以有多個 Liability

### ✅ Transaction (交易)
**檔案**: `Models/Transaction.swift`
- [x] id: String (UUID)
- [x] accountId: String (外鍵 → Account.id)
- [x] type: TransactionType (enum: buy, sell, deposit, withdraw, dividend, fee)
- [x] assetType: AssetType (enum)
- [x] symbol: String (股票代碼)
- [x] quantity: Decimal
- [x] price: Decimal
- [x] currency: Currency (enum)
- [x] fee: Decimal
- [x] notes: String? (可選)
- [x] transactionDate: Date
- [x] createdAt: Date
- [x] updatedAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**計算屬性**:
- [x] totalAmount: 交易總金額（不含手續費）
- [x] totalAmountWithFee: 交易總金額（含手續費）

**資料庫對應**: `transactions` 表
- ✅ 所有欄位都有對應
- ✅ 外鍵關係正確 (account_id → accounts.id)
- ✅ 索引已建立 (account_id, transaction_date)

**交易類型邏輯**:
- `buy`: 增加持股，totalAmountWithFee = totalAmount + fee
- `sell`: 減少持股，totalAmountWithFee = totalAmount - fee
- `deposit`: 增加現金，totalAmountWithFee = totalAmount + fee
- `withdraw`: 減少現金，totalAmountWithFee = totalAmount - fee
- `dividend`: 增加現金，totalAmountWithFee = totalAmount
- `fee`: 減少現金，totalAmountWithFee = fee

### ✅ Holding (持股)
**檔案**: `Models/Holding.swift`
- [x] id: String (UUID)
- [x] accountId: String (外鍵 → Account.id)
- [x] assetType: AssetType (enum)
- [x] symbol: String
- [x] quantity: Decimal
- [x] averageCost: Decimal (平均成本)
- [x] currency: Currency (enum)
- [x] lastUpdated: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**計算屬性**:
- [x] totalCost: 總成本 = quantity * averageCost

**資料庫對應**: `holdings` 表
- ✅ 所有欄位都有對應
- ✅ 外鍵關係正確 (account_id → accounts.id)
- ✅ 唯一約束: (account_id, asset_type, symbol)
- ✅ 索引已建立 (account_id)

**生成方式**:
- 從 Transaction 記錄重播計算得出
- 使用 `HoldingCalculator.calculateHoldings()` 方法
- **使用 FIFO（先進先出）方法**：賣出時先賣出最早買入的批次

### ✅ HoldingSnapshot (持股快照)
**檔案**: `Models/Holding.swift`
- [x] id: String (從 Holding.id 繼承)
- [x] holding: Holding (基礎持股資料)
- [x] currentPrice: Decimal? (當前價格，可選)
- [x] currentPriceDate: Date? (價格日期，可選)
- [x] investmentRatio: Decimal? (投資佔比)
- [x] assetRatio: Decimal? (資產佔比)
- [x] 符合 Identifiable 協議

**計算屬性**:
- [x] marketValue: 當前市值 = quantity * currentPrice
- [x] unrealizedGainLoss: 未實現損益 = marketValue - totalCost
- [x] unrealizedGainLossPercent: 未實現損益百分比

**注意**: 
- ⚠️ 不符合 Codable（因為有計算屬性）
- ✅ 用於 UI 顯示，不儲存到資料庫

### ✅ Liability (負債)
**檔案**: `Models/Liability.swift`
- [x] id: String (UUID)
- [x] accountId: String (外鍵 → Account.id)
- [x] name: String
- [x] principal: Decimal (本金)
- [x] interestRate: Decimal (利率)
- [x] monthlyPayment: Decimal (每月本息)
- [x] remainingBalance: Decimal (剩餘餘額)
- [x] currency: Currency (enum)
- [x] startDate: Date
- [x] endDate: Date? (可選)
- [x] notes: String? (可選)
- [x] createdAt: Date
- [x] updatedAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**資料庫對應**: `liabilities` 表
- ✅ 所有欄位都有對應
- ✅ 外鍵關係正確 (account_id → accounts.id)

### ✅ Price (價格)
**檔案**: `Models/Price.swift`
- [x] id: String (UUID)
- [x] assetType: AssetType (enum)
- [x] symbol: String
- [x] price: Decimal
- [x] currency: Currency (enum)
- [x] priceDate: Date
- [x] source: String? (API 來源，可選)
- [x] createdAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**資料庫對應**: `prices` 表
- ✅ 所有欄位都有對應
- ✅ 唯一約束: (asset_type, symbol, price_date)
- ✅ 索引已建立 (asset_type, symbol, price_date DESC)

**用途**:
- 儲存歷史股價資料
- 用於計算當前市值和損益

### ✅ ExchangeRate (匯率)
**檔案**: `Models/ExchangeRate.swift`
- [x] id: String (UUID)
- [x] fromCurrency: Currency (enum)
- [x] toCurrency: Currency (enum)
- [x] rate: Decimal
- [x] rateDate: Date
- [x] source: String? (API 來源，可選)
- [x] createdAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**資料庫對應**: `fx_rates` 表
- ✅ 所有欄位都有對應
- ✅ 唯一約束: (from_currency, to_currency, rate_date)
- ✅ 索引已建立 (rate_date DESC)

### ✅ Snapshot (快照)
**檔案**: `Models/Snapshot.swift`
- [x] id: String (UUID)
- [x] userId: String (外鍵 → User.id)
- [x] snapshotDate: Date
- [x] totalAssets: Decimal
- [x] totalLiabilities: Decimal
- [x] totalCash: Decimal
- [x] totalInvestments: Decimal
- [x] unrealizedGainLoss: Decimal
- [x] realizedGainLoss: Decimal
- [x] baseCurrency: Currency (enum)
- [x] snapshotData: SnapshotData? (詳細資料，可選)
- [x] createdAt: Date
- [x] 符合 Codable 協議
- [x] 符合 Identifiable 協議

**計算屬性**:
- [x] netWorth: 淨資產 = totalAssets - totalLiabilities
- [x] liabilityRatio: 負債比例 = (totalLiabilities / totalAssets) * 100
- [x] cashRatio: 現金比例 = (totalCash / totalAssets) * 100
- [x] investmentRatio: 投資比例 = (totalInvestments / totalAssets) * 100

**資料庫對應**: `snapshots` 表
- ✅ 所有欄位都有對應
- ✅ 外鍵關係正確 (user_id → users.id)
- ✅ 唯一約束: (user_id, snapshot_date)
- ✅ 索引已建立 (user_id, snapshot_date DESC)

### ✅ SnapshotData (快照詳細資料)
**檔案**: `Models/Snapshot.swift`
- [x] accounts: [String: AccountSnapshot]? (可選)
- [x] holdings: [HoldingSnapshotData]? (可選)
- [x] 符合 Codable 協議

**用途**: 儲存在 Snapshot.snapshotData 中（JSONB 格式）

## 2. 資料流驗證

### 交易 → 持股計算流程

1. **新增交易** (`Transaction`)
   - 使用者輸入交易資訊
   - 儲存到 `transactions` 表

2. **重播交易計算持股** (`HoldingCalculator.calculateHoldings()`)
   - 讀取該帳戶的所有交易
   - 按時間排序
   - 重播計算：
     - `buy`: 增加持股，計算新的平均成本
     - `sell`: 減少持股
     - 其他類型: 不影響持股

3. **更新持股** (`Holding`)
   - 計算結果更新到 `holdings` 表
   - 或建立新的持股記錄

4. **計算已實現損益** (`HoldingCalculator.calculateRealizedGainLoss()`)
   - 從賣出交易計算已實現損益
   - 成本基礎 = 平均成本 * 賣出數量
   - 損益 = 賣出金額 - 成本基礎

### 持股 → 總覽計算流程

1. **獲取持股** (`Holding`)
   - 從 `holdings` 表讀取

2. **獲取當前價格** (`Price`)
   - 查詢 `prices` 表（最新日期）
   - 或調用 API 獲取

3. **建立持股快照** (`HoldingSnapshot`)
   - 結合 Holding + 當前價格
   - 計算市值、未實現損益

4. **計算總覽數據**
   - 總投資 = 所有持股市值總和
   - 總現金 = 從交易記錄計算（待實作）
   - 總負債 = 所有負債餘額總和
   - 總資產 = 總投資 + 總現金
   - 未實現損益 = 所有持股未實現損益總和
   - 已實現損益 = 從交易記錄計算

## 3. 資料完整性檢查

### 必填欄位驗證
- ✅ 所有必填欄位都有對應
- ✅ 外鍵關係正確
- ✅ 唯一約束正確

### 資料類型驗證
- ✅ Decimal 用於金額（精度足夠）
- ✅ Date 用於時間戳記
- ✅ String 用於 ID 和文字
- ✅ Enum 用於類型分類

### 計算邏輯驗證
- ✅ 平均成本計算正確
- ✅ 損益計算正確
- ✅ 比例計算正確

## 4. 潛在問題與改進建議

### ⚠️ 現金計算
**問題**: 目前 `totalCash` 固定為 0
**原因**: 現金計算邏輯尚未實作
**建議**: 
- 從交易記錄中計算現金餘額
- deposit/withdraw/dividend 影響現金
- buy/sell 的 fee 也影響現金

### ⚠️ 匯率轉換
**問題**: 多幣別切換時，金額不會實際轉換
**原因**: 匯率轉換邏輯尚未實作
**建議**:
- 使用 ExchangeRate 表查詢匯率
- 轉換所有金額到目標貨幣

### ⚠️ 賣出數量驗證
**問題**: 系統可能允許賣出超過持有數量
**建議**: 
- 在新增/更新交易時驗證
- 檢查賣出數量是否 <= 當前持有數量

### ⚠️ 資料持久化
**問題**: 目前使用 MockDataService，資料不會持久化
**建議**: 
- 整合 Supabase/Firebase
- 實作真實的資料服務

## 5. 測試建議

### 單元測試案例
1. **交易重播測試**
   - 測試多筆買入交易的平均成本計算
   - 測試賣出交易的持股減少
   - 測試已實現損益計算

2. **資料驗證測試**
   - 測試必填欄位驗證
   - 測試資料類型驗證
   - 測試外鍵關係

3. **計算邏輯測試**
   - 測試損益計算
   - 測試比例計算
   - 測試匯率轉換（待實作）

### 整合測試案例
1. **完整流程測試**
   - 新增帳戶 → 新增交易 → 檢查持股 → 檢查總覽

2. **資料一致性測試**
   - 交易記錄與持股是否一致
   - 總覽數據是否正確

## 6. 結論

### ✅ 資料結構完整性
- 所有核心模型都已定義
- 資料庫 Schema 完整
- 關聯關係正確

### ✅ 計算邏輯完整性
- 持股計算邏輯正確（使用 FIFO 方法）
- 損益計算邏輯正確（使用 FIFO 方法）
- 比例計算邏輯正確

### ⚠️ 待改進項目
- 現金計算邏輯
- 匯率轉換邏輯
- 資料驗證邏輯
- 資料持久化

