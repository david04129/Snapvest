# Walleaf 上架前待辦清單

> **最後更新**：2026-06-08  
> **你的現況**：Xcode 本機開發中；Apple Developer 已付費、Membership **審核中**（請自行確認是否已 Active）；尚未使用 App Store Connect。  
> **明天接續**：**#11 模擬器訂閱驗收**（見下方 [「#11 完整驗收清單」](#11-完整驗收清單手動打勾)）
> **相關規格**：[`WALLEAF_PLUS_SUBSCRIPTION_SPEC.md`](WALLEAF_PLUS_SUBSCRIPTION_SPEC.md) · [`WALLEAF_V1_LAUNCH_PLAN.md`](WALLEAF_V1_LAUNCH_PLAN.md) · [`WALLEAF_LEGAL_DRAFT.md`](WALLEAF_LEGAL_DRAFT.md)

**符號**：🟢 現在就能做｜🟡 需 Developer Membership **Active** 後才能做｜🟠 已實作、待你手動驗收

**進度紀錄**（2026-05-31 依 repo 現況更新）：

---

## 第一階段：審核等待期（現在開始）

### P0 — 不斷線、每天該做的

- [ ] **#1** 🟠 模擬器跑通主流程（記帳、帳戶、交易、首頁走勢、設定、備份／還原）— 功能齊全，建議你再跑一輪完整回歸後打勾
- [ ] **#2** 🟢 確認審核狀態（enrollment email、[developer.apple.com/account](https://developer.apple.com/account) Membership 是否 **Active**）
- [x] **#3** 🟢 Bundle ID 在 Xcode 定案為 `com.EggHsu.Walleaf`（Tests：`com.EggHsu.WalleafTests` / UITests：`com.EggHsu.WalleafUITests`）

---

### P1 — 訂閱與 Plus（本機可完成，不用 Connect）

