# Walleaf 版本清單

> **用途**：記錄每次 App / 官網 / 後端的重要版本，方便回溯、hotfix 與 App Store 對照。  
> **更新規則**：每次準備送審、上架、或打 tag 前，**先更新本文件再 push**。

---

## 快速索引

| 版本 | Build | 狀態 | Git Tag / 備份 | 正式上架 |
|------|-------|------|----------------|----------|
| **1.2.0** | 9 | **待送審** | `v1.2.0-build9` / `backup/v1.2.0-build9` | — |
| 1.1.0 | 7 | **待送審** | `v1.1.0-build7` | — |
| 1.0.0 | 6 | **已上架** | `v1.0.0-build6` | 2026-06（App Store 已可發布） |

---

## 版本詳細紀錄

### v1.2.0 — Fugle 報價／台股清單、匯入與 catalog OTA

| 項目 | 內容 |
|------|------|
| **狀態** | **待送審**（正式 baseline；`build8` 為預 release，已由 **build9** 取代） |
| **日期** | 2026-06-21 |
| **Git Tag** | `v1.2.0-build9` |
| **Git Commit** | `61a6cee` |
| **備份分支** | `backup/v1.2.0-build9` |
| **最低 iOS** | **18.6**（恢復 Phase 1 前設定；iOS 17 **不支援**） |
| **Symbol catalog** | 台股 **1.15**（3258 檔，Fugle 可交易清單）；先前 **1.14** 為 2744 檔 |

#### 改動摘要

**App**
- **台股匯入**：`SymbolListService.resolveTaiwanImportSymbol` — CSV `symbol` 欄可填**代號或中文簡稱**（catalog exact match）；`TransactionImportService` 整合。
- **匯入教學**：成交明細欄位改「代號或股票名稱」；持有倉位示意改中文名稱範例（`TransactionImportTutorialView`）。
- **其他資產備註**：詳情頁備註列恆顯、可編輯（`ManualAssetDetailView` + `EditManualAssetNotesSheet`）。
- **前收信任**：`DailyReferenceCloseResolver` 信任 bootstrap 來源 **`fugle`**；`SupabasePriceService` 解析 Edge `previousPriceSource`。
- **Deployment target**：App target **18.6**（恢復原設定；放棄 iOS 17；Swift 6 × iOS 17 runtime 不相容）。
- **股價合併**：移除 `PriceSnapshotMerger` 單日 100% 價差防呆，雲端修正可覆寫本機錯價。
- **Free 方案放寬**（`PlusFeatureGate` / `SubscriptionComplianceState`）：
  - 帳戶／其他資產：**無上限**（移除原 3 個限制）。
  - distinct 持股：**3 → 5 檔**（可加碼既有標的；第 6 檔需 Plus）。
  - 投資帳戶與持股：**可跨台股・美股・加密**（移除單一市場限制與跨市場合規模式）。
  - 合規模式僅在 **>5 檔** 持股時觸發（全數賣出清倉、無法買入）。
  - Paywall 對照表文案同步（`WalleafPlusPaywallL10n`）。
- **更多頁**：兌換優惠碼移至「關於」下方；新增「追蹤FB粉專」；關於版本讀取 `CFBundleShortVersionString`（1.2.0）。

**後端 / Edge / 排程**
- **即時補價** `fetch-or-create-price`：台股 **Fugle `intraday/quote`（含 `previousClose`）→ Yahoo 5d 備援**；新增 `_shared/fugleQuote.ts`。
- **排程** `daily_price_update.py`：Fugle 抓價時一併寫入 **previousClose** → snapshot + history。
- **一次性腳本** `backfill_tw_previous_close_fugle.py`：修正 Yahoo 錯誤前收（如 6669）。
- **Supabase migration** `026_tracked_symbols_summary.sql`：`tracked_symbols_summary` 檢視（抓價池統計）。
- **Rate limit 註解**：外部來源含 Fugle。

**Symbols / CI**
- **台股建置** `build_symbols_tw.py`：預設 **Fugle tickers**（`TWSE` + `TPEx`, `type=EQUITY`）；`--legacy` 保留舊 CSV 流程。
- **Bundle + output**：`symbols_tw.json` **1.15 / 3258 檔**（剔除已下市如 0054、00716R；清單上標的 Fugle 可報價）。
- **GitHub Actions** `monthly-symbols-update.yml`：需 **`FUGLE_API_KEY`**；手動 Run 可勾 **skip_db_sync**。

