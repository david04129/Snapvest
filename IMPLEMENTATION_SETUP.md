# 股價系統實作 - 設定指南

## 已完成項目

1. **Supabase SQL** - `backend/supabase/migrations/001_price_tables.sql`
2. **每日更新腳本** - `backend/scripts/daily_price_update.py`（Yahoo Finance + CoinGecko）
3. **Edge Function** - `backend/supabase/functions/fetch-or-create-price`（新增股票即時取價）
4. **iOS 整合** - `SupabasePriceService`、`PriceService` 可從 Supabase 讀取
5. **GitHub Actions** - `.github/workflows/daily-price-update.yml`（每日排程）

---

## 你需要完成的設定

### 1. Supabase 專案

1. 至 [supabase.com](https://supabase.com) 建立專案
2. SQL Editor 執行 `backend/supabase/migrations/001_price_tables.sql`
3. 取得 **Project URL**、**anon key**、**service_role key**

### 2. iOS App（Supabase 連線）

在 **Info.plist** 加上（或建立後在 Xcode 中編輯）：

```xml
<key>SUPABASE_URL</key>
<string>https://你的專案.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>你的 anon key</string>
```

或直接在 `SupabaseConfigLoader.swift` 暫時寫死（僅開發用）：

```swift
SupabaseConfig.url = "https://xxxx.supabase.co"
SupabaseConfig.anonKey = "eyJ..."
```

### 3. 每日排程（二選一）

**選項 A：GitHub Actions（推薦）**

1. 將 repo push 到 GitHub
2. Settings > Secrets and variables > Actions
3. 新增 `SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY`
4. 每日 16:00 會自動執行；也可在 Actions 頁面手動 Run workflow

**選項 B：本機 cron**

```bash
# 編輯 crontab
crontab -e
# 加入（請改成實際路徑）
0 16 * * * cd /path/to/Snapvest && /usr/bin/python3 backend/scripts/daily_price_update.py
```

記得先設定環境變數（例如在 `~/.zshrc` 或 `~/.bash_profile`）。

### 4. Edge Function 部署（新增股票即時取價）

```bash
# 安裝 Supabase CLI
npm install -g supabase

# 登入並連結專案
supabase login
supabase link --project-ref 你的專案ID

# 部署
supabase functions deploy fetch-or-create-price
```

---

## holdings 表

目前每日腳本會從 `holdings` 讀取使用者持股。若你尚未建立 accounts、transactions、holdings 等表，可先只更新熱門股：

- 腳本會從 `tracked_symbols`（is_active）讀取待更新標的
- `holdings` 若不存在會略過，不影響熱門股更新

未來整合完整後端時，再補上 accounts、transactions、holdings 表結構。

---

## 測試

1. **手動跑每日腳本**：`python backend/scripts/daily_price_update.py`
2. **檢查 Supabase**：Table Editor 看 `asset_price_snapshots` 是否有資料
3. **iOS**：設定好 Info.plist 後，開啟 App 應能從 Supabase 取得股價
