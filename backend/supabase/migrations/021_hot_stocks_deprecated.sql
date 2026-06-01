-- hot_stocks / hot_stocks_seed / hot_stocks_backup 已退役：抓價僅用 tracked_symbols。
-- 表保留供舊資料查詢；新程式不再讀寫。日後可另開 migration DROP（確認無依賴後）。

COMMENT ON TABLE public.hot_stocks IS 'DEPRECATED: 抓價改為 tracked_symbols only（2026-06）';
COMMENT ON TABLE public.hot_stocks_seed IS 'DEPRECATED: 不再併入每日 catalog';
COMMENT ON TABLE public.hot_stocks_backup IS 'DEPRECATED: 不再每日備份 hot_stocks';