**文件**
- `ENGINEERING_HANDBOOK.md`、`README.md`（iOS 18.6）、`scripts/README.md`、`docs/SYMBOL_CATALOG_UPDATE_GUIDE.md`。

#### 部署提醒（後端）

```bash
# Edge Secret + 部署
supabase secrets set FUGLE_API_KEY=...
cd backend && supabase functions deploy fetch-or-create-price

# 修正既有錯誤 Yahoo 前收（本機）
cd backend/scripts && python3 backfill_tw_previous_close_fugle.py --yahoo-only

# Supabase migration
# 套用 026_tracked_symbols_summary.sql
```

#### GitHub Secrets（Monthly Symbols Update）

| Secret | 用途 |
|--------|------|
| `FUGLE_API_KEY` | 台股 symbols 建置 |
| `SUPABASE_URL` | OTA catalog 同步 |
| `SUPABASE_SERVICE_ROLE_KEY` | OTA catalog 同步 |

#### 備份位置

| 類型 | 路徑 |
|------|------|
| 備份分支 | `git checkout backup/v1.2.0-build9` |
| Git tag | `git checkout v1.2.0-build9` |
| 詳細 manifest | [`releases/Walleaf-1.2.0-build9.manifest.txt`](Walleaf-1.2.0-build9.manifest.txt) |
| 預 release（已取代） | `v1.2.0-build8` / [`Walleaf-1.2.0-build8.manifest.txt`](Walleaf-1.2.0-build8.manifest.txt) |
| 開發快照 manifest | [`releases/Walleaf-1.2.0.manifest.txt`](Walleaf-1.2.0.manifest.txt) |
| 1.1.0 送審 baseline | `git checkout v1.1.0-build7` |

#### 還原方式

```bash
git fetch origin --tags
git checkout v1.2.0-build9
# 或
git checkout backup/v1.2.0-build9
```

---

### v1.1.0 (build 7) — 霧化、圖表手勢、分享與 Paywall 試用

| 項目 | 內容 |
|------|------|
| **狀態** | **待送審** |
| **日期** | 2026-06-19 |
| **Git Tag** | `v1.1.0-build7` |
| **Git Commit** | `36703d6` |
| **備份分支** | `backup/v1.1.0-build7` |
| **Team ID** | `64F82QUW6Z` |
| **維護分支** | `main`（`release/1.0.0` 保留 1.0.0 hotfix 用） |
| **Bundle ID** | `com.EggHsu.Walleaf` |
| **App Store Apple ID** | `6778330994` |
| **App Store 下載** | https://apple.co/4b0KA8X |
| **最低 iOS** | **18.0**（Phase 1；原 18.6 → 18.0，無 API 改動） |

#### 改動摘要

**App**
- **評分（為 Walleaf 評分）**：點擊後直接開啟 App Store **撰寫評論**頁。
- **App Store 語言**：App 僅宣告 **繁體中文（zh-Hant）**。
- **兌換優惠碼**：Apple Offer Code 兌換 sheet（設定、Paywall）。
- **Free 超上限霧化**：Free 且帳戶或持股超上限時，首頁／管理／投資／分享長圖對數字、圖表、占比做視覺模糊；Plus／示範模式不套用。
- **分享**：可全部取消勾選；走勢圖與首頁相同線性渲染；分享文字附 App Store 下載連結。
- **首頁圖表手勢**：長按後 scrub／選 slice；修正非 7 天區間 scrub 座標；長按 0.45 秒觸發。
- **新增交易**：買入／賣出切換與賣出持股選單改善；買賣表單改為先填價格再填數量。
- **Paywall**：年訂 7 天免費試用 UI（角標 + pill + 訂閱說明）；底部按鈕間距修正。
- **最低系統**：iOS **18.0**（Phase 2 放棄 iOS 17：Swift 6 編譯設定與 iOS 17 runtime 不相容）。
- **版本號**：Marketing 1.1.0 / Build 7。

**官網**
- （本版 App binary 無新增；官網見下方表格）

