// Supabase Edge Function: 匿名加入全站 tracked_symbols 大池子
// 呼叫: POST .../functions/v1/track-symbol  Body: { "assetType": "stock_us", "symbol": "AAPL" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const allowedAssetTypes = new Set(["stock_tw", "stock_us", "crypto"])
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

function normalizeSymbol(assetType: string, rawSymbol: unknown): string | null {
  const trimmed = String(rawSymbol ?? "").trim()
  if (!trimmed) return null
  if (trimmed.length > 20) return null

  if (assetType === "stock_tw") {
    // 台股 / ETF / 權證：接受 4 到 6 碼英數字，支援 00981A 等字母代號。
    const upper = trimmed.toUpperCase()
    return /^[A-Z0-9]{4,6}$/.test(upper) ? upper : null
  }

  if (assetType === "stock_us") {
    const upper = trimmed.toUpperCase()
    // 美股 ticker：英數與 . -，例如 AAPL、BRK-B、BRK.B。
    return /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(upper) ? upper : null
  }

  if (assetType === "crypto") {
    const upper = trimmed.toUpperCase()
    // 加密 ticker：英數，避免符號注入與任意字串。
    return /^[A-Z0-9]{1,20}$/.test(upper) ? upper : null
  }

  return null
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

    const { assetType, symbol: rawSymbol } = await req.json()
    if (!allowedAssetTypes.has(String(assetType))) {
      return new Response(JSON.stringify({ error: "unsupported assetType" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const normalizedSymbol = normalizeSymbol(String(assetType), rawSymbol)
    if (!normalizedSymbol) {
      return new Response(JSON.stringify({ error: "invalid symbol" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )
    const now = taipeiNowISOSeconds()
    const insertResult = await supabase.from("tracked_symbols").insert(
      {
        asset_type: assetType,
        symbol: normalizedSymbol,
        normalized_symbol: normalizedSymbol,
        first_seen_at: now,
        last_seen_at: now,
        is_active: true,
      },
    )

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
        .eq("normalized_symbol", normalizedSymbol)

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
