-- 匯率表已存在（003 跑過）時，只補這段即可；可重複執行
-- 在 SQL Editor 另存為：「Exchange Rates - Service Role Write」

DROP POLICY IF EXISTS "Allow service_role write exchange_rates" ON exchange_rates;

CREATE POLICY "Allow service_role write exchange_rates"
  ON exchange_rates
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

GRANT SELECT ON exchange_rates TO anon;
GRANT ALL ON exchange_rates TO service_role;
