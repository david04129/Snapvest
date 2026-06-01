#!/usr/bin/env python3
"""
同步台股／美股交易日曆至 market_calendar。
- 台股：FinMind TaiwanStockTradingDate（區間內列出的日期為交易日）
- 美股：Finnhub stock/market-holiday（休市日標記 is_trading_day=false）

用法:
  python sync_market_calendar.py
  python sync_market_calendar.py --days-forward 90
"""
from __future__ import annotations

import os
import sys
from datetime import date, timedelta
from pathlib import Path

try:
    import requests
    from supabase import create_client
except ImportError:
    print("請先安裝: pip install -r requirements.txt")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from daily_price_update import (  # noqa: E402
    FINMIND_DATA_URL,
    FINMIND_TOKEN,
    FINNHUB_API_KEY,
    TW_TZ,
    get_supabase,
    tw_now,
    tw_now_local_seconds,
)
from market_session import TW_REGULAR_CLOSE, TW_REGULAR_OPEN, US_REGULAR_CLOSE, US_REGULAR_OPEN  # noqa: E402

FINNHUB_HOLIDAY_URL = "https://finnhub.io/api/v1/stock/market-holiday"


def tw_today() -> date:
    return tw_now().date()


def sync_tw_calendar(supabase, start: date, end: date, synced_at: str) -> int:
    """FinMind 回傳區間內所有交易日；其餘日期在 upsert 時標為休市（僅 upsert 交易日列，休市由查詢 fallback）。"""
    if not FINMIND_TOKEN:
        print("  略過台股日曆：未設定 FINMIND_TOKEN")
        return 0

    params = {
        "dataset": "TaiwanStockTradingDate",
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
    }
    if FINMIND_TOKEN:
        params["token"] = FINMIND_TOKEN

    resp = requests.get(FINMIND_DATA_URL, params=params, timeout=60)
    resp.raise_for_status()
    payload = resp.json()
    if payload.get("status") not in (200, "success"):
        print(f"  FinMind 日曆失敗: {payload.get('msg', payload)}")
        return 0

    trading_dates: set[date] = set()
    for row in payload.get("data") or []:
        d = row.get("date")
        if d:
            trading_dates.add(date.fromisoformat(str(d)[:10]))

    rows = []
    cursor = start
    while cursor <= end:
        is_open = cursor in trading_dates
        rows.append(
            {
                "market": "tw",
                "trade_date": cursor.isoformat(),
                "is_trading_day": is_open,
                "session_open": TW_REGULAR_OPEN.isoformat(),
                "session_close": TW_REGULAR_CLOSE.isoformat(),
                "holiday_name": None if is_open else "non_trading_day",
                "source": "finmind",
                "synced_at": synced_at,
            }
        )
        cursor += timedelta(days=1)

    for i in range(0, len(rows), 100):
        supabase.table("market_calendar").upsert(
            rows[i : i + 100],
            on_conflict="market,trade_date",
        ).execute()
    print(f"  台股日曆: {start} ~ {end}，交易日 {len(trading_dates)} 天")
    return len(rows)


def sync_us_calendar(supabase, start: date, end: date, synced_at: str) -> int:
    if not FINNHUB_API_KEY:
        print("  略過美股日曆：未設定 FINNHUB_API_KEY")
        return 0

    resp = requests.get(
        FINNHUB_HOLIDAY_URL,
        params={"exchange": "US", "token": FINNHUB_API_KEY},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()

    holiday_by_date: dict[date, str] = {}
    for entry in data if isinstance(data, list) else data.get("data") or []:
        at = entry.get("at") or entry.get("date")
        if not at:
            continue
        d = date.fromisoformat(str(at)[:10])
        if start <= d <= end:
            holiday_by_date[d] = entry.get("eventName") or entry.get("name") or "holiday"

    rows = []
    cursor = start
    while cursor <= end:
        if cursor.weekday() >= 5:
            is_open = False
            name = "weekend"
        elif cursor in holiday_by_date:
            is_open = False
            name = holiday_by_date[cursor]
        else:
            is_open = True
            name = None
        rows.append(
            {
                "market": "us",
                "trade_date": cursor.isoformat(),
                "is_trading_day": is_open,
                "session_open": US_REGULAR_OPEN.isoformat(),
                "session_close": US_REGULAR_CLOSE.isoformat(),
                "holiday_name": name,
                "source": "finnhub",
                "synced_at": synced_at,
            }
        )
        cursor += timedelta(days=1)

    for i in range(0, len(rows), 100):
        supabase.table("market_calendar").upsert(
            rows[i : i + 100],
            on_conflict="market,trade_date",
        ).execute()
    print(f"  美股日曆: {start} ~ {end}，休市 {len(holiday_by_date)} 天（Finnhub）")
    return len(rows)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="同步 market_calendar")
    parser.add_argument("--days-back", type=int, default=7)
    parser.add_argument("--days-forward", type=int, default=60)
    args = parser.parse_args()

    supabase = get_supabase()
    today = tw_today()
    start = today - timedelta(days=args.days_back)
    end = today + timedelta(days=args.days_forward)
    synced_at = tw_now_local_seconds()

    print(f"[{tw_now().isoformat()}] 同步 market_calendar {start} ~ {end}")
    n_tw = sync_tw_calendar(supabase, start, end, synced_at)
    n_us = sync_us_calendar(supabase, start, end, synced_at)
    print(f"完成：台 {n_tw} 列、美 {n_us} 列")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
