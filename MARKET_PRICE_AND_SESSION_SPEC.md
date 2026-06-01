# Snapvest 股價更新與盤中狀態 — 產品規格與實作建議

> **狀態**：已實作（2026-05-31）  
> **建立**：2026-05-31  
> **相關現有文件**：[BACKEND_AND_APIS.md](./BACKEND_AND_APIS.md)、[ENGINEERING_HANDBOOK.md](./ENGINEERING_HANDBOOK.md)

---

## 一、產品需求整理（七項）

### 需求 1：App 與後端能判斷「是否正在交易（盤中）」

| 項目 | 說明 |
|------|------|
| **目標** | App 與後端對「台股／美股／加密」有**一致**的盤中判斷；App 在對應市場 regular 交易時段內顯示「盤中」標示。 |
| **非目標** | 不要求逐筆即時行情；不處理使用者手機時區自行推算（以伺服器／台北時間為準）。 |
| **例假日／颱風** | 不能只靠「週一～五 + 9:00–13:30」；需有**交易日曆**（休市日不顯示盤中、不跑盤中高頻更新）。 |

**建議 UI（範例）**

- 台股 regular 內：標籤「台股盤中」
- 美股 regular 內：標籤「美股盤中」
- 休市日：不顯示盤中；可顯示「今日休市」或「顯示上一交易日收盤」
- 加密：可標「24 小時交易」或依產品選擇不顯示「盤中」（見需求 5）

---

### 需求 2：App 進入、下拉更新、新增股票 — 一律從 DB 取最新股價

| 觸發 | 行為 |
|------|------|
| 冷啟動進 App | 讀 Supabase `asset_price_snapshots`（批量：`fetch-prices-batch` 或既有 REST），再重算本機快照／淨值 |
| 下拉刷新 | 同上；**不**對每檔持股直接打 Finnhub／FinMind |
| 新增股票 | 讀 DB；若該檔尚無價格，可走既有 `fetch-or-create-price` **單檔**補寫入 DB 後再顯示 |

**原則**

- API Key 僅在後端；App 只持 Supabase anon key。
- 「最新」= **DB 裡該檔 `current_updated_at` 最新的那一筆**，由後端排程（需求 3～5）負責寫入。
- 若 DB 比本機舊，沿用現有 `shouldFetchPrices`／`price_update_metadata` 邏輯觸發同步。

---

### 需求 3：盤中後端每 10～15 分鐘更新 DB（僅 `tracked_symbols`）

| 項目 | 說明 |
|------|------|
| **頻率** | 建議 **10 分鐘**（排程可設 8～9 分鐘觸發，留執行緩衝）；若 API 配額緊可改 **15 分鐘**。 |
| **範圍** | 僅更新 **`tracked_symbols`（`is_active = true`）** 去重後的清單，不每輪重掃全站 seed 熱門股（seed 可併入 tracked 或每日一次即可）。 |
| **條件** | 僅在該市場 **`isIntradayActive`（交易日 ∧ regular 時段）** 時執行（見需求 1、4）。 |
| **寫入** | `asset_price_snapshots` + 更新 `price_update_metadata`；台股同輪可一併匯率（FinMind 台銀牌告）。 |

**與現有程式關係**

- 可重用 [backend/scripts/daily_price_update.py](./backend/scripts/daily_price_update.py) 的抓價與 upsert 邏輯；排程**僅**讀 `tracked_symbols`（已移除 `hot_stocks` catalog）。

---

### 需求 4：收盤後不再盤中高頻抓價；收盤時抓收盤價；App 顯示「收盤」

| 階段 | 後端 | App 顯示 |
|------|------|----------|
| **Regular 盤中** | 每 10～15 分鐘更新（需求 3） | 顯示「N 分鐘前」（需求 6） |
| **收盤後（仍為交易日）** | **停止**盤中輪詢；在**收盤後固定時間**跑一輪「收盤價寫入」 | 標示 **「收盤」**（需求 6） |
| **休市日** | 不跑盤中、不跑收盤；保留上一交易日價格 | 「休市」+ 收盤價或上一交易日 |

