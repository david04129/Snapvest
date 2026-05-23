-- 緊急：手動把 USD/TWD 更新為今日近似值（SQL Editor 直接 Run，不需 service role）
-- 自動全幣別更新請部署 Edge Function update-exchange-rates 後用 curl 觸發

UPDATE exchange_rates
SET
  rate = 31.478,
  updated_at = NOW()
WHERE from_currency = 'USD' AND to_currency = 'TWD';

UPDATE price_update_metadata
SET last_updated_at = NOW()
WHERE id = 'global';

-- 確認
SELECT to_currency, rate, updated_at
FROM exchange_rates
WHERE from_currency = 'USD' AND to_currency = 'TWD';
