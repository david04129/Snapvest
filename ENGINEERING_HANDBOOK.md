# Snapvest 工程手冊

> 給開發者／維護者看的白話說明：GitHub、Supabase、App 各自做什麼、每天幾點更新、股價從哪來、檔案在哪裡。
>
> **Repo：** [github.com/david04129/Snapvest](https://github.com/david04129/Snapvest)  
> **初次設定教學：** [STEP_BY_STEP_SETUP.md](./STEP_BY_STEP_SETUP.md)  
> **Symbols 腳本細節：** [scripts/README.md](./scripts/README.md)

---

## 目錄

1. [三句話搞懂架構](#三句話搞懂架構)
2. [整體架構圖](#整體架構圖)
3. [資料分兩大類](#資料分兩大類)
4. [GitHub 是什麼？做什麼？](#github-是什麼做什麼)
5. [Supabase 是什麼？做什麼？](#supabase-是什麼做什麼)
6. [Supabase SQL 在做什麼？](#supabase-sql-在做什麼)
7. [iOS App 讀寫什麼？](#ios-app-讀寫什麼)
8. [每日／每月自動排程總表](#每日每月自動排程總表)
9. [股價與匯率：用什麼 API？](#股價與匯率用什麼-api)
10. [股票代號清單（Symbols）怎麼來？](#股票代號清單symbols怎麼來)
11. [重要檔案與目錄](#重要檔案與目錄)
12. [金鑰與設定](#金鑰與設定)
13. [常見問題](#常見問題)
14. [手動操作速查](#手動操作速查)

---

## 三句話搞懂架構

| 角色 | 一句話 |
|------|--------|
| **GitHub** | 放程式碼的地方，也是「定時機器人」——自動跑腳本、更新 JSON 清單、把股價寫進 Supabase |
| **Supabase** | 雲端資料庫——存股價、匯率、走勢圖等「會每天變」的資料；App 上線後連它讀資料 |
| **App（iPhone）** | 你寫的 SwiftUI 程式——顯示畫面；從 Supabase 拿股價；從 App 內建 JSON 搜尋股票代號 |

**記住這個差別：**

- **代號清單**（symbols）→ 存在 **GitHub**，打包進 App，**不經 Supabase**
- **股價／匯率／走勢** → 存在 **Supabase**，App **即時讀取**，不用發新版也能看到新股價

---

## 整體架構圖

```mermaid
flowchart TB
    subgraph GitHub["GitHub（程式碼 + 定時機器人）"]
        Code[原始碼 / JSON 清單]
        WF1[Monthly Symbols Update<br/>每月 1 日]
        WF2[Daily Price Update<br/>每天多次]
        WF3[Daily Portfolio Snapshot<br/>每天 00:05 結算前一日]
    end

    subgraph Supabase["Supabase（雲端 PostgreSQL）"]
        T1[(asset_price_snapshots<br/>股價)]
        T2[(exchange_rates<br/>匯率)]
        T3[(user_portfolio_state<br/>你的持股摘要)]
        T4[(user_daily_snapshots<br/>走勢圖)]
        EF[Edge Function<br/>fetch-or-create-price]
    end

    subgraph App["iOS App"]
        UI[畫面]
        Bundle[內建 symbols JSON]
    end

    Ext[外部 API<br/>Yahoo / CoinGecko / 證交所…]

    WF1 -->|commit JSON| Code
    Code -->|Xcode build| Bundle
    Bundle --> UI

    WF2 -->|寫入| T1
    WF2 -->|寫入| T2
    WF3 -->|讀 T1 T2 T3| T4
    UI -->|讀| T1
    UI -->|讀| T2
    UI -->|讀| T4
    UI -->|同步持股| T3
    UI -->|缺價時呼叫| EF
    EF --> Ext
    EF -->|寫入| T1
    WF2 --> Ext
```

---

## 資料分兩大類

### A 類：打包在 App 裡（跟 GitHub 有關）

| 內容 | 存在哪 | 誰更新 | App 怎麼拿到 |
|------|--------|--------|--------------|
| 台股／美股／加密 **代號 + 名稱** | GitHub repo → Xcode Bundle | 每月 GitHub Actions 或本機 `build_all.sh` | **發新版 App** 才會更新 |
| CoinGecko 對照表（給後端抓加密價用） | `backend/scripts/data/crypto_coingecko_map.json` | 同上 | App 不直接讀 |

### B 類：存在 Supabase（App 即時讀）

| 內容 | 資料表 | 誰寫入 | App 用途 |
|------|--------|--------|----------|
| 各檔股價 | `asset_price_snapshots` | 每日腳本 + Edge Function | 顯示現價、算損益 |
| 全站最後更新時間 | `price_update_metadata` | 每日腳本 | 判斷要不要刷新 |
| 熱門股清單 | `hot_stocks` | SQL 初始 + Edge Function 新增時加入 | 每日腳本優先更新 |
| 匯率 | `exchange_rates` | 每日腳本 | 台幣／美金換算 |
| 你的持股／現金／負債摘要 | `user_portfolio_state` | **App 交易後同步** | 給每日快照腳本算走勢 |
| 每日淨資產走勢 | `user_daily_snapshots` | 每日 00:05 腳本（寫入前一日） | 首頁走勢圖 |

---

## GitHub 是什麼？做什麼？

**GitHub** = 你的程式碼倉庫 + 自動化工人。

- **倉庫：** [https://github.com/david04129/Snapvest](https://github.com/david04129/Snapvest)
- **Actions 頁面：** [https://github.com/david04129/Snapvest/actions](https://github.com/david04129/Snapvest/actions)

GitHub 在 Snapvest 裡主要做三件事：

1. **存程式碼**（Swift、Python、SQL、JSON）
2. **定時跑 Workflow**（股價更新、走勢計算、symbols 建置）
3. **symbols 有變時自動 commit**（機器人帳號 `github-actions[bot]` push 回 `main`）

> GitHub **不是**資料庫。股價不會長期存在 GitHub，只有「腳本跑完後寫進 Supabase」。

---

## Supabase 是什麼？做什麼？

**Supabase** = 託管的 PostgreSQL 資料庫 + 可選的 Edge Function（小後端）。

- **官網：** [https://supabase.com](https://supabase.com)
- **Dashboard：** 登入後進你的專案（例如 Project URL 像 `https://xxxxx.supabase.co`）

Snapvest 用 Supabase 當「**會變動資料的倉庫**」：

- App 用 **anon / publishable key** **讀**股價、匯率、走勢
- GitHub Actions 用 **service_role key** **寫**股價、匯率、走勢
- Edge Function 在資料庫沒某檔價格時，**即時去外部 API 抓**再寫入

---

## Supabase SQL 在做什麼？

`backend/supabase/migrations/*.sql` 這些檔案 = **蓋資料庫骨架的設計圖**。

你要在 [Supabase SQL Editor](https://supabase.com/docs/guides/database/overview) 裡**手動執行**（新功能時再跑新的 migration），**不是每天自動跑**。

| 檔案 | 建立什麼 | 用途 |
|------|----------|------|
| [001_price_tables.sql](./backend/supabase/migrations/001_price_tables.sql) | `asset_price_snapshots`、`price_update_metadata`、`hot_stocks` | 股價與熱門股 |
| [002_rls_policies.sql](./backend/supabase/migrations/002_rls_policies.sql) | RLS 權限 | App 只能讀、不能亂改 |
| [003_exchange_rates.sql](./backend/supabase/migrations/003_exchange_rates.sql) | `exchange_rates` | 匯率表 |
| [004_exchange_rates_write_policy.sql](./backend/supabase/migrations/004_exchange_rates_write_policy.sql) | service_role 寫入權限 | 給 GitHub Actions 寫匯率 |
| [005_user_portfolio_state.sql](./backend/supabase/migrations/005_user_portfolio_state.sql) | `user_portfolio_state` | App 同步持股給後端 |
| [006_user_daily_snapshots.sql](./backend/supabase/migrations/006_user_daily_snapshots.sql) | `user_daily_snapshots` | 首頁走勢圖資料 |

**RLS（Row Level Security）白話：** 像門禁——App 的 key 只能進「讀取區」；GitHub Actions 的 service_role key 才能「寫入區」。

---

## iOS App 讀寫什麼？

### App 從 Supabase 讀

| 功能 | Swift 檔案 | 讀哪張表 |
|------|------------|----------|
| 顯示股價 | [SupabasePriceService.swift](./Snapvest/Snapvest/Services/SupabasePriceService.swift) | `asset_price_snapshots` |
| 缺價時即時抓 | 同上 → 呼叫 Edge Function | 寫入後回傳 |
| 匯率 | [PriceService.swift](./Snapvest/Snapvest/Services/PriceService.swift) 等 | `exchange_rates` |
| 首頁走勢圖 | [SupabaseDailySnapshotService.swift](./Snapvest/Snapvest/Services/SupabaseDailySnapshotService.swift) | `user_daily_snapshots` |

### App 寫入 Supabase

| 功能 | Swift 檔案 | 寫哪張表 |
|------|------------|----------|
| 交易後同步持股摘要 | [SupabasePortfolioStateService.swift](./Snapvest/Snapvest/Services/SupabasePortfolioStateService.swift) | `user_portfolio_state` |

> 這份摘要給每天 00:05 的 Python 腳本讀，用來算你的淨資產走勢（`snapshot_date` = 前一日）。

### App 讀本機 Bundle（不連網）

| 功能 | Swift 檔案 | 資料來源 |
|------|------------|----------|
| 選股搜尋、台股簡稱 | [SymbolListService.swift](./Snapvest/Snapvest/Services/SymbolListService.swift) | `Snapvest/Snapvest/Resources/Symbols/*.json` |

### 帳戶／交易紀錄（目前狀態）

目前核心交易資料在 [DataService.swift](./Snapvest/Snapvest/Services/DataService.swift) 的 `MockDataService`（**記憶體 Mock**），尚未全面搬到 Supabase。  
也就是說：**你的買賣紀錄主要還在 App 本機邏輯裡**；只有「持股摘要副本」會同步到 Supabase 供走勢計算。

---

## 每日／每月自動排程總表

以下時間皆為 **台灣時間（UTC+8）**。

### 每天

| 時間 | Workflow 名稱 | 做什麼 | 寫到哪 |
|------|---------------|--------|--------|
| **週一～五 16:00** | [Daily Price Update](./.github/workflows/daily-price-update.yml) | ① 更新匯率 ② 更新台股 ③ 更新加密 | Supabase |
| **週六、日 16:00** | 同上 | 只更新加密（Crypto 24/7） | Supabase |
| **週二～六 07:00** | 同上 | 只更新美股（配合美股收盤後） | Supabase |
| **每天 00:05** | [Daily Portfolio Snapshot](./.github/workflows/daily-portfolio-snapshot.yml) | 讀持股 + 股價 + 匯率 → 算淨資產，**寫入前一日** `snapshot_date` | Supabase `user_daily_snapshots` |

**00:05 為什麼在隔天凌晨？**  
日終結算：5/26 00:05 執行 → 記錄 **5/25** 的快照，可納入 5/25 晚間交易。台股／加密用前一日 16:00 股價；美股接受 **lag 一個美股交易日**（沿用最近一次 07:00 更新）。

#### 一天時間軸（平日）

```
07:00  更新美股股價
16:00  更新匯率 + 台股 + 加密
00:05（隔天）結算並寫入「前一日」淨資產走勢
```

#### 週末

```
週六 16:00  只更新加密
週日 16:00  只更新加密
（美股／台股週末不開盤，週一 07:00 / 16:00 再更新）
```

### 每月

| 時間 | Workflow 名稱 | 做什麼 | 寫到哪 |
|------|---------------|--------|--------|
| **每月 1 日 10:00** | [Monthly Symbols Update](./.github/workflows/monthly-symbols-update.yml) | 重抓台股／美股／加密代號清單 | **GitHub**（commit JSON） |

若清單跟上次完全一樣 → 不 commit，顯示「無變動，略過 commit」。

### 手動觸發

三個 Workflow 都支援 **Run workflow**（在 Actions 頁面），不用等到排程時間。

---

## 股價與匯率：用什麼 API？

Snapvest 有 **兩條抓價路線**：

1. **每日批量更新**（GitHub Actions → Python）
2. **App 新增冷門標的、DB 還沒價格時**（Edge Function 即時抓）

---

### 1. 每日批量更新（`daily_price_update.py`）

**腳本位置：** [backend/scripts/daily_price_update.py](./backend/scripts/daily_price_update.py)  
**Workflow：** [.github/workflows/daily-price-update.yml](./.github/workflows/daily-price-update.yml)

**更新哪些股票？**  
不是全市場每一檔，而是：

- 你在 Supabase 的 `holdings`（若有建表）
- **∪** `hot_stocks`（熱門股 + 你透過 App 新增時 Edge Function 加進去的）
- 合併去重後才抓

| 資料 | API | 連結 | 備註 |
|------|-----|------|------|
| **匯率** | ExchangeRate-API（open.er-api.com） | [https://open.er-api.com/v6/latest/USD](https://open.er-api.com/v6/latest/USD) | 免 API key；以 USD 為基準 |
| **美股** | Yahoo Finance（透過 Python `yfinance`） | [yfinance 專案](https://github.com/ranaroussi/yfinance) | 免費；可能遇到 rate limit |
| **台股** | Yahoo Finance（symbol 格式 `2330.TW`） | 同上 | 免費；可能遇到 rate limit |
| **加密貨幣** | CoinGecko Simple Price | [CoinGecko API 文件](https://docs.coingecko.com/reference/simple-price) | 免費有頻率限制；需 `crypto_coingecko_map.json` 對照 symbol → id |

**加密 symbol 對照表：** [backend/scripts/data/crypto_coingecko_map.json](./backend/scripts/data/crypto_coingecko_map.json)（由 `build_symbols_crypto.py` 產生）

---

### 2. 即時取價（Edge Function `fetch-or-create-price`）

**程式位置：** [backend/supabase/functions/fetch-or-create-price/index.ts](./backend/supabase/functions/fetch-or-create-price/index.ts)

**什麼時候觸發？**  
App 查 `asset_price_snapshots` 發現**沒有這檔的價格**時，會 POST 這支 Function。

| 資產 | API | 連結 | 備註 |
|------|-----|------|------|
| **台股** | Yahoo Finance Chart API | `https://query1.finance.yahoo.com/v8/finance/chart/{代號}.TW` | 例：`2330.TW` |
| **美股** | Yahoo Finance Chart API | `https://query1.finance.yahoo.com/v8/finance/chart/{代號}` | 例：`AAPL` |
| **加密** | CoinGecko Simple Price | [Simple Price API](https://docs.coingecko.com/reference/simple-price) | 可帶 `coingeckoId`；也會搜尋 CoinGecko |

抓到價格後會：

1. 寫入 `asset_price_snapshots`
2. 加入 `hot_stocks`（之後每日腳本也會更新這檔）

**部署方式（手動，不經 GitHub Actions）：**

```bash
cd backend
supabase link --project-ref 你的專案ID
supabase functions deploy fetch-or-create-price
```

Supabase CLI 文件：[Edge Functions](https://supabase.com/docs/guides/functions)

---

### 股價流程（白話版）

```
你打開 App 要看某檔股價
        │
        ▼
先查 Supabase 資料庫有沒有？
        │
   有 ──┴── 沒有
   │         │
   ▼         ▼
直接顯示   呼叫 Edge Function
           去 Yahoo / CoinGecko 抓
           寫入 DB 再顯示

另外，GitHub 每天定時跑腳本
批量更新「你有持有 + 熱門」的價格
```

---

## 股票代號清單（Symbols）怎麼來？

**目的：** 讓使用者在 App 裡搜尋「2330」「AAPL」「BTC」時找得到名稱。

### 資料來源

| 市場 | 腳本 | 外部來源 | 連結 |
|------|------|----------|------|
| **美股** | [build_symbols_us.py](./scripts/build_symbols_us.py) | NASDAQ 官方清單 | [nasdaqtraded.txt](https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqtraded.txt) |
| **台股** | [build_symbols_tw.py](./scripts/build_symbols_tw.py) | 證交所上市 CSV（**公司簡稱**）+ 櫃買上櫃／興櫃 + ETF 手動補充 | [證交所 open data CSV](https://dts.twse.com.tw/opendata/t187ap03_L.csv)、[櫃買中心](https://www.tpex.org.tw/) |
| **加密** | [build_symbols_crypto.py](./scripts/build_symbols_crypto.py) | CoinGecko 市值 Top 500 | [CoinGecko Markets API](https://docs.coingecko.com/reference/coins-markets) |

### 建置流程

```bash
cd scripts
./build_all.sh
```

`build_all.sh` 會依序：

1. **備份**現有清單到 `scripts/output/archive/`（每種最多留 2 版舊檔）
2. 建置 `symbols_tw.json` / `symbols_us.json` / `symbols_crypto.json`
3. 建 `symbols_manifest.json`（版本摘要）
4. 同步到 App Bundle：`Snapvest/Snapvest/Resources/Symbols/`

### 產出檔案位置

| 用途 | 路徑 |
|------|------|
| App 打包用 | [Snapvest/Snapvest/Resources/Symbols/](./Snapvest/Snapvest/Resources/Symbols/) |
| 建置中間產物 | [scripts/output/](./scripts/output/) |
| **舊版備份**（最多 2 份） | [scripts/output/archive/](./scripts/output/archive/) |
| 後端加密對照 | [backend/scripts/data/crypto_coingecko_map.json](./backend/scripts/data/crypto_coingecko_map.json) |

### 自動更新 vs 手動

| 方式 | 說明 |
|------|------|
| **每月自動** | GitHub Actions `Monthly Symbols Update` → 有變就 commit 到 `main` |
| **本機手動** | 發 App 新版前可再跑 `./build_all.sh` 確保最新 |
| **使用者何時看到新清單** | 必須 **重新安裝／更新 App**（因為 JSON 打包在 App 裡） |

### 若自動更新壞了，怎麼還原？

1. 到 `scripts/output/archive/` 找舊版，例如 `archive/tw/symbols_tw_v8_2026-05-24.json`
2. 複製覆蓋回：
   - `scripts/output/symbols_*.json`
   - `Snapvest/Snapvest/Resources/Symbols/symbols_*.json`
3. commit 並重新 build App

---

## 重要檔案與目錄

```
Snapvest/
├── Snapvest/Snapvest/          # iOS App 原始碼
│   ├── Resources/Symbols/      # 打包進 App 的代號清單
│   └── Services/               # Supabase 連線、股價、走勢
├── backend/
│   ├── scripts/
│   │   ├── daily_price_update.py          # 每日股價／匯率
│   │   ├── daily_portfolio_snapshot.py    # 每日淨資產走勢
│   │   └── data/crypto_coingecko_map.json
│   └── supabase/
│       ├── migrations/         # SQL 建表（手動在 Supabase 執行）
│       └── functions/
│           └── fetch-or-create-price/   # 即時抓價
├── scripts/
│   ├── build_all.sh            # 一鍵建 symbols
│   ├── archive_symbols.py      # 備份舊版清單
│   └── output/                 # 建置產物 + archive/
├── .github/workflows/          # GitHub Actions 排程
├── STEP_BY_STEP_SETUP.md       # 從零設定 Supabase 教學
└── ENGINEERING_HANDBOOK.md     # 本文件
```

---

## 金鑰與設定

### GitHub Secrets（給 Actions 用）

路徑：Repo → **Settings** → **Secrets and variables** → **Actions**

| Secret | 用途 | 哪個 Workflow 需要 |
|--------|------|-------------------|
| `SUPABASE_URL` | Supabase 專案網址 | Daily Price、Daily Portfolio Snapshot |
| `SUPABASE_SERVICE_ROLE_KEY` | 後端寫入權限（**不可放 App**） | 同上 |

文件：[GitHub Encrypted secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)

### App 設定（Info.plist）

| Key | 用途 |
|-----|------|
| `SUPABASE_URL` | Supabase 專案 URL |
| `SUPABASE_ANON_KEY` | App 讀取用（publishable 或 anon JWT） |
| `SUPABASE_ANON_JWT` | 選填；呼叫 Edge Function 時的 Bearer |

載入邏輯：[SupabaseConfigLoader.swift](./Snapvest/Snapvest/Utilities/SupabaseConfigLoader.swift)

在 Supabase Dashboard 找這些值：**Project Settings → API**  
文件：[Supabase API Keys](https://supabase.com/docs/guides/api/api-keys)

---

## 常見問題

### Q：我更新了 symbols，為什麼 App 還是舊的？

因為 symbols 是**打包在 App 裡**的，不是從 Supabase 下載。需要 **Xcode 重新 build 並發新版**。

### Q：股價需要發新版 App 嗎？

**不需要。** 股價在 Supabase，App 每次開啟會去讀資料庫。

### Q：GitHub 自動 commit 是什麼？

Monthly Symbols Update 跑完後，若 JSON 有變，機器人會自動 `git commit` + `push` 到 `main`。你可以在 [Commits](https://github.com/david04129/Snapvest/commits/main) 搜尋 `chore(symbols):`。

### Q：Supabase SQL 要每天跑嗎？

**不用。** 只有第一次建專案、或加新功能（新 migration）時跑。

### Q：排程沒跑怎麼辦？

1. 到 [Actions](https://github.com/david04129/Snapvest/actions) 手動 **Run workflow** 測試  
2. 檢查 Secrets 是否設定  
3. 確認 workflow 檔在 `main` 分支（cron 只跑 default branch）  
4. GitHub 免費方案排程可能延遲 15 分鐘～1 小時；repo 長期無活動可能暫停  

詳細排查可見 [STEP_BY_STEP_SETUP.md](./STEP_BY_STEP_SETUP.md) 或 [BACKEND_AND_APIS.md](./BACKEND_AND_APIS.md) 第六節。

### Q：美股有簡短公司名嗎？

目前美股清單來自 NASDAQ 的 **完整 Security Name**（例如 `Apple Inc. Common Stock`），**沒有像台股那樣的「公司簡稱」欄位**。若要簡稱需另接 API 或規則處理。

---

## 手動操作速查

| 想做什麼 | 怎麼做 |
|----------|--------|
| 手動更新股價／匯率 | [Actions → Daily Price Update → Run workflow](https://github.com/david04129/Snapvest/actions/workflows/daily-price-update.yml) |
| 手動算走勢 | [Actions → Daily Portfolio Snapshot → Run workflow](https://github.com/david04129/Snapvest/actions/workflows/daily-portfolio-snapshot.yml) |
| 手動更新 symbols | [Actions → Monthly Symbols Update → Run workflow](https://github.com/david04129/Snapvest/actions/workflows/monthly-symbols-update.yml) |
| 本機測股價腳本 | `cd backend/scripts && export SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... && python daily_price_update.py` |
| 本機建 symbols | `cd scripts && ./build_all.sh` |
| 部署 Edge Function | `cd backend && supabase functions deploy fetch-or-create-price` |
| 在 Supabase 看股價表 | Dashboard → **Table Editor** → `asset_price_snapshots` |
| 看 GitHub 上的 symbols JSON | [Resources/Symbols/](https://github.com/david04129/Snapvest/tree/main/Snapvest/Snapvest/Resources/Symbols) |

---

## 相關外部連結整理

| 服務 | 連結 |
|------|------|
| GitHub Repo | [github.com/david04129/Snapvest](https://github.com/david04129/Snapvest) |
| GitHub Actions | [Snapvest Actions](https://github.com/david04129/Snapvest/actions) |
| Supabase | [supabase.com](https://supabase.com) |
| Supabase 文件 | [supabase.com/docs](https://supabase.com/docs) |
| NASDAQ 美股清單 | [nasdaqtraded.txt](https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqtraded.txt) |
| 證交所上市 CSV | [t187ap03_L.csv](https://dts.twse.com.tw/opendata/t187ap03_L.csv) |
| 櫃買中心 | [tpex.org.tw](https://www.tpex.org.tw/) |
| CoinGecko API | [docs.coingecko.com](https://docs.coingecko.com/) |
| 匯率 API | [open.er-api.com](https://open.er-api.com/) |
| Yahoo Finance（非官方） | [query1.finance.yahoo.com](https://query1.finance.yahoo.com/) |
| yfinance（Python） | [github.com/ranaroussi/yfinance](https://github.com/ranaroussi/yfinance) |
| 政府資料開放平台（台股備援 CSV） | [data.nat.gov.tw](https://data.nat.gov.tw/dataset/18419) |

---

*最後更新：2026-05-24。若程式有改動，以 repo 內實際檔案為準。*
