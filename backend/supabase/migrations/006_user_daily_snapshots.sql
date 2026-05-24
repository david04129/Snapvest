-- 使用者每日淨資產／總資產快照（後端 22:30 TW 排程寫入，供 App 走勢圖）
CREATE TABLE IF NOT EXISTS user_daily_snapshots (
  user_id TEXT NOT NULL,
  snapshot_date DATE NOT NULL,
  total_assets DECIMAL(18, 2) NOT NULL DEFAULT 0,
  total_liabilities DECIMAL(18, 2) NOT NULL DEFAULT 0,
  net_worth DECIMAL(18, 2) NOT NULL DEFAULT 0,
  total_cash DECIMAL(18, 2) NOT NULL DEFAULT 0,
  total_investments DECIMAL(18, 2) NOT NULL DEFAULT 0,
  unrealized_gain_loss DECIMAL(18, 2) NOT NULL DEFAULT 0,
  base_currency TEXT NOT NULL DEFAULT 'TWD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_user_daily_snapshots_date
  ON user_daily_snapshots (snapshot_date DESC);

CREATE INDEX IF NOT EXISTS idx_user_daily_snapshots_user_date
  ON user_daily_snapshots (user_id, snapshot_date DESC);

ALTER TABLE user_daily_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read user_daily_snapshots"
  ON user_daily_snapshots FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow service_role write user_daily_snapshots"
  ON user_daily_snapshots FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

GRANT SELECT ON user_daily_snapshots TO anon;
GRANT ALL ON user_daily_snapshots TO service_role;
