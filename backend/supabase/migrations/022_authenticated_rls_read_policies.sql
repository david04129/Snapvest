-- Phase A：Anonymous Auth — authenticated 角色可讀公開資料（保留既有 anon policies）
-- 僅對「存在的表」建立 policy / GRANT（精簡 DB 可能只有 6 張表）
-- 執行：Supabase Dashboard > SQL Editor

-- === 核心表（Snapvest 現行最小 schema）===

DROP POLICY IF EXISTS "Allow authenticated read asset_price_snapshots" ON asset_price_snapshots;
CREATE POLICY "Allow authenticated read asset_price_snapshots"
  ON asset_price_snapshots FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read price_update_metadata" ON price_update_metadata;
CREATE POLICY "Allow authenticated read price_update_metadata"
  ON price_update_metadata FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read exchange_rates" ON exchange_rates;
CREATE POLICY "Allow authenticated read exchange_rates"
  ON exchange_rates FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read asset_price_history" ON public.asset_price_history;
CREATE POLICY "Allow authenticated read asset_price_history"
  ON public.asset_price_history FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read market_calendar" ON public.market_calendar;
CREATE POLICY "Allow authenticated read market_calendar"
  ON public.market_calendar FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated read tracked_symbols" ON public.tracked_symbols;
CREATE POLICY "Allow authenticated read tracked_symbols"
  ON public.tracked_symbols FOR SELECT TO authenticated USING (true);

GRANT SELECT ON TABLE public.asset_price_snapshots TO authenticated;
GRANT SELECT ON TABLE public.price_update_metadata TO authenticated;
GRANT SELECT ON TABLE public.exchange_rates TO authenticated;
GRANT SELECT ON TABLE public.asset_price_history TO authenticated;
GRANT SELECT ON TABLE public.market_calendar TO authenticated;
GRANT SELECT ON TABLE public.tracked_symbols TO authenticated;

-- === 選用表（舊環境可能有；表不存在則略過）===

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'hot_stocks'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated read hot_stocks" ON hot_stocks';
    EXECUTE 'CREATE POLICY "Allow authenticated read hot_stocks" ON hot_stocks FOR SELECT TO authenticated USING (true)';
    EXECUTE 'GRANT SELECT ON TABLE public.hot_stocks TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'hot_stocks_seed'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated read hot_stocks_seed" ON hot_stocks_seed';
    EXECUTE 'CREATE POLICY "Allow authenticated read hot_stocks_seed" ON hot_stocks_seed FOR SELECT TO authenticated USING (true)';
    EXECUTE 'GRANT SELECT ON TABLE public.hot_stocks_seed TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'hot_stocks_backup'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated read hot_stocks_backup" ON hot_stocks_backup';
    EXECUTE 'CREATE POLICY "Allow authenticated read hot_stocks_backup" ON hot_stocks_backup FOR SELECT TO authenticated USING (true)';
    EXECUTE 'GRANT SELECT ON TABLE public.hot_stocks_backup TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_daily_snapshots'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated read user_daily_snapshots" ON user_daily_snapshots';
    EXECUTE 'CREATE POLICY "Allow authenticated read user_daily_snapshots" ON user_daily_snapshots FOR SELECT TO authenticated USING (true)';
    EXECUTE 'GRANT SELECT ON TABLE public.user_daily_snapshots TO authenticated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_portfolio_state'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated read user_portfolio_state" ON user_portfolio_state';
    EXECUTE 'CREATE POLICY "Allow authenticated read user_portfolio_state" ON user_portfolio_state FOR SELECT TO authenticated USING (true)';
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated insert user_portfolio_state" ON user_portfolio_state';
    EXECUTE 'CREATE POLICY "Allow authenticated insert user_portfolio_state" ON user_portfolio_state FOR INSERT TO authenticated WITH CHECK (true)';
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated update user_portfolio_state" ON user_portfolio_state';
    EXECUTE 'CREATE POLICY "Allow authenticated update user_portfolio_state" ON user_portfolio_state FOR UPDATE TO authenticated USING (true) WITH CHECK (true)';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE ON TABLE public.user_portfolio_state TO authenticated';
  END IF;
END $$;
