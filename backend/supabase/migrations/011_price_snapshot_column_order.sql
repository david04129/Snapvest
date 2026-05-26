-- 調整 asset_price_snapshots 欄位順序（僅影響 Table Editor 顯示順序，語意不變）
-- current_price_source 緊接 current_updated_at；previous_price_source 緊接 previous_updated_at
-- 需已執行 009、010（010 可與本檔同一 session 接續執行）

BEGIN;

ALTER TABLE IF EXISTS asset_price_snapshots RENAME TO asset_price_snapshots_legacy;

CREATE TABLE asset_price_snapshots (
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  PRIMARY KEY (asset_type, symbol),

  name TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',

  current_price DECIMAL(18, 8),
  current_close_date DATE,
  current_updated_at TIMESTAMPTZ,
  current_price_source TEXT,

  previous_price DECIMAL(18, 8),
  previous_close_date DATE,
  previous_updated_at TIMESTAMPTZ,
  previous_price_source TEXT
);

INSERT INTO asset_price_snapshots (
  asset_type,
  symbol,
  name,
  currency,
  current_price,
  current_close_date,
  current_updated_at,
  current_price_source,
  previous_price,
  previous_close_date,
  previous_updated_at,
  previous_price_source
)
SELECT
  asset_type,
  symbol,
  name,
  currency,
  current_price,
  current_close_date,
  current_updated_at,
  current_price_source,
  previous_price,
  previous_close_date,
  previous_updated_at,
  previous_price_source
FROM asset_price_snapshots_legacy;

DROP TABLE asset_price_snapshots_legacy;

CREATE INDEX IF NOT EXISTS idx_asset_price_current_updated
  ON asset_price_snapshots (current_updated_at);

ALTER TABLE asset_price_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon read asset_price_snapshots" ON asset_price_snapshots;
CREATE POLICY "Allow anon read asset_price_snapshots"
  ON asset_price_snapshots FOR SELECT
  TO anon
  USING (true);

COMMENT ON COLUMN asset_price_snapshots.current_close_date IS
  '此 current_price 對應的收盤所屬日期（DATE）';
COMMENT ON COLUMN asset_price_snapshots.current_updated_at IS
  '本列 current_price 寫入時間（到秒）';
COMMENT ON COLUMN asset_price_snapshots.current_price_source IS
  'current_price 的資料來源（finmind / finnhub / yfinance / coingecko / yahoo）';
COMMENT ON COLUMN asset_price_snapshots.previous_close_date IS
  'previous_price 對應的收盤所屬日期';
COMMENT ON COLUMN asset_price_snapshots.previous_updated_at IS
  'previous_price 當時寫入時間';
COMMENT ON COLUMN asset_price_snapshots.previous_price_source IS
  'previous_price 的資料來源';

COMMIT;
