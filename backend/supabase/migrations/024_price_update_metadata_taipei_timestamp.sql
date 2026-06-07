-- price_update_metadata.last_updated_at 改為台灣本地時間顯示（到秒）。
-- 與 asset_price_snapshots.current_updated_at 一致；Table Editor 不再顯示 UTC 慢 8 小時。

ALTER TABLE public.price_update_metadata
  ALTER COLUMN last_updated_at TYPE TIMESTAMP
    USING date_trunc('second', last_updated_at AT TIME ZONE 'Asia/Taipei'),
  ALTER COLUMN last_updated_at SET DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW()));

COMMENT ON COLUMN public.price_update_metadata.last_updated_at IS
  '全站股價／匯率排程最後完成時間（Asia/Taipei 本地，到秒）';
