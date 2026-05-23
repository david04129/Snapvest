# Symbols 維護腳本

建立與維護台股、美股、加密貨幣的股票/代幣名稱清單，供 Snapvest App 選股使用。

## 輸出格式（單檔結構）

每個 `symbols_*.json` 格式：

```json
{
  "version": 1,
  "updatedAt": "2025-02-14",
  "items": [
    {"symbol": "2330", "name": "台積電"},
    {"symbol": "AAPL", "name": "Apple Inc."},
    {"symbol": "btc", "name": "Bitcoin", "coingeckoId": "bitcoin"}
  ]
}
```

- `version`：每次更新遞增，App 用來判斷是否需要重新下載
- `updatedAt`：更新日期
- `items`：symbol + name 清單，依 symbol 排序

## 資料來源

| 市場 | 來源 | 說明 |
|------|------|------|
| 美股 | NASDAQ nasdaqtraded.txt | 自動下載，含 NASDAQ/NYSE/AMEX |
| 加密貨幣 | CoinGecko API /coins/markets（市值 Top 500） | 含 `coingeckoId`（抓價必用）；並產生 `backend/scripts/data/crypto_coingecko_map.json` |
| 台股 | 證交所(上市) + 櫃買(上櫃、興櫃) | 自動下載 上市+上櫃+興櫃；上市失敗時可放 CSV 於 scripts/data/ |

## 使用方式

### 一鍵建立全部

```bash
./build_all.sh
```

或手動執行：

```bash
python3 build_symbols_us.py      # 美股
python3 build_symbols_crypto.py  # 加密貨幣
python3 build_symbols_tw.py      # 台股
python3 build_manifest.py        # manifest
```

### 台股無法自動下載時

1. 前往 [政府資料開放平台 - 上市公司基本資料](https://data.nat.gov.tw/dataset/18419)
2. 下載 CSV 檔案
3. 放置於 `scripts/data/` 目錄，檔名可為：
   - `tw_listed.csv`
   - `tw_securities.csv`
   - `t187ap03_L.csv`
4. 再次執行 `python3 build_symbols_tw.py`

## 輸出目錄

```
scripts/
├── output/
│   ├── symbols_tw.json
│   ├── symbols_us.json
│   ├── symbols_crypto.json
│   └── symbols_manifest.json
└── data/           # 台股本地 CSV（可選）
    └── tw_listed.csv
```

## 上傳到後端

1. 將 `output/` 下的檔案上傳至你的 Storage（如 Supabase Storage）
2. 修改 `build_manifest.py` 內的 `BASE_URL` 為實際網址
3. 重新執行 `build_manifest.py` 以更新 manifest 中的 url

## 維護頻率建議

- 美股、加密：每月執行一次
- 台股：每月或每季執行一次（上市/上櫃變動較少）

## version 更新規則

- 只要 `items` 有變動（新增、刪除、改名），就遞增 `version`
- 腳本會自動從現有檔案讀取 version 並 +1，無需手動修改
