// Phase B：per-user（JWT sub）或 anon（apikey + IP）滑動視窗限流

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"
import { AuthContext } from "./authContext.ts"

export type RateLimitRule = {
  prefix: string
  limit: number
  windowSeconds: number
}

export type RateLimitCheckResult = {
  allowed: boolean
  retryAfterSeconds: number
  count: number
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

export function rateLimitIdentity(auth: AuthContext, req: Request): string {
  if (auth.mode === "jwt" && auth.userId) {
    return `user:${auth.userId}`
  }
  const apikey = req.headers.get("apikey")?.trim() ?? "no-key"
  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("x-real-ip")?.trim() ??
    req.headers.get("cf-connecting-ip")?.trim() ??
    "unknown"
  return `anon:${apikey.slice(-16)}:${ip}`
}

function bucketKey(prefix: string, identity: string, windowSeconds: number): string {
  return `${prefix}:${identity}:w${windowSeconds}`
}

export async function checkRateLimit(
  supabase: SupabaseClient,
  req: Request,
  auth: AuthContext,
  rule: RateLimitRule,
): Promise<RateLimitCheckResult> {
  const identity = rateLimitIdentity(auth, req)
  const key = bucketKey(rule.prefix, identity, rule.windowSeconds)
  const { data, error } = await supabase.rpc("check_edge_rate_limit", {
    p_bucket_key: key,
    p_limit: rule.limit,
    p_window_seconds: rule.windowSeconds,
  })

  if (error) {
    console.error("[rateLimit] rpc failed:", error.message)
    return { allowed: true, retryAfterSeconds: 0, count: 0 }
  }

  const payload = data as {
    allowed?: boolean
    retry_after_seconds?: number
    count?: number
  }

  return {
    allowed: payload.allowed !== false,
    retryAfterSeconds: Math.max(Number(payload.retry_after_seconds ?? 0), 0),
    count: Number(payload.count ?? 0),
  }
}

export async function enforceRateLimits(
  supabase: SupabaseClient,
  req: Request,
  auth: AuthContext,
  rules: RateLimitRule[],
): Promise<Response | null> {
  for (const rule of rules) {
    const result = await checkRateLimit(supabase, req, auth, rule)
    if (!result.allowed) {
      return rateLimitExceededResponse(result.retryAfterSeconds)
    }
  }
  return null
}

export function rateLimitExceededResponse(retryAfterSeconds: number): Response {
  const retry = Math.max(retryAfterSeconds, 1)
  return new Response(
    JSON.stringify({
      error: "rate_limit_exceeded",
      retryAfterSeconds: retry,
    }),
    {
      status: 429,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Retry-After": String(retry),
      },
    },
  )
}

/** fetch-prices-batch：60/min per identity */
export const FETCH_PRICES_BATCH_LIMITS: RateLimitRule[] = [
  { prefix: "fetch-prices-batch", limit: 60, windowSeconds: 60 },
]

/** fetch-or-create 全部請求（含 DB hit）：120/min */
export const FETCH_OR_CREATE_ALL_LIMITS: RateLimitRule[] = [
  { prefix: "fetch-or-create:all", limit: 120, windowSeconds: 60 },
]

/** fetch-or-create 僅外部 Yahoo/CoinGecko：30/min + 200/hour */
export const FETCH_OR_CREATE_EXTERNAL_LIMITS: RateLimitRule[] = [
  { prefix: "fetch-or-create:external", limit: 30, windowSeconds: 60 },
  { prefix: "fetch-or-create:external", limit: 200, windowSeconds: 3600 },
]

/** track-symbols-batch：10 batch/min */
export const TRACK_SYMBOLS_BATCH_LIMITS: RateLimitRule[] = [
  { prefix: "track-symbols-batch", limit: 10, windowSeconds: 60 },
]

/** 無 JWT 腳本兜底（較嚴） */
export const ANON_SCRIPT_STRICT_LIMITS: RateLimitRule[] = [
  { prefix: "anon-strict", limit: 10, windowSeconds: 60 },
]

export async function enforceWithAnonFallback(
  supabase: SupabaseClient,
  req: Request,
  auth: AuthContext,
  rules: RateLimitRule[],
): Promise<Response | null> {
  const blocked = await enforceRateLimits(supabase, req, auth, rules)
  if (blocked) return blocked

  if (auth.mode !== "jwt") {
    return await enforceRateLimits(supabase, req, auth, ANON_SCRIPT_STRICT_LIMITS)
  }
  return null
}
