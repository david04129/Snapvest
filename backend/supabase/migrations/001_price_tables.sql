-- Snapvest 股價系統 - Supabase Schema
-- 執行方式：在 Supabase Dashboard > SQL Editor 中執行

-- 1. 資產價格快照表（與 AssetPriceSnapshot 對應）
CREATE TABLE IF NOT EXISTS asset_price_snapshots (
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  PRIMARY KEY (asset_type, symbol),
  
  name TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  
  current_price DECIMAL(18, 8),
  previous_price DECIMAL(18, 8),
  current_price_date TIMESTAMPTZ,
  previous_price_date TIMESTAMPTZ,
  
  last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_successful_update TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_asset_price_last_updated ON asset_price_snapshots(last_updated);

-- 2. 價格更新元數據（全站最後更新時間，供 App 比對）
CREATE TABLE IF NOT EXISTS price_update_metadata (
  id TEXT PRIMARY KEY DEFAULT 'global',
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 初始一筆
INSERT INTO price_update_metadata (id, last_updated_at) 
VALUES ('global', NOW()) 
ON CONFLICT (id) DO NOTHING;

-- 3. 熱門股票清單（每市場 10 檔，供每日更新使用）
CREATE TABLE IF NOT EXISTS hot_stocks (
  asset_type TEXT NOT NULL,
  symbol TEXT NOT NULL,
  display_order INT DEFAULT 0,
  PRIMARY KEY (asset_type, symbol)
);

-- 預設熱門清單：台股、美股、加密貨幣各 10 檔
INSERT INTO hot_stocks (asset_type, symbol, display_order) VALUES
  -- 台股權值前 10
  ('stock_tw', '2330', 1),   -- 台積電
  ('stock_tw', '2317', 2),   -- 鴻海
  ('stock_tw', '2454', 3),   -- 聯發科
  ('stock_tw', '2308', 4),   -- 台達電
  ('stock_tw', '2891', 5),   -- 中信金
  ('stock_tw', '2882', 6),   -- 國泰金
  ('stock_tw', '2886', 7),   -- 兆豐金
  ('stock_tw', '1301', 8),   -- 台塑
  ('stock_tw', '2412', 9),   -- 中華電
  ('stock_tw', '2382', 10),  -- 廣達
  -- 美股巨頭前 10
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
  -- 加密貨幣前 10
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
