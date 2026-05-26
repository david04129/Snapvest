#!/usr/bin/env python3
"""
獨立測試：Finnhub 抓取「台幣對 10 種常用外幣」匯率

不修改、不 import Snapvest 主流程。僅寫入 experiments/output/。

環境變數：
  FINNHUB_API_KEY  必填（https://finnhub.io）

限速（與 finnhub_us_batch_test.py 相同）：
  - 每分鐘最多 58 次
  - 10 種幣約 10 秒

執行：
  cd backend/scripts/experiments
  export FINNHUB_API_KEY='your_key'
  python3 finnhub_fx_twd_test.py
"""
from __future__ import annotations

import json
import math
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

try:
    import requests
except ImportError:
    print("請安裝: pip3 install requests")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "output"

FINNHUB_FOREX_RATES_URL = "https://finnhub.io/api/v1/forex/rates"

# 台灣常用 10 種外幣（對 TWD）
FOREIGN_CURRENCIES = [
    "USD",
    "EUR",
    "JPY",
    "GBP",
    "CNY",
    "HKD",
    "AUD",
    "SGD",
    "KRW",
    "CAD",
]

REQUESTS_PER_MINUTE = 58
MIN_INTERVAL_SEC = 60.0 / REQUESTS_PER_MINUTE


@dataclass
class RunStats:
    total: int = 0
    ok: int = 0
    fail: int = 0
    errors: list[str] = field(default_factory=list)


def _is_valid_rate(val) -> bool:
    if val is None:
        return False
    try:
        f = float(val)
    except (TypeError, ValueError):
        return False
    if math.isnan(f) or math.isinf(f):
        return False
    return f > 0


def fetch_rates_for_base(
    session: requests.Session, base: str, token: str
) -> dict[str, float]:
    """GET /forex/rates?base=XXX → quote 字典"""
    resp = session.get(
        FINNHUB_FOREX_RATES_URL,
        params={"base": base, "token": token},
        timeout=20,
    )
    if resp.status_code == 403:
        raise RuntimeError(
            "403 Forbidden：/forex/rates 為 Finnhub 付費 Forex 方案，"
            "免費 key 僅能穩定用美股 /quote 等，無法抓匯率。"
        )
    if resp.status_code == 429:
        raise RuntimeError("429 Too Many Requests")
    resp.raise_for_status()
    body = resp.json()
    quote = body.get("quote") or {}
    if not isinstance(quote, dict):
        return {}
    out: dict[str, float] = {}
    for k, v in quote.items():
        if _is_valid_rate(v):
            out[str(k).upper()] = float(v)
    return out


def twd_per_unit_foreign(quotes: dict[str, float]) -> float | None:
    """1 單位外幣 = ? TWD（Finnhub：base=外幣時 quote.TWD）"""
    return quotes.get("TWD")


def foreign_per_twd(quotes: dict[str, float], currency: str) -> float | None:
    """1 TWD = ? 外幣（Finnhub：base=TWD 時 quote.USD 等）"""
    return quotes.get(currency.upper())


def main() -> int:
    token = os.environ.get("FINNHUB_API_KEY", "").strip()
    if not token:
        print("請設定環境變數 FINNHUB_API_KEY")
        return 1

    stats = RunStats(total=len(FOREIGN_CURRENCIES))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    started = time.monotonic()
    by_foreign: dict[str, dict] = {}
    session = requests.Session()
    last_request_at = 0.0

    print("Finnhub 匯率測試：台幣對 10 種常用外幣")
    print(f"幣別：{', '.join(FOREIGN_CURRENCIES)}")
    print(f"限速：每分鐘 {REQUESTS_PER_MINUTE} 次，間隔 ≥ {MIN_INTERVAL_SEC:.1f} 秒\n")

    # --- 方式 A：以外幣為 base，讀 quote.TWD（10 次請求，與股價測試相同節奏）---
    for i, currency in enumerate(FOREIGN_CURRENCIES, start=1):
        elapsed_since = time.monotonic() - last_request_at
        if last_request_at > 0 and elapsed_since < MIN_INTERVAL_SEC:
            time.sleep(MIN_INTERVAL_SEC - elapsed_since)

        try:
            last_request_at = time.monotonic()
            quotes = fetch_rates_for_base(session, currency, token)
            twd_rate = twd_per_unit_foreign(quotes)
            if twd_rate is not None:
                stats.ok += 1
                by_foreign[currency] = {
                    "method": "forex/rates",
                    "base": currency,
                    "twd_per_1_foreign": twd_rate,
                    "interpretation": f"1 {currency} = {twd_rate} TWD",
                    "quote_keys_sample": sorted(quotes.keys())[:8],
                }
                status = f"OK  1 {currency} = {twd_rate:.6f} TWD"
            else:
                stats.fail += 1
                msg = f"{currency}: quote 無 TWD（keys={list(quotes.keys())[:6]}）"
                stats.errors.append(msg)
                by_foreign[currency] = {"method": "forex/rates", "base": currency, "error": msg}
                status = "EMPTY"
        except Exception as e:
            stats.fail += 1
            stats.errors.append(f"{currency}: {e}")
            by_foreign[currency] = {"method": "forex/rates", "base": currency, "error": str(e)}
            status = f"ERR ({e})"
            if "429" in str(e):
                print("遇到 429，額外等待 60 秒…")
                time.sleep(60)

        print(f"[{i:2d}/{stats.total}] {currency} | {status}")

    # --- 方式 B：單次 base=TWD（對照用，不計入 58/min 十筆節奏）---
    twd_base_snapshot: dict | None = None
    try:
        time.sleep(MIN_INTERVAL_SEC)
        twd_quotes = fetch_rates_for_base(session, "TWD", token)
        twd_base_snapshot = {
            "method": "forex/rates",
            "base": "TWD",
            "foreign_per_1_twd": {
                c: foreign_per_twd(twd_quotes, c)
                for c in FOREIGN_CURRENCIES
                if foreign_per_twd(twd_quotes, c) is not None
            },
            "interpretation_note": "1 TWD = X 外幣；與上方「1 外幣 = Y TWD」互為倒數關係（若有微小誤差為交叉匯率計算差）",
        }
        print("\n[對照] base=TWD 單次請求完成")
    except Exception as e:
        twd_base_snapshot = {"error": str(e)}
        print(f"\n[對照] base=TWD 失敗: {e}")

    duration_sec = time.monotonic() - started
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUTPUT_DIR / f"finnhub_fx_twd_{ts}.json"

    payload = {
        "provider": "finnhub",
        "endpoint": "/forex/rates",
        "pair_count": stats.total,
        "ok": stats.ok,
        "fail": stats.fail,
        "requests_per_minute_limit": REQUESTS_PER_MINUTE,
        "duration_seconds": round(duration_sec, 2),
        "foreign_vs_twd": by_foreign,
        "twd_base_reference": twd_base_snapshot,
        "errors_sample": stats.errors[:20],
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n--- 摘要 ---")
    print(f"成功: {stats.ok} / {stats.total}")
    print(f"失敗: {stats.fail}")
    print(f"耗時: {duration_sec:.1f} 秒")
    print(f"結果已寫入: {out_path}")
    if stats.errors:
        print(f"錯誤: {stats.errors[:5]}")
    if stats.fail == stats.total and any("403" in e for e in stats.errors):
        print(
            "\n結論：Finnhub 免費方案不含 Forex Rates。"
            "Snapvest 匯率請繼續用 open.er-api.com；"
            "若要以台幣為中心可另測 FinMind TaiwanExchangeRate（實驗腳本可再加）。"
        )
    return 0 if stats.fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