**後端 / GCP**
- 無

#### 061901 備份點（霧化功能開發前 baseline）

| 項目 | 內容 |
|------|------|
| **名稱** | **061901 版** |
| **Git Tag** | `061901` |
| **Commit** | `7fd69cd` |
| **分支** | `backup/061901` |
| **包含** | 評分直連 App Store、優惠碼兌換、僅 zh-Hant、1.1.0 (7)；**不含** Free 超上限霧化 |
| **還原方式** | `git checkout 061901` 或 `git checkout backup/061901` |

#### v1.1.0-build7 備份點（送審前完整版）

| 項目 | 內容 |
|------|------|
| **名稱** | **v1.1.0 (build 7) 送審前備份** |
| **Git Tag** | `v1.1.0-build7` |
| **分支** | `backup/v1.1.0-build7` |
| **還原方式** | `git checkout v1.1.0-build7` 或 `git checkout backup/v1.1.0-build7` |

#### 061901 之後的改動紀錄

> 若不滿意後續改動，可還原至 `061901` tag；送審 baseline 用 `v1.1.0-build7`。

| 日期 | 改動 |
|------|------|
| 2026-06-19 | **Free 超上限霧化**：`FreeLimitBlurEnvironment.swift`；首頁／管理／投資／分享長圖；更新 `WALLEAF_PLUS_SUBSCRIPTION_SPEC.md` §4.1 |
| 2026-06-19 | **首頁圖表手勢**：`ChartHoldToInteractOverlay` + `ChartLongPressInteraction`（0.45s）；修正 scrub 座標 |
| 2026-06-19 | **分享**：空選擇、走勢圖線性渲染、`HomeShareMessageBuilder` App Store 連結 |
| 2026-06-19 | **交易表單**：買賣先價格後數量；新增交易買賣切換與賣出選單改善 |
| 2026-06-19 | **Paywall**：年訂 7 天試用角標／pill／訂閱說明；底部按鈕與說明文字版面 |
| 2026-06-20 | **最低 iOS Phase 1**：`IPHONEOS_DEPLOYMENT_TARGET` 18.6 → **18.0**（僅 Xcode 設定；iOS 17 留待 **v1.2.0**） |

#### 備份位置

| 類型 | 路徑 |
|------|------|
| 原始碼（tag） | `git checkout v1.1.0-build7` |
| 備份分支 | `git checkout backup/v1.1.0-build7` |
| 詳細 manifest | [`releases/Walleaf-1.1.0-build7.manifest.txt`](Walleaf-1.1.0-build7.manifest.txt) |
| Xcode Archive（本機） | `releases/artifacts/Walleaf-1.1.0-build7.xcarchive` |
| Xcode Organizer 原始檔 | `~/Library/Developer/Xcode/Archives/2026-06-19/Snapvest 2026-6-19, 1.25 PM.xcarchive` |
| **061901 baseline** | `git checkout 061901` |
| 1.0.0 回溯 | `git checkout v1.0.0-build6` |
| GitHub Tag | https://github.com/david04129/Snapvest/releases/tag/v1.1.0-build7 |
| App Store Connect | 送審建置版本 **1.1.0 (7)** |

#### 還原方式

```bash
git fetch --tags
git checkout v1.1.0-build7
# 或
git checkout backup/v1.1.0-build7
```

從 Archive 重裝 / 重送：Xcode → Organizer → 開啟 `releases/artifacts/Walleaf-1.1.0-build7.xcarchive`

#### App Store 正式版紀錄

| 項目 | 內容 |
|------|------|
| **送審** | 2026-06-19 準備上傳 |
| **備註** | 年訂 7 天試用需在 Connect「試賣優惠」設定；優惠碼在 Connect → Offer Codes 建立 |

#### Connect 優惠碼設定提醒（自用 / 朋友）

1. App Store Connect → **訂閱** → Walleaf Plus → **Offer Codes**
2. 建立優惠（試用延長、折扣等）→ 產生兌換碼
3. App 內：**更多 → 兌換優惠碼** 或 Paywall **兌換優惠碼** → 貼上 Apple 提供的碼
4. 年訂 **7 天免費試用**：年訂 Product → **試賣優惠** → 免費試用 1 週

---

