-- 排程抓價池概覽：Supabase Table Editor 開啟 tracked_symbols_summary 即可見各類 active 檔數。
-- 資料來源：tracked_symbols（Cloud Run daily_price_update 僅更新 is_active=true 者）

CREATE OR REPLACE VIEW public.tracked_symbols_summary AS
SELECT
  COUNT(*) FILTER (WHERE asset_type = 'stock_tw' AND is_active) AS tw_active,
  COUNT(*) FILTER (WHERE asset_type = 'stock_us' AND is_active) AS us_active,
  COUNT(*) FILTER (WHERE asset_type = 'crypto' AND is_active) AS crypto_active,
  COUNT(*) FILTER (WHERE is_active) AS total_active,
  COUNT(*) FILTER (WHERE asset_type = 'stock_tw' AND NOT is_active) AS tw_inactive,
  COUNT(*) FILTER (WHERE asset_type = 'stock_us' AND NOT is_active) AS us_inactive,
  COUNT(*) FILTER (WHERE asset_type = 'crypto' AND NOT is_active) AS crypto_inactive,
  COUNT(*) FILTER (WHERE NOT is_active) AS total_inactive,
  COUNT(*) AS total_rows,
  MAX(last_price_synced_at) AS latest_price_synced_at,
  MAX(last_seen_at) AS latest_last_seen_at
FROM public.tracked_symbols;

COMMENT ON VIEW public.tracked_symbols_summary IS
  'tracked_symbols 即時統計（單列）。tw/us/crypto_* = 排程抓價池 active/inactive 檔數。';

GRANT SELECT ON public.tracked_symbols_summary TO anon;
GRANT SELECT ON public.tracked_symbols_summary TO authenticated;
GRANT SELECT ON public.tracked_symbols_summary TO service_role;
