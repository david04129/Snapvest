# Snapvest 後端架構與股價 API 說明

## 一、整體架構

```
┌─────────────────┐     ┌──────────────────────────────────────┐
│   iOS App       │     │            Supabase                   │
│                 │────▶│  PostgreSQL (asset_price_snapshots) │
│  - 讀取股價     │     │  - 股價快照                           │
│  - 新增股票時   │     │  - hot_stocks（熱門股）               │
│    呼叫 Edge    │     └──────────────────────────────────────┘
│    Function     │                      ▲
└────────┬────────┘                      │
         │                               │ 寫入
         │ 即時取價                      │
         ▼                               │
┌────────────────────────────────────────────────────────────┐
│  Edge Function: fetch-or-create-price                      │
│  - 資料庫無資料時，從外部 API 抓取並寫入                     │
└────────────────────────────────────────────────────────────┘
         │
         │ 每日批量更新
         ▼
┌────────────────────────────────────────────────────────────┐
│  GitHub Actions (daily-price-update)                       │
│  - 分時排程：週一～五 16:00 匯率+台股+加密；週六日 16:00 加密；週二～六 07:00 美股 │
│  - backend/scripts/daily_price_update.py                   │
└────────────────────────────────────────────────────────────┘
```

---

## 二、股價抓取流程

### 1. App 端：單檔取價（`PriceService.fetchCurrentPrice`）

當畫面需要顯示某一檔的「目前股價」（例如買入表單、持有明細）時：

```
┌─────────────────────────────────────────────────────────────────┐
│  PriceService.fetchCurrentPrice(assetType, symbol)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │ Supabase 已設定？              │
              └───────────────────────────────┘
                     │是              │否
                     ▼                ▼
    ┌────────────────────────────┐   DataService（Mock 本機）
    │ Supabase REST API         │
    │ GET asset_price_snapshots  │
    │ ?asset_type=eq.xxx         │
    │ &symbol=eq.xxx             │
    └────────────────────────────┘
                     │
            ┌───────┴───────┐
            │ 有資料？      │
            └───────┬───────┘
               │是       │否
               ▼         ▼
            回傳價格   fetchOrCreatePrice（見下）
                           │
                    ┌──────┴──────┐
                    │ 成功？      │
                    └──────┬──────┘
                      │是    │否
                      ▼      ▼
                   回傳   回傳 nil（顯示 --）
```

### 2. App 端： Edge Function 即時取價（`SupabasePriceService.fetchOrCreatePrice`）

當資料庫沒有該檔價格時觸發（例如使用者新增一檔冷門股）：

```
┌─────────────────────────────────────────────────────────────────┐
│  POST .../functions/v1/fetch-or-create-price                    │
│  Body: { "assetType": "stock_us", "symbol": "GRAB" }             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Edge Function 內部流程：                                         │
│  1. 再查一次 DB（asset_price_snapshots）→ 有則直接回傳             │
│  2. 沒有 → 依 assetType 呼叫對應 API：                            │
│     - 台股：TWSE → Yahoo 備援                                    │
│     - 美股：Finnhub → Yahoo 備援（遇 429 重試一次）                │
│     - 加密：Finnhub → CoinGecko 備援                             │
│  3. 取到價格 → 寫入 asset_price_snapshots、加入 hot_stocks         │
│  4. 回傳 { price, currency, source }                            │
└─────────────────────────────────────────────────────────────────┘
```

### 3. App 端：批量取價（資產總覽、儀表板）

載入多檔持股價格時（`AssetsViewModel`、`SnapshotUpdater` 等）：

```
1. SupabasePriceService.fetchPrices(symbols) 
   → REST API 一次查多檔（並行请求）

2. 若有缺漏（某檔 DB 無資料）：
   → 對該檔呼叫 priceService.fetchCurrentPrice
   → 可能觸發 fetchOrCreatePrice，寫入 DB 後回傳
```

### 4. 後端：每日批量更新（GitHub Actions）

