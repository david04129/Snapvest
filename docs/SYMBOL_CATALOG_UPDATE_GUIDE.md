# Symbol Catalog 更新操作指南

這份文件說明之後要怎麼手動更新 Snapvest 的選股清單，包括：

- 小版 OTA：只處理 symbol 加／刪，例如 `1.12 -> 1.13`
- 大版 App 發布：整包清單更新，允許改名，例如 `1.x -> 2.0`

清單分三個市場，各自獨立版本：

- `tw`：台股
- `us`：美股
- `crypto`：加密貨幣

## 版本規則

### 小版 OTA

小版只做 symbol 加／刪，不處理改名。

規則：

- 每次重新抓清單後，跟 DB 目前 `vn_items` 比 symbol 集合。
- 有新增或刪除 symbol，才會：
  - `minor + 1`
  - `vn_minus_1_items <- 舊 vn_items`
  - `vn_items <- 新清單`
  - 把這次 add/remove 合併進 `cumulative_adds` / `cumulative_removes`
- 如果 symbol 集合沒有變，只是名稱或 `updatedAt` 不同，DB 不進版。
- 異常資料不寫入，例如筆數太低、重複 symbol、相對 DB 現版縮水太多。

### 大版 App 發布

大版會重設 epoch，整包清單跟 App 一起發布，允許改名。

例如發布 App 2.0：

- DB 設為 `epoch = 2`
- `minor = 0`
- `vn_items = 2.0 完整清單`
- `vn_minus_1_items = NULL`
- `cumulative_adds = []`
- `cumulative_removes = []`

大版後的小版 OTA 就從 `2.0 -> 2.1 -> 2.2` 開始累積。

## DB 表

資料在 Supabase：

```sql
public.symbol_catalog_markets
```

常用欄位：

- `market`
- `epoch`
- `minor`
- `vn_items`
- `vn_minus_1_items`
- `cumulative_adds`
- `cumulative_removes`

查目前狀態：

```sql
SELECT market, epoch, minor,
       jsonb_array_length(vn_items) AS items,
       jsonb_array_length(cumulative_adds) AS adds,
       jsonb_array_length(cumulative_removes) AS removes
FROM public.symbol_catalog_markets
ORDER BY market;
```

## 本機準備

先確認 Python 依賴：

```bash
cd /Users/david/Desktop/Snapvest
pip3 install -r backend/scripts/requirements.txt
```

設定 Supabase 環境變數：

```bash
export SUPABASE_URL="https://你的專案ID.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="你的service_role_key"
```

檢查目前終端機是否有設定：

```bash
echo "SUPABASE_URL=${SUPABASE_URL:-空}"
echo "SERVICE_ROLE_KEY_LENGTH=${#SUPABASE_SERVICE_ROLE_KEY}"
```

注意：`export` 只對目前這個終端機視窗有效。新開視窗要重新設定。

## 小版 OTA：手動更新流程

用途：平常想手動重抓清單，讓 DB 依照 symbol 加／刪自動決定是否進小版。

### 1. 確認目前 git 狀態

```bash
cd /Users/david/Desktop/Snapvest
git status --short
```

如果有自己正在做的改動，先確認不要被 symbols 產物混在一起。

### 2. 重抓三個市場清單

```bash
cd /Users/david/Desktop/Snapvest/scripts
./build_all.sh
```

這會更新：

- `scripts/output/symbols_tw.json`
- `scripts/output/symbols_us.json`
- `scripts/output/symbols_crypto.json`
- `scripts/output/symbols_manifest.json`
- `Snapvest/Snapvest/Resources/Symbols/*.json`
- `backend/scripts/data/crypto_coingecko_map.json`

### 3. 同步到 Supabase DB

```bash
cd /Users/david/Desktop/Snapvest/scripts
python3 sync_symbol_catalog_to_db.py
```

可能看到的結果：

```text
✅ tw 1.12 -> 1.13 (+5 -1，vn 共 2348 筆)
—  us 無 symbol 變動，維持 1.6
—  crypto 無 symbol 變動，維持 1.8
✅ symbols_manifest.json 已更新
```

如果看到：

```text
⏭️  DB sync 略過：缺少 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY
```

代表環境變數沒設，請重新貼：

