# Snapvest UI 顏色對照表

以下所有顏色定義集中在 `AppColors`（`Snapvest/Snapvest/Utilities/ColorTheme.swift`）。
實際色值依 `ThemePalette`（`ThemePalette.swift`）的 **淺色 `.light`** / **深色 `.dark`** 兩套，由 `ThemeManager` 切換。
`Color.*` 僅作為相容入口，實際色值以當前主題的 `AppColors` 為準。

## 配色盤（14 色）
- `AppColors.blue1`：最深藍
- `AppColors.blue2`：深藍
- `AppColors.blue3`：中深藍
- `AppColors.blue4`：中藍
- `AppColors.blueGreen1`：藍綠 1
- `AppColors.blueGreen2`：藍綠 2
- `AppColors.blueGreen3`：藍綠 3
- `AppColors.blueGreen4`：藍綠 4
- `AppColors.green1`：淺青綠
- `AppColors.green2`：中青綠
- `AppColors.green3`：深青綠
- `AppColors.green4`：深綠
- `AppColors.green5`：最深綠
- `AppColors.bluePale`：極淺藍（背景用）

## 全局主色
- `AppColors.appPrimary`：主要交互色（按鈕、重點圖示）
- `AppColors.appSecondary`：次要交互色（輔助元素）

## 背景與卡片
- `AppColors.mainBackground`：主畫面背景
- `AppColors.cardBackground`：卡片背景
- `AppColors.secondaryBackground`：次要區塊背景
- `AppColors.tertiaryBackground`：第三級背景

## 文字層級
- `AppColors.primaryText`：主要文字
- `AppColors.secondaryText`：次要文字
- `AppColors.tertiaryText`：輔助文字

## 分隔與邊框
- `AppColors.separator`：分隔線
- `AppColors.borderLight`：輕邊框
- `AppColors.strokeSubtle`：淡描邊（細線）
- `AppColors.strokeMuted`：弱描邊（卡片/選取）

## 漲跌幅狀態
- `AppColors.profitGreen`：獲利/正向
- `AppColors.lossRed`：虧損/負向

## 資產與帳戶類型
- `AppColors.stockTWColor`：台股類別色
- `AppColors.stockTWDeepBlue`：台股文字/數字色
- `AppColors.stockUSColor`：美股類別色
- `AppColors.stockUSDeepGreen`：美股文字/數字色
- `AppColors.stockUSDeepPurple`：美金帳戶色
- `AppColors.cryptoColor`：加密貨幣類別色
- `AppColors.cryptoDeepBrown`：加密貨幣文字/數字色

## 圖表
- `AppColors.pieChartColors`：圓餅圖預設輪播色
- `AppColors.placeholderFill`：圖表佔位/空狀態填色

## 互動/狀態
- `AppColors.disabledBackground`：停用按鈕背景
- `AppColors.disabledForeground`：停用文字
- `AppColors.overlayDark`：深色遮罩

## 按鈕與操作
- `AppColors.noticeForeground`：提示文字（如「交易紀錄」）
- `AppColors.noticeBackground`：提示背景
- `AppColors.actionEditBackground`：編輯動作背景
- `AppColors.actionDestructiveBackground`：刪除/危險動作背景
- `AppColors.actionForeground`：動作按鈕文字（白字）
- `AppColors.chipBackground`：小標籤/膠囊背景

## 陰影
- `AppColors.shadowLow`：非常淺陰影
- `AppColors.shadowMedium`：一般陰影
- `AppColors.shadowSoft`：柔和陰影
- `AppColors.shadowCard`：卡片陰影
- `AppColors.shadowHigh`：較強陰影
