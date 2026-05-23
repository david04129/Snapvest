# Snapvest 上架後營運監控檢查清單

> 用途：App 上架後定期 review 成本、流量與穩定性。  
> 建議頻率：**上線第 1～2 週每週看一次**，之後改**每月**（或 Supabase 告警觸發時立即看）。  
> 最後更新：2026-05-23

---

## 1. 架構速記（review 時對照）

| 路徑 | 觸發時機 | 打 Supabase | 打外部股價 API |
|------|----------|-------------|----------------|
| **排程** `daily_price_update.py` | 見下方排程表 | 寫入 `asset_price_snapshots`、`exchange_rates` | Yahoo、CoinGecko、open.er-api.com |
| **App 讀價** `fetchPrices` | 冷啟動／DB 有更新 | 讀 `price_update_metadata` + `asset_price_snapshots` | 否 |
| **補價** `fetch-or-create-price` | DB 無該檔價格 | 讀+寫 snapshots、寫 `hot_stocks` | Finnhub*、TWSE、Yahoo、CoinGecko |

\* Finnhub 僅在 Edge Function 設定了 `FINNHUB_API_KEY` 時啟用。

**排程（台灣時間）：**

| 時間 | 星期 | 內容 |
|------|------|------|
| 16:00 | 週一～五 | 匯率 + 台股 + 加密 |
| 16:00 | 週六、日 | 僅加密 |
| 07:00 | 週二～六 | 僅美股 |

更新對象：**`holdings` ∪ `hot_stocks`**（不是 Top 500 全表）。

---

## 2. Supabase Dashboard 要看哪裡

路徑（介面可能隨版本微調）：**Project → Reports / Observability / Logs**

| 指標 | 在哪裡看 | 備註 |
|------|----------|------|
| **REST / API 請求數** | API reports | App 冷啟動、讀價、匯率 |
| **Egress（出站流量）** | Usage / Billing | 回應 JSON 累積；持倉多、欄位多會變大 |
| **Edge Function 呼叫數** | Functions metrics | `fetch-or-create-price` 補價 |
| **Edge Function 錯誤率** | Functions logs | 404、429（限流） |
| **Database 大小** | Database / Usage | snapshots、transactions 成長 |
| **Auth MAU** | Auth | 與 API 請求量相關 |

建議在 Supabase **設用量／預算提醒**（若方案支援），避免月底才發現超標。

---

## 3. 粗算：冷啟動讀 DB（心裡有數即可）

假設：

- 每人持倉 **N** 檔（跨台股／美股／加密）
- 每天**完全關掉 App 再開** **F** 次
- 每次冷啟動約 **2～4** 次 REST（metadata + 依 `asset_type` 批量 `in` 查詢）

**約 REST 次數／天 ≈ 活躍使用者 × F × 3**（取中間值 3）

| 日活 (DAU) | F=3, 每人 20 檔 | 約 REST/天 |
|------------|-----------------|------------|
| 50 | — | ~450 |
| 500 | — | ~4,500 |
| 5,000 | — | ~45,000 |

此表**不含**：補價 Edge Function、匯率讀取、其他業務 API（交易、帳戶等）。  
用途：**趨勢判斷**，非精確帳單。

---

## 4. 門檻建議：何時「只要看」、何時「要動手」

依 indie / 小型理財 App 經驗值；請對照你**實際方案上限**調整。

### 🟢 正常（維持監控即可）

- REST / egress 遠低於方案上限，曲線隨 DAU 線性成長
- Edge Function 錯誤率 < 1%，429 偶發
- 排程 GitHub Actions 每日成功（綠勾）
- 使用者回報「股價 --」集中在**新標的**或**冷門加密**

### 🟡 注意（下次 review 要討論優化）

| 現象 | 可能原因 | 待辦（見 §6） |
|------|----------|----------------|
| egress 連續兩週明顯上升 | DAU 增、持倉變多、`select=*` 拉大 | 磁碟快取、精簡 select |
| Edge Function 呼叫數 >> DAU × 5 | 每檔 `fetchCurrentPrice`、DB 常缺價 | 批量讀、減少逐檔補價 |
| `hot_stocks` 列數持續膨脹 | 每補價都進表、從未清理 | 清理策略 |
| CoinGecko 429 變多 | 排程 + 補價超免費額度 | Pro / 拉長間隔 / 減 hot |
| 排程 job 常 > 10 分鐘 | 持倉+hot 太多 | 分批、拆 job |

### 🔴 應處理（優先）

- 單日 Edge Function 錯誤率 > 5% 或大量 500
- 排程連續失敗 ≥ 2 天（股價全面過期）
- 用量預警／帳單接近方案上限
- 安全：RLS 異常、anon key 外洩疑慮

---

## 5. 定期 Review 紀錄表（複製填寫）

```markdown
### Review：YYYY-MM-DD
- DAU（估）：___
- Supabase REST（7 日）：___
- Egress（7 日）：___ MB
- Edge Function 呼叫（7 日）：___
- hot_stocks 列數：___
- holdings 涉及標的數（估）：___
- GitHub Actions 排程：✅ / ❌
- 本週使用者回報股價問題：有 / 無 — 說明：___
- 燈號：🟢 / 🟡 / 🔴
- 決議：維持 / 排入優化 / 立即處理 — ___
```

---

## 6. 優化待辦清單（需要時才做）

依**成本效益**排序，實作前可再開 issue / PR 討論。

| 優先 | 項目 | 解決什麼 | 複雜度 |
|------|------|----------|--------|
| P1 | **`hot_stocks` 清理**（例如：僅保留 holdings 內 + 90 天內活躍） | 排程 API/DB 寫入膨脹 | 中 |
| P1 | **減少逐檔 `fetchCurrentPrice`**（Portfolio 等改批量 `fetchPrices`） | Edge Function + 外部 API | 中 |
| P2 | **App 磁碟快取股價**（冷啟動先顯示上次，背景再對 metadata 刷新） | 冷啟動 REST 次數 | 中 |
| P2 | **REST `select` 只取必要欄位** | egress | 低 |
| P3 | CoinGecko Pro 或拉長排程間隔 | 429 / 穩定度 | 低～高 |
| P3 | 美股／台股排程備援與 Edge 對齊（如排程也試 TWSE） | 資料一致性 | 中 |

---

## 7. 上架前最小檢查（與流量無關但必做）

- [ ] Supabase **RLS** 已啟用且測過 anon / authenticated
- [ ] GitHub Secrets：`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` 正確
- [ ] 分時排程 workflow 已 push（三組 cron）
- [ ] `crypto_coingecko_map.json` 已隨建置腳本維護
- [ ] Edge Function `fetch-or-create-price` 已部署（含 `coingeckoId`）
- [ ] App 內 `symbols_crypto.json` 含 `coingeckoId`（與後端映射一致）
- [ ] 用量／帳單提醒已設定

---

## 8. 相關文件

| 文件 | 內容 |
|------|------|
| [BACKEND_AND_APIS.md](../BACKEND_AND_APIS.md) | API 與架構總覽 |
| [PRICE_API_USAGE.md](../PRICE_API_USAGE.md) | 股價 API 使用說明 |
| [backend/README.md](../backend/README.md) | 排程與腳本參數 |
| [.github/workflows/daily-price-update.yml](../.github/workflows/daily-price-update.yml) | 實際 cron |

---

## 9. 修訂紀錄

| 日期 | 說明 |
|------|------|
| 2026-05-23 | 初版：上架後 Supabase／排程／補價監控與門檻 |
