-- 將 price_source 拆為 current_price_source / previous_price_source
-- 需已執行 008（或曾有 price_source 欄位）

ALTER TABLE asset_price_snapshots
  ADD COLUMN IF NOT EXISTS current_price_source TEXT,
  ADD COLUMN IF NOT EXISTS previous_price_source TEXT;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'asset_price_snapshots'
      AND column_name = 'price_source'
  ) THEN
    UPDATE asset_price_snapshots
    SET current_price_source = COALESCE(current_price_source, price_source)
    WHERE price_source IS NOT NULL;
    ALTER TABLE asset_price_snapshots DROP COLUMN price_source;
  END IF;
END $$;

COMMENT ON COLUMN asset_price_snapshots.current_price_source IS
  'current_price 的資料來源（finmind / finnhub / yfinance / coingecko / yahoo）';
COMMENT ON COLUMN asset_price_snapshots.previous_price_source IS
  'previous_price 的資料來源';
