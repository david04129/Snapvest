-- Snapvest 匯率表（每日由批次腳本更新）
-- 來源: FinMind TaiwanExchangeRate（1 外幣 = rate TWD）；排程見 daily_price_update.py
-- 執行方式：在 Supabase Dashboard > SQL Editor 中執行

CREATE TABLE IF NOT EXISTS exchange_rates (
  from_currency TEXT NOT NULL DEFAULT 'USD',
  to_currency TEXT NOT NULL,
  rate DECIMAL(18, 8) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (from_currency, to_currency)
);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_updated ON exchange_rates(updated_at);

-- RLS：允許 App (anon) 讀取
ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read exchange_rates"
  ON exchange_rates FOR SELECT
  TO anon
  USING (true);
