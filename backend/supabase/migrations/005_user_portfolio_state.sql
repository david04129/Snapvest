-- 使用者投資組合狀態（App 每次交易後 upsert，供後端每日計算淨資產/總資產）
CREATE TABLE IF NOT EXISTS user_portfolio_state (
  user_id TEXT PRIMARY KEY,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cash JSONB NOT NULL DEFAULT '[]'::jsonb,
  holdings JSONB NOT NULL DEFAULT '[]'::jsonb,
  liabilities JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_user_portfolio_state_synced_at
  ON user_portfolio_state (synced_at DESC);

ALTER TABLE user_portfolio_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read user_portfolio_state"
  ON user_portfolio_state FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon upsert user_portfolio_state"
  ON user_portfolio_state FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Allow anon update user_portfolio_state"
  ON user_portfolio_state FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);
