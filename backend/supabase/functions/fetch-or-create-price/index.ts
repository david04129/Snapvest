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
const NY_TZ = "America/New_York"

function marketTimeZone(assetType: string): string {
  return assetType === "stock_us" ? NY_TZ : TAIPEI_TZ
}

function closeDateString(d: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d)
}

function closeDateFromUnixSeconds(sec: number, timeZone: string): string {
  return closeDateString(new Date(sec * 1000), timeZone)
}

function marketTodayKey(assetType: string): string {
  return closeDateString(new Date(), marketTimeZone(assetType))
}

function taipeiUpdatedAtSeconds(d = new Date()): string {
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

async function fetchYahooChart(yahooSymbol: string): Promise<Response> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}?interval=1d&range=5d`
  return fetch(url, { headers: yahooFetchHeaders })
}

type YahooBar = { ts: number; close: number }

type YahooStockQuote = {
  currentPrice: number
  currentCloseDate: string
  previousPrice: number | null
  previousCloseDate: string | null
}

function validPrice(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n) && n > 0
}

function parseYahooStockChart(json: Record<string, unknown>, assetType: string): YahooStockQuote | null {
  const result = (json as {
    chart?: {
      result?: Array<{
        meta?: Record<string, unknown>
        timestamp?: number[]
        indicators?: { quote?: Array<{ close?: (number | null)[] }> }
      }>
    }
  })?.chart?.result?.[0]
  if (!result) return null

  const meta = result.meta ?? {}
  const tz = marketTimeZone(assetType)
  const timestamps = result.timestamp ?? []
  const closes = result.indicators?.quote?.[0]?.close ?? []

  const bars: YahooBar[] = []
  for (let i = 0; i < closes.length; i++) {
    const c = closes[i]
    const ts = timestamps[i]
    if (validPrice(c) && ts != null) bars.push({ ts, close: c })
  }

  let currentPrice: number | null = validPrice(meta.regularMarketPrice)
    ? meta.regularMarketPrice as number
    : null
  if (currentPrice == null && bars.length > 0) {
    currentPrice = bars[bars.length - 1].close
  }
  if (!validPrice(currentPrice)) return null

  let currentCloseDate: string | null = null
  if (typeof meta.regularMarketTime === "number") {
    currentCloseDate = closeDateFromUnixSeconds(meta.regularMarketTime, tz)
  } else if (bars.length > 0) {
    currentCloseDate = closeDateFromUnixSeconds(bars[bars.length - 1].ts, tz)
  }
  if (!currentCloseDate) {
    currentCloseDate = marketTodayKey(assetType)
  }

  let previousPrice: number | null = null
  let previousCloseDate: string | null = null

  if (bars.length >= 2) {
    const prevBar = bars[bars.length - 2]
    previousPrice = prevBar.close
    previousCloseDate = closeDateFromUnixSeconds(prevBar.ts, tz)
  } else {
    const metaPrev = meta.chartPreviousClose ?? meta.regularMarketPreviousClose ?? meta.previousClose
    if (validPrice(metaPrev) && metaPrev !== currentPrice) {
      previousPrice = metaPrev as number
      if (bars.length === 1) {
        previousCloseDate = closeDateFromUnixSeconds(bars[0].ts, tz)
        if (previousCloseDate === currentCloseDate) {
          const d = new Date(bars[0].ts * 1000)
          d.setDate(d.getDate() - 1)
          previousCloseDate = closeDateString(d, tz)
        }
      }
    }
  }

  const todayKey = marketTodayKey(assetType)
  if (previousCloseDate && previousCloseDate >= todayKey) {
    previousCloseDate = null
    previousPrice = null
  }
  if (previousPrice != null && previousPrice === currentPrice) {
    previousPrice = null
    previousCloseDate = null
  }

  return {
    currentPrice,
    currentCloseDate,
    previousPrice,
    previousCloseDate,
  }
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

    const { data: existing } = await supabase
      .from("asset_price_snapshots")
      .select("current_price, previous_price, previous_close_date, currency")
      .eq("asset_type", assetType)
      .eq("symbol", symbol)
      .single()

    if (existing?.current_price) {
      return new Response(
        JSON.stringify({
          price: existing.current_price,
          currency: existing.currency,
          source: "database",
          previousPrice: existing.previous_price ?? null,
          previousCloseDate: existing.previous_close_date ?? null,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    let price: number | null = null
    let priceSource = "yahoo"
    const currency = assetType === "stock_tw" ? "TWD" : "USD"
    let currentCloseDate = marketTodayKey(assetType)
    let previousPrice: number | null = null
    let previousCloseDate: string | null = null

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
      currentCloseDate = marketTodayKey(assetType)
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
      const parsed = parseYahooStockChart(json, assetType)
      if (!parsed) {
        return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
      }
      price = parsed.currentPrice
      currentCloseDate = parsed.currentCloseDate
      previousPrice = parsed.previousPrice
      previousCloseDate = parsed.previousCloseDate
    }

    if (price == null || price <= 0) {
      return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    const updatedAt = taipeiUpdatedAtSeconds()
    const { data: prior } = await supabase
      .from("asset_price_snapshots")
      .select(
        "current_price, current_close_date, current_updated_at, current_price_source, previous_updated_at, previous_price_source",
      )
      .eq("asset_type", assetType)
      .eq("symbol", symbol)
      .maybeSingle()

    const row: Record<string, unknown> = {
      asset_type: assetType,
      symbol,
      currency,
      current_price: price,
      current_close_date: currentCloseDate,
      current_updated_at: updatedAt,
      current_price_source: priceSource,
      price_kind: "intraday",
    }

    if (previousPrice != null && previousCloseDate) {
      row.previous_price = previousPrice
      row.previous_close_date = previousCloseDate
      row.previous_updated_at = updatedAt
      row.previous_price_source = priceSource
    } else if (prior?.current_price) {
      row.previous_price = prior.current_price
      row.previous_close_date = prior.current_close_date
      row.previous_updated_at = prior.current_updated_at
      row.previous_price_source = prior.current_price_source
    }

    await supabase.from("asset_price_snapshots").upsert(row, { onConflict: "asset_type,symbol" })

    const body: Record<string, unknown> = {
      price,
      currency,
      source: priceSource,
      currentCloseDate,
    }
    if (previousPrice != null && previousCloseDate) {
      body.previousPrice = previousPrice
      body.previousCloseDate = previousCloseDate
    }

    return new Response(JSON.stringify(body), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
