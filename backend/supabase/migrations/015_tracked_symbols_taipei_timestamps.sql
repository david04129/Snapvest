-- 將 tracked_symbols 記錄時間改成台灣本地時間顯示（到秒）。
-- 原本 TIMESTAMPTZ 在 Supabase Table Editor 會以 UTC 顯示，看起來慢 8 小時。

ALTER TABLE public.tracked_symbols
  ALTER COLUMN first_seen_at TYPE TIMESTAMP
    USING date_trunc('second', first_seen_at AT TIME ZONE 'Asia/Taipei'),
  ALTER COLUMN first_seen_at SET DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  ALTER COLUMN last_seen_at TYPE TIMESTAMP
    USING date_trunc('second', last_seen_at AT TIME ZONE 'Asia/Taipei'),
  ALTER COLUMN last_seen_at SET DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  ALTER COLUMN last_price_synced_at TYPE TIMESTAMP
    USING CASE
      WHEN last_price_synced_at IS NULL THEN NULL
      ELSE date_trunc('second', last_price_synced_at AT TIME ZONE 'Asia/Taipei')
    END;
