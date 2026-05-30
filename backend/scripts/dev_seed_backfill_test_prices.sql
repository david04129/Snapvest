-- DEBUG ONLY: seed fake symbols for local daily trend backfill testing.
-- Run in Supabase SQL Editor if local env vars are not available.
-- The symbols are intentionally fake-looking to avoid overwriting real market prices.

WITH symbols(asset_type, symbol, currency, base_price, symbol_index) AS (
  VALUES
    ('stock_tw', '990001', 'TWD', 935.0::numeric, 0),
    ('stock_tw', '990002', 'TWD', 182.0::numeric, 1),
    ('stock_tw', '990003', 'TWD', 1260.0::numeric, 2),
    ('stock_tw', '990004', 'TWD', 54.2::numeric, 3),
    ('stock_tw', '990005', 'TWD', 88.6::numeric, 4),
    ('stock_tw', '990006', 'TWD', 182.4::numeric, 5),
    ('stock_tw', '990007', 'TWD', 22.8::numeric, 6),
    ('stock_us', 'ZZTST1', 'USD', 195.5::numeric, 7),
    ('stock_us', 'ZZTST2', 'USD', 430.0::numeric, 8),
    ('stock_us', 'ZZTST3', 'USD', 126.0::numeric, 9),
    ('stock_us', 'ZZTST4', 'USD', 340.0::numeric, 10),
    ('stock_us', 'ZZTST5', 'USD', 505.0::numeric, 11),
    ('stock_us', 'ZZTST6', 'USD', 184.0::numeric, 12),
    ('stock_us', 'ZZTST7', 'USD', 176.0::numeric, 13),
    ('stock_us', 'ZZTST8', 'USD', 585.0::numeric, 14),
    ('crypto', 'TSTBTC', 'USD', 104000.0::numeric, 15),
    ('crypto', 'TSTETH', 'USD', 3850.0::numeric, 16),
    ('crypto', 'TSTSOL', 'USD', 166.0::numeric, 17),
    ('crypto', 'TSTXRP', 'USD', 2.22::numeric, 18),
    ('crypto', 'TSTUSD', 'USD', 1.0::numeric, 19)
),
days(price_date, day_index) AS (
  SELECT
    (timezone('Asia/Taipei', now())::date - offset_days)::date,
    10 - offset_days
  FROM generate_series(10, 1, -1) AS offset_days
),
prices AS (
  SELECT
    s.asset_type,
    s.symbol,
    s.currency,
    d.price_date,
    d.day_index,
    round(
      s.base_price * (
        1
        + (((d.day_index % 5) - 2) * 0.006)
        + ((d.day_index - 4.5) * 0.004)
        + (((s.symbol_index % 4) - 1.5) * 0.003)
      ),
      8
    ) AS close_price
  FROM symbols s
  CROSS JOIN days d
  -- 模擬股票週末/休市：台股與美股故意缺幾天；crypto 仍每天有價。
  WHERE s.asset_type = 'crypto'
    OR d.day_index NOT IN (2, 3, 6)
),
history_cleanup AS (
  DELETE FROM public.asset_price_history h
  USING symbols s, days d
  WHERE h.asset_type = s.asset_type
    AND h.symbol = s.symbol
    AND h.price_date = d.price_date
  RETURNING 1
),
history_upsert AS (
  INSERT INTO public.asset_price_history (
    asset_type,
    symbol,
    price_date,
    close_price,
    currency,
    source,
    updated_at
  )
  SELECT
    asset_type,
    symbol,
    price_date,
    close_price,
    currency,
    'dev_seed',
    date_trunc('second', timezone('Asia/Taipei', now()))
  FROM prices
  ON CONFLICT (asset_type, symbol, price_date)
  DO UPDATE SET
    close_price = EXCLUDED.close_price,
    currency = EXCLUDED.currency,
    source = EXCLUDED.source,
    updated_at = EXCLUDED.updated_at
  RETURNING 1
),
snapshot_source AS (
  SELECT
    asset_type,
    symbol,
    currency,
    max(close_price) FILTER (WHERE day_index = 9) AS current_price,
    max(price_date) FILTER (WHERE day_index = 9) AS current_close_date,
    max(close_price) FILTER (WHERE day_index = 8) AS previous_price,
    max(price_date) FILTER (WHERE day_index = 8) AS previous_close_date
  FROM prices
  GROUP BY asset_type, symbol, currency
),
snapshot_upsert AS (
  INSERT INTO public.asset_price_snapshots (
    asset_type,
    symbol,
    currency,
    current_price,
    current_close_date,
    current_updated_at,
    current_price_source,
    previous_price,
    previous_close_date,
    previous_updated_at,
    previous_price_source
  )
  SELECT
    asset_type,
    symbol,
    currency,
    current_price,
    current_close_date,
    date_trunc('second', timezone('Asia/Taipei', now())),
    'dev_seed',
    previous_price,
    previous_close_date,
    date_trunc('second', timezone('Asia/Taipei', now())),
    'dev_seed'
  FROM snapshot_source
  ON CONFLICT (asset_type, symbol)
  DO UPDATE SET
    currency = EXCLUDED.currency,
    current_price = EXCLUDED.current_price,
    current_close_date = EXCLUDED.current_close_date,
    current_updated_at = EXCLUDED.current_updated_at,
    current_price_source = EXCLUDED.current_price_source,
    previous_price = EXCLUDED.previous_price,
    previous_close_date = EXCLUDED.previous_close_date,
    previous_updated_at = EXCLUDED.previous_updated_at,
    previous_price_source = EXCLUDED.previous_price_source
  RETURNING 1
),
fx_upsert AS (
  INSERT INTO public.exchange_rates (
    from_currency,
    to_currency,
    rate,
    updated_at
  )
  VALUES (
    'USD',
    'TWD',
    32.15,
    date_trunc('second', timezone('Asia/Taipei', now()))
  )
  ON CONFLICT (from_currency, to_currency)
  DO UPDATE SET
    rate = EXCLUDED.rate,
    updated_at = EXCLUDED.updated_at
  RETURNING 1
)
SELECT
  (SELECT count(*) FROM history_cleanup) AS deleted_history_rows,
  (SELECT count(*) FROM history_upsert) AS history_rows,
  (SELECT count(*) FROM snapshot_upsert) AS snapshot_rows,
  (SELECT count(*) FROM fx_upsert) AS fx_rows;
