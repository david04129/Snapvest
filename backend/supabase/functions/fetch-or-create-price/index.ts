// Supabase Edge Function: 新增股票時，若資料庫無價格則即時抓取並儲存
// 台股：Fugle intraday/quote（previousClose）→ Yahoo 5d 備援
// 部署（擇一）:
//   cd backend && supabase functions deploy fetch-or-create-price
//   cd 專案根目錄 && supabase functions deploy fetch-or-create-price
// 呼叫: POST .../functions/v1/fetch-or-create-price  Body: { "assetType": "stock_us", "symbol": "AAPL" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { readAuthContext } from "../_shared/authContext.ts"
import {
  enforceRateLimits,
  enforceWithAnonFallback,
  FETCH_OR_CREATE_ALL_LIMITS,
  FETCH_OR_CREATE_EXTERNAL_LIMITS,
} from "../_shared/rateLimit.ts"
import { fetchFugleTwQuote, type StockQuote } from "../_shared/fugleQuote.ts"
import { allowedAssetTypes, normalizeSymbol } from "../_shared/symbolValidation.ts"

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

/** 台股：上市 `.TW`、上櫃 `.TWO`；美股直接用 symbol。 */
function yahooChartSymbols(assetType: string, symbol: string): string[] {
  if (assetType === "stock_tw") {
    return [`${symbol}.TW`, `${symbol}.TWO`]
  }
  if (assetType === "stock_us") {
    return [symbol]
  }
  return []
}

async function fetchYahooStockQuote(
  assetType: string,
  symbol: string,
): Promise<YahooStockQuote | null> {
  for (const yahooSymbol of yahooChartSymbols(assetType, symbol)) {
    const res = await fetchYahooChart(yahooSymbol)
    if (!res.ok) continue
    let json: Record<string, unknown>
    try {
      json = await res.json()
    } catch {
      continue
    }
    const parsed = parseYahooStockChart(json, assetType)
    if (parsed) return parsed
  }
  return null
}

type YahooBar = { ts: number; close: number }

type YahooStockQuote = Omit<StockQuote, "source">

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

async function fetchTwStockQuote(symbol: string): Promise<StockQuote | null> {
  const fugle = await fetchFugleTwQuote(symbol)
  if (fugle) return fugle
  const yahoo = await fetchYahooStockQuote("stock_tw", symbol)
  if (!yahoo) return null
  return { ...yahoo, source: "yahoo" }
}