```bash
export SUPABASE_URL="https://你的專案ID.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="你的service_role_key"

cd /Users/david/Desktop/Snapvest/scripts
python3 sync_symbol_catalog_to_db.py
```

### 4. 確認本機 summary

```bash
cd /Users/david/Desktop/Snapvest
python3 scripts/print_symbols_summary.py
```

確認顯示的是 DB 規則後的版本。例如只有台股有 symbol 加／刪，可能是：

```text
symbols_tw.json: 1.13, items=2348, updatedAt=...
symbols_us.json: 1.6, items=12800, updatedAt=...
symbols_crypto.json: 1.8, items=496, updatedAt=...
```

### 5. 在 Supabase SQL Editor 確認 DB

貼到 Supabase SQL Editor，不要貼到終端機：

```sql
SELECT market, epoch, minor,
       jsonb_array_length(vn_items) AS items,
       jsonb_array_length(cumulative_adds) AS adds,
       jsonb_array_length(cumulative_removes) AS removes
FROM public.symbol_catalog_markets
ORDER BY market;
```

確認 DB 版本跟 `print_symbols_summary.py` 一致。

### 6. 查這次累積 patch 內容

查台股新增：

```sql
SELECT elem->>'symbol' AS symbol, elem->>'name' AS name
FROM symbol_catalog_markets,
     jsonb_array_elements(cumulative_adds) AS elem
WHERE market = 'tw'
ORDER BY symbol
LIMIT 50;
```

查台股刪除：

```sql
SELECT elem->>'symbol' AS symbol
FROM symbol_catalog_markets,
     jsonb_array_elements(cumulative_removes) AS elem
WHERE market = 'tw'
ORDER BY symbol
LIMIT 50;
```

### 7. App 驗證

啟動 App，Xcode Console 可用 filter：

```text
SymbolCatalogSync
```

只有當 App 本機版本落後 DB 時才會看到：

```text
[SymbolCatalogSync] tw 1.12 -> 1.13
```

如果 App bundle 已經跟 DB 同版，就不會出現這行，這是正常的。

可以從 SQL 查一個新增 symbol，然後在 App 的選股搜尋確認找得到。

## 小版 OTA：GitHub Actions 手動跑

GitHub workflow：

```text
Actions -> Monthly Symbols Update -> Run workflow
```

注意事項：

- workflow 會使用 GitHub `main` 上的腳本，不會使用你本機未 push 的修改。
- workflow 要能寫 DB，GitHub Secrets 必須有：
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- 如果 GitHub Summary 顯示版本進了，但 DB 沒變，先確認那次 workflow 是否已包含 `Sync symbol catalog to Supabase` 這個 step。

查 GitHub Secrets：

```bash
cd /Users/david/Desktop/Snapvest
gh secret list
```

設定 GitHub Secrets：

```bash
cd /Users/david/Desktop/Snapvest
gh secret set SUPABASE_URL --body "https://你的專案ID.supabase.co"
gh secret set SUPABASE_SERVICE_ROLE_KEY --body "你的service_role_key"
```

## 大版：發布新 epoch

用途：發 App 新版，整包清單更新，包括改名。

例如要發布 `2.0`：

### 1. 重抓清單

```bash
cd /Users/david/Desktop/Snapvest/scripts
./build_all.sh
```

### 2. 發布新 epoch

```bash
export SUPABASE_URL="https://你的專案ID.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="你的service_role_key"

cd /Users/david/Desktop/Snapvest/scripts
python3 publish_symbol_catalog_epoch.py --epoch 2
```

預期：

```text
✅ tw 發布 epoch 2.0（xxxx 筆）
✅ us 發布 epoch 2.0（xxxx 筆）
✅ crypto 發布 epoch 2.0（xxxx 筆）
✅ symbols_manifest.json 已更新
```

### 3. 確認 DB

貼到 Supabase SQL Editor：

```sql
SELECT market, epoch, minor,
       jsonb_array_length(vn_items) AS items,
       jsonb_array_length(cumulative_adds) AS adds,
       jsonb_array_length(cumulative_removes) AS removes,
       vn_minus_1_items IS NULL AS no_previous_snapshot
FROM public.symbol_catalog_markets
ORDER BY market;
```

預期：

- `epoch = 2`
- `minor = 0`
- `adds = 0`
- `removes = 0`
- `no_previous_snapshot = true`

