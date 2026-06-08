# Cloud Run 股價排程

Supabase 維持為 DB；盤中／收盤股價由此處觸發（取代 GitHub Actions 定時排程；`.github/workflows/daily-price-update.yml` 僅保留手動 Run workflow 備援）。

**抓價範圍**：僅 `tracked_symbols`（`is_active=true`）。不再使用 `hot_stocks` / `hot_stocks_seed`；請刪除 GCP 上的 `snapvest-catalog` Scheduler（若已建立）。

## 建置與部署（概略）

```bash
# 建置 context 為 backend/（Dockerfile 內 COPY scripts/... 相對此目錄）
export PROJECT_ID=你的-gcp專案
export REGION=asia-east1

cd backend
# 若 Job 日誌出現「不認得 --mode」：多半是 COPY 層被 cache，請改 Dockerfile 的 SCRIPTS_CACHE_BUST 後重建
gcloud builds submit --tag gcr.io/$PROJECT_ID/snapvest-price-job .

gcloud run jobs create snapvest-price-job \
  --image gcr.io/$PROJECT_ID/snapvest-price-job \
  --region $REGION \
  --set-secrets=SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,FINNHUB_API_KEY=FINNHUB_API_KEY:latest,FINMIND_TOKEN=FINMIND_TOKEN:latest,FUGLE_API_KEY=FUGLE_API_KEY:latest \
  --max-retries 1 \
  --task-timeout 15m \
  --memory 512Mi
```

Secret 請先在 Secret Manager 建立，並授權 Cloud Run service account。

## Cloud Scheduler

| Job 名稱 | Time zone | Cron | 指令覆寫 args |
|----------|-----------|------|-------------|
| snapvest-intraday-tw | `Asia/Taipei` | `*/15 9-13 * * 1-5` | `--mode intraday --markets tw` |
| snapvest-intraday-us | `America/New_York` | `*/15 9-15 * * 1-5` | `--mode intraday --markets us` |
| snapvest-close-tw | `Asia/Taipei` | `0 14 * * 1-5` | `--mode close --markets tw` |
| snapvest-close-us | `America/New_York` | `5 16 * * 1-5` | `--mode close --markets us` |
| snapvest-crypto-hourly | `Asia/Taipei` | `0 * * * *` | `--mode crypto_hourly`（**00:00 台北** 另寫昨日 `asset_price_history`） |
| snapvest-calendar | `Asia/Taipei` | `0 6 * * *` | `--mode calendar` |
| snapvest-exchange | `Asia/Taipei` | `5 14 * * 1-5` | `--mode exchange`（可併入 close-tw，二擇一） |

美股排程使用 `America/New_York`，由 Cloud Scheduler 自動處理夏令／冬令；寫入 Supabase 的 `updated_at` 仍由腳本以台灣時間產生。Job 內也會用 `market_session` 在非盤中 skip。

**台股（盤中／收盤）**：Fugle `intraday/quote` → `current_price_source=fugle`。需 Secret **`FUGLE_API_KEY`**。匯率／交易日曆仍用 **`FINMIND_TOKEN`**。

### 移除已退役排程（一次性）

```bash
gcloud scheduler jobs delete snapvest-catalog --location=asia-east1 --quiet
gcloud scheduler jobs delete snapvest-crypto-rollup --location=asia-east1 --quiet
```

### Scheduler 前置（同一終端機視窗內先執行，否則 `--uri` 會是空值）

```bash
export PROJECT_ID=你的-gcp專案
export REGION=asia-east1
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
export JOB_URI="https://${REGION}-run.googleapis.com/v2/projects/${PROJECT_ID}/locations/${REGION}/jobs/snapvest-price-job:run"
echo "JOB_URI=$JOB_URI"   # 應印出完整 https://... URL，不可為空

gcloud run jobs add-iam-policy-binding snapvest-price-job \
  --region=$REGION \
  --member="serviceAccount:${RUN_SA}" \
  --role="roles/run.invoker"
```

建立排程時 `message-body` 的 `args` 須為 JSON 陣列，例如 `["--mode","calendar"]`（不可用 `"--mode calendar"` 單一字串）。

## 本機測試

```bash
cd backend/scripts
export SUPABASE_URL=...
export SUPABASE_SERVICE_ROLE_KEY=...
export FINNHUB_API_KEY=...
export FINMIND_TOKEN=...
export FUGLE_API_KEY=...

python daily_price_update.py --mode calendar
python daily_price_update.py --mode intraday --markets tw --no-skip-closed
python daily_price_update.py --mode close --markets tw
python daily_price_update.py --mode crypto_hourly
# 加密日線：僅在台北 00:00 的 hourly 執行時寫入 history（price_date=昨日）
```

## Edge Functions（Supabase CLI，非 Cloud Run）

```bash
cd backend
supabase functions deploy market-status --no-verify-jwt
```
