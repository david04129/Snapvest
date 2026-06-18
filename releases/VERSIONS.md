# Walleaf 版本清單

> **用途**：記錄每次 App / 官網 / 後端的重要版本，方便回溯、hotfix 與 App Store 對照。  
> **更新規則**：每次準備送審、上架、或打 tag 前，**先更新本文件再 push**。

---

## 快速索引

| 版本 | Build | 狀態 | Git Tag | 正式上架 |
|------|-------|------|---------|----------|
| 1.0.0 | 6 | **已上架** | `v1.0.0-build6` | 2026-06（App Store 已可發布） |

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

## 版本詳細紀錄

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

## main 上尚未打 tag 的改動（1.0.0 之後）

> 這些 commit 在 `v1.0.0-build6` **之後**，**不影響**已上架的 App binary，但官網已更新。

| Commit | 日期 | 改動 |
|--------|------|------|
| `42a597d` | 2026-06-14 | 官網：手機導覽排版 |
| `20e4a64` | 2026-06-19 | 官網：App Store 官方 Badge、移除「即將推出」 |
| `85a13c4` | 2026-06-19 | 新增版本 manifest、`.gitignore` 忽略 artifacts |

**下一版 App 送審前**：應新開 `v1.0.1-build7`（或對應 build 號）並在本文件新增一節。

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
    └── Walleaf-1.0.0-build6.xcarchive
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

*最後更新：2026-06-19*
