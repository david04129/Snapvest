-- 記錄股價來源，便於區分本輪排程成功 vs 沿用舊價
-- 常見值：yfinance, coingecko, yahoo, finmind, finnhub

ALTER TABLE asset_price_snapshots
  ADD COLUMN IF NOT EXISTS price_source TEXT;

COMMENT ON COLUMN asset_price_snapshots.price_source IS
  '最後一次成功寫入 current_price 的資料來源（yfinance / coingecko / yahoo / finmind / finnhub）';
