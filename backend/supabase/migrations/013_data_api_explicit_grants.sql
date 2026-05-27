-- Supabase Data API explicit grants
-- 2026-10-30 起，public schema 新表不再預設暴露給 Data API。
-- RLS policy 只決定「哪些列可存取」；GRANT 決定「角色是否可透過 PostgREST/GraphQL/supabase-js 存取表」。

-- App / anon：只開放目前 App 需要的讀取與 user_portfolio_state upsert。
GRANT SELECT ON TABLE public.asset_price_snapshots TO anon;
GRANT SELECT ON TABLE public.price_update_metadata TO anon;
GRANT SELECT ON TABLE public.hot_stocks TO anon;
GRANT SELECT ON TABLE public.hot_stocks_seed TO anon;
GRANT SELECT ON TABLE public.hot_stocks_backup TO anon;
GRANT SELECT ON TABLE public.exchange_rates TO anon;
GRANT SELECT ON TABLE public.user_daily_snapshots TO anon;

GRANT SELECT, INSERT, UPDATE ON TABLE public.user_portfolio_state TO anon;

-- Backend jobs / Edge Functions：保留完整維護權限。
GRANT ALL ON TABLE public.asset_price_snapshots TO service_role;
GRANT ALL ON TABLE public.price_update_metadata TO service_role;
GRANT ALL ON TABLE public.hot_stocks TO service_role;
GRANT ALL ON TABLE public.hot_stocks_seed TO service_role;
GRANT ALL ON TABLE public.hot_stocks_backup TO service_role;
GRANT ALL ON TABLE public.exchange_rates TO service_role;
GRANT ALL ON TABLE public.user_portfolio_state TO service_role;
GRANT ALL ON TABLE public.user_daily_snapshots TO service_role;
