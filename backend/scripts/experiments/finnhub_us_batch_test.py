#!/usr/bin/env python3
"""
獨立測試：Finnhub 抓取 200 檔美股報價（模擬 hot_stocks 清單）

不修改、不 import Snapvest 既有腳本。僅讀取本目錄 data/us_symbols_200.json。

環境變數：
  FINNHUB_API_KEY  必填（https://finnhub.io）

限速（免費方案官方 60 次/分鐘，此腳本略留餘裕）：
  - 每分鐘最多 58 次 quote
  - 200 檔約需 4 分鐘

執行：
  cd backend/scripts/experiments
  export FINNHUB_API_KEY='your_key'
  python3 finnhub_us_batch_test.py
"""
from __future__ import annotations

import json
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
SYMBOLS_PATH = SCRIPT_DIR / "data" / "us_symbols_200.json"
OUTPUT_DIR = SCRIPT_DIR / "output"

FINNHUB_QUOTE_URL = "https://finnhub.io/api/v1/quote"

# 接近上限：每分鐘 58 次（官方免費 60/min，留 2 次緩衝）
REQUESTS_PER_MINUTE = 58
MIN_INTERVAL_SEC = 60.0 / REQUESTS_PER_MINUTE  # 約 1.03 秒/次


@dataclass
class RunStats:
    total: int = 0
    ok: int = 0
    fail: int = 0
    errors: list[str] = field(default_factory=list)


def load_symbols() -> list[str]:
    raw = json.loads(SYMBOLS_PATH.read_text(encoding="utf-8"))
    symbols = list(dict.fromkeys(str(s).strip().upper() for s in raw if str(s).strip()))
    if len(symbols) < 200:
        print(f"警告：清單僅 {len(symbols)} 檔（目標 200），仍繼續測試。")
    return symbols[:200]


def fetch_quote(session: requests.Session, symbol: str, token: str) -> dict | None:
    resp = session.get(
        FINNHUB_QUOTE_URL,
        params={"symbol": symbol, "token": token},
        timeout=15,
    )
    if resp.status_code == 429:
        raise RuntimeError("429 Too Many Requests")
    resp.raise_for_status()
    data = resp.json()
    # Finnhub: c=current, pc=previous close
    if data.get("c") is None or data.get("c") == 0:
        return None
    return data


def main() -> int:
    token = os.environ.get("FINNHUB_API_KEY", "").strip()
    if not token:
        print("請設定環境變數 FINNHUB_API_KEY")
        return 1

    symbols = load_symbols()
    stats = RunStats(total=len(symbols))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    started = time.monotonic()
    results: dict[str, dict] = {}

    print(f"Finnhub 美股測試：{stats.total} 檔")
    print(f"限速：每分鐘 {REQUESTS_PER_MINUTE} 次，間隔 ≥ {MIN_INTERVAL_SEC:.1f} 秒")
    est_minutes = (stats.total + REQUESTS_PER_MINUTE - 1) // REQUESTS_PER_MINUTE
    print(f"預估耗時：約 {est_minutes} 分鐘\n")

    session = requests.Session()
    last_request_at = 0.0

    for i, symbol in enumerate(symbols, start=1):
        elapsed_since = time.monotonic() - last_request_at
        if last_request_at > 0 and elapsed_since < MIN_INTERVAL_SEC:
            time.sleep(MIN_INTERVAL_SEC - elapsed_since)

        try:
            last_request_at = time.monotonic()
            data = fetch_quote(session, symbol, token)
            if data:
                stats.ok += 1
                results[symbol] = {
                    "current": data.get("c"),
                    "prev_close": data.get("pc"),
                    "high": data.get("h"),
                    "low": data.get("l"),
                    "open": data.get("o"),
                    "timestamp": data.get("t"),
                }
                status = "OK"
            else:
                stats.fail += 1
                stats.errors.append(f"{symbol}: 無有效報價")
                status = "EMPTY"
        except Exception as e:
            stats.fail += 1
            stats.errors.append(f"{symbol}: {e}")
            status = f"ERR ({e})"
            if "429" in str(e):
                print("遇到 429，額外等待 60 秒…")
                time.sleep(60)

        minute_bucket = (i - 1) // REQUESTS_PER_MINUTE + 1
        print(f"[{i:3d}/{stats.total}] 第 {minute_bucket} 分鐘批次 | {symbol} | {status}")

    duration_sec = time.monotonic() - started
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUTPUT_DIR / f"finnhub_us_{ts}.json"
    payload = {
        "provider": "finnhub",
        "market": "US",
        "symbol_count": stats.total,
        "ok": stats.ok,
        "fail": stats.fail,
        "requests_per_minute_limit": REQUESTS_PER_MINUTE,
        "duration_seconds": round(duration_sec, 2),
        "quotes": results,
        "errors_sample": stats.errors[:20],
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n--- 摘要 ---")
    print(f"成功: {stats.ok} / {stats.total}")
    print(f"失敗: {stats.fail}")
    print(f"耗時: {duration_sec / 60:.1f} 分鐘 ({duration_sec:.0f} 秒)")
    print(f"結果已寫入: {out_path}")
    if stats.errors:
        print(f"錯誤範例（最多 5 筆）: {stats.errors[:5]}")
    return 0 if stats.fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
