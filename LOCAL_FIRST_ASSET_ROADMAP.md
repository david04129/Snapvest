# Walleaf Local-First Asset Roadmap

本文件記錄 Walleaf 後續資料架構方向：使用者完整資產資料保存在手機本機，後端只提供公開市場資料。

## 核心原則

- 使用者的帳戶、持股、成本、現金、負債、手動資產、每日資產快照都應保存在手機本機。
- 後端 DB 只保存公開市場資料，例如股價、ETF 價格、加密貨幣價格、匯率、市場資料更新時間，以及匿名化 symbol tracking。
- 後端不應長期保存使用者持股數量、成本、現金、負債、每日淨資產或 user_id 對應的資產明細。
- 補齊走勢圖缺失日期後，結果要寫回手機本機，避免下次開 App 重算相同區間。
- iCloud 備份應使用使用者自己的 iCloud，不進 Walleaf DB。
- 使用者可選擇「主要幣別」，App 仍保留原幣資訊，但總覽、台幣切換按鈕與本機 daily snapshots 應改以主要幣別呈現。
- 選擇主要幣別後，首頁淨資產、總資產、現金、投資、負債、走勢圖、帳戶頁總額與資產頁總額，都應以主要幣別顯示；「原幣」仍顯示資產或帳戶自己的幣別。
- 後端匯率維持抓各幣別對 TWD 的公開匯率；App 以 TWD 作為 pivot，在手機本機計算任意兩個幣別的交叉匯率。
- 現金帳戶不併入手動資產；現金有收入、支出、轉帳與交易扣款行為，應維持為獨立帳戶模型。

## 建議 Phase

### Phase 1: 幣別與帳戶模型基礎

目標：先把幣別與帳戶類型整理成後續資產模型與 daily snapshot 的地基，避免手動資產和走勢圖後續重工。

帳戶類型建議收斂為：

- 現金帳戶
- 台股證券
- 美股證券
- 加密貨幣錢包
- 其他資產
- 分期貸款
- 其他貸款

幣別設計：

- 支援使用者在「更多」中設定主要幣別。
- 主要幣別預設為 TWD，但可選 TWD、USD、AUD、JPY、EUR、HKD、CNY 等。
- AUD（澳幣 / 澳洲）需出現在可選幣別 UI。
- 原幣顯示仍保留各帳戶或資產自己的幣別。
- 原本 UI 的「台幣」切換應改為「主要幣別」切換，文字顯示目前主要幣別名稱。
- 主要幣別套用範圍包含首頁卡片、首頁走勢圖、帳戶頁總額、資產頁總額、持股明細的主要幣別顯示、分享圖中的主要幣別數字。
- 匯率換算公式：`amountInTarget = amount * TWD_per_fromCurrency / TWD_per_targetCurrency`；TWD 自己的 `TWD_per_TWD = 1`。

帳戶與資產限制：

- 現金帳戶可選幣別，代表該帳戶的現金單位。
- 台股證券只支援台股 / 台股 ETF / 台股債券 ETF，帳戶幣別固定 TWD。
- 美股證券只支援美股 / 美股 ETF，帳戶幣別可選，交易時依標的原幣與帳戶幣別記錄匯率。
- 加密貨幣錢包只支援加密貨幣，帳戶幣別可選，作為帳戶估值或交易現金基準。
- 不再用「複委託」作為使用者可見分類；複委託情境由「美股證券 + 帳戶幣別」自然涵蓋。

技術整理：

- 新增或整理 `UserBaseCurrencyPreference`。
- 建立 `CurrencyConversionService`，讓畫面不要直接寫死 USD/TWD 或 TWD。
- 逐步將 `TWD` / `台幣` 命名改為 base currency / 主要幣別。

### Phase 2: 手動資產資料模型

目標：先補齊資產世界觀，再重做走勢圖，避免未來重工。

新增或整理本機資料結構：

- `ManualAsset`
- `ManualAssetCategory`
- `ManualAssetValuation`
- `ManualAssetStore`

建議類別：

- 基金
- 債券
- 房地產
- 保單
- 收藏品
- 貴金屬
- 退休金
- 私募 / 股權
- 員工股票 / 選擇權
- 應收款
- 其他

每個手動資產建議欄位：

- 名稱
- 類別
- 幣別
- 目前估值
- 成本 / 投入金額
- 購入日期
- 備註
- 是否納入總資產
- 最後更新日期

每次使用者更新估值時，寫入 `ManualAssetValuation`，供走勢圖與歷史估值使用。

### Phase 3: 手動資產 MVP UI

目標：讓使用者能新增、編輯、刪除手動資產。

建議介面：

- 帳戶頁新增「其他資產」入口。
- 其他資產頁顯示手動資產清單。
- 新增資產時選類別、幣別、估值、成本與備註。
- 編輯估值時寫入 valuation history。
- 支援是否納入總資產。

第一版先整合到：

- 帳戶頁
- 資產頁
- 首頁總資產數字

### Phase 4: 本機 Daily Snapshot v2

目標：建立可以涵蓋所有資產類型的每日快照格式。

新增或整理：

- `LocalPortfolioDailySnapshot`
- `LocalPortfolioDailySnapshotStore`
- `PortfolioDailySnapshotBuilder`

每日 snapshot 應包含：

