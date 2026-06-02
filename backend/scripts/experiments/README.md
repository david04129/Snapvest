# API 限速實驗（獨立於 Snapvest 主流程）

此目錄**不會**被 `daily_price_update.py` 或其它既有腳本引用。可安全刪除整個 `experiments/` 資料夾而不影響 App。

## 檔案

| 檔案 | 說明 |
|------|------|
| `finnhub_us_batch_test.py` | 200 檔美股，`/quote`，約 4 分鐘（58 次/分鐘） |
| `finmind_tw_batch_test.py` | 台股清單（含 ETF），`TaiwanStockPrice`（58 次/分鐘，且每小時≤600） |
| `fugle_tw_quote_test.py` | Fugle 台股 `intraday/quote`（上市／上櫃／ETF／00751B／00675L）+ 可選當日日 K |
| `data/us_symbols_200.json` | 模擬 hot_stocks 美股清單 |
| `data/tw_symbols_50.json` | 模擬 hot_stocks 台股清單（含 0050、006208、00675L、00751B 等） |
| `output/` | 執行後產生的 JSON（git 可忽略） |

## 前置

```bash
pip3 install requests
```

## API Key

1. **Finnhub**：https://finnhub.io → 免費 API key  
2. **FinMind**：https://finmindtrade.com → 註冊並驗證信箱後取得 token（建議，600 次/小時）  
3. **Fugle**：https://developer.fugle.tw/ → API Key

```bash
export FINNHUB_API_KEY='你的_finnhub_key'
export FINMIND_TOKEN='你的_finmind_token'
export FUGLE_API_KEY='你的_fugle_api_key'
```

## 執行

```bash
cd backend/scripts/experiments

# 美股 200 檔（約 4 分鐘）
python3 finnhub_us_batch_test.py

# 台股清單（目前 54 檔，約 1 分鐘）
python3 finmind_tw_batch_test.py

# Fugle 台股報價（5 檔範例，含 00751B / 00675L）
python3 fugle_tw_quote_test.py
```

## 限速設計（保守）

| 供應商 | 官方參考 | 本測試腳本 |
|--------|----------|------------|
| Finnhub 免費 | ~60 次/分鐘 | **58 次/分鐘**（間隔約 1.03 秒） |
| FinMind（有 token） | 600 次/小時 | **58 次/分鐘** + 滾動 1 小時不超過 600 |

遇 HTTP 429 會額外 sleep 60 秒再繼續。

## 調整

腳本頂部常數可改：

- `finnhub_us_batch_test.py` → `REQUESTS_PER_MINUTE`
- `finmind_tw_batch_test.py` → `REQUESTS_PER_MINUTE`

清單可改 `data/*.json`，腳本會自動去重。
