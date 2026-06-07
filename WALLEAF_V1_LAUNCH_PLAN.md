# Walleaf v1.0 上架計劃（Free + Plus 首發）

> **目標**：App Store 首發即提供 Free 與 Walleaf Plus 訂閱，含 7 天試用。  
> **定價**：月訂 NT$60／年訂 NT$390（年訂約為月付 12 個月的 54%）  
> **規格詳情**：見 [`WALLEAF_PLUS_SUBSCRIPTION_SPEC.md`](WALLEAF_PLUS_SUBSCRIPTION_SPEC.md)

---

## 階段總覽

| 階段 | 目標 | 建議時間 |
|------|------|----------|
| **0. 定案** | 產品規則、定價、試用寫死 | ✅ 已完成（2026-06-06） |
| **1. 商店與法律** | Connect 商品、隱私權 URL、商店文案 | 與階段 2 並行，約 3～5 天 |
| **2. 訂閱核心** | StoreKit 2、entitlement、Paywall | 約 1 週 |
| **3. 功能 Gate** | Free 上限、合規賣出、Plus 功能鎖 | 約 1 週 |
| **4.  QA 與送審** | Sandbox 購買、TestFlight、審核備註 | 約 3～7 天 |

---

## 階段 0：已定案（不再討論 unless 改規格）

- [x] Free：3 檔、3 帳戶、單一投資市場、無備份／還原／匯入／Face ID
- [x] Plus：全解鎖
- [x] **試用**：7 天（Introductory Offer，月訂或年訂擇一或兩者皆設—Connect 設定）
- [x] **定價**：月 NT$60、年 NT$390
- [x] **超額合規**：僅允許**賣出**；且該檔必須**全數賣出**（不可部分賣）
- [x] **買入**：不合規時一律禁止
- [x] 帳戶 >3：舊帳可查看、可記帳；不可新增第 4 帳戶
- [x] 退訂：資料不刪；Plus 功能關；Face ID 自動關

---

## 階段 1：App Store Connect 與法律

### 1.1 App Store Connect

- [ ] 建立 **Subscription Group**（例：`walleaf_plus`）
- [ ] 商品 **月訂** Product ID（例：`walleaf.plus.monthly`）→ NT$60
- [ ] 商品 **年訂** Product ID（例：`walleaf.plus.yearly`）→ NT$390
- [ ] 兩商品皆設 **7 天免費試用**（Introductory Offer，新訂閱者）
- [ ] 訂閱本地化：繁中名稱、說明、權益列表（備份、匯入、無上限…）
- [ ] **Family Sharing**：關閉
- [ ] 準備 **審核用截圖**：Paywall、Plus 權益說明
- [ ] **App Review Information**：沙盒測試說明、如何觸發訂閱

### 1.2 法律與政策

- [ ] 潤飾 [`WALLEAF_LEGAL_DRAFT.md`](WALLEAF_LEGAL_DRAFT.md)（隱私權 + 服務條款 + 免責）
- [ ] 填寫：營運者、聯絡信箱、生效日期
- [ ] 部署至可公開 URL（GitHub Pages / 簡單官頁）
- [ ] Connect 填入 **Privacy Policy URL**
- [ ] 完成 **App 隱私問卷**（對照本機資料 + Supabase symbol／匿名 Auth）

### 1.3 商店 listing

- [ ] App 名稱、副標、描述（明確寫 Free 限制與 Plus 权益，**勿寫永久全免**）
- [ ] 關鍵字、分類、年齡分級
- [ ] 截圖 6.7" / 6.5"（首頁、管理、投資、備份、Paywall）
- [ ] 更新說明範本（首發版）

---

## 階段 2：iOS 訂閱核心

### 2.1 新模組

- [ ] `SubscriptionManager`（StoreKit 2）
  - [ ] 啟動時讀取 `Transaction.currentEntitlements`
  - [ ] 監聽 `Transaction.updates`
  - [ ] `purchase(productID)`、`restore()`
  - [ ] `@Published var isPlusActive: Bool`（含試用期間 = true）
  - [ ] 對外暴露月／年 `Product` 供 Paywall 顯示價格
- [ ] `PlusEntitlement` / `PlusFeatureGate` 單一入口
  - [ ] `isPlusActive` 快取與 UI 刷新
- [ ] `SubscriptionComplianceState`（Free 合規計算）
  - [ ] distinct 持股檔數
  - [ ] 帳戶總數
  - [ ] 投資市場種類數
  - [ ] `isOverFreeLimits: Bool`
  - [ ] `requiresFullLiquidationSell: Bool`（超額時）

### 2.2 Paywall UI

