#!/usr/bin/env python3
"""
一次性修正：以 Fugle previousClose 覆寫台股 snapshot 前收與 history。

適用於 fetch-or-create 曾以 Yahoo 5d K 寫入錯誤前收（如 6669 ≈1603）的列。

環境變數：SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FUGLE_API_KEY

用法：
  cd backend/scripts
  python3 backfill_tw_previous_close_fugle.py --dry-run
  python3 backfill_tw_previous_close_fugle.py
  python3 backfill_tw_previous_close_fugle.py --symbol 6669
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import date, timedelta
from typing import Optional
from urllib.parse import quote as url_quote

try:
    import requests
    from supabase import create_client
except ImportError:
    print("請安裝: pip install -r requirements.txt")
    sys.exit(1)

FUGLE_STOCK_BASE = "https://api.fugle.tw/marketdata/v1.0/stock"
REQUEST_INTERVAL_SEC = 0.35


def _is_valid_price(value) -> bool:
    if value is None:
        return False
    try:
        p = float(value)
        return p > 0 and p == p
    except (TypeError, ValueError):
        return False


def _prior_trading_day(d: date) -> date:
    candidate = d - timedelta(days=1)
    for _ in range(10):
        if candidate.weekday() < 5:
            return candidate
        candidate -= timedelta(days=1)
    return d - timedelta(days=1)


def _parse_date(value) -> Optional[date]:
    if value is None:
        return None
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def fetch_fugle_previous(http: requests.Session, api_key: str, symbol: str) -> Optional[dict]:
    url = f"{FUGLE_STOCK_BASE}/intraday/quote/{url_quote(symbol, safe='')}"
    resp = http.get(url, headers={"X-API-KEY": api_key}, timeout=30)
    if resp.status_code != 200:
        return None
    body = resp.json()
    if not isinstance(body, dict):
        return None
    prev = body.get("previousClose")
    if not _is_valid_price(prev):
        prev = body.get("referencePrice")
    if not _is_valid_price(prev):
        return None
    session_date = _parse_date(body.get("date")) or date.today()
    prev_date = _prior_trading_day(session_date)
    return {
        "previous_price": float(prev),
        "previous_close_date": prev_date.isoformat(),
        "session_date": session_date.isoformat(),
    }


def tw_now_local_seconds() -> str:
    from datetime import datetime
    from zoneinfo import ZoneInfo

    return datetime.now(ZoneInfo("Asia/Taipei")).replace(microsecond=0).strftime("%Y-%m-%d %H:%M:%S")


def main() -> None:
    parser = argparse.ArgumentParser(description="Fugle 前收 backfill（台股）")
    parser.add_argument("--dry-run", action="store_true", help="只列印不寫入")
    parser.add_argument("--symbol", help="只處理單一代號")
    parser.add_argument(
        "--yahoo-only",
        action="store_true",
        help="只處理 previous_price_source=yahoo 的列（預設：全部台股 snapshot）",
    )
    args = parser.parse_args()

    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    fugle_key = os.environ.get("FUGLE_API_KEY", "").strip()
    if not url or not key:
        print("請設定 SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY")
        sys.exit(1)
    if not fugle_key:
        print("請設定 FUGLE_API_KEY")
        sys.exit(1)

    supabase = create_client(url, key)
    query = supabase.table("asset_price_snapshots").select(
        "symbol, previous_price, previous_close_date, previous_price_source, current_price, currency"
    ).eq("asset_type", "stock_tw")
    if args.symbol:
        query = query.eq("symbol", args.symbol.strip().upper())
    if args.yahoo_only:
        query = query.eq("previous_price_source", "yahoo")

    resp = query.execute()
    rows = resp.data or []
    if not rows:
        print("無符合條件的列")
        return

    print(f"待處理 {len(rows)} 檔台股 snapshot")
    http = requests.Session()
    updated_at = tw_now_local_seconds()
    ok = 0
    skip = 0
    fail = 0

    for row in rows:
        symbol = row["symbol"]
        time.sleep(REQUEST_INTERVAL_SEC)
        fugle = fetch_fugle_previous(http, fugle_key, symbol)
        if not fugle:
            print(f"  {symbol}: Fugle 無前收，略過")
            fail += 1
            continue

        old_prev = row.get("previous_price")
        new_prev = fugle["previous_price"]
        new_date = fugle["previous_close_date"]
        currency = row.get("currency") or "TWD"

        if old_prev is not None and abs(float(old_prev) - new_prev) < 0.0001:
            print(f"  {symbol}: 前收已是 {new_prev}，略過")
            skip += 1
            continue

        print(
            f"  {symbol}: previous {old_prev} → {new_prev} "
            f"({new_date}) source=fugle"
        )

        if args.dry_run:
            ok += 1
            continue

        try:
            supabase.table("asset_price_snapshots").update(
                {
                    "previous_price": str(new_prev),
                    "previous_close_date": new_date,
                    "previous_updated_at": updated_at,
                    "previous_price_source": "fugle",
                }
            ).eq("asset_type", "stock_tw").eq("symbol", symbol).execute()

            supabase.table("asset_price_history").upsert(
                {
                    "asset_type": "stock_tw",
                    "symbol": symbol,
                    "price_date": new_date,
                    "close_price": str(new_prev),
                    "currency": currency,
                    "source": "fugle",
                    "updated_at": updated_at,
                },
                on_conflict="asset_type,symbol,price_date",
            ).execute()
            ok += 1
        except Exception as e:
            print(f"  {symbol}: 寫入失敗 {e}")
            fail += 1

    print(f"完成：更新 {ok}、略過 {skip}、失敗 {fail}" + ("（dry-run）" if args.dry_run else ""))


if __name__ == "__main__":
    main()
