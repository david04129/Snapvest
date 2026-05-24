# 變更記錄 - 2026/05/24

> 今日重點：每日投資組合快照（後端排程 + App 走勢圖接 Supabase）、匯率流程釐清、Git 備份與 push。

**Commit：** `6e68aeb`  
**備份分支：** `backup/snapshot-20260524-004749`（指向改動前的 `349baa9`）

---

## 一、每日投資組合快照（Phase 2 完成）

### 背景

- Phase 1 已完成：App 交易後 sync `user_portfolio_state`（現金 / 持股 / 負債）
- 今日補上 Phase 2～4：後端每天算淨資產 → 寫入 `user_daily_snapshots` → App 走勢圖讀真實資料

### 新增／修改檔案

| 檔案 | 說明 |
|------|------|
| `backend/supabase/migrations/006_user_daily_snapshots.sql` | 每日快照表（主鍵 `user_id + snapshot_date`） |
| `backend/supabase/migrations/003_exchange_rates.sql` | 匯率表 migration（補進 repo） |
| `backend/scripts/daily_portfolio_snapshot.py` | 讀 state + 股價 + 匯率 → 算總資產／淨資產 → upsert |
| `.github/workflows/daily-portfolio-snapshot.yml` | 每天 **23:40 台灣時間**（UTC 15:40）自動跑 |
| `Snapvest/Services/SupabaseDailySnapshotService.swift` | App 從 Supabase 讀走勢資料 |
| `Snapvest/Views/HomeTrendChartView.swift` | 改讀 Supabase；不足 2 天顯示空狀態 |
| `Snapvest/Views/HomeView.swift` | 走勢圖傳入 `userId` |
| `Snapvest/Models/PortfolioStateSyncPayload.swift` | 持股 sync 新增 `averageCost`（後端算未實現損益） |
| `backend/scripts/daily_price_update.py` | 移除重複的匯率更新函式 |

### 資料流

```
App 交易 → user_portfolio_state（最新狀態，每次覆蓋）

GitHub Actions 23:40
  → 讀 user_portfolio_state
  → 讀 asset_price_snapshots、exchange_rates
  → 寫 user_daily_snapshots（每人每天一筆，同天 upsert 不蓋昨天）

App 首頁走勢圖 → 讀 user_daily_snapshots（依 user_id）
```

### 重要行為

| 項目 | 說明 |
|------|------|
| **不覆蓋歷史** | 主鍵 `(user_id, snapshot_date)`，每天新增一列；同天重跑只更新當天 |
| **多使用者** | 每位在 `user_portfolio_state` 的使用者，每天各一筆 |
| **走勢圖門檻** | 至少 **2 個不同日期** 才畫線，否則「尚無足夠資料顯示走勢」 |
| **不回填** | 排程只寫「當天」，過去沒跑的日子不會自動補 |

### Supabase（使用者已手動完成）

- `user_daily_snapshots` 表與 RLS 已在 Dashboard 建立（policy 名稱與 migration 檔略有不同，功能相同）
- 已手動跑過 `daily_portfolio_snapshot.py`，目前有至少 1 筆快照

---

## 二、匯率（討論與決策，未另 commit）

### 問題釐清

- 後端 `open.er-api.com` 一次回傳 **160+ 種**匯率，全部寫入 `exchange_rates`
- App 實際主要只用 **USD → TWD**
- 曾規劃 **方案 B（15 種白名單）**，後決定 **維持全部一起更新**（已還原白名單改動）

### 操作備忘

```bash
cd backend/scripts
export SUPABASE_URL='...'
export SUPABASE_SERVICE_ROLE_KEY='...'
python3 update_exchange_rates_only.py   # 只更新匯率
python3 daily_portfolio_snapshot.py   # 只跑每日快照
```

---

## 三、Git 備份

| 項目 | 內容 |
|------|------|
| 備份分支（改動前） | `backup/snapshot-20260524-004749` @ `349baa9` |
| 備份分支（改動後） | `backup/snapshot-20260524-post-daily` @ `6e68aeb` |
| 本地 tag | `backup-20260524-daily-snapshot` @ `6e68aeb` |
| **本地資料夾副本** | **`/Users/david/Desktop/Snapvest-backup-20260524`**（含完整 `.git`） |
| Push | `main` 與改動前備份分支均已 push 至 `origin` |

還原改動前：

```bash
git checkout backup/snapshot-20260524-004749
```

還原今日完成版（本地）：

```bash
git checkout backup/snapshot-20260524-post-daily
# 或直接開 Desktop 上的 Snapvest-backup-20260524 資料夾
```

---

## 四、待你後續確認的事

1. **GitHub Actions → Daily Portfolio Snapshot** 是否已手動 Run 過、secrets 是否正常
2. **明天 23:40 後** `user_daily_snapshots` 是否自動多一筆（第二個日期 → 走勢圖可畫線）
3. 比對 App 首頁數字與 `user_daily_snapshots` 當日 `total_assets` / `net_worth` 是否接近

---

## 五、已知架構差異（尚未修）

| 項目 | App | 後端快照腳本 |
|------|-----|--------------|
| 持股換匯 | 依**帳戶幣別** | 依**持股標的 currency** |
| 影響 | 美股放在台幣證券戶時可能與後端數字有差 | 示範資料（美股戶）無此問題 |

---

## 六、新建檔案清單

```
.github/workflows/daily-portfolio-snapshot.yml
backend/scripts/daily_portfolio_snapshot.py
backend/supabase/migrations/003_exchange_rates.sql
backend/supabase/migrations/006_user_daily_snapshots.sql
Snapvest/Snapvest/Services/SupabaseDailySnapshotService.swift
```
