-- 匿名全站追蹤標的池：只保存公開 symbol，不保存 user_id、持股數量、成本或帳戶資訊。

CREATE TABLE IF NOT EXISTS public.tracked_symbols (
  asset_type TEXT NOT NULL CHECK (asset_type IN ('stock_tw', 'stock_us', 'crypto')),
  symbol TEXT NOT NULL,
  normalized_symbol TEXT NOT NULL,
  first_seen_at TIMESTAMP NOT NULL DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  last_seen_at TIMESTAMP NOT NULL DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  last_price_synced_at TIMESTAMP,
  failure_count INT NOT NULL DEFAULT 0,
  last_error TEXT,
  last_failed_at TIMESTAMP,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (asset_type, normalized_symbol)
);

CREATE INDEX IF NOT EXISTS idx_tracked_symbols_active
  ON public.tracked_symbols (is_active, asset_type, normalized_symbol);

ALTER TABLE public.tracked_symbols ENABLE ROW LEVEL SECURITY;

-- App 不直接寫表，改由 Edge Function 使用 service_role upsert，避免暴露任意寫入面。
CREATE POLICY "Allow anon read tracked_symbols"
  ON public.tracked_symbols FOR SELECT
  TO anon
  USING (true);

GRANT SELECT ON TABLE public.tracked_symbols TO anon;
GRANT ALL ON TABLE public.tracked_symbols TO service_role;

-- Local-first privacy: App no longer reads/writes user portfolio state or cloud daily snapshots.
REVOKE SELECT, INSERT, UPDATE ON TABLE public.user_portfolio_state FROM anon;
REVOKE SELECT ON TABLE public.user_daily_snapshots FROM anon;
