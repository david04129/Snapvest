// Supabase Edge Function: 一次讀取多檔目前價、歷史價與主要匯率。
// 呼叫: POST .../functions/v1/fetch-prices-batch

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { readAuthContext } from "../_shared/authContext.ts"
import {
  enforceWithAnonFallback,
  FETCH_PRICES_BATCH_LIMITS,
} from "../_shared/rateLimit.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const allowedAssetTypes = new Set(["stock_tw", "stock_us", "crypto"])
const maxSymbols = 100
const maxHistoryDays = 120
const maxPriceSlots = 6000

type SymbolInput = {
  assetType?: unknown
  symbol?: unknown
}

type NormalizedSymbol = {
  assetType: string
  symbol: string
  key: string
  currency: string
}

function normalizeSymbol(assetType: string, rawSymbol: unknown): string | null {
  const trimmed = String(rawSymbol ?? "").trim()
  if (!trimmed || trimmed.length > 20) return null

  if (assetType === "stock_tw") {
    return /^\d{4,6}$/.test(trimmed) ? trimmed : null
  }

  if (assetType === "stock_us") {
    const upper = trimmed.toUpperCase()
    return /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(upper) ? upper : null
  }

  if (assetType === "crypto") {
    const upper = trimmed.toUpperCase()
    return /^[A-Z0-9]{1,20}$/.test(upper) ? upper : null
  }

  return null
}

function quoteCurrency(assetType: string): string {
  return assetType === "stock_tw" ? "TWD" : "USD"
}

function dateFromKey(value: unknown): Date | null {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null
  const parsed = new Date(`${value}T00:00:00Z`)
  return Number.isNaN(parsed.getTime()) || dateKey(parsed) !== value ? null : parsed
}

function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function dateKeysInclusive(start: Date, end: Date): string[] {
  const keys: string[] = []
  const cursor = new Date(start)
  while (cursor <= end) {
    keys.push(dateKey(cursor))
    cursor.setUTCDate(cursor.getUTCDate() + 1)
  }
  return keys
}

function daysInclusive(start: Date, end: Date): number {
  const dayMs = 24 * 60 * 60 * 1000
  return Math.floor((end.getTime() - start.getTime()) / dayMs) + 1
}

function decimalNumber(value: unknown): number | null {
  const number = Number(value)
  return Number.isFinite(number) && number > 0 ? number : null
}

function compactRows<T extends { asset_type?: string; symbol?: string }>(
  rows: T[] | null,
  requestedKeys: Set<string>,
): T[] {
  return (rows ?? []).filter((row) => {
    const assetType = String(row.asset_type ?? "")
    const symbol = String(row.symbol ?? "")
    return requestedKeys.has(`${assetType}:${symbol}`)
  })
}

type PreviousCloseGroup = {
  assetType: string
  currentDate: string
  symbols: string[]
}

async function previousCloseDateForGroup(
  supabase: ReturnType<typeof createClient>,
  group: PreviousCloseGroup,
): Promise<string | null> {
  const { data } = await supabase
    .from("asset_price_history")
    .select("price_date")
    .eq("asset_type", group.assetType)
    .in("symbol", group.symbols)
    .lt("price_date", group.currentDate)
    .order("price_date", { ascending: false })
    .limit(1)

  const priceDate = data?.[0]?.price_date
  return typeof priceDate === "string" ? priceDate.slice(0, 10) : null
}

