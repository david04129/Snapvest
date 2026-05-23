# Snapvest UI 顏色對照表（方向 A：沉穩理財）

色值定義在 `Snapvest/Snapvest/Utilities/ThemePalette.swift`（`.light` / `.dark`）。  
`AppColors`（`ColorTheme.swift`）為唯一取用入口；`Color.*` 僅相容舊呼叫。  
切換主題：`ThemeManager` + `ThemeToggleButton`。

## 設計原則

1. **品牌主色**（`appPrimary` 青綠 `#0F766E`）≠ 美股藍，用於 Tab、按鈕、選中 chip。  
2. **三類資產**同屏可辨識但不搶戲：台股琥珀、美股藍、加密青綠。  
3. **圓餅五段**（`allocation*`）與三類資產色一致，不再出現「列表金黃、圓餅粉紅台股」。  
4. **漲跌**固定用 `profitGreen` / `lossRed`，不混用資產色。

## 品牌與全局

| Token | 淺色 | 用途 |
|-------|------|------|
| `appPrimary` | `#0F766E` | 主要交互、Tab tint、選中狀態 |
| `appSecondary` | `#0D9488` | 次要強調 |
| `mainBackground` | `#F4F6F8` | 主畫面背景（暖灰） |
| `cardBackground` | `#FFFFFF` | 卡片 |
| `primaryText` | `#111827` | 主文字 |
| `secondaryText` | `#64748B` | 次文字 |

## 資產類別（列表、三格摘要、持股色條）

| Token | 淺色 | 類別 |
|-------|------|------|
| `stockTWColor` | `#D97706` | 台股區塊／圖示 |
| `stockTWDeepAmber` | `#B45309` | 台股數字強調 |
| `stockUSColor` | `#2563EB` | 美股區塊／圖示 |
| `stockUSDeep` | `#1D4ED8` | 美股數字強調 |
| `cryptoColor` | `#0D9488` | 加密區塊／圖示 |
| `cryptoDeep` | `#0F766E` | 加密數字強調 |

相容別名（請新程式改用上表）：`stockTWDeepBlue` → `stockTWDeepAmber`；`stockUSDeepPurple` → `stockUSDeep`；`cryptoDeepBrown` → `cryptoDeep`。

## 首頁圓餅圖（總資產五段）

| Token | 淺色 | 區塊 |
|-------|------|------|
| `allocationTwdCash` | `#059669` | 台幣現金 |
| `allocationUsdCash` | `#34D399` | 美金現金 |
| `allocationStockTW` | `#D97706` | 台股（= `stockTWColor`） |
| `allocationStockUS` | `#2563EB` | 美股（= `stockUSColor`） |
| `allocationCrypto` | `#0D9488` | 加密（= `cryptoColor`） |

## 圖表輔助

| Token | 用途 |
|-------|------|
| `pieChartTWColors` / `pieChartUSColors` / `pieChartCryptoColors` | 同類持倉多檔時的色階 |
| `pieChartVibrantColors` | 細項模式輪播 |
| `profitGreen` / `lossRed` | 損益正負 |

## 深色模式

同一語意，提高亮度與對比；詳見 `ThemePalette.dark`。