```
分時自動觸發（台灣時間：週一～五 16:00 匯率+台股+加密；週六日 16:00 加密；週二～六 07:00 美股）
         │
         ▼
daily_price_update.py
         │
         ├── 1. 從 Supabase 取得待更新清單
         │      - holdings 表（使用者持有）
         │      - hot_stocks 表（熱門股）
         │      - 合併去重
         │
         ├── 2. 美股 + 台股 → yfinance（Yahoo）
         │      - 逐檔抓取，每檔間隔 0.3 秒
         │
         ├── 3. 加密貨幣 → CoinGecko
         │      - 批次 API，ids 逗號分隔
         │      - 請求間隔 1.2 秒
         │
         └── 4. upsert 寫入 asset_price_snapshots
                - 舊 current_price 存為 previous_price
                - 更新 price_update_metadata.last_updated_at
```

### 5. 流程總覽圖

```
                     App 需要股價
                           │
            ┌──────────────┼──────────────┐
            │              │              │
        單檔取價        批量取價       歷史價格
            │              │              │
            ▼              ▼              ▼
   PriceService     fetchPrices     DataService
   fetchCurrentPrice    │          fetchPrices
            │              │         (Supabase)
            │              │
            └──────┬──────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ Supabase REST API    │
        │ asset_price_snapshots│
        └──────────────────────┘
                   │ 查無
                   ▼
        ┌──────────────────────┐
        │ Edge Function        │
        │ fetch-or-create-price│
        └──────────────────────┘
                   │ 呼叫外部 API
                   ▼
        TWSE / Finnhub / Yahoo / CoinGecko


        每日 16:00
              │
              ▼
        ┌──────────────────────┐
        │ GitHub Actions       │
        │ daily_price_update   │
        └──────────────────────┘
                   │
                   ▼
        yfinance / CoinGecko
                   │
                   ▼
        ┌──────────────────────┐
        │ asset_price_snapshots│
        └──────────────────────┘
```

---

## 三、後端與 GitHub 的關係

### 1. Supabase（主後端）

- **用途**：資料庫、Edge Function 託管
- **位置**：Supabase 雲端
- **金鑰**：
  - `SUPABASE_URL`、`SUPABASE_ANON_KEY`：App 端使用（可放 Info.plist）
  - `SUPABASE_SERVICE_ROLE_KEY`：後端／腳本／Edge Function 使用（不可給 App）

### 2. GitHub Repository

- **用途**：程式碼版控、GitHub Actions 排程
- **連結**：程式碼 push 到 GitHub，GitHub Actions 依排程執行每日股價更新

### 3. GitHub Actions

| 項目 | 說明 |
|------|------|
| **Workflow** | `.github/workflows/daily-price-update.yml` |
| **觸發** | 三組 cron（見 workflow 註解）、或手動 Run workflow（完整更新） |
| **工作** | 執行 `python backend/scripts/daily_price_update.py` |
| **Secrets** | 需在 repo Settings > Secrets 設定 `SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` |

### 4. Edge Function 部署

- **不經 GitHub**：手動在本機執行 Supabase CLI 部署
- **指令**：
  ```bash
  cd backend
  supabase link --project-ref 你的專案ID
  supabase functions deploy fetch-or-create-price
  ```
- **Secret**：`supabase secrets set FINNHUB_API_KEY=xxx`（選填）

---

## 四、股價取得來源一覽

### 1. 即時取價（Edge Function - 新增股票時）

當使用者在 App 新增一檔「資料庫還沒有」的股票時，會呼叫 Edge Function 即時抓價。

| 資產類型 | 主要 API | 備援 API | 備註 |
|----------|----------|----------|------|
| **台股** | TWSE 證交所 | Yahoo Finance | TWSE 免 API key，僅支援上市 |
| **美股** | Finnhub | Yahoo Finance | 需設 `FINNHUB_API_KEY` |
| **加密貨幣** | Finnhub (BINANCE:XXXUSDT) | CoinGecko | 需設 `FINNHUB_API_KEY` |

