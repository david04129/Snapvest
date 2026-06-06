# Snapvest 股價系統 -  step by step 設定教學

請依序完成以下步驟。

---

## 第一步：建立 Supabase 專案

### 1-1 註冊與登入

1. 開啟 https://supabase.com
2. 點 **Start your project**
3. 用 GitHub 登入

### 1-2 建立新專案

1. 點 **New Project**
2. 選擇 Organization（或建立新的）
3. 填寫：
   - **Name**：例如 `Snapvest`
   - **Database Password**：設定一組密碼並記下來
   - **Region**：選離你較近的（如 `Northeast Asia (Tokyo)`）
4. 點 **Create new project**，等候建立完成

### 1-3 記下需要的金鑰

1. 左側選 **Project Settings**（齒輪圖示）
2. 點 **API** 區塊
3. 記錄這兩個值：
   - **Project URL**：例如 `https://abcdefgh.supabase.co`
   - **anon public**：在 Project API keys 裡，`anon` 和 `public` 對應的那個（可給 App 用）
   - **service_role**：同區塊裡的 `service_role`（**只能給後端用，不能放在 App 裡**）

---

## 第二步：建立資料表

### 2-1 開啟 SQL Editor

1. 左側點 **SQL Editor**
2. 點 **New query**

### 2-2 貼上 SQL 並執行

1. 開啟專案裡的 `backend/supabase/migrations/001_price_tables.sql`
2. 複製全部內容
3. 貼到 Supabase SQL Editor
4. 點 **Run**（或 Cmd/Ctrl + Enter）

### 2-3 執行 RLS 政策（讓 App 能讀取股價）

**重要**：若沒有設定 RLS 政策，App 用 anon key 無法讀取資料。

1. 開啟專案裡的 `backend/supabase/migrations/002_rls_policies.sql`
2. 複製全部內容
3. 貼到 Supabase SQL Editor，點 **Run**

### 2-4 啟用 Anonymous Sign-In（Phase A）

App 會為每台裝置建立匿名 Supabase 使用者（JWT）。

1. Dashboard → **Authentication** → **Providers**
2. **Anonymous Sign-Ins** → **Enable** → Save
3. 在 SQL Editor 執行 `backend/supabase/migrations/022_authenticated_rls_read_policies.sql`
4. 完整驗證：[docs/PHASE_A_ANONYMOUS_AUTH_VERIFICATION.md](./docs/PHASE_A_ANONYMOUS_AUTH_VERIFICATION.md)

### 2-5 檢查結果

1. 左側點 **Table Editor**
2. 應該能看到：
   - `asset_price_snapshots`
   - `price_update_metadata`
   - `tracked_symbols`（App 匿名追蹤池；`hot_stocks` 已退役）

---

## 第三步：執行第一次股價更新（本機測試）

### 3-1 安裝 Python 依賴

1. 開啟終端機（Terminal）
2. 執行：

```bash
cd /Users/david/Desktop/Snapvest/backend/scripts
pip install -r requirements.txt
```

若 `pip` 不存在，可改用 `pip3`。

### 3-2 設定環境變數

在終端機執行（請把 `你的URL`、`你的SERVICE_ROLE_KEY` 換成實際值）：

```bash
export SUPABASE_URL="https://你的專案ID.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="你的 service_role key"
```

例如：

```bash
export SUPABASE_URL="https://abcdefgh.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6..."
```

### 3-3 執行更新腳本

```bash
python daily_price_update.py
```

若沒錯誤，最後會顯示類似：

```
[2026-02-14 ...] 開始每日股價更新
共 30 檔待更新（已去重）
Yahoo: 取得 20 筆
CoinGecko: 取得 10 筆
已寫入 30 筆至 Supabase
更新完成
```

### 3-4 檢查資料庫

1. 回到 Supabase
2. 開啟 **Table Editor** > **asset_price_snapshots**
3. 應該能看到剛更新的股價

---

## 第四步：設定 iOS App 連線 Supabase

### 4-1 在 Xcode 開啟專案

1. 雙擊 `Snapvest.xcodeproj` 或用 Xcode 開啟專案
2. 確認左側專案導覽能看到 Snapvest 相關檔案

### 4-2 加入 Supabase 設定（二選一）

**方法 A：在 Xcode 的 Info 分頁（建議）**

