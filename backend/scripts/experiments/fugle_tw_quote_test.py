#!/usr/bin/env python3
"""
Fugle 台股報價測試（盤中／盤後同一支 API）

驗證上市、上櫃、ETF、含字母尾碼代號（00751B、00675L）能否取得價格。
盤中與盤後皆使用 REST：
  GET /marketdata/v1.0/stock/intraday/quote/{symbol}
另可選比對日 K（收盤語意）：
  GET /marketdata/v1.0/stock/historical/candles/{symbol}?timeframe=D

環境變數：
  FUGLE_API_KEY  必填（https://developer.fugle.tw/）

執行：
  cd backend/scripts/experiments
  export FUGLE_API_KEY='your_key'
  python3 fugle_tw_quote_test.py
"""
from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Optional
from urllib.parse import quote

try:
    import requests
except ImportError:
    print("請安裝: pip3 install requests")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "output"

FUGLE_BASE = "https://api.fugle.tw/marketdata/v1.0/stock"
REQUEST_INTERVAL_SEC = 0.35  # 避免連打；依方案調整

# 代號, 類別說明, 預期市場（僅供對照 log，以 API 回傳為準）
DEFAULT_CASES: list[tuple[str, str, str]] = [
    ("2330", "上市", "TSE"),
    ("6547", "上櫃", "OTC"),
    ("0050", "上市 ETF", "TSE"),
    ("00751B", "債券 ETF（字母尾碼）", "TSE"),
    ("00675L", "槓桿／反向 ETF（字母尾碼）", "TSE"),
]


@dataclass
class CaseResult:
    symbol: str
    category: str
    expected_market: str
    quote_ok: bool = False
    quote_error: str = ""
    quote: dict[str, Any] = field(default_factory=dict)
    candles_ok: bool = False
    candles_error: str = ""
    candles: dict[str, Any] = field(default_factory=dict)


def taipei_today() -> str:
    from zoneinfo import ZoneInfo

    return datetime.now(ZoneInfo("Asia/Taipei")).date().isoformat()


def _valid_price(value: Any) -> bool:
    if value is None:
        return False
    try:
        p = float(value)
        return p > 0 and p == p
    except (TypeError, ValueError):
        return False


def _pick_quote_price(body: dict) -> tuple[Optional[float], str]:
    """與排程建議一致：優先 lastPrice，其次 closePrice。"""
    for key, label in (
        ("lastPrice", "lastPrice"),
        ("closePrice", "closePrice"),
    ):
        if _valid_price(body.get(key)):
            return float(body[key]), label
    return None, ""


def fetch_intraday_quote(
    session: requests.Session,
    api_key: str,
    symbol: str,
) -> tuple[Optional[dict], str]:
    """盤中／盤後同一 endpoint。"""
    path_symbol = quote(symbol, safe="")
    url = f"{FUGLE_BASE}/intraday/quote/{path_symbol}"
    try:
        resp = session.get(
            url,
            headers={"X-API-KEY": api_key},
            timeout=30,
        )
        if resp.status_code == 401:
            return None, "401 Unauthorized（檢查 FUGLE_API_KEY）"
        if resp.status_code == 403:
            return None, "403 Forbidden（方案或權限不足）"
        if resp.status_code == 404:
            return None, f"404 Not Found（代號 {symbol} 可能不存在於 Fugle）"
        if resp.status_code == 429:
            return None, "429 Too Many Requests"
        resp.raise_for_status()
        data = resp.json()
        if not isinstance(data, dict):
            return None, "回應非 JSON object"
        price, field_name = _pick_quote_price(data)
        if not price:
            return None, "無有效 lastPrice/closePrice"
        return {
            "price": price,
            "price_field": field_name,
            "date": data.get("date"),
            "exchange": data.get("exchange"),
            "market": data.get("market"),
            "name": data.get("name"),
            "type": data.get("type"),
            "lastPrice": data.get("lastPrice"),
            "closePrice": data.get("closePrice"),
            "previousClose": data.get("previousClose"),
            "referencePrice": data.get("referencePrice"),
            "isOpen": data.get("isOpen"),
            "isClose": data.get("isClose"),
            "lastUpdated": data.get("lastUpdated"),
        }, ""
    except requests.RequestException as e:
        return None, str(e)


def fetch_daily_candle_today(
    session: requests.Session,
    api_key: str,
    symbol: str,
    session_date: str,
) -> tuple[Optional[dict], str]:
    """日 K 當日 close（盤後對照用；盤中當日 K 可能尚未完整）。"""
    path_symbol = quote(symbol, safe="")
    url = f"{FUGLE_BASE}/historical/candles/{path_symbol}"
    params = {
        "from": session_date,
        "to": session_date,
        "timeframe": "D",
        "fields": "open,high,low,close,volume",
    }
    try:
        resp = session.get(
            url,
            headers={"X-API-KEY": api_key},
            params=params,
            timeout=30,
        )
        if resp.status_code in (401, 403, 404, 429):
            return None, f"HTTP {resp.status_code}"
        resp.raise_for_status()
        body = resp.json()
        rows = body.get("data") or []
        if not rows:
            return None, "當日無日 K 資料（盤中常見）"
        row = rows[0]
        close = row.get("close")
        if not _valid_price(close):
            return None, "日 K close 無效"
        return {
            "date": row.get("date"),
            "close": float(close),
            "open": row.get("open"),
            "high": row.get("high"),
            "low": row.get("low"),
            "volume": row.get("volume"),
            "timeframe": body.get("timeframe"),
        }, ""
    except requests.RequestException as e:
        return None, str(e)


