// Supabase Edge Function: 批量匿名加入 tracked_symbols
// 呼叫: POST .../functions/v1/track-symbols-batch
// Body: { "symbols": [{ "assetType": "stock_us", "symbol": "AAPL" }, ...] }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { readAuthContext } from "../_shared/authContext.ts"
import {
  enforceWithAnonFallback,
  TRACK_SYMBOLS_BATCH_LIMITS,
} from "../_shared/rateLimit.ts"
import { allowedAssetTypes, normalizeSymbol } from "../_shared/symbolValidation.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const maxSymbols = 100
const TAIPEI_TZ = "Asia/Taipei"

function taipeiNowISOSeconds(d = new Date()): string {
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

type SymbolInput = {
  assetType?: unknown
  symbol?: unknown
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const apikey = req.headers.get("apikey")?.trim()
    if (!apikey) {
      return new Response(JSON.stringify({ error: "apikey required" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const authContext = readAuthContext(req)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const rateLimited = await enforceWithAnonFallback(
      supabase,
      req,
      authContext,
      TRACK_SYMBOLS_BATCH_LIMITS,
    )
    if (rateLimited) return rateLimited

    const body = await req.json()
    const rawSymbols = Array.isArray(body?.symbols) ? body.symbols as SymbolInput[] : []
    if (rawSymbols.length === 0 || rawSymbols.length > maxSymbols) {
      return new Response(JSON.stringify({ error: `symbols must contain 1-${maxSymbols} items` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const normalizedByKey = new Map<string, { assetType: string; symbol: string }>()
    for (const raw of rawSymbols) {
      const assetType = String(raw.assetType ?? "")
      if (!allowedAssetTypes.has(assetType)) {
        return new Response(JSON.stringify({ error: "unsupported assetType" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
      const symbol = normalizeSymbol(assetType, raw.symbol)
      if (!symbol) {
        return new Response(JSON.stringify({ error: "invalid symbol" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
      normalizedByKey.set(`${assetType}:${symbol}`, { assetType, symbol })
    }

    const now = taipeiNowISOSeconds()
    let tracked = 0

    for (const { assetType, symbol } of normalizedByKey.values()) {
      const insertResult = await supabase.from("tracked_symbols").insert({
        asset_type: assetType,
        symbol,
        normalized_symbol: symbol,
        first_seen_at: now,
        last_seen_at: now,
        is_active: true,
      })

      if (insertResult.error && insertResult.error.code !== "23505") {
        return new Response(JSON.stringify({ error: insertResult.error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }

      if (insertResult.error?.code === "23505") {
        const { error } = await supabase
          .from("tracked_symbols")
          .update({ last_seen_at: now, is_active: true })
          .eq("asset_type", assetType)
          .eq("normalized_symbol", symbol)

        if (error) {
          return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          })
        }
      }

      tracked += 1
    }

    return new Response(JSON.stringify({ ok: true, tracked }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