1. 在 Xcode 左側點選 **Snapvest** 專案（最上面藍色圖示）
2. 中間選 **Snapvest** target
3. 上方點 **Info** 分頁
4. 找到 **Custom iOS Target Properties**
5. 點該區塊左側的 **+** 新增項目
6. 新增兩筆：
   - 第一筆：Key 選 **String** 或直接輸入 `SUPABASE_URL`，Value 填 `https://你的專案ID.supabase.co`
   - 第二筆：Key 輸入 `SUPABASE_ANON_KEY`，Value 填你的 **anon public** key

若 Key 欄位無法自訂，可右鍵 > **Add Row**，再手動輸入 key 名稱。

**方法 B：直接改程式碼（最快，僅開發用）**

1. 在 Xcode 開啟 `Snapvest/Utilities/SupabaseConfigLoader.swift`
2. 在 `configure()` 的 `#if DEBUG` 區塊內，在 `if let url = ...` 之前加入：

```swift
SupabaseConfig.url = "https://你的專案ID.supabase.co"
SupabaseConfig.anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...."  // 貼上你的 anon key
```

3. 把原本的 `if let url = ...` 那幾行註解掉或刪掉，讓上面兩行優先執行

### 4-4 編譯並執行 App

1. 在 Xcode 按 **Run** 建置並執行
2. 開啟後若有從 Supabase 取得股價，代表設定成功  
   （若尚未有持股，可能要多開幾個畫面觸發取價）

---

## 第五步：設定每日自動更新（使用 GitHub Actions）

### 5-1 將專案推到 GitHub

1. 若尚未建立 repo，在 GitHub 建立一個
2. 在本機專案目錄執行：

```bash
cd /Users/david/Desktop/Snapvest
git add .
git commit -m "Add price system"
git remote add origin https://github.com/你的帳號/Snapvest.git
git push -u origin main
```

（若已 push 過，就略過這步或改用你的流程）

### 5-2 設定 Secrets

1. 開啟專案的 GitHub 頁面
2. 點 **Settings** > **Secrets and variables** > **Actions**
3. 點 **New repository secret**
4. 新增兩個 secret：
   - Name: `SUPABASE_URL`，Value: 你的 Project URL
   - Name: `SUPABASE_SERVICE_ROLE_KEY`，Value: 你的 service_role key

### 5-3 確認 Workflow

1. 點 **Actions**
2. 左側會看到 **Daily Price Update**
3. 可點 **Run workflow** 測試一次
4. 之後每天約 16:00（台灣時間）會自動執行

---

## 第六步（選做）：Edge Function 即時取價

當使用者新增一檔「資料庫還沒有」的股票時，可透過 Edge Function 即時從 API 取價並寫入資料庫。

### 6-1 安裝 Supabase CLI

```bash
npm install -g supabase
```

（需先安裝 Node.js：https://nodejs.org）

### 6-2 登入並連結專案

```bash
supabase login
```

依提示完成登入後：

```bash
cd /Users/david/Desktop/Snapvest
supabase link --project-ref 你的專案ID
```

專案 ID 在 Supabase **Project Settings** > **General** 的 **Reference ID**。

### 6-3 部署 Function

```bash
supabase functions deploy fetch-or-create-price
```

部署成功後，App 在新增股票時可呼叫此 Function 做即時取價（需在 App 裡實作呼叫邏輯）。

---

## 疑難排解

### 腳本執行失敗

- 檢查 `SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` 是否正確、有引號
- 確認有執行 `pip install -r requirements.txt`

### App 抓不到股價

- 確認 Info.plist 有正確設定 `SUPABASE_URL`、`SUPABASE_ANON_KEY`
- 檢查 Supabase 專案中 `asset_price_snapshots` 是否有資料
- 若沒有持股，先執行一次 `daily_price_update.py` 更新熱門股

### GitHub Actions 失敗

- 檢查 Secrets 是否正確設定
- 到 Actions 對應的 workflow run 裡查看錯誤訊息

---

## 檢查清單

- [ ] Supabase 專案已建立
- [ ] 已執行 `001_price_tables.sql`
- [ ] 已執行 `002_rls_policies.sql`（讓 App 能讀取股價）
- [ ] 本機執行過一次 `daily_price_update.py` 且成功
- [ ] `asset_price_snapshots` 有資料
- [ ] Info.plist 已設定 `SUPABASE_URL`、`SUPABASE_ANON_KEY`
- [ ] App 可成功編譯並從 Supabase 取得股價
- [ ] （選做）已設定 GitHub Actions Secrets 並成功 Run 一次
- [ ] （選做）已部署 `fetch-or-create-price` Edge Function
