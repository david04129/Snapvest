# Walleaf 上架前待辦清單

> **最後更新**：2026-05-31  
> **你的現況**：Xcode 本機開發中；Apple Developer 已付費、Membership **審核中**（請自行確認是否已 Active）；尚未使用 App Store Connect。  
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
- [ ] **#8** 🟢 實作 `PlusFeatureGate`（備份／還原／匯入／Face ID）— **尚未做**：目前四功能 Free 仍可直接用
- [ ] **#9** 🟢 Free 上限邏輯（帳戶 ≤3、持股 ≤5、單一投資市場）— **尚未做**
- [ ] **#10** 🟢 合規賣出規則（超額禁買入；只能全數賣清）— **尚未做**
- [ ] **#11** 🟢 模擬器測完整訂閱流程（購買 → 解鎖 → 恢復購買）— Paywall 可開，但 #8–#10 未完成時測試意義有限

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
✅ 已完成：#3–#7（Bundle ID、StoreKit、SubscriptionManager、Paywall）
👉 現在優先做：
1. 🟢 #8–#10  PlusFeatureGate + Free 上限 + 合規賣出（訂閱核心剩這塊）
2. 🟢 #11     模擬器完整訂閱流程（#8 做完後測）
3. 🟢 #15–#16 法律定稿 + 政策公開 URL（送審必備）
4. 🟠 #1      主流程回歸（含備份還原）
5. 🟡 #23–#26 （Developer Active 後當天必做）
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
- 新增持股／匯入 — 第 6 檔前攔截
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

### #11 模擬器測完整訂閱流程

**測試腳本**：

1. 確認 Scheme 已綁 `WalleafPlus.storekit`
2. 刪除模擬器上的 App → 重新 Run（乾淨狀態）
3. 設定 → Walleaf Plus → 選年訂 → 購買（StoreKit 測試對話框）
4. 確認備份／匯入／Face ID 可用
5. Xcode → **Debug → StoreKit → Manage Transactions** — 過期或退款測試
6. 確認過期後 Plus 功能關閉、資料仍在
7. 點「恢復購買」確認可恢復

**StoreKit 測試加速**（模擬器）：

- Debug → StoreKit → Time Rate → 選加速（例如 1 hour = 1 month）可快速測試續訂／過期

---

## 修訂紀錄

| 日期 | 說明 |
|------|------|
| 2026-05-31 | 進度更新：#4–#7 完成；#8–#10 未開始；#12–#13／#20–#22 已實作待驗收 |
| 2026-06-06 | 初版：整合審核等待期 + Active 後 checklist；#4 StoreKit 檔已加入 repo |