## 如何新增一筆版本（模板）

複製下面區塊，貼到「版本詳細紀錄」最上方（新版在前）：

```markdown
### vX.Y.Z (build N) — 簡短標題

| 項目 | 內容 |
|------|------|
| **狀態** | 開發中 / 已送審 / 已上架 / 僅本地 tag / 已棄用 |
| **日期** | YYYY-MM-DD |
| **Git Tag** | `vX.Y.Z-buildN` |
| **Git Commit** | `xxxxxxxx` |
| **維護分支** | `release/X.Y.Z`（若有） |
| **Bundle ID** | `com.EggHsu.Walleaf` |
| **App Store Apple ID** | 6778330994 |

#### 改動摘要
- App：
- 官網：
- 後端 / GCP：
- 其他：

#### 備份位置
| 類型 | 路徑 |
|------|------|
| 原始碼（tag） | `git checkout vX.Y.Z-buildN` |
| 維護分支 | `git checkout release/X.Y.Z` |
| 詳細 manifest | `releases/Walleaf-X.Y.Z-buildN.manifest.txt`（若有） |
| Xcode Archive（本機） | `releases/artifacts/Walleaf-X.Y.Z-buildN.xcarchive` |
| Xcode Organizer 原始檔 | `~/Library/Developer/Xcode/Archives/…` |
| App Store Connect | 建置版本 → 1.X.X (N) |

#### App Store 正式版紀錄（若已上架）
| 項目 | 內容 |
|------|------|
| **送審日期** | |
| **審核通過** | |
| **發布日期** | |
| **Submission ID** | |
| **Connect 版本頁** | App Store Connect → 1.X.X |
| **備註** | |

#### 還原方式
```bash
git fetch --tags
git checkout vX.Y.Z-buildN
```
```

---

### v1.0.0 (build 6) — 首次 App Store 上架

| 項目 | 內容 |
|------|------|
| **狀態** | **已上架**（Connect 顯示：已可發布 / Ready for Sale） |
| **日期** | 送審 2026-06-13；審核通過 2026-06-16 前後；發布 2026-06 |
| **Git Tag** | `v1.0.0-build6` |
| **Git Commit** | `9875a58` |
| **維護分支** | `release/1.0.0` |
| **Bundle ID** | `com.EggHsu.Walleaf` |
| **App Store Apple ID** | `6778330994` |
| **Team ID** | `64F82QUW6Z` |

#### 改動摘要（此版本核心）

**App（1.0.0）**
- Walleaf 首發：Free + Walleaf Plus 訂閱（月訂 / 年訂）
- 個人資產記帳：帳戶、交易、持股、走勢、圓餅圖、績效
- 備份還原、CSV 匯入、Face ID 隱私鎖（Plus）
- StoreKit 2 訂閱、Paywall、Free 上限 gate
- iOS 18 相容、iPhone 上架設定（build 6）

**官網（tag 當下）**
- `walleafapp.com` 繁中 / 英文首頁、隱私權、服務條款、免責聲明

**後端**
- Supabase + GCP Cloud Run 股價排程（與 1.0.0 配套）

#### 備份位置

| 類型 | 路徑 |
|------|------|
| 原始碼（tag） | `git checkout v1.0.0-build6` |
| 維護分支 | `git checkout release/1.0.0` |
| 詳細 manifest | [`releases/Walleaf-1.0.0-build6.manifest.txt`](Walleaf-1.0.0-build6.manifest.txt) |
| Xcode Archive（本機） | `releases/artifacts/Walleaf-1.0.0-build6.xcarchive` |
| Xcode Organizer 原始檔 | `~/Library/Developer/Xcode/Archives/2026-06-13/Snapvest 2026-6-13, 11.39 PM.xcarchive` |
| App Store Connect | 建置版本 **1.0.0 (6)** |
| GitHub Tag | https://github.com/david04129/Snapvest/releases/tag/v1.0.0-build6 |

#### App Store 正式版紀錄