def run_case(
    session: requests.Session,
    api_key: str,
    symbol: str,
    category: str,
    expected_market: str,
    session_date: str,
    *,
    with_candles: bool,
) -> CaseResult:
    r = CaseResult(symbol=symbol, category=category, expected_market=expected_market)
    time.sleep(REQUEST_INTERVAL_SEC)

    q, err = fetch_intraday_quote(session, api_key, symbol)
    if q:
        r.quote_ok = True
        r.quote = q
    else:
        r.quote_error = err

    if with_candles:
        time.sleep(REQUEST_INTERVAL_SEC)
        c, cerr = fetch_daily_candle_today(session, api_key, symbol, session_date)
        if c:
            r.candles_ok = True
            r.candles = c
        else:
            r.candles_error = cerr

    return r


def main() -> int:
    api_key = os.environ.get("FUGLE_API_KEY", "").strip()
    if not api_key:
        print("請設定環境變數 FUGLE_API_KEY")
        print("  export FUGLE_API_KEY='...'")
        print("  python3 fugle_tw_quote_test.py")
        return 1

    with_candles = "--no-candles" not in sys.argv
    session_date = taipei_today()
    now_utc = datetime.now(timezone.utc).isoformat()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    session = requests.Session()

    print("Fugle 台股報價測試")
    print(f"  台北交易日: {session_date}")
    print(f"  執行時間 UTC: {now_utc}")
    print("  盤中／盤後: 皆使用 GET .../intraday/quote/{symbol}（同一指令）")
    if with_candles:
        print(f"  另測日 K: historical/candles?from={session_date}&to={session_date}&timeframe=D")
    print()

    results: list[CaseResult] = []
    for symbol, category, expected_market in DEFAULT_CASES:
        print(f"--- {symbol} ({category}) ---")
        r = run_case(
            session,
            api_key,
            symbol,
            category,
            expected_market,
            session_date,
            with_candles=with_candles,
        )
        results.append(r)

        if r.quote_ok:
            q = r.quote
            market_match = (
                "OK"
                if q.get("market") == expected_market
                else f"預期 {expected_market} 實際 {q.get('market')}"
            )
            print(
                f"  quote: OK  {q['price_field']}={q['price']}  "
                f"market={q.get('market')} exchange={q.get('exchange')}  "
                f"isOpen={q.get('isOpen')} isClose={q.get('isClose')}  "
                f"({market_match})"
            )
            if q.get("name"):
                print(f"         {q['name']}")
        else:
            print(f"  quote: FAIL  {r.quote_error}")

        if with_candles:
            if r.candles_ok:
                c = r.candles
                diff = ""
                if r.quote_ok:
                    delta = abs(c["close"] - r.quote["price"])
                    diff = f"  |quote−日K|={delta:.4g}"
                print(f"  日K:   OK  close={c['close']} date={c.get('date')}{diff}")
            else:
                print(f"  日K:   —   {r.candles_error}")
        print()

    ok_quote = sum(1 for r in results if r.quote_ok)
    ok_candles = sum(1 for r in results if r.candles_ok)
    total = len(results)

    print("--- 摘要 ---")
    print(f"intraday/quote 成功: {ok_quote}/{total}")
    if with_candles:
        print(f"historical 日K 成功: {ok_candles}/{total}")
    print()
    print("解讀：")
    print("  • quote 在盤後成功 → 盤中通常也可用同一 API（非收盤後才有另一支）。")
    print("  • 日 K 當日在盤中可能 empty；收盤 job 可仍以 quote 或盤後日 K 擇一。")

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUTPUT_DIR / f"fugle_tw_{ts}.json"
    payload = {
        "provider": "fugle",
        "session_date_taipei": session_date,
        "ran_at_utc": now_utc,
        "endpoints": {
            "quote": f"{FUGLE_BASE}/intraday/quote/{{symbol}}",
            "daily_candles": f"{FUGLE_BASE}/historical/candles/{{symbol}}",
        },
        "same_api_intraday_and_after_hours": True,
        "quote_ok": ok_quote,
        "quote_total": total,
        "candles_ok": ok_candles if with_candles else None,
        "cases": [
            {
                "symbol": r.symbol,
                "category": r.category,
                "expected_market": r.expected_market,
                "quote_ok": r.quote_ok,
                "quote_error": r.quote_error,
                "quote": r.quote,
                "candles_ok": r.candles_ok,
                "candles_error": r.candles_error,
                "candles": r.candles,
            }
            for r in results
        ],
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"結果已寫入: {out_path}")

    return 0 if ok_quote == total else 2


if __name__ == "__main__":
    raise SystemExit(main())
