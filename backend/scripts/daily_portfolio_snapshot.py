#!/usr/bin/env python3
"""
每日投資組合快照：讀 user_portfolio_state + asset_price_snapshots + exchange_rates
→ 計算總資產／淨資產 → upsert user_daily_snapshots

用法:
  export SUPABASE_URL=...
  export SUPABASE_SERVICE_ROLE_KEY=...
  python3 backend/scripts/daily_portfolio_snapshot.py
"""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

from daily_price_update import TW_TZ, _raise_on_supabase_error, get_supabase


def _parse_decimal(value: Any) -> Decimal:
    if value is None:
        return Decimal("0")
    if isinstance(value, Decimal):
        return value
    text = str(value).strip()
    if not text:
        return Decimal("0")
    return Decimal(text)


def _field(item: dict[str, Any], *keys: str) -> Any:
    """App JSONB 使用 camelCase（assetType）；腳本亦相容 snake_case。"""
    for key in keys:
        if key in item and item[key] is not None:
            return item[key]
    return None


def _quantize_money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _normalize_symbol(asset_type: str, symbol: str) -> str:
    sym = str(symbol).strip()
    if asset_type in ("crypto", "stock_us"):
        return sym.upper()
    return sym


def _price_key(asset_type: str, symbol: str) -> tuple[str, str]:
    return asset_type, _normalize_symbol(asset_type, symbol)


def _display_price(row: dict[str, Any]) -> Decimal | None:
    for field in ("current_price", "previous_price"):
        raw = row.get(field)
        if raw is None:
            continue
        price = _parse_decimal(raw)
        if price > 0:
            return price
    return None


def fetch_usd_rates(supabase) -> dict[str, Decimal]:
    resp = (
        supabase.table("exchange_rates")
        .select("to_currency,rate")
        .eq("from_currency", "USD")
        .execute()
    )
    _raise_on_supabase_error(resp, "exchange_rates read")
    rates: dict[str, Decimal] = {}
    for row in resp.data or []:
        code = row.get("to_currency")
        if not code:
            continue
        rate = _parse_decimal(row.get("rate"))
        if rate > 0:
            rates[str(code)] = rate
    return rates


def to_twd(amount: Decimal, currency: str, rates: dict[str, Decimal]) -> Decimal:
    if amount == 0:
        return Decimal("0")
    if currency == "TWD":
        return amount

    twd_rate = rates.get("TWD")
    if currency == "USD":
        return amount * twd_rate if twd_rate else amount

    foreign_rate = rates.get(currency)
    if foreign_rate and twd_rate and foreign_rate > 0:
        return amount / foreign_rate * twd_rate
    return amount


def compute_snapshot(
    state: dict[str, Any],
    prices: dict[tuple[str, str], dict[str, Any]],
    rates: dict[str, Decimal],
) -> dict[str, Decimal]:
    total_cash = Decimal("0")
    for item in state.get("cash") or []:
        amount = _parse_decimal(_field(item, "amount"))
        currency = str(_field(item, "currency") or "TWD")
        total_cash += to_twd(amount, currency, rates)

    total_investments = Decimal("0")
    unrealized_gain_loss = Decimal("0")
    for item in state.get("holdings") or []:
        asset_type = str(_field(item, "asset_type", "assetType") or "")
        symbol = str(_field(item, "symbol") or "")
        quantity = _parse_decimal(_field(item, "quantity"))
        if quantity <= 0:
            continue

        currency = str(_field(item, "currency") or "TWD")
        price_row = prices.get(_price_key(asset_type, symbol))
        price = _display_price(price_row) if price_row else None
        market_value = (price or Decimal("0")) * quantity
        total_investments += to_twd(market_value, currency, rates)

        avg_cost_raw = _field(item, "average_cost", "averageCost")
        if price is not None and avg_cost_raw is not None:
            avg_cost = _parse_decimal(avg_cost_raw)
            gain = (price - avg_cost) * quantity
            unrealized_gain_loss += to_twd(gain, currency, rates)
        elif price_row is None and asset_type and symbol:
            print(f"    警告：找不到股價 {asset_type}/{symbol}，市值計為 0")

    total_liabilities = Decimal("0")
    for item in state.get("liabilities") or []:
        amount = _parse_decimal(_field(item, "amount"))
        currency = str(_field(item, "currency") or "TWD")
        total_liabilities += to_twd(amount, currency, rates)

    total_assets = total_cash + total_investments
    net_worth = total_assets - total_liabilities

    return {
        "total_cash": _quantize_money(total_cash),
        "total_investments": _quantize_money(total_investments),
        "total_assets": _quantize_money(total_assets),
        "total_liabilities": _quantize_money(total_liabilities),
        "net_worth": _quantize_money(net_worth),
        "unrealized_gain_loss": _quantize_money(unrealized_gain_loss),
    }


def main() -> None:
    snapshot_date = datetime.now(TW_TZ).date().isoformat()
    print(f"[{datetime.now(TW_TZ).isoformat()}] 開始每日投資組合快照（snapshot_date={snapshot_date}）")

    supabase = get_supabase()
    rates = fetch_usd_rates(supabase)
    twd = rates.get("TWD")
    if twd:
        print(f"USD/TWD = {twd}")

    states_resp = supabase.table("user_portfolio_state").select("*").execute()
    _raise_on_supabase_error(states_resp, "user_portfolio_state read")

    prices_resp = supabase.table("asset_price_snapshots").select("*").execute()
    _raise_on_supabase_error(prices_resp, "asset_price_snapshots read")
    prices: dict[tuple[str, str], dict[str, Any]] = {}
    for row in prices_resp.data or []:
        asset_type = str(row.get("asset_type") or "")
        symbol = str(row.get("symbol") or "")
        prices[_price_key(asset_type, symbol)] = row

    rows: list[dict[str, Any]] = []
    for state in states_resp.data or []:
        user_id = state.get("user_id")
        if not user_id:
            continue

        holdings = state.get("holdings") or []
        metrics = compute_snapshot(state, prices, rates)
        print(
            f"  {user_id}: holdings={len(holdings)} "
            f"cash={metrics['total_cash']} inv={metrics['total_investments']} "
            f"assets={metrics['total_assets']} net={metrics['net_worth']} "
            f"unrealized={metrics['unrealized_gain_loss']}"
        )
        rows.append(
            {
                "user_id": user_id,
                "snapshot_date": snapshot_date,
                "total_assets": str(metrics["total_assets"]),
                "total_liabilities": str(metrics["total_liabilities"]),
                "net_worth": str(metrics["net_worth"]),
                "total_cash": str(metrics["total_cash"]),
                "total_investments": str(metrics["total_investments"]),
                "unrealized_gain_loss": str(metrics["unrealized_gain_loss"]),
                "base_currency": "TWD",
            }
        )

    if not rows:
        print("沒有任何 user_portfolio_state，略過寫入")
        return

    upsert_resp = supabase.table("user_daily_snapshots").upsert(
        rows,
        on_conflict="user_id,snapshot_date",
    ).execute()
    _raise_on_supabase_error(upsert_resp, "user_daily_snapshots upsert")
    print(f"完成：寫入 {len(rows)} 筆 user_daily_snapshots")


if __name__ == "__main__":
    main()
