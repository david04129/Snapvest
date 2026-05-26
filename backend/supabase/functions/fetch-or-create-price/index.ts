// Supabase Edge Function: 新增股票時，若資料庫無價格則即時抓取並儲存
// 部署（擇一）:
//   cd backend && supabase functions deploy fetch-or-create-price
//   cd 專案根目錄 && supabase functions deploy fetch-or-create-price
// 呼叫: POST .../functions/v1/fetch-or-create-price  Body: { "assetType": "stock_us", "symbol": "AAPL" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" }

const yahooFetchHeaders = {
  "User-Agent": "Mozilla/5.0 (compatible; Snapvest/1.0; +https://snapvest.app)",
  Accept: "application/json",
}

const coingeckoHeaders = {
  "User-Agent": "Mozilla/5.0 (compatible; Snapvest/1.0; +https://snapvest.app)",
  Accept: "application/json",
}

const TAIPEI_TZ = "Asia/Taipei"

function taipeiCloseDateString(d = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TAIPEI_TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d)
}

function taipeiUpdatedAtISOSeconds(d = new Date()): string {
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
  return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}:${get("second")}+08:00`
}

async function fetchYahooChart(yahooSymbol: string): Promise<Response> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}?interval=1d&range=1d`
  return fetch(url, { headers: yahooFetchHeaders })
}

const COINGECKO_ID_MAP: Record<string, string> = {
  BTC: "bitcoin", ETH: "ethereum", BNB: "binancecoin", SOL: "solana",
  XRP: "ripple", ADA: "cardano", DOGE: "dogecoin", AVAX: "avalanche-2",
  DOT: "polkadot", LINK: "chainlink", MATIC: "matic-network",
  PEPE: "pepe", WIF: "dogwifcoin", ETHFI: "ether-fi",
}

async function fetchCoinGeckoUsdPrice(cgId: string): Promise<number | null> {
  const url = `https://api.coingecko.com/api/v3/simple/price?ids=${encodeURIComponent(cgId)}&vs_currencies=usd`
  const res = await fetch(url, { headers: coingeckoHeaders })
  if (!res.ok) return null
  const json = await res.json()
  const price = json?.[cgId]?.usd
  return price != null && Number(price) > 0 ? Number(price) : null
}

async function resolveCoinGeckoId(symbol: string, hint?: string): Promise<string | null> {
  const trimmedHint = hint?.trim()
  if (trimmedHint) return trimmedHint
  if (COINGECKO_ID_MAP[symbol]) return COINGECKO_ID_MAP[symbol]
  const lower = symbol.toLowerCase()
  const fromSimple = await fetchCoinGeckoUsdPrice(lower)
  if (fromSimple != null) return lower
  const searchRes = await fetch(
    `https://api.coingecko.com/api/v3/search?query=${encodeURIComponent(symbol)}`,
    { headers: coingeckoHeaders },
  )
  if (!searchRes.ok) return null
  const searchJson = await searchRes.json()
  const coins: Array<{ id?: string; symbol?: string }> = searchJson?.coins ?? []
  const exact = coins.find((c) => c.symbol?.toUpperCase() === symbol)
  return exact?.id ?? coins[0]?.id ?? null
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

    const { assetType, symbol: rawSymbol, coingeckoId } = await req.json()
    if (!assetType || !rawSymbol) {
      return new Response(JSON.stringify({ error: "assetType and symbol required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    const symbol =
      assetType === "stock_us" || assetType === "crypto"
        ? String(rawSymbol).trim().toUpperCase()
        : String(rawSymbol).trim()

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

    // 1. 檢查 DB 是否已有
    const { data: existing } = await supabase.from("asset_price_snapshots").select("current_price, currency").eq("asset_type", assetType).eq("symbol", symbol).single()
    if (existing?.current_price) {
      return new Response(JSON.stringify({ price: existing.current_price, currency: existing.currency, source: "database" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 2. 從外部 API 抓取
    let price: number | null = null
    let priceSource = "yahoo"
    const currency = assetType === "stock_tw" ? "TWD" : "USD"

    if (assetType === "crypto") {
      priceSource = "coingecko"
      const cgId = await resolveCoinGeckoId(symbol, coingeckoId)
      if (!cgId) {
        return new Response(JSON.stringify({ error: "CoinGecko id not found" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
      price = await fetchCoinGeckoUsdPrice(cgId)
      if (price == null) {
        return new Response(JSON.stringify({ error: "CoinGecko price not found" }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
    } else if (assetType === "stock_tw" || assetType === "stock_us") {
      const yahooSymbol = assetType === "stock_tw" ? `${symbol}.TW` : symbol
      const res = await fetchYahooChart(yahooSymbol)
      if (!res.ok) {
        return new Response(JSON.stringify({ error: `Yahoo API HTTP ${res.status}` }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
      let json: Record<string, unknown>
      try {
        json = await res.json()
      } catch {
        return new Response(JSON.stringify({ error: "Yahoo API returned invalid JSON" }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
      const quote = (json as { chart?: { result?: Array<{ meta?: { regularMarketPrice?: number }; indicators?: { quote?: Array<{ close?: number[] }> } }> } })
        ?.chart?.result?.[0]?.meta?.regularMarketPrice
        ?? (json as { chart?: { result?: Array<{ indicators?: { quote?: Array<{ close?: number[] }> } }> } })
        ?.chart?.result?.[0]?.indicators?.quote?.[0]?.close?.pop()
      price = quote ? Number(quote) : null
    }

    if (price == null || price <= 0) {
      return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 3. 寫入 DB（零散參考價；收盤日＝台北曆日，非排程 EOD）
    const closeDate = taipeiCloseDateString()
    const updatedAt = taipeiUpdatedAtISOSeconds()
    const { data: prior } = await supabase
      .from("asset_price_snapshots")
      .select("current_price, current_close_date, current_updated_at")
      .eq("asset_type", assetType)
      .eq("symbol", symbol)
      .maybeSingle()

    const row: Record<string, unknown> = {
      asset_type: assetType,
      symbol,
      currency,
      current_price: price,
      current_close_date: closeDate,
      current_updated_at: updatedAt,
      price_source: priceSource,
    }
    if (prior?.current_price) {
      row.previous_price = prior.current_price
      row.previous_close_date = prior.current_close_date
      row.previous_updated_at = prior.current_updated_at
    }

    await supabase.from("asset_price_snapshots").upsert(row, { onConflict: "asset_type,symbol" })

    return new Response(JSON.stringify({ price, currency, source: priceSource }), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
