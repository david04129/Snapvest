-- Snapvest 股價系統 - RLS 政策
-- 讓 App（使用 anon/publishable key）可以讀取股價，但無法寫入
-- 執行方式：在 Supabase Dashboard > SQL Editor 中執行

-- 1. 啟用 RLS（若尚未啟用）
ALTER TABLE asset_price_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_update_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE hot_stocks ENABLE ROW LEVEL SECURITY;

-- 2. 允許任何人（anon）讀取股價（供 App 顯示）
CREATE POLICY "Allow anon read asset_price_snapshots"
  ON asset_price_snapshots FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon read price_update_metadata"
  ON price_update_metadata FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon read hot_stocks"
  ON hot_stocks FOR SELECT
  TO anon
  USING (true);
