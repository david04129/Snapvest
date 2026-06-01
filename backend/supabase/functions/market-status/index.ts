// GET/POST .../functions/v1/market-status
// 回傳台股／美股／加密市場盤中狀態（台北時間 asOf）

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const TAIPEI = "Asia/Taipei"
const NEW_YORK = "America/New_York"

type MarketCode = "tw" | "us" | "crypto"

function twNow(): Date {
  return new Date()
}

function localParts(d: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(d)
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "00"
  return {
    date: `${get("year")}-${get("month")}-${get("day")}`,
    hour: Number(get("hour")),
    minute: Number(get("minute")),
  }
}

function minutesSinceMidnight(hour: number, minute: number): number {
  return hour * 60 + minute
}

function isWeekday(dateStr: string, timeZone: string, d: Date): boolean {
  const wd = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" }).format(d)
  return wd !== "Sat" && wd !== "Sun"
}

function isTwRegular(d: Date): boolean {
  const { hour, minute } = localParts(d, TAIPEI)
  const m = minutesSinceMidnight(hour, minute)
  return m >= 9 * 60 && m <= 13 * 60 + 30
}

function isUsRegular(d: Date): boolean {
  const { hour, minute } = localParts(d, NEW_YORK)
  const m = minutesSinceMidnight(hour, minute)
  return m >= 9 * 60 + 30 && m <= 16 * 60
}

type CalRow = { market: string; trade_date: string; is_trading_day: boolean; holiday_name: string | null }

function buildCalIndex(rows: CalRow[]): Map<string, CalRow> {
  const m = new Map<string, CalRow>()
  for (const r of rows) {
    m.set(`${r.market}:${r.trade_date}`, r)
  }
  return m
}

function tradingDayFromCalendar(
  cal: Map<string, CalRow>,
  market: "tw" | "us",
  dateStr: string,
  d: Date,
  timeZone: string,
): { isTradingDay: boolean; reason: string | null } {
  const row = cal.get(`${market}:${dateStr}`)
  if (row) {
    if (!row.is_trading_day) {
      return { isTradingDay: false, reason: row.holiday_name ?? "holiday" }
    }
    return { isTradingDay: true, reason: null }
  }
  if (!isWeekday(dateStr, timeZone, d)) {
    return { isTradingDay: false, reason: "weekend" }
  }
  return { isTradingDay: true, reason: "calendar_missing" }
}

function statusForMarket(market: MarketCode, d: Date, cal: Map<string, CalRow>) {
  if (market === "crypto") {
    return {
      isTradingDay: true,
      isRegularSession: true,
      isIntradayActive: true,
      session: "regular",
      reason: null,
    }
  }

  const timeZone = market === "tw" ? TAIPEI : NEW_YORK
  const { date: dateStr } = localParts(d, timeZone)
  const { isTradingDay, reason: dayReason } = tradingDayFromCalendar(cal, market, dateStr, d, timeZone)

  if (!isTradingDay) {
    return {
      isTradingDay: false,
      isRegularSession: false,
      isIntradayActive: false,
      session: "holiday",
      reason: dayReason,
    }
  }

  const inRegular = market === "tw" ? isTwRegular(d) : isUsRegular(d)
  if (inRegular) {
    return {
      isTradingDay: true,
      isRegularSession: true,
      isIntradayActive: true,
      session: "regular",
      reason: null,
    }
  }

  return {
    isTradingDay: true,
    isRegularSession: false,
    isIntradayActive: false,
    session: "closed",
    reason: "outside_session",
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    const now = twNow()
    const tw = localParts(now, TAIPEI)
    const start = new Date(now)
    start.setDate(start.getDate() - 7)
    const end = new Date(now)
    end.setDate(end.getDate() + 60)

    const startStr = start.toISOString().slice(0, 10)
    const endStr = end.toISOString().slice(0, 10)

    const { data: calRows, error } = await supabase
      .from("market_calendar")
      .select("market, trade_date, is_trading_day, holiday_name")
      .gte("trade_date", startStr)
      .lte("trade_date", endStr)

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const cal = buildCalIndex((calRows ?? []) as CalRow[])
    const asOf = `${tw.date}T${String(tw.hour).padStart(2, "0")}:${String(tw.minute).padStart(2, "0")}:00+08:00`

    const markets = {
      tw: statusForMarket("tw", now, cal),
      us: statusForMarket("us", now, cal),
      crypto: statusForMarket("crypto", now, cal),
    }

    return new Response(JSON.stringify({ asOf, markets }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