| 項目 | 內容 |
|------|------|
| **Marketing Version** | 1.0.0 |
| **Build Number** | 6 |
| **送審日期** | 2026-06-13（Archive 上傳成功） |
| **審核裝置** | iPad Air 11-inch (M3) |
| **Submission ID** | `b79b8847-f908-466c-a225-ba97596b375b` |
| **退件原因（已修正）** | 3.1.2 缺 Terms 連結；2.1 加密貨幣問答 |
| **許可協議** | Apple 標準 EULA + 描述內 Terms / Privacy 連結 |
| **訂閱** | `walleaf.plus.monthly` / `walleaf.plus.yearly` |
| **App Store 連結** | https://apps.apple.com/app/id6778330994 |

#### 還原方式

```bash
git fetch --tags
git checkout v1.0.0-build6
# 或用維護分支
git checkout release/1.0.0
```

從 Archive 重裝 / 重送：Xcode → Organizer → 開啟 `releases/artifacts/Walleaf-1.0.0-build6.xcarchive`

---

## main 上尚未納入正式 App Store tag 的改動

（v1.2.0 開發內容已整併至上方 **v1.2.0** 章節；送審前請 bump **1.2.0 (build N)**、Archive、打 tag。）

| 日期 | 改動 |
|------|------|
| — | （見 v1.2.0 改動摘要） |

### 1.0.0 上架後、官網 only（不影響 App binary）

| Commit | 日期 | 改動 |
|--------|------|------|
| `42a597d` | 2026-06-14 | 官網：手機導覽排版 |
| `20e4a64` | 2026-06-19 | 官網：App Store 官方 Badge、移除「即將推出」 |
| `85a13c4` | 2026-06-19 | 新增版本 manifest、`.gitignore` 忽略 artifacts |
| `f2d10a5` | 2026-06-19 | 新增 `VERSIONS.md` |

**v1.1.0 送審**：tag `v1.1.0-build7`、分支 `backup/v1.1.0-build7`、manifest 與 Archive 已備份至 `releases/`（見上方 v1.1.0 備份位置）。**送審前請以含 iOS 18.0 deployment target 的 commit 重新 Archive**（Phase 1 後 binary 最低版本為 18.0）。

---

## 相容性路線圖

| 階段 | 目標 | 版本 | 狀態 |
|------|------|------|------|
| Phase 1 | 最低 **iOS 18.0**（18.6 → 18.0） | **v1.1.0** | **已完成** |
| Phase 2 | 最低 **iOS 17.0** | **v1.2.0** | **已取消**（Swift 6 `MainActor` 預設隔離 × iOS 17 runtime 不相容；維持 18.0） |

Phase 2 原計畫降至 iOS 17.0；實測 iOS 17 模擬器啟動時 SwiftUI AttributeGraph crash（`nonisolated(nonsending)` metadata）。catalog **tw 1.14** 等仍屬 v1.2.0 功能，與最低 OS 無關。

---

## 歷史 / 非正式 Tag（參考用）

| Tag | 用途 | 備註 |
|-----|------|------|
| `backup-20260524-daily-snapshot` | 早期開發快照 | 非 App Store 版本 |
| `before-account-detail-redesign` | 帳戶詳情改版前 | 非 App Store 版本 |

---

## 檔案結構說明

```
releases/
├── VERSIONS.md                          ← 本文件（版本總表）
├── Walleaf-X.Y.Z-buildN.manifest.txt    ← 單版詳細 manifest（可選）
└── artifacts/                           ← 本機二進位備份（不進 git）
    ├── Walleaf-1.0.0-build6.xcarchive
    └── Walleaf-1.1.0-build7.xcarchive
```

---

## 維護 Checklist

每次 **App 送審 / 上架** 請勾：

- [ ] Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 已更新
- [ ] Archive 成功並上傳 Connect
- [ ] 打 git tag：`vX.Y.Z-buildN`
- [ ] 建立或更新 `release/X.Y.Z` 分支
- [ ] 複製 `.xcarchive` 到 `releases/artifacts/`
- [ ] 新增或更新 `manifest.txt`
- [ ] **更新本文件 `VERSIONS.md`**
- [ ] `git push origin main --tags` 與 `release/*` 分支

每次 **僅官網 / 後端** 改動：

- [ ] 在本文件「尚未打 tag 的改動」表格加一列
- [ ] 若已部署正式環境，註明部署日期

---

*最後更新：2026-06-20（v1.2.0：Fugle 報價／台股清單、匯入與 OTA workflow）*
