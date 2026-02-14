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
python daily_price_update.py
```

### 排程（範例：每日 16:00）

**GitHub Actions**（`.github/workflows/daily-price.yml`）：

```yaml
name: Daily Price Update
on:
  schedule:
    - cron: '0 8 * * *'  # UTC 08:00 = 台灣 16:00
  workflow_dispatch:
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r backend/scripts/requirements.txt
      - run: python backend/scripts/daily_price_update.py
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

**本機 cron**：`0 16 * * * cd /path/to/Snapvest && python backend/scripts/daily_price_update.py`

## 三、新增股票即時取價（Edge Function）

當使用者新增一檔資料庫沒有的股票時，呼叫此 Function 即時取價並寫入 DB。

### 部署

```bash
supabase functions deploy fetch-or-create-price
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
