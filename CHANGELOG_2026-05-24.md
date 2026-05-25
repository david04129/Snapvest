# 變更記錄 - 2026/05/24

> 今日重點：本機估值 B 全線落地、走勢圖（雲端歷史 + 當日即時）、雲端每日快照 bug 修正、歷史走勢 backfill、Phase 5 首頁 UX。

**最新 commit：** `8c3e16b`  
**備份分支（今晚）：**
- `backup/snapshot-20260524-pre-import-235505` @ `308fe9c`（匯入 SQL 前）
- `backup/snapshot-20260524-import-235505` @ `8c3e16b`（匯入 SQL 後）

---

## 今日 commit 時間軸

| Commit | 摘要 |
|--------|------|
| `6e68aeb` | 每日投資組合快照（後端排程 + App 走勢讀 Supabase） |
| `7304f09` | 帳戶 CSV 匯入、台股簡稱、股價截斷顯示 |
| `3bbcb82` | 每月 symbols 清單 GitHub Actions |
| `6c26f2b` | Monthly Symbols workflow YAML 修正 |
| `fbfca7f` / `735a982` | symbols 自動更新（CI） |
| `99be06f` | 首頁金額隱私、工程手冊 `ENGINEERING_HANDBOOK.md` |
| `9913b2f` | 首頁分享、今日損益、走勢區間顯示 |
| `3154f50` | 本機 JSON 持久化、`AppUser` 分使用者 |
| `288d61c` | Phase 1–3：Splash、本機 B 冷啟動、股價 gate、重複交易檢查 |
| `df4f2c1` | Phase 4：`rebuildAndNotify` 統一路徑、走勢 session 快取 |
| `4ecc6d6` | Phase 5：Tab 更新時間、十色圖表、分享預覽、排程改 **22:30** |
| `308fe9c` | 雲端快照持股計算修正、走勢「今天即時」、首頁換匯修正 |
| `8c3e16b` | david.hsu / piggy.lu 歷史走勢 SQL backfill |

---

## 一、本機估值 B + 冷啟動（Phase 1–4）

### 核心行為

- 交易／帳戶變更 → `SnapshotRefreshCoordinator.rebuildAndNotify` → 寫本機 JSON + sync `user_portfolio_state`
- Splash（`LaunchCoordinator` / `AppRootView`）先灌入 persisted 快照，首頁不再先閃 0
- 三大 Tab（首頁／帳戶／資產）共用 persisted 估值 B，不再各自重算 Supabase
- 移除 mock 種子與舊 Supabase 重算 dead code

### 主要檔案

- `LaunchCoordinator.swift`、`AppRootView.swift`、`LaunchSplashView.swift`
- `LocalUserDataStore.swift`、`DataService.swift` 持久化
- `SnapshotRefreshCoordinator.swift`、`SnapshotUpdater.swift`
- `PortfolioViewModel.prepareFromPersisted`

---

## 二、走勢圖

### 資料來源（`308fe9c` 後）

| 日期 | 來源 |
|------|------|
| **過去** | Supabase `user_daily_snapshots`（每人 `user_id` 篩選，約 400 天） |
| **今天** | 本機 `HomeDashboardSnapshot`（與首頁卡片同源，交易後即更新） |

實作：`TrendChartPointMerger` + `HomeTrendChartSessionCache`（只快取雲端歷史，不含當日）。

### 歷史 backfill（`8c3e16b`）

從 Numbers 匯出，產生 Supabase SQL（手動在 SQL Editor 執行）：

| 檔案 | user_id | 筆數 | 日期範圍 |
|------|---------|------|----------|
| `backend/scripts/import_david_hsu_daily_snapshots.sql` | `david.hsu` | 97 | 2025-12-25～2026-05-23 |
| `backend/scripts/import_piggy_lu_daily_snapshots.sql` | `piggy.lu` | 103 | 2025-12-25～2026-05-23 |

欄位對應：總資產→`total_assets`、投資資產→`total_investments`、總現金→`total_cash`、總負債→`total_liabilities`、淨資產→`net_worth`；`unrealized_gain_loss` = 0。

---

## 三、雲端每日快照 bug 修正（`308fe9c`）

### 問題

