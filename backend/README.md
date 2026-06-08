# Snapvest 後端 - 股價系統

## 架構

- **Supabase**：PostgreSQL 資料庫、Edge Functions
- **每日排程**：Python 腳本（Yahoo Finance + CoinGecko）
- **新增股票**：Edge Function `fetch-or-create-price`

## 一、Supabase 設定

### 1. 建立專案

1. 至 [supabase.com](https://supabase.com) 建立專案
2. 在 SQL Editor 執行 `supabase/migrations/001_price_tables.sql`

### 2. 取得金鑰

- Project Settings > API：`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY`（僅後端使用）
- App 使用 `SUPABASE_URL`、`SUPABASE_ANON_KEY`

## 二、每日股價更新（Python）

### 安裝

```bash
cd backend/scripts
pip install -r requirements.txt
```

### 環境變數

建立 `.env` 或設定：

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

### 執行

```bash
# 完整更新（匯率 + 台股 + 美股 + 加密）
python daily_price_update.py

# 只更新匯率
python daily_price_update.py --exchange-only

# 分市場（不含匯率，與 GitHub Actions 排程一致）
python daily_price_update.py --markets tw,crypto
python daily_price_update.py --markets us
python daily_price_update.py --markets crypto
```

### 排程（Cloud Run + Cloud Scheduler）

台股、加密、匯率排程使用台灣時間；美股排程使用 `America/New_York`，由 Cloud Scheduler 自動處理夏令／冬令。腳本寫入 Supabase 的 `updated_at` 仍使用台灣時間。

| 時間 | 時區／星期 | 內容 |
|------|-----------|------|
| 14:00 | 台灣，週一～五 | 台股收盤價 |
| 14:05 | 台灣，週一～五 | 匯率 |
| 每小時 | 台灣，每日 | 加密 snapshots（00:00 另寫昨日 history） |
| 16:05 | 紐約，美股交易日 | 美股收盤價 |

手動觸發（Actions → Run workflow）保留為備援，會跑完整更新（匯率 + 全部市場）。

## 三、新增股票即時取價（Edge Function）

當使用者新增一檔資料庫沒有的股票時，呼叫此 Function 即時取價並寫入 DB。

### 部署

```bash
# 函式原始碼在 backend/supabase/functions/；根目錄 supabase/functions 為符號連結
cd backend && supabase functions deploy fetch-or-create-price
# 或在專案根目錄：supabase functions deploy fetch-or-create-price
```

### 呼叫

```
POST https://xxxx.supabase.co/functions/v1/fetch-or-create-price
Headers: Authorization: Bearer <ANON_KEY>
Body: { "assetType": "stock_us", "symbol": "AAPL" }
```

## 四、iOS App 整合

App 需：
1. 加入 Supabase Swift 套件
2. 實作從 Supabase 讀取股價
3. 登入時比對 `price_update_metadata.last_updated_at`，若較新再拉取

詳見專案內 `PRICE_FETCHING_SUMMARY.md` 與 iOS 相關程式碼。