### 4. App 發版

確認 App bundle 內的：

```text
Snapvest/Snapvest/Resources/Symbols/symbols_manifest.json
```

已經是：

```json
{
  "tw": { "epoch": 2, "minor": 0, ... },
  "us": { "epoch": 2, "minor": 0, ... },
  "crypto": { "epoch": 2, "minor": 0, ... }
}
```

然後再用這個狀態打包發新版 App。

舊 App 如果還是 `1.x`，看到 DB `2.0` 時不會套用 patch，會等使用者更新 App。

## 測試 OTA patch

如果要手動測 App 能不能從 DB 套 patch，可以在 Supabase SQL Editor 暫時加一檔測試 symbol。

不要貼到終端機，這是 SQL：

```sql
UPDATE symbol_catalog_markets
SET
  minor = minor + 1,
  updated_at = date_trunc('second', timezone('Asia/Taipei', NOW())),
  cumulative_adds = cumulative_adds || '[{"symbol":"9999","name":"OTA測試股"}]'::jsonb,
  vn_items = vn_items || '[{"symbol":"9999","name":"OTA測試股"}]'::jsonb
WHERE market = 'tw';
```

殺掉 App 重開，Console 應看到：

```text
[SymbolCatalogSync] tw 1.12 -> 1.13
```

測完要清理：

```sql
UPDATE symbol_catalog_markets
SET
  minor = minor - 1,
  cumulative_adds = (
    SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
    FROM jsonb_array_elements(cumulative_adds) elem
    WHERE elem->>'symbol' <> '9999'
  ),
  vn_items = (
    SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
    FROM jsonb_array_elements(vn_items) elem
    WHERE elem->>'symbol' <> '9999'
  )
WHERE market = 'tw';
```

如果測試時 bump 多次，`minor = minor - 1` 可能不夠精準，請改成指定正確版本。

## 常見問題

### GitHub Summary 顯示進版，但 DB 沒進版

可能原因：

- workflow 用的是舊版腳本，還沒包含 DB sync step。
- GitHub Secrets 沒有 `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`。
- 只是 JSON version 變了，但 symbol 集合沒有加／刪。DB sync 會把本機 JSON 對齊回 DB 版本，不會亂 bump。

### `git pull` 被 symbols 檔案擋住

如果本機跑過 `./build_all.sh`，又要拉 GitHub Actions commit，可能會被同檔案衝突擋住。可以先暫存 symbols 產物：

```bash
cd /Users/david/Desktop/Snapvest

git stash push -u -m "temp local symbols output before pulling monthly update" -- \
  Snapvest/Snapvest/Resources/Symbols/symbols_crypto.json \
  Snapvest/Snapvest/Resources/Symbols/symbols_manifest.json \
  Snapvest/Snapvest/Resources/Symbols/symbols_tw.json \
  Snapvest/Snapvest/Resources/Symbols/symbols_us.json \
  backend/scripts/data/crypto_coingecko_map.json \
  scripts/output/symbols_crypto.json \
  scripts/output/symbols_manifest.json \
  scripts/output/symbols_tw.json \
  scripts/output/symbols_us.json \
  scripts/output/archive/crypto/ \
  scripts/output/archive/tw/ \
  scripts/output/archive/us/
```

再 pull：

```bash
git pull
```

通常不要立刻 `git stash pop`，因為 stash 裡是本機舊 symbols 產物。

### `zsh: parse error near ')'`

代表你把 SQL 貼到終端機了。SQL 要貼到 Supabase SQL Editor。

### `NotOpenSSLWarning`

本機 Python 可能會印 urllib3 的 OpenSSL warning。只要腳本成功輸出 symbols / sync 結果，通常可以先忽略。

### 台股抓取出現 `Connection reset by peer`

台股來源偶爾會重置連線。腳本有異常筆數防護；如果台股筆數明顯太低，DB sync 會略過寫入。可以稍後重跑：

```bash
cd /Users/david/Desktop/Snapvest/scripts
./build_all.sh
python3 sync_symbol_catalog_to_db.py
```

## 最後提交

確認 App 編譯、DB 狀態、symbols summary 都正確後，再整理 git：

```bash
cd /Users/david/Desktop/Snapvest
git status --short
```

如果要提交，確認不要把 secrets 或 `.env` 放進 commit。
