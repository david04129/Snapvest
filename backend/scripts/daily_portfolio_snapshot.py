#!/usr/bin/env python3
"""
每日投資組合快照：讀 user_portfolio_state + asset_price_snapshots + exchange_rates
→ 計算總資產／淨資產 → upsert user_daily_snapshots

排程語意（台灣 00:05）：結算「前一日」淨值（例：5/26 00:05 → snapshot_date=5/25）。
美股股價沿用最近一次 07:00 更新（accept lag 一個美股交易日）。

用法:
  export SUPABASE_URL=...
  export SUPABASE_SERVICE_ROLE_KEY=...
  python3 backend/scripts/daily_portfolio_snapshot.py
  python3 backend/scripts/daily_portfolio_snapshot.py --snapshot-date 2026-05-25
  python3 backend/scripts/daily_portfolio_snapshot.py --snapshot-date today
"""
from __future__ import annotations

import argparse
import re
from datetime import datetime, timedelta
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


def _effective_fx_rate(row: dict) -> Decimal:
    """本輪 rate 優先，否則 previous_rate。"""
    rate = _parse_decimal(row.get("rate"))
    if rate > 0:
        return rate
    return _parse_decimal(row.get("previous_rate"))


def fetch_fx_to_twd(supabase) -> dict[str, Decimal]:
    """1 單位外幣 = ? TWD（FinMind 牌告列）。"""
    resp = (
        supabase.table("exchange_rates")
        .select("from_currency,rate,previous_rate")
        .eq("to_currency", "TWD")
        .execute()
    )
    _raise_on_supabase_error(resp, "exchange_rates read")
    rates: dict[str, Decimal] = {}
    for row in resp.data or []:
        code = row.get("from_currency")
        if not code:
            continue
        rate = _effective_fx_rate(row)
        if rate > 0:
            rates[str(code)] = rate
    return rates


def to_twd(amount: Decimal, currency: str, rates_to_twd: dict[str, Decimal]) -> Decimal:
    if amount == 0:
        return Decimal("0")
    if currency == "TWD":
        return amount
    twd_per_unit = rates_to_twd.get(currency)
    if twd_per_unit and twd_per_unit > 0:
        return amount * twd_per_unit
    return amount


_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def resolve_snapshot_date(explicit: str | None = None) -> str:
    """預設寫入「台灣時間前一日」，對齊 00:05 日終結算。"""
    now = datetime.now(TW_TZ)
    if explicit is None:
        return (now.date() - timedelta(days=1)).isoformat()

    normalized = explicit.strip().lower()
    if normalized == "today":
        return now.date().isoformat()
    if normalized == "yesterday":
        return (now.date() - timedelta(days=1)).isoformat()
    if not _DATE_RE.match(explicit.strip()):
        raise ValueError(
            f"無效的 --snapshot-date：{explicit!r}（請用 YYYY-MM-DD、today 或 yesterday）"
        )
    return explicit.strip()


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
    parser = argparse.ArgumentParser(description="Snapvest 每日投資組合快照")
    parser.add_argument(
        "--snapshot-date",
        metavar="DATE",
        help="寫入日期（YYYY-MM-DD）；或 today / yesterday。預設：yesterday（台灣時間）",
    )
    args = parser.parse_args()

    snapshot_date = resolve_snapshot_date(args.snapshot_date)
    now_tw = datetime.now(TW_TZ)
    print(
        f"[{now_tw.isoformat()}] 開始每日投資組合快照"
        f"（snapshot_date={snapshot_date}，executed_on={now_tw.date().isoformat()}）"
    )

    supabase = get_supabase()
    rates = fetch_fx_to_twd(supabase)
    usd_twd = rates.get("USD")
    if usd_twd:
        print(f"USD/TWD = {usd_twd}")

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
    try:
        main()
    except ValueError as exc:
        print(f"錯誤：{exc}")
        raise SystemExit(1) from exc
