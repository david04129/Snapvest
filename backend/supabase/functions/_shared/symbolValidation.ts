// Shared symbol normalization (aligned with fetch-prices-batch / track-symbol)

export const allowedAssetTypes = new Set(["stock_tw", "stock_us", "crypto"])

export function normalizeSymbol(assetType: string, rawSymbol: unknown): string | null {
  const trimmed = String(rawSymbol ?? "").trim()
  if (!trimmed || trimmed.length > 20) return null

  if (assetType === "stock_tw") {
    const upper = trimmed.toUpperCase()
    return /^[A-Z0-9]{4,6}$/.test(upper) ? upper : null
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