- date
- totalAssets
- totalLiabilities
- netWorth
- totalCash
- totalInvestments
- manualAssetsValue
- unrealizedGainLoss
- breakdown by asset category
- baseCurrency
- original currency breakdown（供原幣 / 主要幣別切換）
- price / exchange rate source updatedAt（供除錯）

### Phase 5: 走勢圖改讀本機 Snapshots

目標：首頁走勢圖只讀手機本機的 daily trend snapshots，不再讀 Supabase `user_daily_snapshots`。

做法：

- 歷史走勢讀本機 `LocalDailyTrendSnapshot` / `dailyTrendSnapshotsByDate`。
- `HomeDashboardSnapshot` 是首頁即時總覽來源；每次首頁快照更新後，覆蓋寫入今天的 daily trend snapshot。
- 首頁走勢圖只負責讀本機 daily trend snapshots，不在畫面層合併 Supabase 或 live snapshot。
- 不使用 Supabase `user_daily_snapshots` fallback；若未來需要匯入舊走勢，應由使用者主動透過 CSV、備份包或本機重算匯入。
- 走勢圖數值以使用者主要幣別呈現；必要時保留原幣細節在明細頁。

### Phase 6: 補齊中間空白日期

目標：使用者幾天沒開 App，走勢圖仍連續，且補出的點持久化在手機。

第一天使用：

- 若本機沒有任何既有 daily trend snapshot，代表使用者第一次使用或走勢資料被清空。
- 此時只建立今天點；不補昨天、不補中間點，因為 App 沒有可推回前一日的本機帳本狀態。
- 除非未來支援使用者主動匯入過往走勢點（例如 CSV 或備份包），否則第一天走勢圖從今天開始。

快速補點路徑：

- 檢查本機 daily snapshots 最後一筆日期。
- 若中間缺日期且沒有本機歷史資料變動：
  - 視為使用者在缺口期間未使用 App，因此持股數量、現金、負債、手動資產估值與成本狀態維持不變。
  - 唯一需要補的是中間日期的公開股價、加密價格與匯率。
  - 使用最後一次已知帳本狀態，搭配缺失日期的股價與匯率，算出每天的走勢點。
  - 手動資產沿用最後估值，除非 valuation history 有新的估值。
  - 使用該日匯率換算到使用者主要幣別。
  - 算出每天 snapshot。
  - 寫入手機本機 store。

每天第一次登入：

- 應檢查並補 / 更新昨天的日終走勢點。
- 原因：使用者昨天即使有開 App，今天點不一定代表昨天 23:59 或收盤後價格。
- 昨天點應以昨天帳本狀態 + 昨天收盤價 / 參考價格 + 昨天匯率重算後覆蓋本機 daily trend snapshot。

補點資料來源：

- App 本機保存使用者自己的帳本狀態與持股數量。
- 後端只提供公開市場資料：symbol 的歷史價格與匯率。
- App 不應把使用者 daily snapshots、持股數量、成本或淨資產送到後端。

區間重算路徑：

- 新增 / 修改 / 刪除過去日期交易。
- 匯入歷史交易。
- 修改過去日期現金紀錄。
- 修改手動資產過去估值。
- 修改負債 / 還款的過去日期資料。

只有上述情境才從受影響日期開始重算區間。

### Phase 7: 後端隱私化

目標：後端只保存公開市場資料，不保存使用者資產明細。

工作：

- 停止呼叫 `syncPortfolioState`。
- 停止寫 `user_portfolio_state`。
- 停止讀 `user_daily_snapshots` 作為主走勢來源。
- 新增或調整匿名 `tracked_symbols` 大池子。
- App 新增持股時，只提交 asset type + symbol，讓後端知道全站有人需要追蹤這檔公開標的。
- `tracked_symbols` 是全 App 共用池，不記錄哪個使用者加入，不提交 user_id、device id、account id、quantity、cost、交易日期或帳戶資訊。
- 一旦大池子加入某檔標的，後端之後每日抓取該標的收盤價或參考價，供所有使用者本機補點使用。
- 建議欄位只包含非個資資料，例如 `asset_type`、`symbol`、`normalized_symbol`、`first_seen_at`、`last_price_synced_at`、`is_active`。
- 需避免保留「誰加入此 symbol」的 audit log；極冷門標的仍可能有匿名池的殘餘推測風險，但後端不能知道持有人、數量、成本或淨資產。
- 後端匯率資料需支援主要幣別換算；可用 TWD 或 USD 作為 pivot，在 App 本機計算交叉匯率。

### Phase 8: iCloud 備份

目標：讓使用者可把本機資料備份到自己的 iCloud。

建議備份包：

- accounts
- transactions
- liabilities
- manual assets
- manual asset valuations
- daily snapshots
- preferences
- base currency preference
- schemaVersion

不備份：

- 股價快取
- 匯率快取
- session cache
- demo data

第一版建議先做 iCloud Drive 備份包，不先做 CloudKit 即時同步。

## 推薦順序

1. 幣別與帳戶模型基礎
2. 手動資產資料模型
3. 手動資產 MVP UI
4. 本機 Daily Snapshot v2
5. 走勢圖改讀本機 snapshots
6. 補齊中間空白日期並持久化
7. 後端隱私化
8. iCloud 備份

原因：主要幣別與帳戶模型會影響手動資產、估值、每日快照、走勢圖與 UI 文案，因此要先處理；手動資產會影響總資產、分類、每日快照與走勢圖，因此應先納入資料模型，再重做走勢圖。