**建議收盤後排程（台灣時間，可微調）**

| 市場 | 收盤後抓取時間 | 說明 |
|------|----------------|------|
| 台股 | 週一～五 **14:00** 或 **14:30** | 13:30 收盤後緩衝 |
| 美股 | 週二～六 **07:00**（沿用現有思路）或 夏令時間對應 **06:00 / 07:00 台北** | 對齊美股收盤後 |
| 加密 | 不適用「收盤」 | 見需求 5 |

**資料欄位建議**

- 在 snapshot 或 metadata 標記 `price_kind`：`intraday` | `close`（或沿用 `current_close_date` + session 判斷）。
- App 若 `!isIntradayActive && isTradingDay` 且價格為當日收盤寫入 → 顯示「收盤」。

---

### 需求 5：加密貨幣每小時更新一次

| 項目 | 說明 |
|------|------|
| **頻率** | **每 60 分鐘** 一輪（可 `:00` 觸發） |
| **範圍** | `tracked_symbols` 中 `asset_type = crypto` |
| **盤中概念** | 7×24；**不**顯示「盤中／收盤」時，可顯示「N 分鐘前」或「每小時更新」 |
| **API** | 沿用 CoinGecko 批次（現有腳本已支援 batch） |

---

### 需求 6：股價旁註明「幾分鐘前」或「收盤」

| 狀態 | 顯示文案（建議） |
|------|------------------|
| 盤中、價格為 intraday 更新 | `更新於 3 分鐘前`（由 `current_updated_at` 與伺服器時間差計算，建議 **無條件進位到整數分鐘**，<1 分鐘可顯示「剛剛」） |
| 收盤後當日最終價 | `收盤`（可選括號收盤日 `5/30 收盤`） |
| 休市日 | `休市` 或 `上一交易日收盤` |
| 無價格 | `--` |

**資料來源**

- 每檔：`asset_price_snapshots.current_updated_at`（及可選 `price_kind` / `current_close_date`）。
- 市場狀態：`market-status` API（需求 1），決定用「分鐘前」還是「收盤」模板。

---

### 需求 7：除 GitHub Actions 外的自動排程方案

**現況問題**

- GitHub Actions `schedule` 常見 **延遲數分鐘～數小時**（排隊、免費額度、尖峰時段），不適合「盤中每 10 分鐘」。
- 現有 workflow：[.github/workflows/daily-price-update.yml](./.github/workflows/daily-price-update.yml) 適合**低頻**（收盤後、每日），不適合盤中高頻。

---

## 二、建議整體架構

```
┌─────────────────────────────────────────────────────────────────────────┐
│  iOS App                                                                 │
│  · GET market-status → 顯示「盤中／收盤／休市」                           │
│  · 進 App / 下拉 / 加股 → fetch-prices-batch 讀 DB → 重算快照            │
│  · 股價旁：「N 分鐘前」或「收盤」（依 market-status + updated_at）        │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ 僅 Supabase REST / Edge（無行情 API Key）
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Supabase                                                                │
│  · asset_price_snapshots（現有）                                         │
│  · tracked_symbols（現有，更新範圍來源）                                  │
│  · market_calendar（新建，交易日／提前收盤／休市）                         │
│  · price_update_metadata（現有）                                         │
│  Edge: market-status | fetch-prices-batch | fetch-or-create-price       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▲
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
 ┌──────────────┐      ┌──────────────┐       ┌──────────────┐
 │ 盤中 worker   │      │ 收盤 worker   │       │ 加密 hourly   │
 │ 每 8–10 分    │      │ 台 14:00      │       │ 每 60 分      │
 │ tracked only │      │ 美 07:00      │       │ tracked crypto│
 │ tw / us      │      │ + 匯率        │       │               │
 └──────┬───────┘      └──────┬───────┘       └──────┬───────┘
        │                       │                       │
        └───────────────────────┴───────────────────────┘
                                │
                    FinMind（台）/ Finnhub（美）/ CoinGecko（加密）
```

**單一真相（SSOT）**

