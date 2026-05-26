-- exchange_rates：保留上一輪匯率（本輪 FinMind 抓不到時 App 仍可用 previous_*）
-- 需已執行 003_exchange_rates.sql

ALTER TABLE exchange_rates
  ADD COLUMN IF NOT EXISTS previous_rate DECIMAL(18, 8),
  ADD COLUMN IF NOT EXISTS previous_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN exchange_rates.rate IS '本輪匯率：1 from_currency = rate to_currency（台銀即期中價）';
COMMENT ON COLUMN exchange_rates.updated_at IS '本輪 rate 寫入時間（到秒）';
COMMENT ON COLUMN exchange_rates.previous_rate IS '上一輪成功寫入的 rate';
COMMENT ON COLUMN exchange_rates.previous_updated_at IS '上一輪 rate 的寫入時間';
