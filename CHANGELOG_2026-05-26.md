# 變更記錄 - 2026/05/26

> 今日重點：調整餘額 `≈ NT$` 換算 UX、交易表單幣別 badge、DB 即時匯率取代寫死 32。

**最新 commit：** `45b2453`  
**上一版 commit：** `341ffec`（每日快照 00:05 + 個股／帳戶持股 UI）

---

## 備份分支對照

| 備份分支 | 指向 commit | 說明 |
|----------|-------------|------|
| `backup/snapshot-20260526-pre-adjust-balance-twd-094839` | `341ffec` | **本次改動前**（調整餘額台幣 hint、交易幣別 badge 尚未合入） |

### 更早的備份（參考）

| 備份分支 | 指向 commit | 說明 |
|----------|-------------|------|
| `backup/snapshot-20260526-pre-eod-snapshot-091845` | （較早） | EOD 快照 00:05 改動前 |
| `backup/snapshot-20260525-pre-trade-refactor-230153` | （較早） | 大 refactor（移除轉帳、賣出修復）前 |

---

## Commit `45b2453` 改動摘要

### 1. 調整餘額（`AdjustCashBalanceView.swift`）

| 項目 | 改前 | 改後 |
|------|------|------|
| 台幣換算位置 | 左側「將新增收入」下方小字 | **右側美金金額 `$50.00` 正下方** |
| 文案格式 | `≈ 1,600`（caption） | **`≈ NT$1,600`（subheadline）** |
| 匯率來源 | 寫死 `32` | `ExchangeRateSessionCache` → DB `fetchExchangeRate` → 帳戶詳情匯率 |
| 新餘額標題 | `新餘額 (USD)` | `新餘額（美金）` + **USD badge** |

### 2. 交易表單幣別標示（共用元件）

**檔案：** `TradeFormShared.swift`（新增）

- `TradeFormUnitPriceLabels` — 買／賣價列標題（台股台幣、美股／加密美金）
- `TradeFormMoneyLabels` — 餘額列標題（台幣／美金）
- `TradeFormCurrencyBadge` — TWD / USD 小 badge
- `TradeFormUnitPriceInput` — 單價輸入 + badge

**套用至：**

- `BuyTradeFormView.swift` — 每股買價列
- `SellTradeFormView.swift` — 每股賣價列
- `AdjustCashBalanceView.swift` — 新餘額列

---

## 尚未改動（後續可接）

以下仍使用寫死 `32` 或 error fallback `32.00`，**不在本次 commit**：

| 檔案 | 現況 |
|------|------|
| `IncomeView.swift` | `usdToTwdRate = 32` |
| `ExpenseView.swift` | 同上 |
| `CashFlowView.swift` | 同上 |
| `BuyTradeFormView.swift` | API 失敗 fallback `32.00` |
| `SellTradeFormView.swift` | 同上 |
| `AccountDetailViewModel.swift` | 初始值 `exchangeRate = 32` |
| `HoldingDetailView.swift` | `?? 32` fallback |

---

## 還原方式

```bash
# 還原到本次改動前（保留工作區可再 git stash）
git checkout backup/snapshot-20260526-pre-adjust-balance-twd-094839

# 或只 revert 這次 commit
git revert 45b2453
```
