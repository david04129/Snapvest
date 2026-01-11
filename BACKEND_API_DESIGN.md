# 後端與 API 設計文件

## 概述

本文檔記錄了 Snapvest 應用程式後端、API 和資料庫的設計思路與流程規劃。主要目標是實現高效的股價更新機制，減少前端 API 調用，提升應用程式性能。

## 核心設計理念

1. **集中管理價格數據**：後端統一維護所有使用者需要的股票價格
2. **批量更新策略**：後端定期批量更新股價，而非即時更新
3. **容錯機制**：使用 previousPrice 作為備份，確保價格數據的可用性
4. **按需讀取**：前端只讀取使用者實際持有的股票價格

## 資料庫設計

### 1. asset_price_snapshots 表（統一價格快照）

用於儲存所有使用者需要的股票價格，所有帳戶共享同一價格數據。

```sql
CREATE TABLE asset_price_snapshots (
  -- 主鍵
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  PRIMARY KEY (asset_type, symbol),
  
  -- 股票資訊
  name TEXT,                    -- 股票名稱（後續維護，目前可選）
  currency TEXT NOT NULL,
  
  -- 價格數據
  current_price DECIMAL(18, 8),
  previous_price DECIMAL(18, 8),
  current_price_date DATE,       -- 價格日期（後端提供，例如昨天收盤價的日期）
  previous_price_date DATE,
  
  -- 時間戳記
  last_updated TIMESTAMP NOT NULL,        -- 後端最後更新時間
  last_successful_update TIMESTAMP,       -- 最後一次成功從外部 API 獲取的時間
  last_api_fetch TIMESTAMP,               -- 最後一次從外部 API 獲取的時間（保留，可能用於監控）
  
  -- 索引
  CREATE INDEX idx_price_last_updated ON asset_price_snapshots(last_updated);
  CREATE INDEX idx_price_last_successful_update ON asset_price_snapshots(last_successful_update);
);
```

#### 欄位說明

- **asset_type + symbol**：唯一識別一檔股票（例如：stockTW + "2330"）
- **name**：股票名稱（例如：台積電），後續會從 Core Data 或其他來源維護
- **current_price**：當前價格（最新一次成功獲取的價格）
- **previous_price**：上一次價格（作為備份，當 current_price 獲取失敗時使用）
- **current_price_date**：當前價格的日期（後端提供的價格日期，例如昨天收盤價的日期）
- **previous_price_date**：上一次價格的日期
- **last_updated**：快照最後更新時間（無論成功或失敗）
- **last_successful_update**：最後一次成功獲取價格的時間

#### PreviousPrice 邏輯

1. **首次更新**（previousPrice 為 nil）：
   - previousPrice = newPrice
   - currentPrice = newPrice（兩個值相同）

2. **後續更新**（previousPrice 已有值）：
   - previousPrice = 舊的 currentPrice（保存舊值）
   - currentPrice = 新獲取的價格

3. **更新失敗**：
   - currentPrice 設為 nil
   - previousPrice 保持不變
   - 顯示時使用 previousPrice 作為備份

### 2. account_snapshots 表（帳戶快照）

用於儲存每個帳戶的快照數據，包含現金餘額和持股列表。

```sql
CREATE TABLE account_snapshots (
  account_id UUID PRIMARY KEY,
  
  -- 現金相關
  cash_balance DECIMAL(18, 2) NOT NULL,
  
  -- 持股列表（JSONB 格式）
  holdings JSONB,  -- 只包含 symbol, quantity, averageCost 等，不包含價格
  
  -- 債務相關（僅債務帳戶）
  liability_id UUID,
  remaining_balance DECIMAL(18, 2),
  total_paid_principal DECIMAL(18, 2),
  total_paid_interest DECIMAL(18, 2),
  total_saved_interest DECIMAL(18, 2),
  paid_periods INTEGER,
  total_periods INTEGER,
  
  -- 時間戳記
  last_updated TIMESTAMP NOT NULL,
  last_transaction_date TIMESTAMP,  -- 最後一筆交易日期（用於驗證快照是否完整）
  version INTEGER NOT NULL DEFAULT 0,  -- 版本號（用於樂觀鎖定）
  
  -- 外鍵
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE INDEX idx_account_snapshots_last_updated ON account_snapshots(last_updated);
```

#### Holdings JSONB 結構範例

```json
[
  {
    "id": "holding-uuid",
    "assetType": "stockTW",
    "symbol": "2330",
    "name": "台積電",
    "quantity": 10,
    "averageCost": 480,
    "currency": "TWD",
    "lastUpdated": "2024-01-16T10:00:00Z"
  }
]
```

注意：holdings 中不包含 currentPrice，價格從 asset_price_snapshots 表讀取。

## 後端架構

### 1. 定期更新任務（Daily Price Update Job）

