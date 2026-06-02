# Edge／REST 防濫用與批次優化（PR1–PR3）

> 記錄 Snapvest 對 Supabase Edge／REST 請求量的分析、已實作項目（PR1／PR2）與待實作規格（PR3）。  
> 最後更新：2026-06-02

---

## 背景

- App 使用 **anon key** 呼叫 Edge Function 與部分 REST；**60 秒下拉冷卻**僅限 App UI，無法阻擋腳本直接重放 API。
- 正常路徑應以 **`fetch-prices-batch`** 讀價；最貴路徑為 **`fetch-or-create-price`**（Yahoo／CoinGecko + 寫 DB）。
- Edge `fetch-prices-batch` 上限 **`maxSymbols = 100`**；超過會失敗並觸發客戶端 REST fallback（改動前可達上百次 REST）。

### 請求量參考（改動前）

| 情境 | 約略客戶端 HTTP |
|------|-----------------|
| 60 檔下拉刷新（理想） | ~2–3（batch + metadata；投資 Tab 多 1 次 market-status） |
| 110 檔下拉刷新 | 1 batch 失敗 → **~110 REST** |
| 匯入 50 檔新標的（預覽） | **~50–150**（每檔 batch(1) + fetch-or-create） |
| 匯入寫入 50 筆 | 再 **~50 次驗價** |
| 惡意腳本 | 不受 App 冷卻限制 |

---

## PR1（已完成）— 客戶端批量優先

### 目標

- 持股／匯入驗價以 **chunk batch** 為主，避免 N 次單檔請求與 >100 檔時 REST 爆炸。

### 實作摘要

| 檔案 | 變更 |
|------|------|
| `SupabasePriceService.swift` | `maxBatchSymbols = 100`；`deduplicatedSymbolInfos`；`fetchPrices` 分批呼叫 `fetch-prices-batch` 後合併；僅缺價／失敗 chunk 走 REST fallback |
| `SymbolPriceValidator.swift` | 新增 `validatePricesAvailable(symbols:)`：1 次 batch + `resolveMissingPrices` |
| `TransactionImportService.swift` | `applyPriceValidation` 改批量驗價 |

### 驗證要點

- 110 檔刷新：Console 應見 **2 次** `chunk batch`，而非 110 次 REST。
- 匯入 50 檔預覽：**1 次** `fetch-prices-batch`（50 < 100）。

---

## PR2（已完成）— 缺價補齊與匯入略過重驗

### 目標

- 重建快照時不要每檔 `fetchDisplayPrice`；匯入寫入不重複打驗價 API。

### 實作摘要

| 檔案 | 變更 |
|------|------|
| `SupabasePriceService.swift` | `resolveMissingPrices`：`fetch-or-create-price` **最多 5 並行** |
| `SnapshotUpdater.swift` | batch 後對缺價清單呼叫 `resolveMissingPrices`，不再逐檔 `fetchDisplayPrice` |
| `TransactionsViewModel.swift` | `importValidatedTransactions(..., assumePricesValidated:)` |
| `TransactionImportView.swift` | 匯入時傳 `assumePricesValidated: true` |

### 驗證要點

- 匯入按鈕後寫入階段：**不應**再出現大量 batch／fetch-or-create；重建結束時 **1～2 次 batch**。
- 單檔買進表單仍可用 `fetchDisplayPrice`（刻意保留）。

---

## PR3（待實作）— 伺服器護欄與追蹤批量

### 目標

PR1／PR2 降低正常 App 流量；PR3 防止略過 App、用 anon key **狂打 Edge／最貴寫入路徑**。

### 工作項目 1：`fetch-or-create-price`（最高優先）

**現狀：**

- 有 `apikey` 檢查；DB 已有 `current_price` 時直接回傳。
- 無 `current_price` 時每次打 Yahoo／CoinGecko 並 upsert。
- 無 rate limit；symbol 驗證弱於其他 Edge。

**待做：**

| 子項 | 內容 |
|------|------|
| A. Rate limit | 以 `apikey`（可選 + IP）滑動視窗，例如 **30 次／分鐘**、**200 次／小時**；超限 **429** + `Retry-After` |
| B. 短快取 | snapshot 在 **N 分鐘**內已更新則禁止再打外部 API（建議 **5～15 分**，與 Cloud Run 盤中節奏對齊） |
| C. 單檔契約 | Body 僅 `{ assetType, symbol }`，拒絕陣列 |
| D. Symbol 驗證 | 與 `track-symbol`／`fetch-prices-batch` 相同 regex |
| E. 限流儲存 | 新表 `edge_rate_limit_buckets` 或 Upstash Redis + migration |