async function fetchTwPreviousForBackfill(symbol: string): Promise<StockQuote | null> {
  const fugle = await fetchFugleTwQuote(symbol)
  if (fugle?.previousPrice && fugle.previousCloseDate) return fugle
  const yahoo = await fetchYahooStockQuote("stock_tw", symbol)
  if (!yahoo?.previousPrice || !yahoo.previousCloseDate) return null
  return { ...yahoo, source: "yahoo" }
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

function acceptableCloseDateKeys(assetType: string, now = new Date()): Set<string> {
  const tz = marketTimeZone(assetType)
  const keys = new Set<string>()
  for (let offset = 0; offset <= 3; offset++) {
    const d = new Date(now.getTime() - offset * 86_400_000)
    keys.add(closeDateString(d, tz))
  }
  return keys
}

function isSnapshotCloseDateStale(
  currentCloseDate: string | null | undefined,
  assetType: string,
): boolean {
  if (assetType === "crypto") return false
  if (!currentCloseDate) return true
  return !acceptableCloseDateKeys(assetType).has(currentCloseDate)
}

async function upsertHistoryClose(
  supabase: ReturnType<typeof createClient>,
  assetType: string,
  symbol: string,
  priceDate: string,
  closePrice: number,
  currency: string,
  source: string,
  updatedAt: string,
): Promise<void> {
  await supabase.from("asset_price_history").upsert(
    {
      asset_type: assetType,
      symbol,
      price_date: priceDate,
      close_price: closePrice,
      currency,
      source,
      updated_at: updatedAt,
    },
    { onConflict: "asset_type,symbol,price_date" },
  )
}

async function hasPriorHistoryClose(
  supabase: ReturnType<typeof createClient>,
  assetType: string,
  symbol: string,
  beforeDate: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("asset_price_history")
    .select("price_date")
    .eq("asset_type", assetType)
    .eq("symbol", symbol)
    .lt("price_date", beforeDate)
    .order("price_date", { ascending: false })
    .limit(1)
  return (data?.length ?? 0) > 0
}

async function backfillPreviousHistoryIfMissing(
  supabase: ReturnType<typeof createClient>,
  assetType: string,
  symbol: string,
  currentCloseDate: string,
  existingPreviousPrice: number | null,
  existingPreviousCloseDate: string | null,
  existingPreviousPriceSource: string | null,
  currency: string,
): Promise<{
  previousPrice: number | null
  previousCloseDate: string | null
  previousPriceSource: string | null
}> {
  const updatedAt = taipeiUpdatedAtSeconds()
  const staleTwYahoo =
    assetType === "stock_tw" && existingPreviousPriceSource === "yahoo"
  if (await hasPriorHistoryClose(supabase, assetType, symbol, currentCloseDate) && !staleTwYahoo) {
    return {
      previousPrice: existingPreviousPrice,
      previousCloseDate: existingPreviousCloseDate,
      previousPriceSource: existingPreviousPriceSource,
    }
  }

  if (validPrice(existingPreviousPrice) && existingPreviousCloseDate) {
    const twYahooBootstrap =
      assetType === "stock_tw" && existingPreviousPriceSource === "yahoo"
    if (!twYahooBootstrap) {
      await upsertHistoryClose(
        supabase,
        assetType,
        symbol,
        existingPreviousCloseDate,
        existingPreviousPrice as number,
        currency,
        "snapshot_bootstrap",
        updatedAt,
      )
      return {
        previousPrice: existingPreviousPrice,
        previousCloseDate: existingPreviousCloseDate,
        previousPriceSource: existingPreviousPriceSource,
      }
    }
  }

  if (assetType !== "stock_tw" && assetType !== "stock_us") {
    return { previousPrice: null, previousCloseDate: null, previousPriceSource: null }
  }

  let parsed: StockQuote | null = null
  if (assetType === "stock_tw") {
    parsed = await fetchTwPreviousForBackfill(symbol)
  } else {
    const yahoo = await fetchYahooStockQuote(assetType, symbol)
    if (yahoo?.previousPrice && yahoo.previousCloseDate) {
      parsed = { ...yahoo, source: "yahoo" }
    }
  }
  if (!parsed?.previousPrice || !parsed.previousCloseDate) {
    return { previousPrice: null, previousCloseDate: null, previousPriceSource: null }
  }

  await upsertHistoryClose(
    supabase,
    assetType,
    symbol,
    parsed.previousCloseDate,
    parsed.previousPrice,
    currency,
    parsed.source,
    updatedAt,
  )

  const snapshotPatch: Record<string, unknown> = {
    previous_price: parsed.previousPrice,
    previous_close_date: parsed.previousCloseDate,
    previous_updated_at: updatedAt,
    previous_price_source: parsed.source,
  }
  await supabase
    .from("asset_price_snapshots")
    .update(snapshotPatch)
    .eq("asset_type", assetType)
    .eq("symbol", symbol)

  return {
    previousPrice: parsed.previousPrice,
    previousCloseDate: parsed.previousCloseDate,
    previousPriceSource: parsed.source,
  }
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

    const authContext = readAuthContext(req)
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

    const allLimited = await enforceWithAnonFallback(supabase, req, authContext, FETCH_OR_CREATE_ALL_LIMITS)
    if (allLimited) return allLimited

    const body = await req.json()
    if (Array.isArray(body)) {
      return new Response(JSON.stringify({ error: "body must be a single symbol object" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { assetType, symbol: rawSymbol, coingeckoId } = body ?? {}
    if (typeof assetType !== "string" || typeof rawSymbol !== "string") {
      return new Response(JSON.stringify({ error: "assetType and symbol required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
    if (!allowedAssetTypes.has(assetType)) {
      return new Response(JSON.stringify({ error: "unsupported assetType" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const symbol = normalizeSymbol(assetType, rawSymbol)
    if (!symbol) {
      return new Response(JSON.stringify({ error: "invalid symbol" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { data: existing } = await supabase
      .from("asset_price_snapshots")
      .select("current_price, current_close_date, previous_price, previous_close_date, previous_price_source, currency")
      .eq("asset_type", assetType)
      .eq("symbol", symbol)
      .single()

    if (existing?.current_price) {
      const currentCloseDate = existing.current_close_date ?? marketTodayKey(assetType)
      const currency = existing.currency ?? (assetType === "stock_tw" ? "TWD" : "USD")

      if (!isSnapshotCloseDateStale(currentCloseDate, assetType)) {
        const priorSource = (existing as { previous_price_source?: string }).previous_price_source ?? null
        const twYahooPreviousNeedsRefresh =
          assetType === "stock_tw"
          && priorSource === "yahoo"
          && validPrice(existing.previous_price)
          && !!existing.previous_close_date
        const needsExternalBackfill =
          (assetType === "stock_tw" || assetType === "stock_us")
          && (
            twYahooPreviousNeedsRefresh
            || (
              !(await hasPriorHistoryClose(supabase, assetType, symbol, currentCloseDate))
              && !(validPrice(existing.previous_price) && existing.previous_close_date)
            )
          )
        if (needsExternalBackfill) {
          const externalLimited = await enforceRateLimits(
            supabase,
            req,
            authContext,
            FETCH_OR_CREATE_EXTERNAL_LIMITS,
          )
          if (externalLimited) return externalLimited
        }
        const backfilled = await backfillPreviousHistoryIfMissing(
          supabase,
          assetType,
          symbol,
          currentCloseDate,
          existing.previous_price ?? null,
          existing.previous_close_date ?? null,
          priorSource,
          currency,
        )
        const dbHitBody: Record<string, unknown> = {
          price: existing.current_price,
          currency,
          source: "database",
          currentCloseDate,
          previousPrice: backfilled.previousPrice,
          previousCloseDate: backfilled.previousCloseDate,
        }
        if (backfilled.previousPriceSource) {
          dbHitBody.previousPriceSource = backfilled.previousPriceSource
        }
        return new Response(
          JSON.stringify(dbHitBody),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
      // current_close_date 過期 → fall through，台股 Fugle → Yahoo 重新抓取
    }

    const externalLimited = await enforceRateLimits(
      supabase,
      req,
      authContext,
      FETCH_OR_CREATE_EXTERNAL_LIMITS,
    )
    if (externalLimited) return externalLimited

    let price: number | null = null
    let priceSource = "yahoo"
    const currency = assetType === "stock_tw" ? "TWD" : "USD"
    let currentCloseDate = marketTodayKey(assetType)
    let previousPrice: number | null = null
    let previousCloseDate: string | null = null
    let previousPriceSource: string | null = null

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
    } else if (assetType === "stock_tw") {
      const parsed = await fetchTwStockQuote(symbol)
      if (!parsed) {
        return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
      }
      price = parsed.currentPrice
      priceSource = parsed.source
      currentCloseDate = parsed.currentCloseDate
      previousPrice = parsed.previousPrice
      previousCloseDate = parsed.previousCloseDate
      previousPriceSource = parsed.previousPrice ? parsed.source : null
    } else if (assetType === "stock_us") {
      const parsed = await fetchYahooStockQuote(assetType, symbol)
      if (!parsed) {
        return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
      }
      price = parsed.currentPrice
      priceSource = "yahoo"
      currentCloseDate = parsed.currentCloseDate
      previousPrice = parsed.previousPrice
      previousCloseDate = parsed.previousCloseDate
      previousPriceSource = parsed.previousPrice ? "yahoo" : null
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
      row.previous_price_source = previousPriceSource ?? priceSource
    } else if (prior?.current_price) {
      row.previous_price = prior.current_price
      row.previous_close_date = prior.current_close_date
      row.previous_updated_at = prior.current_updated_at
      row.previous_price_source = prior.current_price_source
    }

    const { error: snapshotError } = await supabase.from("asset_price_snapshots").upsert(row, { onConflict: "asset_type,symbol" })
    if (snapshotError) {
      return new Response(JSON.stringify({ error: `snapshot upsert failed: ${snapshotError.message}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    if (previousPrice != null && previousCloseDate) {
      const { error: historyError } = await supabase.from("asset_price_history").upsert(
        {
          asset_type: assetType,
          symbol,
          price_date: previousCloseDate,
          close_price: previousPrice,
          currency,
          source: priceSource,
          updated_at: updatedAt,
        },
        { onConflict: "asset_type,symbol,price_date" },
      )
      if (historyError) {
        return new Response(JSON.stringify({ error: `history upsert failed: ${historyError.message}` }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
    }

    const responseBody: Record<string, unknown> = {
      price,
      currency,
      source: priceSource,
      currentCloseDate,
    }
    if (previousPrice != null && previousCloseDate) {
      responseBody.previousPrice = previousPrice
      responseBody.previousCloseDate = previousCloseDate
      responseBody.previousPriceSource = previousPriceSource ?? priceSource
    }

    return new Response(JSON.stringify(responseBody), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