> **逐步教學**：見下方 [「#4–#11 訂閱實作逐步指南」](#411-訂閱實作逐步指南)

- [x] **#4** 🟢 新增 StoreKit Configuration 檔（`WalleafPlus.storekit`）
- [x] **#5** 🟢 Scheme 綁定 StoreKit 檔（Edit Scheme → Run → Options）
- [x] **#6** 🟢 實作 `SubscriptionManager`（StoreKit 2）
- [x] **#7** 🟢 實作 Paywall 畫面（替換「Walleaf Plus 即將推出」）
- [x] **#8** 🟢 實作 `PlusFeatureGate`（備份／還原／匯入／Face ID）
- [x] **#9** 🟢 Free 上限邏輯（帳戶 ≤3、持股 ≤3、單一投資市場）
- [x] **#10** 🟢 合規賣出規則（超額禁買入；只能全數賣清）
- [ ] **#11** 🟠 模擬器測完整訂閱流程 — 程式已接（#8–#10 已完成），**明天依下方「#11 完整驗收清單」逐項打勾**

**Product ID（已定案，Connect 與 StoreKit 檔須一致）**：

| 方案 | Product ID | 定價 |
|------|------------|------|
| 月訂 | `walleaf.plus.monthly` | NT$60 |
| 年訂 | `walleaf.plus.yearly` | NT$390 |
| 試用 | Intro Offer | 7 天免費 |

---

### P2 — 產品 polish（審核中可並行）

- [ ] **#12** 🟠 使用教學區塊驗收（示範模式、持倉、批量匯入、備份還原教學）— UI 已建，待逐項驗收
- [ ] **#13** 🟠 示範模式走勢圖驗收（總資產／淨資產／負債合理）— 待你確認
- [ ] **#14** 🟢 設定頁「關於與支援」（版本號、聯絡 email、政策連結）— **尚未做**
- [ ] **#15** 🟢 法律文件定稿（潤飾 `WALLEAF_LEGAL_DRAFT.md`）— 初稿在，[ ] 營運者／信箱／生效日仍空
- [ ] **#16** 🟢 政策網頁上線（GitHub Pages / Notion 等可公開 URL）— **尚未做**
- [ ] **#17** 🟢 App Store 文案草稿（名稱、描述、關鍵字）— **尚未做**
- [ ] **#18** 🟢 截圖規劃（6.7" / 6.5"，5～8 張）— **尚未做**

---

### P3 — 技術債與品質（有空再做）

- [ ] **#19** 🟢 備份還原回歸測試（匯出 → 新 App／刪 App → 還原）
- [ ] **#20** 🟠 429 / 網路錯誤 UX 驗收 — 程式已接（Edge rate limit、`ManualRefreshCooldown`），待實際觸發驗收
- [ ] **#21** 🟠 Onboarding 驗收 — `OnboardingView`／Splash 已實作，待完整走一輪
- [ ] **#22** 🟠 整理 Debug 開關 — `showsDeveloperSettings = false` 已藏開發區；`#if DEBUG` 區塊仍留，上架前再清

---

## 第二階段：Developer Active 後

> 收到審核通過 email、Membership 顯示 **Active** 後，**照編號順序**做。

### P0 — 當天必做（約 30～60 分鐘）

- [ ] **#23** 🟡 Developer → Identifiers 建 App ID `com.EggHsu.Walleaf`
- [ ] **#24** 🟡 Xcode Signing 確認綠勾（Team + Automatically manage signing）
- [ ] **#25** 🟡 真機 smoke test（能開、能記帳、股價正常）
- [ ] **#26** 🟡 App Store Connect 新建 App（名稱 Walleaf、Bundle ID 選剛建的）

---

### P1 — 訂閱接上 Apple（Connect + 真機）

- [ ] **#27** 🟡 Connect 建訂閱群組（例：Walleaf Plus）
- [ ] **#28** 🟡 Connect 建兩個訂閱產品（ID 與 StoreKit 檔一致）
- [ ] **#29** 🟡 定價 NT$60 / NT$390 + Intro Offer 7 天試用
- [ ] **#30** 🟡 訂閱本地化文案（繁中）
- [ ] **#31** 🟡 Sandbox 測試帳號
- [ ] **#32** 🟡 真機測 IAP（關 StoreKit Configuration 或改用 Production sandbox）
- [ ] **#33** 🟡 簽署 Paid Apps Agreement

---

### P2 — 送審準備

- [ ] **#34** 🟡 App 隱私問卷
- [ ] **#35** 🟡 年齡分級問卷
- [ ] **#36** 🟡 Archive → Upload Build
- [ ] **#37** 🟡 TestFlight 內測
- [ ] **#38** 🟡 截圖 + 預覽圖上傳
- [ ] **#39** 🟡 審核備註（Plus 試用、Sandbox 方式、本機備份說明）
- [ ] **#40** 🟡 Submit for Review（v1.0 即含 Free／Plus）

---

## 本週優先 5 件（速查）

```
✅ 已完成：#3–#10（Bundle ID、StoreKit、Paywall、Gate、Free 上限、合規賣出）
👉 明天優先做：
1. 🟠 #11     模擬器完整訂閱驗收（下方清單逐項打勾）
2. 🟢 #15–#16 法律定稿 + 政策公開 URL（送審必備）
3. 🟠 #1      主流程回歸（含備份還原）
4. 🟠 #12–#13 使用教學／示範模式走勢驗收
5. 🟡 #2      確認 Developer Membership 是否 Active → 通過後接 #23
```

---

## 依賴關係

```
🟢 本機開發 + StoreKit Configuration (#4–#11)
        ↓
🟡 Developer Active (#23)
        ↓
🟡 Identifiers + Connect App (#23–#26)
        ↓
🟡 Connect 訂閱產品 (#27–#29)
        ↓
🟡 Sandbox 真機 IAP (#31–#32)
        ↓
🟡 TestFlight → 送審 (#36–#40)
```

---

## 命名策略備忘（不必全改 Snapvest）

| 項目 | 建議 | 狀態 |
|------|------|------|
| 使用者看到的名稱 | Walleaf | ✅ 已完成 |
| Bundle ID | `com.EggHsu.Walleaf` | ✅ Xcode 已設 |
| Xcode 專案／target 名 Snapvest | 可維持 | 內部代號 |
| UserDefaults key `snapvest.*` | 不要改 | 改需遷移 |
| repo 資料夾 Snapvest | 不要改 | 與 App 無關 |

---

## #4–#11 訂閱實作逐步指南

> 以下為 Cursor／AI 協作時的標準步驟；每完成一步在上方 P1 打勾。

### #4 新增 StoreKit Configuration 檔

**檔案位置**：`Snapvest/Snapvest/WalleafPlus.storekit`

**內容要點**：

- 訂閱群組名稱：Walleaf Plus
- `walleaf.plus.monthly` — P1M — NT$60 — 7 天免費試用
- `walleaf.plus.yearly` — P1Y — NT$390 — 7 天免費試用
- Storefront：`TWN`、Locale：`zh_Hant_TW`

**驗收**：在 Xcode 左側 Project Navigator 看得到 `WalleafPlus.storekit`；點開可編輯兩個 subscription。

---

### #5 Scheme 綁定 StoreKit 檔

1. Xcode 上方 scheme 選 **Snapvest** → **Edit Scheme…**（或 ⌘<）
2. 左側選 **Run**
3. 分頁 **Options**
4. **StoreKit Configuration** 下拉選 **WalleafPlus.storekit**（不是 None）
5. **Close**
6. **Product → Clean Build Folder**（⇧⌘K）→ Run 模擬器

**驗收**：Scheme 的 Run → Options 顯示 WalleafPlus.storekit。

---

### #6 實作 SubscriptionManager

**新增檔案**：

- `Snapvest/Snapvest/Services/SubscriptionManager.swift`
- `Snapvest/Snapvest/Models/PlusProductID.swift`（Product ID 常數）

**職責**：

- `@MainActor` + `ObservableObject`
- `loadProducts()` → `Product.products(for: [...])`
- `refreshEntitlements()` → `Transaction.currentEntitlements`
- `purchase(_ product: Product)` / `restorePurchases()`
- `@Published var isPlusActive: Bool`
- `@Published var monthlyProduct` / `yearlyProduct`
- 啟動時 `Task` 監聽 `Transaction.updates`
- 在 `SnapvestApp` 或 `AppRootView` 注入 `.environmentObject`

**驗收**：Debug 啟動後 console 或 breakpoint 可看到兩個 Product 載入成功、`isPlusActive == false`。

---

### #7 實作 Paywall 畫面

**新增檔案**：`Snapvest/Snapvest/Views/WalleafPlusPaywallView.swift`

**UI 要點**：

- 月／年方案卡片（顯示 `product.displayPrice`）
- 「7 天免費試用」文案
- 訂閱按鈕 → `subscriptionManager.purchase`
- 「恢復購買」
- Plus 權益列表（備份、匯入、Face ID、無上限）
- 小字：自動續訂、取消方式、服務條款連結 placeholder

**修改**：`SettingsView` — Walleaf Plus 卡片改開 Paywall sheet，移除 `comingSoonFeature = .subscription`。

**驗收**：設定 → Walleaf Plus → 看到月 NT$60、年 NT$390（StoreKit 本機價格）。

---

### #8 實作 PlusFeatureGate

**新增檔案**：`Snapvest/Snapvest/Utilities/PlusFeatureGate.swift`

**方法範例**：

- `canUseBackupRestore(isPlusActive:)`
- `canUseImport(isPlusActive:)`
- `canUsePrivacyLock(isPlusActive:)`
- 非 Plus → 回傳 false，UI 改開 Paywall

**修改入口**：

| 功能 | 檔案 |
|------|------|
| 備份 | `SettingsView` backupExportRow |
| 還原 | `SettingsView` backupRestoreRow |
| 匯入 | `TransactionImportView`、相關 NavigationLink |
| Face ID | `SettingsView` privacyLockRow |

**驗收**：未訂閱時點備份／還原／匯入／Face ID → 出現 Paywall；模擬器購買後 → 可進入。

---

### #9 Free 上限邏輯

**新增檔案**：`Snapvest/Snapvest/Utilities/SubscriptionComplianceState.swift`

**規則**（見 `WALLEAF_PLUS_SUBSCRIPTION_SPEC.md`）：

- 帳戶總數 ≤ 3
- distinct 持股 ≤ 5
- 投資帳戶市場只能一種（台股 **或** 美股 **或** 加密）

**修改**：

- `AddAccountView` — 建立第 4 帳戶前攔截
- 新增持股／匯入 — 第 4 檔前攔截
- `AddAccountView` — 第二種投資市場攔截

**驗收**：Free 使用者第 4 帳戶被擋；Plus 或試用中可建立。

---

### #10 合規賣出規則

**條件**：Free 且已超過 Free 上限（`isOverFreeLimits`）

**規則**：

- **禁買入**（`BuyTradeFormView`、新增買入入口）
- **賣出**只能全數賣清（`SellTradeFormView` 數量鎖為全部、不可部分賣）

**驗收**：超額 Free 使用者無法買入；賣出時數量固定為持有全部。

---

### #11 完整驗收清單（手動打勾）

> **目的**：在模擬器 + StoreKit Configuration 下，確認 Free／Plus、上限、合規賣出、過期行為都正確。  
> **全部打勾後**，在上方 P1 把 **#11** 改為 `[x]`。

#### 0. 測試前準備

- [ ] **11-0-1** Scheme → Run → Options → **StoreKit Configuration** = `WalleafPlus.storekit`
- [ ] **11-0-2** 用 **Xcode Run** 啟動模擬器（不是手動點模擬器上的 App 圖示）
- [ ] **11-0-3** 建議先 **刪除模擬器上的 App → 重新 Run**（乾淨未訂閱狀態）
- [ ] **11-0-4** 確認設定 → Walleaf Plus 能看到月 NT$60、年 NT$390

#### A. 未訂閱（Free）— Plus 功能鎖

- [ ] **11-A-1** 設定 → **備份到 iCloud Drive** → 出現 Paywall（不進匯出）
- [ ] **11-A-2** 設定 → **從備份還原** → 出現 Paywall
- [ ] **11-A-3** 投資帳戶詳情 → **匯入** → 出現 Paywall
- [ ] **11-A-4** 設定 → **Face ID 解鎖** 嘗試開啟 → 出現 Paywall（或無法啟用）

#### B. 未訂閱（Free）— 上限攔截

- [ ] **11-B-1** 已有 **3 個帳戶** 時，新增第 4 個 → Paywall + 說明
- [ ] **11-B-2** 已有 **台股** 投資帳戶時，再開 **美股／加密** 投資帳戶 → Paywall
- [ ] **11-B-3** 已有 **3 檔** distinct 持股時，**買入第 4 檔新標的** → 被擋（Paywall 或錯誤訊息）
- [ ] **11-B-4** 已有持股時，**買入另一市場** 的新標的 → 被擋

> 帳戶／持股不夠測上限時：可用 **示範模式** 確認 demo 不受限；或暫時用現有資料測 **合規模式**（見 C）。

#### C. 合規模式（Free 且已超額：>3 檔或跨市場）

- [ ] **11-C-1** 首頁／各 Tab 頂部出現 **「Free 合規模式」橫幅**（在標題列下方，不遮住走勢圖）
- [ ] **11-C-2** **買入**（含加碼、新標的）→ 被擋，提示只能清倉或訂閱 Plus
- [ ] **11-C-3** **賣出** → 數量 **鎖定為全部持有**，無法部分賣
- [ ] **11-C-4** 賣至 ≤3 檔且 **單一市場** 後 → 橫幅消失，可正常 Free 買賣（仍受 3 帳戶等限制）

#### D. 購買 Plus — 解鎖

- [ ] **11-D-1** 設定 → Walleaf Plus → 選 **年訂** → StoreKit 對話框 **購買成功**
- [ ] **11-D-2** Paywall／設定卡片顯示 **已訂閱**（或 Plus 已啟用）
- [ ] **11-D-3** **備份** 可進入匯出流程
- [ ] **11-D-4** **還原** 可選檔（不必真的覆蓋資料）
- [ ] **11-D-5** **匯入** 可進入匯入畫面
- [ ] **11-D-6** **Face ID 解鎖** 可成功開啟
- [ ] **11-D-7** 可建立 **第 4 個帳戶**、**第二種投資市場帳戶**（Plus 下不受 Free 上限）

#### E. 訂閱過期 — Plus 關閉、資料保留

**作法（Manage Transactions）**：

1. App 在模擬器跑著，且 **11-D 已全部通過**
2. Xcode 選單：**Debug → StoreKit → Manage Transactions…**
   - 若選項是灰的：確認是用 Xcode **Run** 啟動的 App
3. 在列表找到 `walleaf.plus.monthly` 或 `walleaf.plus.yearly`
4. 選中訂閱交易 → 按 **Refund**（退款，模擬訂閱結束；**Xcode 沒有 Expire 按鈕**）
   - 若 Refund 後 entitlement 還在：改試 **Delete** 刪除該筆交易，或見下方「其他作法」
5. 回到 App：**切到背景再回前景**，或完全關掉 App 重開

- [ ] **11-E-1** Manage Transactions 成功找到並 **Refund**（或 Delete）訂閱
- [ ] **11-E-2** 過期後 **Plus 功能關閉**（備份／還原／匯入／Face ID 再被擋）
- [ ] **11-E-3** **Face ID 自動關閉**（若過期前有開）
- [ ] **11-E-4** **帳戶、持股、交易、走勢資料仍在**（沒被刪）
- [ ] **11-E-5** 若仍超 Free 上限 → **合規橫幅** 再次出現、買入仍被擋

**其他作法（沒有 Expire 時）**：

| 作法 | 路徑 | 用途 |
|------|------|------|
| **Refund** | Manage Transactions → 選交易 → Refund | **最常用**：模擬退款／訂閱失效 |
| **Delete** | Manage Transactions → 選交易 → Delete（或刪除圖示） | 移除交易紀錄， entitlement 應消失；可重測試用 |
| **Don't Renew** | Manage Transactions → **＋** 新增訂閱 → 選 **Don't Renew** | 只買一個週期、不自動續訂，等 renewal rate 跑完 |
| **Time Rate** | 點 `WalleafPlus.storekit` → Editor → **Subscription Renewal Rate**；或 Debug → StoreKit → Time Rate | 加速時間，等試用／訂閱自然到期 |
| **Decline 漲價** | 選訂閱 → Request Price Increase Consent → **Decline** | 模擬使用者拒絕漲價而**取消訂閱** |

**另選：Time Rate 加速**（測試 7 天試用結束，不必手動 Refund）

- Debug → StoreKit → **Time Rate** → 例如 1 month = 5 minutes
- 購買含 7 天試用方案後等待試用結束（時間較長，可另日測）

#### F. 恢復購買

- [ ] **11-F-1** 在 **Refund 後**（或刪 App 重裝後），Paywall 點 **恢復購買**
- [ ] **11-F-2** 若 StoreKit 仍有有效 entitlement → 恢復成功、Plus 功能再開
- [ ] **11-F-3** 若已 Refund 且無有效訂閱 → 顯示「找不到可恢復的有效訂閱」類訊息（符合預期）

> **注意**：Refund 後「恢復購買」通常**無法**恢復，需 **重新購買** 才會再變 Plus；兩種情況都算測到。

#### G. 月訂路徑（可選，建議至少測一條）

- [ ] **11-G-1** 乾淨狀態 → 購買 **月訂** → 解鎖成功
- [ ] **11-G-2** Paywall 顯示月方案價格與試用文案正確

#### H. 示範模式（不應受 Free 限制）

- [ ] **11-H-1** 使用教學 → **進入示範模式** → 不受 #11-B 帳戶／持股上限影響（可瀏覽 demo 資料）
- [ ] **11-H-2** 結束示範模式 → 回到真實資料與訂閱狀態

---

#### #11 常見問題

| 狀況 | 處理 |
|------|------|
| Manage Transactions 是灰的 | 用 Xcode Run 啟動；Scheme 已選 StoreKit 檔 |
| Refund 後 Plus 還在 | App 切背景再回前景，或 Kill 重開；仍不行就 **Delete** 交易 |
| 找不到交易 | 先完成購買；Manage Transactions 視窗重新整理 |
| 真機 | 本段只適用 **StoreKit Configuration + 模擬器**；真機改 #32 Sandbox |

---

### #11 模擬器測完整訂閱流程（摘要）

上方 [「#11 完整驗收清單」](#11-完整驗收清單手動打勾) 為明日驗收入口；此段保留快速參考。

1. 確認 Scheme 已綁 `WalleafPlus.storekit`
2. 刪 App → 重新 Run
3. 依清單 **A → B → C → D → E → F** 順序測
4. 全部 `[x]` 後，P1 的 **#11** 打勾

**StoreKit 訂閱結束**：Debug → StoreKit → Manage Transactions → 選訂閱 → **Refund**（或 Delete）

**StoreKit 加速**：Debug → StoreKit → Time Rate

---

## 修訂紀錄

| 日期 | 說明 |
|------|------|
| 2026-06-08 | 擴充 #11 完整驗收清單（A–H + StoreKit Expire 步驟）；明天接續手動驗收 |
| 2026-06-07 | 實作 #8–#10：PlusFeatureGate、Free 上限、合規賣出；合規橫幅版面修正 |
| 2026-05-31 | 進度更新：#4–#7 完成；#8–#10 未開始；#12–#13／#20–#22 已實作待驗收 |
| 2026-06-06 | 初版：整合審核等待期 + Active 後 checklist；#4 StoreKit 檔已加入 repo |
