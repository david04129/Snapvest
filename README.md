# Snapvest - 資產管理 App

一個功能完整的資產管理應用程式，支援台股、美股、加密貨幣和匯率管理。

## 功能特色

- 📊 **總覽儀表板**：總資產、負債、現金、投資比例、損益分析
- 💼 **多帳戶管理**：支援多個投資帳戶
- 📈 **多資產類型**：台股、美股、加密貨幣
- 💱 **多幣別支援**：台幣/原幣視角切換
- 📉 **視覺化圖表**：圓餅圖、炫風圖、走勢圖（開發中）
- 📝 **交易管理**：完整的交易流水紀錄
- 📸 **快照系統**：資產歷史快照與走勢分析

## 技術架構

- **前端**：Swift + SwiftUI
- **後端**：Firebase / Supabase（待整合）
- **API 資料來源**：
  - 台股：yfinance API
  - 美股：yfinance API / Alpha Vantage
  - 加密貨幣：CoinGecko API
  - 匯率：ExchangeRate-API

## 專案結構

```
Snapvest/
├── Snapvest/
│   ├── Models/          # 資料模型
│   ├── Views/           # SwiftUI 視圖
│   ├── ViewModels/      # 視圖模型
│   ├── Services/        # 服務層（API、資料庫）
│   ├── Utilities/       # 工具類
│   └── Resources/       # 資源文件
├── SnapvestTests/       # 單元測試
└── README.md
```

## 開發進度

- [x] 專案結構設計
- [x] 資料模型定義
- [x] 資料庫 Schema 設計
- [x] 資料服務層（Mock 實作）
- [x] 總覽面板 UI
- [x] 帳戶管理功能
- [x] 交易管理功能
- [x] 持股計算邏輯（重播交易）
- [ ] 圓餅圖視覺化（使用 Charts 框架）
- [ ] 走勢圖視覺化
- [ ] 炫風圖視覺化
- [ ] Firebase/Supabase 後端整合
- [ ] API 服務實現
- [ ] 股票代碼搜尋/自動完成
- [ ] 測試與優化
- [ ] App Store 上架

## 使用說明

### 開發環境需求
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### 安裝步驟
1. 開啟 `Snapvest.xcodeproj`
2. 選擇目標裝置或模擬器
3. 執行專案（⌘R）

### 後端整合（待實作）
1. 建立 Supabase 專案
2. 執行 `DATABASE_SCHEMA.md` 中的 SQL 語句
3. 更新 `DataService` 實作，替換 `MockDataService`

## 授權

版權所有 © 2024

