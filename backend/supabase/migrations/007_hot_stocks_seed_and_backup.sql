-- 種子熱門股（每日重建 hot_stocks 時固定併入，不被覆寫清空）
-- hot_stocks 備份（保留最近 2 日，供還原查詢）

CREATE TABLE IF NOT EXISTS hot_stocks_seed (
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  display_order INT DEFAULT 0,
  PRIMARY KEY (asset_type, symbol)
);

CREATE TABLE IF NOT EXISTS hot_stocks_backup (
  backup_date DATE NOT NULL,
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  display_order INT DEFAULT 0,
  PRIMARY KEY (backup_date, asset_type, symbol)
);

CREATE INDEX IF NOT EXISTS idx_hot_stocks_backup_date ON hot_stocks_backup (backup_date DESC);

-- 種子清單（與 001 初始 hot_stocks 相同）
INSERT INTO hot_stocks_seed (asset_type, symbol, display_order) VALUES
  ('stock_tw', '2330', 1),
  ('stock_tw', '2317', 2),
  ('stock_tw', '2454', 3),
  ('stock_tw', '2308', 4),
  ('stock_tw', '2891', 5),
  ('stock_tw', '2882', 6),
  ('stock_tw', '2886', 7),
  ('stock_tw', '1301', 8),
  ('stock_tw', '2412', 9),
  ('stock_tw', '2382', 10),
  ('stock_us', 'AAPL', 1),
  ('stock_us', 'MSFT', 2),
  ('stock_us', 'GOOGL', 3),
  ('stock_us', 'AMZN', 4),
  ('stock_us', 'NVDA', 5),
  ('stock_us', 'META', 6),
  ('stock_us', 'TSLA', 7),
  ('stock_us', 'BRK-B', 8),
  ('stock_us', 'JPM', 9),
  ('stock_us', 'V', 10),
  ('crypto', 'BTC', 1),
  ('crypto', 'ETH', 2),
  ('crypto', 'BNB', 3),
  ('crypto', 'SOL', 4),
  ('crypto', 'XRP', 5),
  ('crypto', 'ADA', 6),
  ('crypto', 'DOGE', 7),
  ('crypto', 'AVAX', 8),
  ('crypto', 'DOT', 9),
  ('crypto', 'LINK', 10)
ON CONFLICT (asset_type, symbol) DO NOTHING;

ALTER TABLE hot_stocks_seed ENABLE ROW LEVEL SECURITY;
ALTER TABLE hot_stocks_backup ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read hot_stocks_seed"
  ON hot_stocks_seed FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon read hot_stocks_backup"
  ON hot_stocks_backup FOR SELECT
  TO anon
  USING (true);
