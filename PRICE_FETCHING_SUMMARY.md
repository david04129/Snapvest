# Snapvest 股價抓取方式整理

## 一、目前實作狀況

### 1. 價格流程（Price Flow）

```
使用者需要股價
    ↓
PriceService.fetchCurrentPrice(assetType, symbol)
    ↓
① 先查 DataService.fetchPrice()（本地快取／資料庫）
    ↓ 沒有
② TODO: 調用外部 API
    ↓
回傳 Decimal? 或 nil
```

### 2. PriceService（`Services/PriceService.swift`）

- **`fetchCurrentPrice(assetType:symbol:)`**  
  - 先透過 `dataService.fetchPrice()` 查本地  
  - 無快取時，預期呼叫外部 API（目前註記 TODO，尚未實作）  
  - 回傳 `nil` 時，前端需自行處理無價格情況  

- **`fetchHistoricalPrices(assetType:symbol:days:)`**  
  - 委託 `dataService.fetchPrices()`  
  - 目前回傳空陣列  

### 3. DataService（Mock / 實際後端）

**MockDataService.fetchPrice** 現況：
- 使用固定 mock 價格字典
- 台股：2330=820、2317=60、2454=850 等
- 美股：AAPL=120、MSFT=360、NVDA=700 等
- 加密貨幣：BTC=65000、ETH=2000 等
- 無 key 時回傳 100

### 4. 呼叫 `fetchCurrentPrice` 的位置

| 模組 | 用途 |
|------|------|
| AccountDetailViewModel | 帳戶詳情：載入持股現價、建立 HoldingSnapshot |
| CategoryTotalViewModel | 類別總資產：計算持股市值 |
| PortfolioViewModel | 投資組合：載入持股現價 |
| BuyTradeFormView | 買入表單：預填「目前股價」 |
| SnapshotUpdater | 快照更新：建立 AssetPriceSnapshot |
| AssetsViewModel | 資產總覽：若無快照則向 PriceService 取價 |

---

## 二、設計目標（依 BACKEND_API_DESIGN.md）

### 1. 後端設計原則

1. **集中管理**：後端統一維護所有使用者需要的股價
2. **批量更新**：定期批量更新，而非每檔即時查價
3. **容錯**：`previousPrice` 作為備援，`currentPrice` 更新失敗時仍可顯示
4. **按需讀取**：前端只抓使用者實際持有的股票價格

### 2. 後端資料表：asset_price_snapshots

| 欄位 | 說明 |
|------|------|
| asset_type, symbol | 主鍵 |
| current_price | 最新成功取得的價格 |
| previous_price | 上一筆價格（容錯用） |
| current_price_date | 目前價格日期 |
| previous_price_date | 上一筆日期 |
| last_updated | 快照最後更新時間 |
| last_successful_update | 最後一次成功抓取時間 |

### 3. 預期 API

| API | 用途 | 狀態 |
|-----|------|------|
| `POST /api/v1/prices/batch` | 登入時批量取得持股價格 | 待實作 |
| `GET /api/v1/prices/{assetType}/{symbol}` | 新增持股時單檔即時取價 | 待實作 |

---

## 三、前端資料結構

### 1. AssetPriceSnapshot

- 統一價格快照：所有帳戶共用
- 含 `currentPrice`、`previousPrice`
- `displayPrice` = `currentPrice ?? previousPrice`（容錯）

### 2. 快照更新策略（SNAPSHOT_UPDATE_STRATEGY.md）

- 價格變動時：只更新 `AssetPriceSnapshot`，不更新持股快照
- 市值、損益在顯示時動態計算：`holdings + AssetPriceSnapshot + ExchangeRate`

---

## 四、待完成項目

1. **PriceService API 實作**  
   - `PriceService.swift` 第 31–33 行：`TODO: 實作 API 調用`  
   - 需串接實際後端或外部財經 API  

2. **外部股價來源選擇**  
   - 台股：證交所、Yahoo Finance 等  
   - 美股：Alpha Vantage、Yahoo Finance、Finnhub 等  
   - 加密貨幣：CoinGecko、Binance 等  

3. **批次價格 API**  
   - 登入後呼叫 `POST /api/v1/prices/batch` 取得持有標的價格  
   - 依 `UserHoldingsSnapshot` 中的 symbol 列表請求  

4. **單檔價格 API**  
   - 新增持股時若本地／快照無價格，呼叫 `GET /api/v1/prices/{assetType}/{symbol}`  
   - 取得後寫入 `AssetPriceSnapshot`  

5. **歷史價格**  
   - `fetchHistoricalPrices` 目前回傳空陣列  
   - 圖表與分析功能需補上歷史資料來源  

---

## 五、資料流程圖（目標架構）

```
後端定期 Job（每日收盤後）
    ↓
從 UserHoldingsSnapshot 取得所有 symbol
    ↓
外部 API 批量取得價格
    ↓
寫入 asset_price_snapshots（currentPrice, previousPrice）

─────────────────────────────────────

前端登入
    ↓
POST /api/v1/prices/batch（symbols = 使用者持有）
    ↓
取得 AssetPriceSnapshot 列表
    ↓
顯示市值、損益

前端新增持股
    ↓
檢查本地／快照是否有價格
    ↓
無 → GET /api/v1/prices/{assetType}/{symbol}
    ↓
寫入 AssetPriceSnapshot 並顯示
```
