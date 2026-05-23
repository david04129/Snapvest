// Supabase Edge Function: 新增股票時，若資料庫無價格則即時抓取並儲存
// 部署（擇一）:
//   cd backend && supabase functions deploy fetch-or-create-price
//   cd 專案根目錄 && supabase functions deploy fetch-or-create-price
// 呼叫: POST .../functions/v1/fetch-or-create-price  Body: { "assetType": "stock_us", "symbol": "AAPL" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" }

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { assetType, symbol } = await req.json()
    if (!assetType || !symbol) {
      return new Response(JSON.stringify({ error: "assetType and symbol required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

    // 1. 檢查 DB 是否已有
    const { data: existing } = await supabase.from("asset_price_snapshots").select("current_price, currency").eq("asset_type", assetType).eq("symbol", symbol).single()
    if (existing?.current_price) {
      return new Response(JSON.stringify({ price: existing.current_price, currency: existing.currency, source: "database" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 2. 從外部 API 抓取
    let price: number | null = null
    const currency = assetType === "stock_tw" ? "TWD" : "USD"

    if (assetType === "crypto") {
      const idMap: Record<string, string> = {
        BTC: "bitcoin", ETH: "ethereum", BNB: "binancecoin", SOL: "solana",
        XRP: "ripple", ADA: "cardano", DOGE: "dogecoin", AVAX: "avalanche-2",
        DOT: "polkadot", LINK: "chainlink", MATIC: "matic-network",
      }
      const cgId = idMap[symbol.toUpperCase()] || symbol.toLowerCase()
      const res = await fetch(`https://api.coingecko.com/api/v3/simple/price?ids=${cgId}&vs_currencies=usd`)
      const json = await res.json()
      price = json[cgId]?.usd ?? null
    } else if (assetType === "stock_tw" || assetType === "stock_us") {
      const yahooSymbol = assetType === "stock_tw" ? `${symbol}.TW` : symbol
      const res = await fetch(`https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}?interval=1d&range=1d`)
      const json = await res.json()
      const quote = json?.chart?.result?.[0]?.meta?.regularMarketPrice ?? json?.chart?.result?.[0]?.indicators?.quote?.[0]?.close?.pop()
      price = quote ? Number(quote) : null
    }

    if (price == null || price <= 0) {
      return new Response(JSON.stringify({ error: "Price not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } })
    }

    // 3. 寫入 DB（並加入 hot_stocks 以便往後每日更新）
    const now = new Date().toISOString()
    await supabase.from("asset_price_snapshots").upsert({
      asset_type: assetType,
      symbol,
      currency,
      current_price: price,
      current_price_date: now,
      last_updated: now,
      last_successful_update: now,
    }, { onConflict: "asset_type,symbol" })

    await supabase.from("hot_stocks").upsert({ asset_type: assetType, symbol, display_order: 999 }, { onConflict: "asset_type,symbol", ignoreDuplicates: true })

    return new Response(JSON.stringify({ price, currency, source: "api" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } })
  }
})
