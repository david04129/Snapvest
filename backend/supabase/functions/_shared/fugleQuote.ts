// Fugle 台股 intraday/quote — 現價與前收（previousClose / referencePrice）

const FUGLE_STOCK_BASE = "https://api.fugle.tw/marketdata/v1.0/stock"
const TAIPEI_TZ = "Asia/Taipei"

export type StockQuote = {
  currentPrice: number
  currentCloseDate: string
  previousPrice: number | null
  previousCloseDate: string | null
  source: "fugle" | "yahoo"
}

function validPrice(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n) && n > 0
}

function closeDateString(d: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d)
}

function parseDateKey(value: unknown): string | null {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}/.test(value)) return null
  return value.slice(0, 10)
}

function weekdayInTimeZone(d: Date, timeZone: string): number {
  const wd = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" }).format(d)
  const map: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }
  return map[wd] ?? 1
}

/** 往前找最近一個週一至週五（不含 holidays；與排程 fallback 一致）。 */
export function priorTradingDayKey(fromKey: string, timeZone = TAIPEI_TZ): string {
  const [y, m, d] = fromKey.split("-").map(Number)
  const cursor = new Date(Date.UTC(y, m - 1, d, 12, 0, 0))
  for (let i = 0; i < 10; i++) {
    cursor.setUTCDate(cursor.getUTCDate() - 1)
    const key = closeDateString(cursor, timeZone)
    const dow = weekdayInTimeZone(cursor, timeZone)
    if (dow !== 0 && dow !== 6) return key
  }
  cursor.setUTCDate(cursor.getUTCDate() - 1)
  return closeDateString(cursor, timeZone)
}

export function marketTodayKey(timeZone = TAIPEI_TZ): string {
  return closeDateString(new Date(), timeZone)
}

type FugleQuoteBody = {
  date?: string
  lastPrice?: number
  closePrice?: number
  previousClose?: number
  referencePrice?: number
}

export async function fetchFugleTwQuote(symbol: string): Promise<StockQuote | null> {
  const apiKey = Deno.env.get("FUGLE_API_KEY")?.trim()
  if (!apiKey) return null

  const encoded = encodeURIComponent(symbol)
  const url = `${FUGLE_STOCK_BASE}/intraday/quote/${encoded}`
  let res: Response
  try {
    res = await fetch(url, { headers: { "X-API-KEY": apiKey } })
  } catch {
    return null
  }
  if (!res.ok) return null

  let body: FugleQuoteBody
  try {
    body = await res.json()
  } catch {
    return null
  }

  let currentPrice: number | null = validPrice(body.lastPrice) ? body.lastPrice! : null
  if (currentPrice == null && validPrice(body.closePrice)) {
    currentPrice = body.closePrice!
  }
  if (!validPrice(currentPrice)) return null

  const currentCloseDate = parseDateKey(body.date) ?? marketTodayKey()

  let previousPrice: number | null = null
  if (validPrice(body.previousClose)) {
    previousPrice = body.previousClose!
  } else if (validPrice(body.referencePrice)) {
    previousPrice = body.referencePrice!
  }

  let previousCloseDate: string | null = null
  if (previousPrice != null && previousPrice !== currentPrice) {
    previousCloseDate = priorTradingDayKey(currentCloseDate)
    const todayKey = marketTodayKey()
    if (previousCloseDate >= todayKey || previousCloseDate >= currentCloseDate) {
      previousCloseDate = null
      previousPrice = null
    }
  } else {
    previousPrice = null
  }

  return {
    currentPrice,
    currentCloseDate,
    previousPrice,
    previousCloseDate,
    source: "fugle",
  }
}