#### 觸發時機
- 每天收盤後（例如：台灣時間 15:00）
- 使用 Cron Job 或 Scheduled Task

#### 更新流程

```
1. 掃描所有使用者的持股快照（UserHoldingsSnapshot）
   - 找出所有唯一的股票（assetType + symbol）
   - 例如：10個使用者，100檔股票

2. 批量透過外部 API 獲取這100檔股票的收盤價
   - 呼叫外部股票 API（例如：Yahoo Finance, Alpha Vantage 等）
   - 記錄獲取結果（成功/失敗）

3. 更新 asset_price_snapshots 表
   For each 股票:
     - 如果獲取成功：
       previousPrice = 舊的 currentPrice
       currentPrice = 新獲取的價格
       currentPriceDate = 收盤價的日期
       lastSuccessfulUpdate = 現在時間
     - 如果獲取失敗：
       currentPrice 設為 nil（或保持舊值）
       previousPrice 保持不變
     - 更新 lastUpdated = 現在時間

4. 記錄更新結果（可選，用於監控）
   - 成功更新的股票數量
   - 失敗的股票列表
   - 錯誤日誌
```

#### 偽代碼範例

```python
def daily_price_update_job():
    # 1. 掃描所有使用者的持股
    all_symbols = scan_all_user_holdings()
    # 結果：[(assetType, symbol), ...]
    
    # 2. 批量獲取價格
    price_results = fetch_prices_from_external_api(all_symbols)
    
    # 3. 更新資料庫
    for (asset_type, symbol), price_data in price_results.items():
        snapshot = db.query(asset_price_snapshots).filter(
            asset_type=asset_type,
            symbol=symbol
        ).first()
        
        if price_data.success:
            # 更新價格
            old_current_price = snapshot.current_price
            old_current_price_date = snapshot.current_price_date
            
            snapshot.previous_price = old_current_price
            snapshot.previous_price_date = old_current_price_date
            snapshot.current_price = price_data.price
            snapshot.current_price_date = price_data.date
            snapshot.last_successful_update = datetime.now()
        else:
            # 獲取失敗，保持 previousPrice
            snapshot.current_price = None
            # previousPrice 保持不變
        
        snapshot.last_updated = datetime.now()
        db.commit()
```

### 2. 前端 API 設計

#### API 1：批量獲取股票價格（使用者登入時）

**端點**：`POST /api/v1/prices/batch`

**用途**：使用者登入 APP 時，批量獲取該使用者持有的股票價格。

**Request Body**：
```json
{
  "symbols": [
    {
      "assetType": "stockTW",
      "symbol": "2330"
    },
    {
      "assetType": "stockUS",
      "symbol": "AAPL"
    },
    {
      "assetType": "crypto",
      "symbol": "BTC"
    }
  ]
}
```

**Response**：
```json
{
  "prices": [
    {
      "assetType": "stockTW",
      "symbol": "2330",
      "name": "台積電",
      "currency": "TWD",
      "currentPrice": 500.00,
      "previousPrice": 495.00,
      "currentPriceDate": "2024-01-16",
      "previousPriceDate": "2024-01-15",
      "lastSuccessfulUpdate": "2024-01-16T15:30:00Z"
    },
    {
      "assetType": "stockUS",
      "symbol": "AAPL",
      "name": "Apple Inc.",
      "currency": "USD",
      "currentPrice": 150.00,
      "previousPrice": 148.00,
      "currentPriceDate": "2024-01-16",
      "previousPriceDate": "2024-01-15",
      "lastSuccessfulUpdate": "2024-01-16T15:30:00Z"
    }
  ]
}
```

**後端處理邏輯**：
1. 從 request body 中提取 symbols 列表
2. 從 asset_price_snapshots 表批量查詢這些股票的價格
3. 如果某些股票沒有價格數據，可選：
   - 返回 null（前端處理）
   - 或後端即時獲取（見 API 2）
4. 返回價格數據

#### API 2：單檔股票價格（新增股票時）

**端點**：`GET /api/v1/prices/{assetType}/{symbol}`

**用途**：使用者新增股票時，如果資料庫沒有該股票的價格，即時獲取並儲存。

**Request**：
```
GET /api/v1/prices/stockUS/AAPL
```

**Response（成功）**：
```json
{
  "assetType": "stockUS",
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "currency": "USD",
  "currentPrice": 150.00,
  "previousPrice": 150.00,  // 首次獲取，兩個值相同
  "currentPriceDate": "2024-01-16",
  "previousPriceDate": "2024-01-16",
  "lastSuccessfulUpdate": "2024-01-16T10:00:00Z"
}
```

**Response（失敗）**：
```json
{
  "error": "Price not found",
  "message": "Unable to fetch price from external API"
}
```

