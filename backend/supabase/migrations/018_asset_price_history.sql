-- 公開市場歷史價格：供 App 本機補齊 daily trend snapshots。
-- 只保存公開 symbol 的日價格，不保存任何使用者持股、成本或資產走勢。

CREATE TABLE IF NOT EXISTS public.asset_price_history (
  asset_type TEXT NOT NULL CHECK (asset_type IN ('stock_tw', 'stock_us', 'crypto')),
  symbol TEXT NOT NULL,
  price_date DATE NOT NULL,
  close_price DECIMAL(18, 8) NOT NULL,
  currency TEXT NOT NULL,
  source TEXT,
  updated_at TIMESTAMP NOT NULL DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  PRIMARY KEY (asset_type, symbol, price_date)
);

CREATE INDEX IF NOT EXISTS idx_asset_price_history_symbol_date
  ON public.asset_price_history (asset_type, symbol, price_date DESC);

ALTER TABLE public.asset_price_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read asset_price_history"
  ON public.asset_price_history FOR SELECT
  TO anon
  USING (true);

GRANT SELECT ON TABLE public.asset_price_history TO anon;
GRANT ALL ON TABLE public.asset_price_history TO service_role;
