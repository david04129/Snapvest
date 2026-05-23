# 變更記錄 - 2026/05/20

> 今日重點：首頁圖表、開機流程、主題色／深色模式。後端股價批次與 Supabase 相關改動見工作區其他未提交檔案。

---

## 一、首頁圖表（圓餅圖 + 績效炫風圖）

### 位置調整

| 改動 | 說明 |
|------|------|
| **首頁** | `HomeView` 在已實現損益卡片下方新增圓餅圖、績效圖區塊 |
| **資產分頁** | `AssetsView` 移除投資組合圓餅圖區塊（改由首頁呈現） |

### 新增檔案

| 檔案 | 說明 |
|------|------|
| `Views/PortfolioAllocationChartView.swift` | 圓餅圖 UI、`PieChartDisplayMode`、`PortfolioPieChartBuilder` |
| `Views/HomePerformanceChartView.swift` | 績效炫風圖（損益金額 / 報酬率） |
| `Services/PieChartDataLoader.swift` | 載入圓餅圖／績效圖所需 `PieChartInputs` |
| `Services/HoldingChartMetrics.swift` | 持股市值、未實現損益、績效列共用計算 |

### 圓餅圖行為

- 標題「圓餅圖」，分段：**總資產 | 投資組合 | 所有細項**
- **總資產**：台幣現金、美金現金、美股、台股、加密（五段）
- **投資組合**：各檔持股（不含現金）
- **所有細項**：現金 + 各檔持股
- 細環甜甜圈、中心顯示選中項名稱與占比、圖例可點選連動
- **預設模式**：總資產

### 績效圖行為

- 標題「績效圖」，分段：**損益金額 | 報酬率**
- 僅持股、不含現金；依獲利排序（炫風圖由中心向左右延伸）
- **預設模式**：損益金額

### ViewModel

- `PortfolioViewModel` 新增 `@Published pieChartInputs`、`refreshPieChartData(userId:)`
- `ensureHomeSnapshot` / `loadData` 結尾會刷新圖表資料

---

## 二、圖表切換 UI 與動畫

| 檔案 | 說明 |
|------|------|
| `Views/ChartSegmentedControl.swift` | 自訂分段控制：選中項主色底 + 滑動高亮（取代系統 `Picker.segmented`） |
| `Utilities/ChartMotion.swift` | 圖表切換 spring 動畫參數 |
| 標題副標 | 「圓餅圖 · 總資產」「績效圖 · 損益金額」等，隨模式更新 |

### 動畫

- 切換模式時：內容淡入／微縮放、長條寬度 spring、數字 `contentTransition`
- **注意**：Swift Charts 無 `.chartAnimation`，已移除；扇區改靠 `animation(value: displayMode)`

### 編譯修正

- `ChartSegmentedControl` 參數順序須為 `options` → `selection` → `label`

---

## 三、開機流程（Logo → Ready 後進首頁）

| 檔案 | 說明 |
|------|------|
| `Views/AppRootView.swift` | App 根畫面：啟動時只顯示 Splash，資料 ready 後才建立 `ContentView` |
| `Views/LaunchSplashView.swift` | 僅 Logo 淡入 + 輕微呼吸（無轉圈、無載入文案） |
| `SnapvestApp.swift` | 改為啟動 `AppRootView` |
| `HomeView.swift` | 改用 `@EnvironmentObject` 共用 `PortfolioViewModel`；移除進頁重複 `.task` / `.onAppear` 載入 |

### Ready 定義

`ensureHomeSnapshot` 完成（首頁快照 + `pieChartInputs`），再顯示主 Tab，避免首頁短暫出現「—」與 0.0%。

---

## 四、主題色與深色模式

| 檔案 | 說明 |
|------|------|
| `Utilities/ThemePalette.swift` | 淺色 `.light`（原配色）、深色 `.dark` 兩套色票 |
| `Utilities/ThemeManager.swift` | 切換狀態、`UserDefaults` 持久化 |
| `Utilities/ColorTheme.swift` | `AppColors` 改為讀取目前 palette |
| `Views/ThemeToggleButton.swift` | 月亮／太陽切換按鈕 |
| `THEME_TOKENS.md` | 補充雙主題說明 |

### 使用方式

- 首頁標題列右側（頭像左）：點擊切換淺色／深色
- 切換時以 `.id(isDarkMode)` 重繪整 App 色票
- 深色：背景 `#0B1220`、卡片 `#1E293B`、主色 `#38BDF8` 等

### 討論紀錄（未改配色，僅建議）

- 曾討論「沉穩理財 / FinTech / 深色」等配色方向，**尚未**替換淺色預設色票
- 少數畫面仍有硬編碼 `.red` / `Color(hex:)`，深色下可能不完全一致

---

## 五、後端／股價（工作區相關，同日或鄰近開發）

> 以下檔案多為未提交狀態，與今日 UI 並行開發時可一併參考。

| 項目 | 說明 |
|------|------|
| `backend/scripts/daily_price_update_batch.py` | 每日批次更新 `asset_price_snapshots` |
| `previous_price_date` 邏輯 | 成功更新時：`previous_*` ← 舊的 `current_*`，`current_*` ← 本次 |
| `fetch-or-create-price/index.ts` | Edge Function 取價流程調整 |
| `003_exchange_rates.sql` | 匯率表 migration |
| `SupabasePriceService.swift` | App 端讀取快照、顯示價與日期 |
| Schema 簡化 | 曾討論 `status` / `failed_at`，**決定維持現有 schema 不變** |

---

## 六、新建檔案清單（今日 UI／主題）

```
Snapvest/Snapvest/Utilities/ChartMotion.swift
Snapvest/Snapvest/Utilities/ThemeManager.swift
Snapvest/Snapvest/Utilities/ThemePalette.swift
Snapvest/Snapvest/Services/HoldingChartMetrics.swift
Snapvest/Snapvest/Services/PieChartDataLoader.swift
Snapvest/Snapvest/Views/AppRootView.swift
Snapvest/Snapvest/Views/ChartSegmentedControl.swift
Snapvest/Snapvest/Views/HomePerformanceChartView.swift
Snapvest/Snapvest/Views/LaunchSplashView.swift
Snapvest/Snapvest/Views/PortfolioAllocationChartView.swift
Snapvest/Snapvest/Views/ThemeToggleButton.swift
```

---

## 七、待續（改天可接）

- [ ] 今日損益卡片仍為 placeholder（固定 0），需接真實計算
- [ ] 開機／載入時圓環 0.0% 與「—」不同步問題（已由 Splash 緩解，可再統一 loading UI）
- [ ] 散落硬編碼顏色收斂至 `AppColors`
- [ ] 淺色主題配色改版（方向 A/B 擇一後改 `ThemePalette.light`）
- [ ] `daily_price_update_batch.py` 若本地僅 1 行需確認是否誤刪
- [ ] 股價 `previous_price_date` 與同日重跑仍相同時的除錯（若仍發生）

---

## 八、測試提醒

1. **iOS**：Xcode Clean Build → Run；試首頁圖表切換、開機 Splash、深色切換
2. **主題**：切深色後切換分頁，確認卡片與 Tab 色一致
3. **後端**：若改批次腳本，需手動跑 `daily_price_update_batch.py` 或 GitHub Action 驗證 Supabase 快照