`user_daily_snapshots` 的 `total_investments`、`unrealized_gain_loss` 為 0，`total_assets` 只剩現金。

### 根因

- App sync 的 JSONB 用 **camelCase**（`assetType`、`averageCost`）
- `daily_portfolio_snapshot.py` 舊版只讀 **snake_case**（`asset_type`）→ 對不到股價 → 投資市值全 0

### 修正

- Python：`_field()` 同時支援 camelCase / snake_case；`stock_us` 代號大寫
- Swift：`PortfolioStateSyncPayload` 編碼改 snake_case（`asset_type`、`average_cost`）
- 首頁 `SnapshotUpdater`：持股市值換匯改依 **`holding.currency`**（與帳戶 Tab、後端腳本一致）

修正後本地驗算 david.hsu 約：總資產 561 萬、投資 449 萬、未實現 97 萬（需重跑 GitHub Actions **Daily Portfolio Snapshot** 才寫入雲端）。

---

## 四、Phase 5 首頁體驗（`4ecc6d6`）

- 各 Tab **資料更新時間** footer（`DataFreshnessStore`）
- 首頁現金卡片 **USD/TWD 匯率** caption
- 表單 **鍵盤／月曆收起**（`KeyboardDismiss` / `snapFormSheetChrome`）
- 圓餅圖／績效圖 **十色** + 切換閃爍修正
- **分享預覽** debounce + 淡入淡出
- Supabase REST **微秒時間戳**解析修正
- 每日快照排程：**23:40 → 22:30（台灣）**（cron `30 14 * * *` UTC）

---

## 五、其他功能與工具

| 項目 | 說明 |
|------|------|
| CSV 帳戶匯入 | 證券戶 buy-sell 流水、無標題列容錯 |
| 每月 symbols CI | 美股／台股／加密 Top 500 → App Bundle |
| 首頁分享 | 走勢／圓餅／績效圖分享 sheet |
| 金額隱私模式 | 首頁敏感數字可隱藏 |
| 工程手冊 | `ENGINEERING_HANDBOOK.md` |
| 重複交易 | 已排查（並行 submit + 雙重檢查），**尚未修 code** |

---

## 六、Supabase 架構備忘

- `user_daily_snapshots`：**單表 + `user_id` 欄**，無子資料夾；App 查詢帶 `user_id=eq.xxx`，不會因多人而變慢
- 索引：`(user_id, snapshot_date DESC)`
- 目前 anon 可讀全表 RLS；多人時長期應改為每人只能讀自己的列

---

## 七、Git 備份（今日）

| 分支 | 指向 | 說明 |
|------|------|------|
| `backup/snapshot-20260524-pre-import-235505` | `308fe9c` | 歷史 SQL 匯入前 |
| `backup/snapshot-20260524-import-235505` | `8c3e16b` | 歷史 SQL 匯入後 |
| `backup/snapshot-20260524-pre-push-212941` 等 | 較早 | Phase 5 commit 前後備份 |

均已 push 至 `origin`。

---

## 八、待辦／確認

1. [ ] GitHub Actions **Daily Portfolio Snapshot** 手動 Run（`308fe9c` 部署後）
2. [ ] Supabase SQL Editor 執行兩份 import SQL（若尚未執行）
3. [ ] 重開 App 驗收走勢圖（歷史 + 今天即時）
4. [ ] 比對首頁總資產與雲端當日快照（排程跑完後）
5. [ ] 重複交易提示一閃而過 — 待同意後再修（提交鎖 + 單次 duplicate 檢查）

---

## 九、新建／重要檔案清單

```
.github/workflows/daily-portfolio-snapshot.yml
backend/scripts/daily_portfolio_snapshot.py
backend/scripts/import_david_hsu_daily_snapshots.sql
backend/scripts/import_piggy_lu_daily_snapshots.sql
backend/supabase/migrations/006_user_daily_snapshots.sql
Snapvest/Snapvest/Services/SupabaseDailySnapshotService.swift
Snapvest/Snapvest/Views/HomeTrendChartView.swift
Snapvest/Snapvest/Utilities/HomeTrendChartSessionCache.swift
Snapvest/Snapvest/Services/LaunchCoordinator.swift
Snapvest/Snapvest/Views/AppRootView.swift
ENGINEERING_HANDBOOK.md
```