async function applyHistoryBackedPreviousCloses(
  supabase: ReturnType<typeof createClient>,
  symbols: NormalizedSymbol[],
  current: Record<string, number | null>,
  currentDates: Record<string, string | null>,
  previous: Record<string, number | null>,
  previousDates: Record<string, string | null>,
  previousSources: Record<string, string | null>,
  currencies: Record<string, string>,
) {
  const groups = new Map<string, PreviousCloseGroup>()
  for (const s of symbols) {
    if (current[s.key] == null) continue
    const currentDate = currentDates[s.key]
    if (!currentDate) continue
    const groupKey = `${s.assetType}:${currentDate}`
    const existing = groups.get(groupKey)
    if (existing) {
      existing.symbols.push(s.symbol)
    } else {
      groups.set(groupKey, {
        assetType: s.assetType,
        currentDate,
        symbols: [s.symbol],
      })
    }
  }

  for (const group of groups.values()) {
    group.symbols = [...new Set(group.symbols)]
    const previousDate = await previousCloseDateForGroup(supabase, group)
    if (!previousDate) continue

    const { data } = await supabase
      .from("asset_price_history")
      .select("asset_type,symbol,price_date,close_price,currency")
      .eq("asset_type", group.assetType)
      .eq("price_date", previousDate)
      .in("symbol", group.symbols)

    for (const row of data ?? []) {
      const assetType = String(row.asset_type ?? "")
      const symbol = String(row.symbol ?? "")
      const key = `${assetType}:${symbol}`
      const closePrice = decimalNumber(row.close_price)
      if (closePrice == null) continue
      previous[key] = closePrice
      previousDates[key] = previousDate
      previousSources[key] = "asset_price_history"
      if (typeof row.currency === "string" && row.currency.length > 0) {
        currencies[key] = row.currency
      }
    }
  }
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

    // Phase B：per-user 限流（無 JWT 時 anon + 更嚴兜底）
    const authContext = readAuthContext(req)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )
    const rateLimited = await enforceWithAnonFallback(
      supabase,
      req,
      authContext,
      FETCH_PRICES_BATCH_LIMITS,
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

    const normalizedByKey = new Map<string, NormalizedSymbol>()
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
      const key = `${assetType}:${symbol}`
      normalizedByKey.set(key, { assetType, symbol, key, currency: quoteCurrency(assetType) })
    }

    const symbols = [...normalizedByKey.values()]
    const requestedKeys = new Set(symbols.map((s) => s.key))
    const includeCurrent = body?.includeCurrent !== false
    const history = body?.history
    const startDate = history ? dateFromKey(history.startDate) : null
    const endDate = history ? dateFromKey(history.endDate) : null

    if ((history && (!startDate || !endDate)) || (startDate && endDate && startDate > endDate)) {
      return new Response(JSON.stringify({ error: "invalid history date range" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
    if (startDate && endDate && daysInclusive(startDate, endDate) > maxHistoryDays) {
      return new Response(JSON.stringify({ error: `history range exceeds ${maxHistoryDays} days` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
    const estimatedHistoryDays = startDate && endDate ? daysInclusive(startDate, endDate) : 0
    const priceSlots = symbols.length * estimatedHistoryDays
    if (priceSlots > maxPriceSlots) {
      return new Response(JSON.stringify({ error: `request exceeds ${maxPriceSlots} price slots` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const assetTypes = [...new Set(symbols.map((s) => s.assetType))]
    const symbolValues = [...new Set(symbols.map((s) => s.symbol))]
    const currencies: Record<string, string> = Object.fromEntries(symbols.map((s) => [s.key, s.currency]))

    const current: Record<string, number | null> = {}
    const previous: Record<string, number | null> = {}
    const currentDates: Record<string, string | null> = {}
    const previousDates: Record<string, string | null> = {}
    const previousSources: Record<string, string | null> = {}
    const priceKind: Record<string, string | null> = {}
    const currentUpdatedAt: Record<string, string | null> = {}
    if (includeCurrent) {
      for (const s of symbols) {
        current[s.key] = null
        previous[s.key] = null
        currentDates[s.key] = null
        previousDates[s.key] = null
        previousSources[s.key] = null
        priceKind[s.key] = null
        currentUpdatedAt[s.key] = null
      }

      const { data, error } = await supabase
        .from("asset_price_snapshots")
        .select("asset_type,symbol,currency,current_price,previous_price,current_close_date,previous_close_date,current_updated_at,previous_updated_at,current_price_source,previous_price_source,price_kind")
        .in("asset_type", assetTypes)
        .in("symbol", symbolValues)

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }

      for (const row of compactRows(data, requestedKeys)) {
        const key = `${row.asset_type}:${row.symbol}`
        current[key] = decimalNumber(row.current_price)
        currentDates[key] = typeof row.current_close_date === "string" ? row.current_close_date.slice(0, 10) : null
        priceKind[key] = typeof row.price_kind === "string" ? row.price_kind : null
        currentUpdatedAt[key] = typeof row.current_updated_at === "string" ? row.current_updated_at : null
        if (typeof row.currency === "string" && row.currency.length > 0) {
          currencies[key] = row.currency
        }
      }

      await applyHistoryBackedPreviousCloses(
        supabase,
        symbols,
        current,
        currentDates,
        previous,
        previousDates,
        previousSources,
        currencies,
      )
    }

    const dates = startDate && endDate ? dateKeysInclusive(startDate, endDate) : []
    const historyMatrix: Record<string, Array<number | null>> = {}
    if (dates.length > 0) {
      for (const s of symbols) {
        historyMatrix[s.key] = Array(dates.length).fill(null)
      }

      const dateIndex = new Map(dates.map((d, index) => [d, index]))
      const { data, error } = await supabase
        .from("asset_price_history")
        .select("asset_type,symbol,price_date,close_price,currency")
        .in("asset_type", assetTypes)
        .in("symbol", symbolValues)
        .gte("price_date", dates[0])
        .lte("price_date", dates[dates.length - 1])
        .order("price_date", { ascending: true })

      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }

      for (const row of compactRows(data, requestedKeys)) {
        const key = `${row.asset_type}:${row.symbol}`
        const day = typeof row.price_date === "string" ? row.price_date.slice(0, 10) : ""
        const index = dateIndex.get(day)
        if (index == null) continue
        historyMatrix[key][index] = decimalNumber(row.close_price)
        if (typeof row.currency === "string" && row.currency.length > 0) {
          currencies[key] = row.currency
        }
      }
    }

    const fx: Record<string, number> = { "TWD:TWD": 1 }
    const fxUpdatedAt: Record<string, string | null> = {}
    if (Object.values(currencies).includes("USD")) {
      const { data } = await supabase
        .from("exchange_rates")
        .select("from_currency,to_currency,rate,previous_rate,updated_at,previous_updated_at")
        .eq("from_currency", "USD")
        .eq("to_currency", "TWD")
        .limit(1)
        .maybeSingle()

      const hasCurrentRate = decimalNumber(data?.rate) != null
      const rate = decimalNumber(data?.rate) ?? decimalNumber(data?.previous_rate)
      if (rate != null) {
        fx["USD:TWD"] = rate
        const updatedAt =
          hasCurrentRate && typeof data?.updated_at === "string"
            ? data.updated_at
            : typeof data?.previous_updated_at === "string"
              ? data.previous_updated_at
              : typeof data?.updated_at === "string"
                ? data.updated_at
                : null
        fxUpdatedAt["USD:TWD"] = updatedAt
      }
    }

    return new Response(
      JSON.stringify({
        dates,
        history: historyMatrix,
        current,
        previous,
        currentDates,
        previousDates,
        previousSources,
        priceKind,
        currentUpdatedAt,
        currencies,
        fx,
        fxUpdatedAt,
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