1. **是否盤中**：`market_calendar` + 固定 regular 時段 → 後端函式 `marketStatus(market, now)` → Edge `market-status` → App。
2. **股價數字**：一律 `asset_price_snapshots`；後端 worker 唯一寫入者（加股補洞除外）。

---

## 三、市場狀態定義（需求 1 實作要點）

### 3.1 名詞

| 名詞 | 定義 |
|------|------|
| `isTradingDay` | 今日在該交易所交易日曆上為交易日（含補班開市；排除颱風停盤等） |
| `isRegularSession` | `isTradingDay` 且目前鐘點落在 regular 時段內 |
| `isIntradayActive` | 是否應執行盤中 10～15 分鐘更新；建議 **= `isRegularSession`** |
| `shouldShowClosingLabel` | 交易日但已過 regular → App 顯示「收盤」 |

### 3.2 靜態 regular 時段（第 1 層）

| 市場 | 時區 | Regular |
|------|------|---------|
| 台股 `tw` | `Asia/Taipei` | 09:00–13:30 |
| 美股 `us` | `America/New_York` | 09:30–16:00（含夏令） |
| 加密 `crypto` | — | 不套用「盤中」標籤（或標 24h） |

### 3.3 交易日曆（第 2 層，解決假日／颱風）

| 市場 | 建議來源 | 同步頻率 |
|------|----------|----------|
| 台股 | FinMind `TaiwanStockTradingDate`（已有 `FINMIND_TOKEN`） | 每日 06:00 台北 |
| 美股 | Finnhub Market Holiday（已有 `FINNHUB_API_KEY`） | 每日 06:00 台北 |
| 提前收盤 | 日曆表存當日 `session_close` 非 16:00 ET | 同上 |

**新表 `market_calendar`（建議）**

- `market`：`tw` | `us`
- `trade_date`：date
- `is_trading_day`：boolean
- `session_open` / `session_close`：timestamptz 或 time + tz
- `holiday_name`：nullable
- `source` / `synced_at`

### 3.4 Edge：`GET /functions/v1/market-status`

查詢參數：`markets=tw,us,crypto`  
回傳各市場 `isTradingDay`、`isRegularSession`、`session`、`reason`、`nextOpen`（可選）。  
App 快取 5～15 分鐘。

---

## 四、排程設計（對應需求 3～5、7）

### 4.1 建議排程總表（台灣時間）

| 任務 | 頻率 | 市場 | 條件 | 更新範圍 |
|------|------|------|------|----------|
| **盤中價** | 每 **8～10** 分 | 台股 | `isIntradayActive(tw)` | `tracked_symbols` 台股 |
| **盤中價** | 每 **8～10** 分 | 美股 | `isIntradayActive(us)` | `tracked_symbols` 美股 |
| **收盤價** | 每日 **14:00** 左右 | 台股 | 交易日 | tracked 台股 + 匯率 |
| **收盤價** | 每日 **07:00** 左右 | 美股 | 交易日（對應美股收盤後） | tracked 美股 |
| **加密** | 每 **60** 分 | 加密 | 全天 | tracked 加密 |
| **日曆同步** | 每日 **06:00** | tw, us | — | 寫入 `market_calendar` |

GitHub Actions：**保留**收盤價／日曆／每月 symbol 清單等**低頻**任務即可；**盤中 10 分鐘不要用 GitHub**。

### 4.2 排程平台建議（取代 GitHub 盤中高頻）

依「與現有 Supabase / Python 腳本整合難度」排序：

