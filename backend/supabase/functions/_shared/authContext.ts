// Shared helpers for Edge Functions (Phase A: optional JWT context, no blocking)

export type AuthContext = {
  mode: "jwt" | "anon"
  userId: string | null
}

export function readAuthContext(req: Request): AuthContext {
  const auth = req.headers.get("authorization")?.trim()
  if (!auth?.toLowerCase().startsWith("bearer ")) {
    return { mode: "anon", userId: null }
  }
  const token = auth.slice(7).trim()
  if (!token.startsWith("eyJ")) {
    return { mode: "anon", userId: null }
  }
  const userId = decodeJwtSub(token)
  if (!userId) {
    return { mode: "anon", userId: null }
  }
  return { mode: "jwt", userId }
}

function decodeJwtSub(token: string): string | null {
  const parts = token.split(".")
  if (parts.length < 2) return null
  try {
    const payloadJson = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))
    const payload = JSON.parse(payloadJson) as { sub?: unknown }
    return typeof payload.sub === "string" && payload.sub.length > 0 ? payload.sub : null
  } catch {
    return null
  }
}
