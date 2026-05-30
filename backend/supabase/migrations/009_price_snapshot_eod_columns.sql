-- asset_price_snapshots：收盤日 + 更新時間（取代混用的 price_date / last_updated）
-- 在 Supabase SQL Editor 執行（需已執行 008 price_source）

ALTER TABLE asset_price_snapshots
  ADD COLUMN IF NOT EXISTS current_close_date DATE,
  ADD COLUMN IF NOT EXISTS current_updated_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS previous_close_date DATE,
  ADD COLUMN IF NOT EXISTS previous_updated_at TIMESTAMP;

-- 自舊欄位遷移（Asia/Taipei）
UPDATE asset_price_snapshots
SET
  current_updated_at = COALESCE(
    last_successful_update AT TIME ZONE 'Asia/Taipei',
    last_updated AT TIME ZONE 'Asia/Taipei',
    current_price_date AT TIME ZONE 'Asia/Taipei'
  ),
  current_close_date = COALESCE(
    current_close_date,
    (COALESCE(last_successful_update, last_updated, current_price_date) AT TIME ZONE 'Asia/Taipei')::date
  )
WHERE current_updated_at IS NULL;

UPDATE asset_price_snapshots
SET
  previous_updated_at = COALESCE(
    previous_updated_at,
    previous_price_date AT TIME ZONE 'Asia/Taipei'
  ),
  previous_close_date = COALESCE(
    previous_close_date,
    (previous_price_date AT TIME ZONE 'Asia/Taipei')::date
  )
WHERE previous_price_date IS NOT NULL
  AND previous_close_date IS NULL;

DROP INDEX IF EXISTS idx_asset_price_last_updated;

ALTER TABLE asset_price_snapshots
  DROP COLUMN IF EXISTS current_price_date,
  DROP COLUMN IF EXISTS previous_price_date,
  DROP COLUMN IF EXISTS last_updated,
  DROP COLUMN IF EXISTS last_successful_update;

CREATE INDEX IF NOT EXISTS idx_asset_price_current_updated
  ON asset_price_snapshots (current_updated_at);

COMMENT ON COLUMN asset_price_snapshots.current_close_date IS '此 current_price 對應的收盤所屬日期（DATE）';
COMMENT ON COLUMN asset_price_snapshots.current_updated_at IS '本列 current_price 寫入時間（到秒）';
COMMENT ON COLUMN asset_price_snapshots.previous_close_date IS 'previous_price 對應的收盤所屬日期';
COMMENT ON COLUMN asset_price_snapshots.previous_updated_at IS 'previous_price 當時寫入時間';
