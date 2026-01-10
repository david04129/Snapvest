# 資料結構問題與改進建議

## 發現的問題

### 1. ⚠️ Holding 的建立方法不一致
**位置**: `ViewModels/TransactionsViewModel.swift:100`
**問題**: 建立新持股時使用 `updateHolding()`，但應該有專門的 `createHolding()` 方法
**影響**: 目前可能可以運作（如果 updateHolding 支援建立），但語義不清晰
**建議**: 
- 在 `DataServiceProtocol` 中新增 `createHolding()` 方法
- 或確認 `updateHolding()` 是否支援 upsert（存在則更新，不存在則建立）

### 2. ⚠️ 現金計算邏輯缺失
**位置**: `ViewModels/PortfolioViewModel.swift:calculateSummary()`
**問題**: `totalCash` 固定為 0，沒有從交易記錄計算
**影響**: 總資產計算不準確
**建議**: 
- 實作現金計算邏輯
- 從交易記錄中計算：deposit 增加，withdraw 減少，buy 減少（含手續費），sell 增加（含手續費），dividend 增加，fee 減少

### 3. ⚠️ 賣出數量驗證缺失
**位置**: `Views/AddTransactionView.swift`
**問題**: 沒有驗證賣出數量是否超過持有數量
**影響**: 可能產生負數持股
**建議**: 
- 在新增/更新交易時驗證
- 檢查當前持股數量
- 賣出數量必須 <= 持有數量

### 4. ⚠️ 多帳戶持股計算
**位置**: `ViewModels/PortfolioViewModel.swift:loadData()`
**問題**: 目前是從所有帳戶的交易計算持股，但應該按帳戶分別計算
**影響**: 如果同一檔股票在不同帳戶，可能會混淆
**狀態**: ✅ 實際上已經按帳戶分別處理（每個帳戶的 holdings 是分開的）

### 5. ⚠️ 匯率轉換邏輯缺失
**位置**: `ViewModels/PortfolioViewModel.swift:calculateSummary()`
**問題**: 多幣別金額沒有轉換到基礎貨幣
**影響**: 總資產計算不準確（如果有多幣別）
**建議**: 
- 使用 ExchangeRate 查詢匯率
- 將所有金額轉換到 baseCurrency
- 計算總資產時統一貨幣

## 資料結構完整性檢查

### ✅ 已完成的項目
1. **所有核心模型定義完整**
   - User, Account, Transaction, Holding, Liability, Price, ExchangeRate, Snapshot
   - 所有欄位都有對應的資料庫欄位

2. **關聯關係正確**
   - User → Account (一對多)
   - Account → Transaction (一對多)
   - Account → Holding (一對多)
   - Account → Liability (一對多)
   - User → Snapshot (一對多)

3. **計算邏輯正確**
   - 持股計算（平均成本法）
   - 已實現損益計算
   - 未實現損益計算
   - 比例計算

4. **資料庫 Schema 完整**
   - 所有表都有定義
   - 索引已建立
   - 外鍵關係正確
   - 唯一約束正確

### ⚠️ 待改進項目

1. **現金計算邏輯**
   ```swift
   // 需要實作
   func calculateCash(accountId: String, transactions: [Transaction]) -> Decimal {
       var cash: Decimal = 0
       for transaction in transactions {
           switch transaction.type {
           case .deposit: cash += transaction.totalAmountWithFee
           case .withdraw: cash -= transaction.totalAmountWithFee
           case .buy: cash -= transaction.totalAmountWithFee
           case .sell: cash += transaction.totalAmountWithFee
           case .dividend: cash += transaction.totalAmount
           case .fee: cash -= transaction.fee
           }
       }
       return cash
   }
   ```

2. **匯率轉換邏輯**
   ```swift
   // 需要實作
   func convertAmount(_ amount: Decimal, 
                     from: Currency, 
                     to: Currency, 
                     date: Date?) async throws -> Decimal {
       if from == to { return amount }
       guard let rate = try await dataService.fetchExchangeRate(from: from, to: to, date: date) else {
           throw DataServiceError.exchangeRateNotFound
       }
       return amount * rate.rate
   }
   ```

3. **賣出數量驗證**
   ```swift
   // 在 AddTransactionView 或 TransactionsViewModel 中
   func validateSellTransaction(_ transaction: Transaction) async throws -> Bool {
       if transaction.type == .sell {
           let holdings = try await dataService.fetchHoldings(accountId: transaction.accountId)
           if let holding = holdings.first(where: { 
               $0.symbol == transaction.symbol && 
               $0.assetType == transaction.assetType 
           }) {
               guard transaction.quantity <= holding.quantity else {
                   throw ValidationError.insufficientQuantity
               }
           } else {
               throw ValidationError.holdingNotFound
           }
       }
       return true
   }
   ```

## 資料驗證建議

### 輸入驗證
1. **交易數量**: 必須 > 0
2. **交易價格**: 必須 > 0
3. **賣出數量**: 必須 <= 持有數量
4. **日期**: 不能是未來日期（可選）

### 資料一致性驗證
1. **持股與交易一致性**: 持股應該可以從交易記錄重播得出
2. **總資產計算**: 總資產 = 總投資 + 總現金
3. **損益計算**: 未實現損益 + 已實現損益 = 總損益

## 測試建議

### 單元測試
1. **HoldingCalculator 測試**
   - 測試多筆買入的平均成本計算
   - 測試賣出後的持股減少
   - 測試已實現損益計算

2. **資料驗證測試**
   - 測試賣出數量驗證
   - 測試必填欄位驗證

### 整合測試
1. **完整流程測試**
   - 新增帳戶 → 新增交易 → 檢查持股 → 檢查總覽
   - 測試多筆交易的平均成本
   - 測試賣出交易的損益計算

2. **資料一致性測試**
   - 交易記錄與持股是否一致
   - 總覽數據是否正確

## 優先級建議

### 高優先級（影響核心功能）
1. ✅ 持股計算邏輯（已完成）
2. ⚠️ 現金計算邏輯（待實作）
3. ⚠️ 賣出數量驗證（待實作）

### 中優先級（影響準確性）
1. ⚠️ 匯率轉換邏輯（待實作）
2. ⚠️ 資料驗證邏輯（待實作）

### 低優先級（優化）
1. ⚠️ 資料持久化（待整合 Supabase）
2. ⚠️ 錯誤處理優化
3. ⚠️ 性能優化

