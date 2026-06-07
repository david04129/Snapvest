-- 選股 catalog OTA：各市場 vn / vn-1 快照與自 epoch.0 起累積的 add/remove patch。
-- App 匿名讀取；寫入僅 service_role（每月排程 sync_symbol_catalog_to_db.py）。

CREATE TABLE IF NOT EXISTS public.symbol_catalog_markets (
  market TEXT PRIMARY KEY CHECK (market IN ('tw', 'us', 'crypto')),
  epoch INT NOT NULL DEFAULT 1 CHECK (epoch >= 1),
  minor INT NOT NULL DEFAULT 0 CHECK (minor >= 0),
  updated_at TIMESTAMP NOT NULL DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  vn_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  vn_minus_1_items JSONB,
  cumulative_adds JSONB NOT NULL DEFAULT '[]'::jsonb,
  cumulative_removes JSONB NOT NULL DEFAULT '[]'::jsonb
);

COMMENT ON TABLE public.symbol_catalog_markets IS
  '選股清單 OTA：vn=現行快照；vn_minus_1=上一版；cumulative_*=自 epoch.0 起累積 patch（僅 symbol 加刪）';
COMMENT ON COLUMN public.symbol_catalog_markets.epoch IS '大版世代（App 發版整包更新時遞增）';
COMMENT ON COLUMN public.symbol_catalog_markets.minor IS 'OTA 小版（同 epoch 內有 symbol 加刪時遞增；epoch.0 為整包基準）';

ALTER TABLE public.symbol_catalog_markets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read symbol_catalog_markets"
  ON public.symbol_catalog_markets FOR SELECT
  TO anon, authenticated
  USING (true);

GRANT SELECT ON TABLE public.symbol_catalog_markets TO anon, authenticated;
GRANT ALL ON TABLE public.symbol_catalog_markets TO service_role;
