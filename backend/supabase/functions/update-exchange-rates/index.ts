// 每日／手動更新 exchange_rates（open.er-api.com）
// 部署: cd backend && supabase functions deploy update-exchange-rates
// 觸發: POST {SUPABASE_URL}/functions/v1/update-exchange-rates
//       Header: Authorization + apikey = SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const EXCHANGE_RATE_API_URL = "https://open.er-api.com/v6/latest/USD"
const CHUNK_SIZE = 100
const TAIPEI_TZ = "Asia/Taipei"

function taipeiLocalTimestampSeconds(d = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: TAIPEI_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(d)
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "00"
  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")}:${get("second")}`
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !serviceKey) {
      return new Response(JSON.stringify({ error: "Missing Supabase env" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const apiRes = await fetch(EXCHANGE_RATE_API_URL)
    if (!apiRes.ok) {
      return new Response(JSON.stringify({ error: `Exchange API HTTP ${apiRes.status}` }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const payload = await apiRes.json() as { result?: string; rates?: Record<string, number> }
    if (payload.result !== "success" || !payload.rates) {
      return new Response(JSON.stringify({ error: "Exchange API invalid payload" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const now = new Date().toISOString()
    const metadataUpdatedAt = taipeiLocalTimestampSeconds()
    const rows = Object.entries(payload.rates)
      .filter(([, rate]) => typeof rate === "number" && rate > 0 && Number.isFinite(rate))
      .map(([to_currency, rate]) => ({
        from_currency: "USD",
        to_currency,
        rate: String(rate),
        updated_at: now,
      }))

    if (rows.length === 0) {
      return new Response(JSON.stringify({ error: "No valid rates" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const supabase = createClient(supabaseUrl, serviceKey)

    for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
      const chunk = rows.slice(i, i + CHUNK_SIZE)
      const { error } = await supabase
        .from("exchange_rates")
        .upsert(chunk, { onConflict: "from_currency,to_currency" })
      if (error) {
        return new Response(JSON.stringify({ error: error.message, chunk: i / CHUNK_SIZE }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
    }

    const { error: metaError } = await supabase
      .from("price_update_metadata")
      .upsert({ id: "global", last_updated_at: metadataUpdatedAt }, { onConflict: "id" })
    if (metaError) {
      return new Response(JSON.stringify({ error: metaError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const twd = payload.rates.TWD
    return new Response(
      JSON.stringify({
        ok: true,
        count: rows.length,
        twd,
        updated_at: now,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
