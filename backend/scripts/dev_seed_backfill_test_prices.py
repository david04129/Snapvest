#!/usr/bin/env python3
"""
Seed deterministic public price data for local daily trend backfill testing.

Writes 20 public symbols across the last 10 Taiwan calendar days into:
- asset_price_history
- asset_price_snapshots
- tracked_symbols
- exchange_rates (USD/TWD)

Required env:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY

Run:
  python3 backend/scripts/dev_seed_backfill_test_prices.py --confirm
"""

import os
import sys
from datetime import date, datetime, timedelta, timezone

from supabase import create_client

TW_TZ = timezone(timedelta(hours=8))
USD_TWD = 32.15

SYMBOLS = [
    ("stock_tw", "990001", "TWD", 935.0),
    ("stock_tw", "990002", "TWD", 182.0),
    ("stock_tw", "990003", "TWD", 1260.0),
    ("stock_tw", "990004", "TWD", 54.2),
    ("stock_tw", "990005", "TWD", 88.6),
    ("stock_tw", "990006", "TWD", 182.4),
    ("stock_tw", "990007", "TWD", 22.8),
    ("stock_us", "ZZTST1", "USD", 195.5),
    ("stock_us", "ZZTST2", "USD", 430.0),
    ("stock_us", "ZZTST3", "USD", 126.0),
    ("stock_us", "ZZTST4", "USD", 340.0),
    ("stock_us", "ZZTST5", "USD", 505.0),
    ("stock_us", "ZZTST6", "USD", 184.0),
    ("stock_us", "ZZTST7", "USD", 176.0),
    ("stock_us", "ZZTST8", "USD", 585.0),
    ("crypto", "TSTBTC", "USD", 104000.0),
    ("crypto", "TSTETH", "USD", 3850.0),
    ("crypto", "TSTSOL", "USD", 166.0),
    ("crypto", "TSTXRP", "USD", 2.22),
    ("crypto", "TSTUSD", "USD", 1.0),
]


def tw_now_local_seconds() -> str:
    return datetime.now(TW_TZ).replace(microsecond=0).strftime("%Y-%m-%d %H:%M:%S")


def price_for(base: float, symbol_index: int, day_index: int) -> float:
    wave = ((day_index % 5) - 2) * 0.006
    drift = (day_index - 4.5) * 0.004
    symbol_bias = ((symbol_index % 4) - 1.5) * 0.003
    return round(base * (1 + wave + drift + symbol_bias), 8)


def main() -> None:
    if "--confirm" not in sys.argv:
        raise SystemExit("This writes fake dev prices. Re-run with --confirm to proceed.")

    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        raise SystemExit("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")

    supabase = create_client(url, key)
    today = datetime.now(TW_TZ).date()
    dates = [today - timedelta(days=offset) for offset in range(10, 0, -1)]
    updated_at = tw_now_local_seconds()

    history_rows = []
    snapshot_rows = []

    for symbol_index, (asset_type, symbol, currency, base_price) in enumerate(SYMBOLS):
        prices = [price_for(base_price, symbol_index, day_index) for day_index in range(len(dates))]
        for price_date, close_price in zip(dates, prices):
            history_rows.append(
                {
                    "asset_type": asset_type,
                    "symbol": symbol,
                    "price_date": price_date.isoformat(),
                    "close_price": close_price,
                    "currency": currency,
                    "source": "dev_seed",
                    "updated_at": updated_at,
                }
            )

        snapshot_rows.append(
            {
                "asset_type": asset_type,
                "symbol": symbol,
                "currency": currency,
                "current_price": prices[-1],
                "current_close_date": dates[-1].isoformat(),
                "current_updated_at": updated_at,
                "current_price_source": "dev_seed",
                "previous_price": prices[-2],
                "previous_close_date": dates[-2].isoformat(),
                "previous_updated_at": updated_at,
                "previous_price_source": "dev_seed",
            }
        )

    supabase.table("asset_price_history").upsert(
        history_rows,
        on_conflict="asset_type,symbol,price_date",
    ).execute()
    supabase.table("asset_price_snapshots").upsert(
        snapshot_rows,
        on_conflict="asset_type,symbol",
    ).execute()
    supabase.table("exchange_rates").upsert(
        {
            "from_currency": "USD",
            "to_currency": "TWD",
            "rate": USD_TWD,
            "updated_at": updated_at,
        },
        on_conflict="from_currency,to_currency",
    ).execute()

    print(
        f"Seeded {len(SYMBOLS)} symbols, {len(history_rows)} history rows "
        f"from {dates[0].isoformat()} to {dates[-1].isoformat()}."
    )


if __name__ == "__main__":
    main()
