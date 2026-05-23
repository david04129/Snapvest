#!/usr/bin/env bash
# 手動觸發匯率更新（需已部署 update-exchange-rates Edge Function）
set -euo pipefail

: "${SUPABASE_URL:?請 export SUPABASE_URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?請 export SUPABASE_SERVICE_ROLE_KEY（Dashboard > API > service_role）}"

URL="${SUPABASE_URL%/}/functions/v1/update-exchange-rates"
echo "POST $URL"
curl -sS -X POST "$URL" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" | python3 -m json.tool

echo ""
echo "驗證 TWD："
curl -sS "${SUPABASE_URL%/}/rest/v1/exchange_rates?from_currency=eq.USD&to_currency=eq.TWD&select=rate,updated_at" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" | python3 -m json.tool
