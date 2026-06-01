-- 交易所交易日曆（台股 FinMind、美股 Finnhub 同步），供盤中判斷與排程 skip。

CREATE TABLE IF NOT EXISTS public.market_calendar (
  market TEXT NOT NULL CHECK (market IN ('tw', 'us')),
  trade_date DATE NOT NULL,
  is_trading_day BOOLEAN NOT NULL DEFAULT true,
  session_open TIME,
  session_close TIME,
  holiday_name TEXT,
  source TEXT,
  synced_at TIMESTAMP NOT NULL DEFAULT date_trunc('second', timezone('Asia/Taipei', NOW())),
  PRIMARY KEY (market, trade_date)
);

CREATE INDEX IF NOT EXISTS idx_market_calendar_market_date
  ON public.market_calendar (market, trade_date DESC);

ALTER TABLE public.market_calendar ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read market_calendar"
  ON public.market_calendar FOR SELECT
  TO anon
  USING (true);

GRANT SELECT ON TABLE public.market_calendar TO anon;
GRANT ALL ON TABLE public.market_calendar TO service_role;

COMMENT ON TABLE public.market_calendar IS '各交易所交易日／休市日；盤中排程與 market-status Edge 讀取';
