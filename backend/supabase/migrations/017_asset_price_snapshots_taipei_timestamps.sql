-- 將 asset_price_snapshots 的更新時間改成台灣本地時間顯示（到秒）。
-- 原本 TIMESTAMPTZ 在 Supabase Table Editor 會以 UTC 顯示，看起來慢 8 小時。

ALTER TABLE public.asset_price_snapshots
  ALTER COLUMN current_updated_at TYPE TIMESTAMP
    USING CASE
      WHEN current_updated_at IS NULL THEN NULL
      ELSE date_trunc('second', current_updated_at AT TIME ZONE 'Asia/Taipei')
    END,
  ALTER COLUMN previous_updated_at TYPE TIMESTAMP
    USING CASE
      WHEN previous_updated_at IS NULL THEN NULL
      ELSE date_trunc('second', previous_updated_at AT TIME ZONE 'Asia/Taipei')
    END;
