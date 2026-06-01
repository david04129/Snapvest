-- 區分盤中快照價與收盤價，供 App 顯示「N 分鐘前」或「收盤」。

ALTER TABLE public.asset_price_snapshots
  ADD COLUMN IF NOT EXISTS price_kind TEXT
    CHECK (price_kind IS NULL OR price_kind IN ('intraday', 'close'));

COMMENT ON COLUMN public.asset_price_snapshots.price_kind IS 'intraday=盤中更新；close=收盤價寫入';

-- 既有列視為收盤語意（歷史排程多為 EOD）
UPDATE public.asset_price_snapshots
SET price_kind = 'close'
WHERE price_kind IS NULL;