**後端處理邏輯**：
1. 檢查資料庫是否有該股票的價格
2. 如果有，直接返回資料庫中的價格
3. 如果沒有：
   a. 透過外部 API 獲取價格
   b. 如果成功：
      - 寫入 asset_price_snapshots 表（previousPrice = currentPrice = 新價格）
      - 返回價格數據
   c. 如果失敗：
      - 返回錯誤

**偽代碼範例**：
```python
def get_price(asset_type, symbol):
    # 1. 檢查資料庫
    snapshot = db.query(asset_price_snapshots).filter(
        asset_type=asset_type,
        symbol=symbol
    ).first()
    
    if snapshot and snapshot.current_price:
        # 資料庫有價格，直接返回
        return {
            "assetType": snapshot.asset_type,
            "symbol": snapshot.symbol,
            "name": snapshot.name,
            "currentPrice": snapshot.current_price,
            "previousPrice": snapshot.previous_price,
            # ...
        }
    
    # 2. 資料庫沒有，從外部 API 獲取
    price_data = fetch_price_from_external_api(asset_type, symbol)
    
    if price_data:
        # 3. 寫入資料庫
        if snapshot:
            # 更新現有記錄
            snapshot.previous_price = snapshot.current_price or price_data.price
            snapshot.previous_price_date = snapshot.current_price_date or price_data.date
            snapshot.current_price = price_data.price
            snapshot.current_price_date = price_data.date
        else:
            # 建立新記錄
            snapshot = AssetPriceSnapshot(
                asset_type=asset_type,
                symbol=symbol,
                current_price=price_data.price,
                previous_price=price_data.price,  # 首次：兩個相同
                current_price_date=price_data.date,
                previous_price_date=price_data.date
            )
            db.add(snapshot)
        
        snapshot.last_successful_update = datetime.now()
        snapshot.last_updated = datetime.now()
        db.commit()
        
        return convert_to_response(snapshot)
    else:
        # 獲取失敗
        return {"error": "Price not found"}
```

## 前端與後端的互動流程

### 1. 使用者登入 APP 時的流程

```
前端：
1. 讀取使用者所有帳戶的快照（AccountSnapshot）
2. 從快照中提取所有持有的股票（symbol + assetType）
3. 呼叫 API 1：POST /api/v1/prices/batch
4. 接收價格數據
5. 更新本地 AssetPriceSnapshot
6. 組合顯示：AccountSnapshot.holdings + AssetPriceSnapshot = 完整持股資訊

後端：
1. 接收批量價格請求
2. 從 asset_price_snapshots 表查詢價格
3. 返回價格數據
```

### 2. 使用者新增股票時的流程

```
前端：
1. 使用者新增股票交易（買入）
2. 檢查本地是否有該股票的價格
3. 如果沒有，呼叫 API 2：GET /api/v1/prices/{assetType}/{symbol}
4. 接收價格數據（或錯誤）
5. 如果成功，更新本地 AssetPriceSnapshot
6. 如果失敗，顯示錯誤或使用 previousPrice

後端：
1. 檢查資料庫是否有價格
2. 如果有，返回
3. 如果沒有，即時從外部 API 獲取
4. 獲取成功：寫入資料庫並返回
5. 獲取失敗：返回錯誤
```

### 3. 定期更新任務的影響

```
後端（每天收盤後）：
1. 掃描所有使用者的持股
2. 批量更新股價到 asset_price_snapshots 表

前端（使用者登入時）：
1. 從後端獲取最新價格
2. 更新本地快照
3. 顯示最新價格
```

## 未來考慮事項

### 1. 價格更新頻率

- **目前**：每天收盤後更新一次（目標：至少有昨天的收盤價）
- **未來**：可考慮增加更新頻率（例如：盤中更新）

### 2. 價格更新失敗處理

- **目前**：使用 previousPrice 作為備份
- **未來**：可考慮重試機制、錯誤通知、監控告警

### 3. 股票名稱維護

- **目前**：name 欄位可選，後續維護
- **未來**：從 Core Data 或其他來源批量更新股票名稱

### 4. 性能優化

- **資料庫索引**：已建立必要的索引
- **批量查詢**：使用批量 API 減少請求次數
- **緩存策略**：可考慮使用 Redis 緩存熱門股票價格

### 5. 監控與日誌

- **更新任務監控**：記錄更新成功/失敗數量
- **API 調用監控**：記錄 API 請求量和響應時間
- **錯誤日誌**：記錄價格獲取失敗的詳細信息

## 總結

本設計實現了：

1. **集中管理**：後端統一維護所有使用者需要的股票價格
2. **批量更新**：定期批量更新，減少 API 調用
3. **容錯機制**：使用 previousPrice 作為備份
4. **按需讀取**：前端只讀取使用者需要的股票價格
5. **即時獲取**：新增股票時，如果資料庫沒有，即時獲取並儲存

這個架構可以大幅提升應用程式性能，減少前端計算負擔，並提供穩定的價格數據服務。