- [ ] 替換 Settings **Walleaf Plus** 卡片（移除「即將推出」）
- [ ] 月／年方案選擇、顯示試用 7 天文案
- [ ] **恢復購買**
- [ ] **管理訂閱**（`AppStore.showManageSubscriptions`）
- [ ] 可共用的 `PaywallSheet`（各 gate 觸發時彈出）

### 2.3 設定頁「關於與支援」（建議首發一併做）

- [ ] 聯絡我們（mailto）
- [ ] 隱私權政策、服務條款（Safari）
- [ ] 版本號
- [ ] 報價免責短句

---

## 階段 3：功能 Gate 與合規交易

### 3.1 Plus 功能鎖（非 Plus → Paywall）

| 入口 | 檔案／區域（待實作時對照） |
|------|---------------------------|
| 備份 | `SettingsView` backupExportRow |
| 還原 | `SettingsView` backupRestoreRow |
| 匯入 | `TransactionImportView`、相關入口 |
| Face ID 隱私鎖 | `SettingsView` privacyLockRow；退訂時 `PrivacyLockManager` 強制關閉 |

### 3.2 Free 上限（非 Plus 且未在試用）

| 規則 | 攔截點 |
|------|--------|
| 第 4 個帳戶 | `AddAccountView` 建立前 |
| 第 4 檔 distinct 持股 | 新增買入／匯入造成新標的前 |
| 第二種投資市場帳戶 | `AddAccountView` 選投資市場時 |

### 3.3 合規模式（`isOverFreeLimits == true`）

- [ ] **禁止所有買入**（含加碼、匯入新標的）
- [ ] **允許賣出**，但 UI 強制：
  - [ ] 數量 = 該標的**全部持有量**（不可改）
  - [ ] 隱藏或停用部分賣出、百分比賣出
  - [ ] 賣單文案：「合規清倉須一次賣出全部持股」
- [ ] 混合市場：須賣到 ≤3 檔且**單一市場**；必要時引導「請先賣清某市場全部持股」
- [ ] 帳戶 >3：既有帳戶仍可記帳；不可新增帳戶
- [ ] 首頁／列表顯示**合規狀態橫幅**（可選但強烈建議）

### 3.4 試用期

- [ ] StoreKit intro offer 生效期間 `isPlusActive == true`
- [ ] 試用結束未付費 → 立即套用 Free + 合規檢查
- [ ] 試用期間若已超 Free 上限，結束後進入合規賣出模式

---

## 階段 4：測試

### 4.1 Sandbox 訂閱測試

- [ ] 新 Sandbox 帳號：訂閱月方案 + 7 天試用
- [ ] 試用中：備份、匯入、Face ID、超過 3 檔
- [ ] 取消訂閱／試用結束：Plus 關閉、Face ID 關、備份導向 paywall
- [ ] 超 3 檔後：只能全數賣出、不能買入、不能部分賣
- [ ] 賣至合規後：恢復正常 Free 買賣（仍受 3 檔／3 帳戶／單市場限制）
- [ ] **恢復購買**（刪 App 重裝）
- [ ] 年訂方案購買路徑

### 4.2 回歸測試

- [ ] 示範模式不受訂閱影響（或明確排除）
- [ ] 備份還原後 entitlement 仍依 Apple ID
- [ ] 離線時 entitlement 快取行為

### 4.3 TestFlight

- [ ] 內部測試 1～2 週
- [ ] 收集：Paywall 理解度、合規賣出 UX

---

## 階段 5：送審

- [ ] Archive + Upload
- [ ] 審核備註：訂閱測試步驟、沙盒帳號、Free 仍可使用之功能
- [ ] 確認無外部付款連結
- [ ] 首發版本號（建議 1.0.0）

---

## 建議 Product ID 命名（實作時統一）

```
walleaf.plus.monthly   → NT$60/月，7 天試用
walleaf.plus.yearly    → NT$390/年，7 天試用
```

---

## 風險與注意

| 風險 | 緩解 |
|------|------|
| 合規「全數賣出」UX 難懂 | 賣出頁預填全量 + 說明橫幅 + 使用教學補充 |
| 試用結束突然鎖功能 | 試用剩 1 天 in-app 提醒（可 v1.0.1） |
| 審核訂閱退件 | Paywall 價格／續訂說明／Restore 齊全 |
| 年訂試用後自動扣 NT$390 | Paywall 明確寫「試用結束後以 NT$390/年計費」 |

---

## 完成定義（v1.0 Done）

- [ ] App Store **已上架**
- [ ] Free 使用者可完整記帳（在限制內）
- [ ] Plus 可訂閱、試用、恢復、管理
- [ ] 所有 Plus gate 與合規賣出邏輯上線
- [ ] 隱私權 URL 可開、App 內可達

---

*計劃版本：2026-06-06*
