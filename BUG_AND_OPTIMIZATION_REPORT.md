# Snapvest 邏輯錯誤、Bug 與優化整理報告

**報告日期**: 2026-02-14  
**測試狀態**: 建置成功 ✅ / 單元測試通過 ✅ / UI 測試通過 ✅

---

## 一、已修正的邏輯錯誤與 Bug

### 1. 交易紀錄跨幣別轉帳匯率不一致 ✅
- **位置**: `TransactionHistoryView.swift` - `getBalance` / `getBalanceChange`
- **問題**: 跨幣別轉入僅從備註解析匯率，未使用 `transaction.exchangeRate`
- **修正**: 優先使用 `transaction.exchangeRate`，與 CashCalculator 邏輯一致

### 2. SymbolPickerView 載入阻塞主執行緒 ✅
- **位置**: `SymbolPickerView.swift`
- **問題**: `loadSymbols` 在主執行緒同步載入約 5 萬筆 JSON，開啟時會卡頓
- **修正**: 改為在 `Task.detached` 背景載入

### 3. AccountAssetCalculator 跨幣別計算錯誤 ✅
- **位置**: `AccountAssetCalculator.swift`
- **問題**: 未傳入 `accounts` 給 CashCalculator；持股市值未做幣別換算
- **修正**: 新增 `accounts` 參數；`calculateHoldingsValue` 支援跨幣別換算

### 4. CategoryTotalViewModel 持股市值混用幣別 ✅
- **位置**: `CategoryTotalViewModel.swift` - `calculateCategoryTotal`
- **問題**: 台幣帳戶持有美股時，`holdingsValue` 為 USD 卻與 TWD 的 `cashBalance` 直接相加
- **修正**: 先將每檔持股市值換算為帳戶貨幣後再加總

---

## 二、尚未修正的邏輯錯誤與潛在 Bug

### 1. 股利 (dividend) 跨幣別未換算
- **位置**: `CashCalculator`, `TransactionHistoryView`
- **問題**: 美股股利為 USD，若存入 TWD 證券戶時，`cash += transaction.totalAmount` 未依匯率換算
- **影響**: 台幣帳戶收到美股股利時，現金餘額計算錯誤
- **建議**: 比照 buy/sell，依 `transaction.exchangeRate` 換算為帳戶貨幣

### 2. CashCalculator.calculateTotalCash 匯率未使用
- **位置**: `CashCalculator.swift` 第 185–209 行
- **問題**: `exchangeRates` 參數未使用，多幣別總現金直接用匯率 1 相加
- **影響**: 總現金（非單一貨幣）計算不正確

### 3. HoldingCalculator 成本與匯率
- **位置**: `HoldingCalculator.swift` 第 34–36 行
- **問題**: 台幣帳戶買美股時，`costPerUnit` 使用 `totalAmountWithFee`（TWD）除以 `quantity`，邏輯正確；但 `totalAmountWithFee` 在 Transaction 中為原始交易貨幣（USD）
- **釐清**: Transaction 的 `totalAmountWithFee` 為交易貨幣（如 USD），故成本應以交易貨幣存。需確認 `Holding.averageCost` 與 FIFO 批次是否以正確幣別表示

### 4. userId 硬編碼
- **位置**: 多處（如 `AccountDetailViewModel`, `loadDebtAccountData`, `DashboardView`）
- **問題**: `"test-user-id"` 寫死在程式碼
- **影響**: 多用戶或正式環境會導致資料錯誤
- **建議**: 由認證系統注入當前 userId

### 5. SymbolPickerView items 變動時的競態條件 ✅
- **位置**: `SymbolPickerView.swift` - `onChange(of: items)`
- **問題**: 多個 filter Task 可能亂序完成
- **修正**: 使用 `filterTask` 取消舊 Task，並以 `searchText == query` 驗證再更新

### 6. AccountDetailViewModel 重複 fetch ✅
- **位置**: `AccountDetailViewModel.swift` - `loadAccountData`
- **問題**: `fetchAccounts` 被呼叫兩次
- **修正**: 合併為單次呼叫並共用結果

### 7. updateHoldings 未考慮轉入交易
- **位置**: `TransactionsViewModel.updateHoldings`
- **問題**: 僅使用 `fetchTransactions(accountId)`，可能不含以該帳戶為目標的轉帳／還款
- **釐清**: 轉帳／還款不影響持股，只影響現金；若 `fetchTransactions` 僅回傳 `accountId` 相符的交易，邏輯正確
- **建議**: 確認 DataService 對轉帳的處理方式

---

## 三、優化建議

### 1. SymbolPickerView：無搜尋時列表過大
- **現況**: 搜尋為空時顯示全部項目（美股約 49,000 筆）
- **建議**: 未搜尋時僅顯示前 200–500 筆，或顯示「請輸入關鍵字搜尋」提示
- **影響**: 降低首次渲染與捲動負擔

### 2. 匯率統一取得方式
- **現況**: 多處使用固定值 32（如 `CategoryTotalViewModel`, `AssetsView`, `HoldingDetailView` 等）
- **建議**: 集中由 `dataService.fetchExchangeRate` 取得，並在 ViewModel 層共用
- **相關 TODO**: AssetsViewModel、CategoryTotalViewModel、AccountsView、CashFlowView 等

### 3.  unit test 覆蓋率
- **現況**: SnapvestTests 僅有空的 `example()` 測試
- **建議**: 為以下加入單元測試
  - `CashCalculator.calculateCash`（含跨幣別、deductFromAccount）
  - `SymbolListService.filter`（搜尋、排序、limit）
  - `TransactionHistoryViewModel.getBalance`
  - `HoldingCalculator` FIFO 邏輯

---

## 四、TODO / 未實作功能清單

| 位置 | 內容 |
|------|------|
| DataService | Firebase/Supabase 整合 |
| CashCalculator | `calculateTotalCash` 使用 `exchangeRates` 進行換算 |
| PriceService | 實作實際 API 呼叫 |
| HomeView | 今日損益計算 |
| ChartsView | 走勢圖、炫風圖 |
| HoldingDetailView | 買入／賣出功能 |
| AddLiabilityView | 錯誤訊息顯示 |
| LiabilityDetailView | 導航至交易紀錄 |
| 多處 | 從匯率服務取得即時匯率 |

---

## 五、測試摘要

```
SnapvestTests
  - example() ✅

SnapvestUITests
  - testLaunch() ✅
  - testExample() ✅
  - testLaunchPerformance() ✅
```

---

## 六、總結

- **已修正**: 7 項
  1. 交易紀錄跨幣別轉帳匯率
  2. SymbolPickerView 載入阻塞
  3. AccountAssetCalculator 跨幣別
  4. CategoryTotalViewModel 持股市值幣別混用
  5. SymbolPickerView items 競態條件
  6. AccountDetailViewModel 重複 fetch
- **待修正**: 5 項（股利匯率、calculateTotalCash、userId 硬編碼等）
- **優化**: 3 項（SymbolPicker 空搜尋、匯率取得、測試覆蓋）
- **TODO**: 約 15+ 處未完成或待實作功能