### 2. 每日批量更新（Python 腳本 - GitHub Actions）

依排程自動更新「使用者持有 ∪ hot_stocks」的價格（非 Top 500 全量）。

| 資產類型 | API | 備註 |
|----------|-----|------|
| **美股** | Yahoo Finance (yfinance) | 免費，可能遇到 rate limit |
| **台股** | Yahoo Finance (yfinance, symbol.TW) | 同上 |
| **加密貨幣** | CoinGecko | 免費，有請求頻率限制 |

### 3. API 詳細說明

#### TWSE（台股 - 即時取價用）
- **URL**：`https://www.twse.com.tw/exchangeReport/STOCK_DAY?response=json&date=YYYYMMDD&stockNo=股號`
- **免 API key**
- **限制**：僅上市股票；上櫃需改用 TPEx API

#### Finnhub（美股、加密貨幣 - 即時取價用）
- **URL**：`https://finnhub.io/api/v1/quote?symbol=XXX&token=API_KEY`
- **需註冊**：https://finnhub.io 取得免費 API key
- **設定**：`supabase secrets set FINNHUB_API_KEY=你的key`
- **Symbol 格式**：美股直接 `AAPL`；加密貨幣 `BINANCE:BTCUSDT`

#### Yahoo Finance（美股、台股 - 每日更新 + 即時備援）
- **用途**：Python 用 `yfinance`；Edge Function 直接呼叫 chart API
- **美股**：`https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1d&range=1d`
- **台股**：symbol 格式 `2330.TW`
- **限制**：易遇到 HTTP 429 rate limit

#### CoinGecko（加密貨幣 - 每日更新 + 即時備援）
- **URL**：`https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd`
- **免 API key**（有頻率限制）
- **Symbol 對應**：BTC→bitcoin, ETH→ethereum 等，見 Edge Function 內 `idMap`

---

## 五、快速參考

| 想做的事 | 操作 |
|----------|------|
| 本機測試每日更新 | `cd backend/scripts && python daily_price_update.py`（需設環境變數） |
| 手動觸發每日更新 | GitHub > Actions > Daily Price Update > Run workflow |
| 部署 Edge Function | `cd backend && supabase functions deploy fetch-or-create-price` |
| 設定 Finnhub | `supabase secrets set FINNHUB_API_KEY=xxx` |

---

## 六、每日排程沒跑？疑難排解

若 16:00 沒有自動更新，依序檢查：

### 1. 手動觸發測試
1. 開啟 GitHub repo 頁面
2. 點 **Actions** 分頁
3. 左側選 **Daily Price Update**
4. 點 **Run workflow** > **Run workflow**
5. 等約 1 分鐘，看是否有新的 run 出現
6. 點進該 run 查看日誌：若失敗會顯示錯誤（常見為 Secrets 未設定）

### 2. Secrets 是否正確
- 路徑：**Settings** > **Secrets and variables** > **Actions**
- 需有：`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY`
- 注意：名稱需完全一致，區分大小寫

### 3. Workflow 是否在 default branch
- Cron 只會執行 **default branch**（通常是 `main`）
- 確認 `.github/workflows/daily-price-update.yml` 已 push 到 main

### 4. GitHub 排程延遲
- 新建立或修改的 cron 有時要 **15 分鐘～1 小時** 才會被識別
- 可做一次小改動並 push，或等隔天再觀察

### 5. Repo 長期無活動
- 若超過約 60 天沒有 push，部分免費方案可能暫停排程
- 解法：隨意改一個檔案並 push

### 6. 暫時改用較高頻率測試
若想快速驗證 cron 是否會跑，可暫時改成每 5 分鐘一次：
```yaml
schedule:
  - cron: '*/5 * * * *'  # 每 5 分鐘（測試用，確認後改回 0 8 * * *）
```
確認有自動跑後，改回 `0 8 * * *`。