| 方案 | 延遲 | 適合 | 備註 |
|------|------|------|------|
| **① Supabase pg_cron + Edge Function** | 低（秒～分鐘級） | 盤中每 10 分、加密每小時 | 需 **Supabase Pro**（或 Team）才有 pg_cron；Edge 內呼叫 FinMind/Finnhub 或 HTTP 觸發外部 worker |
| **② Supabase Edge + 第三方 cron 打 HTTP** | 低 | 同上 | 用 [cron-job.org](https://cron-job.org)、**EasyCron**、**Render Cron** 等每 10 分 `POST` 你的 Edge `run-intraday-prices`；Secret 保護 |
| **③ Cloudflare Workers Cron Triggers** | 低 | 觸發 Edge 或 Worker 內抓價 | 免費額度通常夠；要把 Python 邏輯移植到 TS 或 Worker 只負責「觸發」跑在別處的腳本 |
| **④ Google Cloud Scheduler → Cloud Run Job** | 低 | 直接跑現有 `daily_price_update.py` | 容器化現有腳本，幾乎零改邏輯；GCP 有免費額度，超出後付費 |
| **⑤ Railway / Fly.io / Render 的 Cron** | 低～中 | 跑 Python 腳本 | 月費固定，適合不想改 Edge 的團隊 |
| **⑥ GitHub Actions** | **高（常延遲）** | 僅收盤後每日、每月 symbols | **不建議**盤中每 10 分 |

**建議選型（務實）**

- **短期、最少改動**：**Cloud Run Job** 或 **Railway Cron** 每 10 分執行 `python daily_price_update.py --intraday --markets tw`（美股另排），環境變數與 GitHub Secrets 相同。
- **長期、全在 Supabase**：**Pro + pg_cron** 呼叫 Edge，或 pg_cron 觸發 **Database Webhook** → Edge。
- **GitHub**：保留 `workflow_dispatch` 手動全量、收盤 workflow；盤中遷出。

---

## 五、App 行為規格（需求 2、6）

### 5.1 冷啟動

1. （可選）`market-status` → UI 盤中標籤  
2. `shouldFetchPrices` 或一律 `fetch-prices-batch`（依產品：建議**每次進 App 都讀 DB**，不必等 metadata 變才讀）  
3. `SnapshotRefreshCoordinator.rebuildAndNotify`  
4. 各列表依 `current_updated_at` 顯示「N 分鐘前」／「收盤」

### 5.2 下拉刷新

- 與冷啟動相同：**只讀 DB + 重算**，不觸發全檔外部 API。  
- 若 DB 最後盤中更新已 >15 分鐘且仍在 `isIntradayActive`：可顯示「股價同步中」並依賴下一輪 worker（**不**在 App 內打 30 次 Finnhub）。

### 5.3 新增股票

1. `track-symbol`（現有）加入 `tracked_symbols`  
2. 讀 DB；無則 `fetch-or-create-price` **一檔**  
3. 該檔納入下一輪盤中／每小時加密更新

### 5.4 顯示邏輯（偽碼）

```
if 無價格 → "--"
else if 市場休市日 → "休市"
else if 價格標記為 close 或 (!isIntradayActive && 當日已寫入收盤) → "收盤"
else → "更新於 {minutes} 分鐘前"
```

---

## 六、API 用量與供應商（現有 vs 加購）

### 6.1 現有即可起步（不強制 iTick）

| 用途 | 供應商 | 備註 |
|------|--------|------|
| 台股盤中／收盤 | **FinMind**（`FINMIND_TOKEN`） | 注意 **600 次/小時**；`tracked_symbols` 台股檔數 × 每 10 分鐘一輪需試算 |
| 美股盤中／收盤 | **Finnhub** `/quote`（`FINNHUB_API_KEY`） | **無 batch**；N 檔 ≈ N 次/輪；並行 + 限速 |
| 加密每小時 | **CoinGecko** | 現有批次邏輯 |
| 台股日曆 | FinMind | 同 token |
| 美股假日 | Finnhub | 同 key |
| 備援 | yfinance | 現有腳本已支援 |

**試算（盤中每 10 分鐘，僅 tracked）**

- 假設活躍池：台 80 + 美 60 + 加密 20  
- 台股：80 × 6 輪/小時 = **480/hr**（接近 FinMind 600 上限）  
- 美股：60 × 6 = **360/hr**（Finnhub 免費 60/min 通常夠）  
- 成長後需：**縮小更新池**、**15 分鐘間隔**、**FinMind 整表查詢**，或 **iTick batch**

### 6.2 建議付費／加購（依規模）

| 項目 | 何時需要 | 說明 |
|------|----------|------|
| **FinMind 付費** | tracked 台股 >50～80 且 10 分鐘一輪 | 提高每小時請求上限 |
| **Finnhub 付費** | 美股 tracked 多、或要更低延遲 | 提高 calls/min；仍可能需逐檔 quote |
| **iTick（可選）** | 台+美 tracked 合計 >100、要減少 HTTP 次數 | `/stock/quotes?region=TW&codes=...` 批次；注意方案單次 codes 上限（10/20/50） |
| **Supabase Pro** | 要用 **pg_cron** 在庫內排程 | 約 $25/月起；也可用外部 cron 免費打 Edge 暫不升級 |
| **Cloud Run / Railway** | 跑 Python 盤中 worker | 小流量常落在免費～低月費（約 $5–20/月） |
| **CoinGecko** | 加密 tracked 很多、超免費額度 | 每小時 batch 通常免費夠用 |

**不建議為此需求單買**：GitHub Actions 付費（無法根本解決 schedule delay）。

---

## 七、實作階段建議（仍不改碼，僅路線）

| 階段 | 內容 | 產出 |
|------|------|------|
| **P0** | `market_calendar` 同步 + `market-status` Edge + App 盤中/休市標籤 | 需求 1 |
| **P1** | 盤中 worker（tracked only, 10min）+ 收盤 worker；遷移排程離開 GitHub 高頻 | 需求 3、4、7 |
| **P2** | App：進 App/下拉必讀 DB；股價「N 分鐘前／收盤」 | 需求 2、6 |
| **P3** | 加密每小時 job | 需求 5 |
| **P4** | 監控：上一輪失敗、日曆過期、`tracked_symbols` 配額告警 | 維運 |

---

## 八、與現有程式的差異摘要

| 現狀 | 目標 |
|------|------|
| 股價主要靠 GitHub 每日 18:00 / 07:00 | 盤中 10～15 分 + 收盤各一次 + 加密每小時 |
| 無盤中判斷 | `market_calendar` + `market-status` |
| `shouldFetchPrices` 可能跳過進 App 同步 | 進 App／下拉**一律讀 DB**（metadata 僅供提示） |
| `fetch-prices-batch` 只讀 DB | 維持；寫入只靠 worker |
| ~~`hot_stocks` 每輪重建~~ | 已退役；盤中／收盤只更新 **tracked_symbols** |
| App 無「幾分鐘前」 | 用 `current_updated_at` + 狀態文案 |

---

## 九、已決策參數（2026-05-31）

1. **盤中更新間隔**：**15 分鐘**（台股、美股）。  
2. **排程平台**：**Cloud Scheduler → Cloud Run Job**；DB 維持 **Supabase**。  
3. **美股盤中**：**要**（夜間 regular 時段每 15 分鐘）。  
4. **加密 UI**：**不顯示盤中**；僅「N 分鐘前」。加密排程 **每 1 小時**。  
5. **匯率**：**每天 1 次**（併台股收盤 job 或 `--mode exchange`）。  
6. **asset_price_history**：台／美僅 **close job** 寫收盤價；加密在 **台北 00:00 `crypto_hourly`** 寫入 **昨日** `price_date`（已移除 23:55 rollup）。  
7. **更新範圍**：盤中／收盤／加密 hourly 使用 **`tracked_symbols` only**（`is_active`）。

---

## 十、驗證清單

- [ ] 執行 migration `019`、`020` 後部署 Edge：`market-status`、`fetch-prices-batch`、`fetch-or-create-price`
- [ ] 盤中 `--mode intraday` 兩輪：`asset_price_snapshots` 更新、`asset_price_history` 該日列數不增加
- [ ] `--mode close` 後：history 有收盤價；App 顯示「收盤」
- [ ] 台北 **00:00** `crypto_hourly` 後：加密 history 的 `price_date` 為昨日
- [ ] 休市日 intraday job 快速結束；投資頁無「台股盤中」標籤

## 十一、文件維護

- [BACKEND_AND_APIS.md](./BACKEND_AND_APIS.md)、[ENGINEERING_HANDBOOK.md](./ENGINEERING_HANDBOOK.md) 已同步排程與 history 規則。  
- 細部 API 欄位以 migration 與 Edge 實作為準。