**不在 PR3：** 將 fetch-or-create 改為 Fugle（維持首次建檔 Yahoo）。

### 工作項目 2：`fetch-prices-batch` 限流

- 同一 `apikey` 例如 **30 POST／分鐘**。
- 可選：帶 `history` 的請求更低配額。
- 429 JSON：`{ error: "rate_limit_exceeded", retryAfterSeconds: N }`。
- **iOS：** 收到 429 顯示「請稍後再試」，避免無限重試。

### 工作項目 3：`track-symbol` 批量

**現狀：** iOS `TrackedSymbolSync` 每 symbol 一次 POST；匯入 50 檔 ≈ 50 次。

**待做：**

- 新 Edge **`track-symbols-batch`**：`{ symbols: [{ assetType, symbol }, ...] }`，上限 50～100，bulk upsert `tracked_symbols`。
- iOS `TrackedSymbolSync` 改為 chunk batch HTTP。
- 限流：例如 **10 batch／分鐘**；單檔 `track-symbol` 可 deprecated 或更嚴。
- **可選：** `fetch-or-create` 成功後由 server 順便寫 `tracked_symbols`（需產品確認）。

### 工作項目 4：共用基礎建設

- `backend/supabase/functions/_shared/rateLimit.ts`
- Migration（若用 DB）：

```sql
-- 概念示意（實作時以 migration 檔為準）
edge_rate_limit_buckets (
  bucket_key text primary key,  -- e.g. "fetch-or-create:<hash>:minute"
  count int not null,
  window_start timestamptz not null
);
```

- 部署：`supabase functions deploy` 相關函式；更新 `BACKEND_AND_APIS.md`、`ENGINEERING_HANDBOOK.md`。

### 工作項目 5：可選（PR3.1 或併入）

| 項目 | 說明 |
|------|------|
| REST 讀價收緊 | anon 不可 SELECT `asset_price_snapshots`，僅 Edge 讀（與 PR1 REST fallback 衝突，需另 PR） |
| `market-status` 限流 | 較輕，例如 60 次／分鐘 |
| 專案級 WAF | Supabase／Cloudflare 設定，非必須寫在 repo |

### PR3 建議實作順序

1. `_shared` rate limit + migration  
2. `fetch-or-create-price`（限流 + 快取 + symbol 驗證）  
3. `fetch-prices-batch`（限流）  
4. `track-symbols-batch` + iOS `TrackedSymbolSync`  
5. iOS 429 處理 + 文件  
6. （可選）`market-status` 限流  

### PR3 Done 定義

- [ ] 相關 Edge 回傳 429 + `Retry-After`  
- [ ] fetch-or-create 近期 snapshot 不打 Yahoo  
- [ ] track-symbols-batch 上線，iOS 追蹤 ≤ ceil(N/100) 次 HTTP  
- [ ] curl 連打驗證腳本通過  
- [ ] iOS 對 429 有可讀提示  

### 實作前需產品決策

1. **fetch-or-create 快取分鐘數**：5 / 10 / 15？  
2. **限流粒度**：僅 `apikey`（全 App 共用配額）或 `apikey + IP`？  

---

## 相關程式與 Edge 路徑

| 觸發 | 典型後端 |
|------|----------|
| 冷啟動／下拉刷新 | `SnapshotRefreshCoordinator` → `fetch-prices-batch` |
| DB 無價新標的 | `fetch-or-create-price` |
| 交易／匯入後 | `TrackedSymbolSync` → `track-symbol` |
| 排程 | Cloud Run `daily_price_update.py`（台股 Fugle 等） |

| Edge / 常數 | 路徑 |
|-------------|------|
| batch 上限 | `backend/supabase/functions/fetch-prices-batch/index.ts` → `maxSymbols = 100` |
| iOS chunk | `SupabasePriceService.maxBatchSymbols` |
| 並行 fetch-or-create | `SupabasePriceService.fetchOrCreateConcurrency = 5` |

---

## 驗證腳本（PR3 完成後）

```bash
# 連打 fetch-or-create（替換 URL 與 anon key）
for i in $(seq 1 35); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST "$SUPABASE_URL/functions/v1/fetch-or-create-price" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
    -d '{"assetType":"stock_us","symbol":"AAPL"}'
done
# 預期：前若干次 200，之後 429
```

---

## 變更紀錄

| 日期 | 內容 |
|------|------|
| 2026-06-02 | 建立文件；PR1／PR2 已合入 main；PR3 規格定稿待實作 |
