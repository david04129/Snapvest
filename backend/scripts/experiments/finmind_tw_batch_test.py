#!/usr/bin/env python3
"""
獨立測試：FinMind 抓取台股日收盤（模擬 hot_stocks 清單，含 ETF／含英文字母代號）

不修改、不 import Snapvest 既有腳本。僅讀取本目錄 data/tw_symbols_50.json。

環境變數：
  FINMIND_TOKEN  建議設定（官網註冊驗證後 600 次/小時；未設定則 300 次/小時）

限速（有 token：600 次/小時；無 token：300 次/小時）：
  - 每分鐘最多 58 次（清單內所有代號依序抓取）
  - 同時追蹤滾動 1 小時總量，不超過 HOURLY_LIMIT

執行：
  cd backend/scripts/experiments
  export FINMIND_TOKEN='your_token'
  python3 finmind_tw_batch_test.py
"""
from __future__ import annotations

import json
import os
import sys
import time
from collections import deque
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

try:
    import requests
except ImportError:
    print("請安裝: pip3 install requests")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
SYMBOLS_PATH = SCRIPT_DIR / "data" / "tw_symbols_50.json"
OUTPUT_DIR = SCRIPT_DIR / "output"

FINMIND_DATA_URL = "https://api.finmindtrade.com/api/v4/data"

# 每分鐘 58 次；另以滾動 1 小時計數不超過 FinMind 上限
REQUESTS_PER_MINUTE = 58
MIN_INTERVAL_SEC = 60.0 / REQUESTS_PER_MINUTE  # 約 1.03 秒/次
HOURLY_LIMIT_WITH_TOKEN = 600
HOURLY_LIMIT_WITHOUT_TOKEN = 300
HOURLY_WINDOW_SEC = 3600.0


@dataclass
class RunStats:
    total: int = 0
    ok: int = 0
    fail: int = 0
    errors: list[str] = field(default_factory=list)


def load_symbols() -> list[str]:
    raw = json.loads(SYMBOLS_PATH.read_text(encoding="utf-8"))
    symbols = list(dict.fromkeys(str(s).strip() for s in raw if str(s).strip()))
    return symbols


def wait_for_rate_limit(
    last_request_at: float,
    request_times: deque[float],
    hourly_limit: int,
) -> float:
    """每分鐘間隔 + 滾動 1 小時不超過 hourly_limit。回傳更新後的 last_request_at。"""
    now = time.monotonic()

    while request_times and now - request_times[0] >= HOURLY_WINDOW_SEC:
        request_times.popleft()

    if len(request_times) >= hourly_limit:
        sleep_sec = HOURLY_WINDOW_SEC - (now - request_times[0]) + 0.1
        if sleep_sec > 0:
            print(
                f"已達每小時 {hourly_limit} 次上限，等待 {sleep_sec:.0f} 秒後繼續…"
            )
            time.sleep(sleep_sec)
        now = time.monotonic()
        while request_times and now - request_times[0] >= HOURLY_WINDOW_SEC:
            request_times.popleft()

    if last_request_at > 0:
        elapsed = now - last_request_at
        if elapsed < MIN_INTERVAL_SEC:
            time.sleep(MIN_INTERVAL_SEC - elapsed)

    return time.monotonic()


def trading_date_range() -> tuple[str, str]:
    """查最近幾個曆日，取 API 回傳最後一筆收盤（避開週末無資料）。"""
    end = date.today()
    start = end - timedelta(days=7)
    return start.isoformat(), end.isoformat()


def fetch_taiwan_stock_price(
    session: requests.Session,
    stock_id: str,
    token: str | None,
    start_date: str,
    end_date: str,
) -> dict | None:
    params: dict[str, str] = {
        "dataset": "TaiwanStockPrice",
        "data_id": stock_id,
        "start_date": start_date,
        "end_date": end_date,
    }
    if token:
        params["token"] = token

    resp = session.get(FINMIND_DATA_URL, params=params, timeout=30)
    if resp.status_code == 429:
        raise RuntimeError("429 Too Many Requests")
    resp.raise_for_status()
    body = resp.json()
    if body.get("status") != 200:
        msg = body.get("msg", body)
        raise RuntimeError(f"FinMind status={body.get('status')}: {msg}")

    rows = body.get("data") or []
    if not rows:
        return None
    last = rows[-1]
    close = last.get("close")
    if close is None:
        return None
    return {
        "date": last.get("date"),
        "stock_id": last.get("stock_id", stock_id),
        "open": last.get("open"),
        "high": last.get("max"),
        "low": last.get("min"),
        "close": close,
        "volume": last.get("Trading_Volume"),
    }


def main() -> int:
    token = os.environ.get("FINMIND_TOKEN", "").strip() or None
    hourly_limit = HOURLY_LIMIT_WITH_TOKEN if token else HOURLY_LIMIT_WITHOUT_TOKEN
    if not token:
        print("未設定 FINMIND_TOKEN，使用未驗證配額（約 300 次/小時）。")

    symbols = load_symbols()
    stats = RunStats(total=len(symbols))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    start_date, end_date = trading_date_range()
    started = time.monotonic()
    results: dict[str, dict] = {}

    print(f"FinMind 台股測試：{stats.total} 檔")
    print(f"查詢區間：{start_date} ~ {end_date}")
    print(
        f"限速：每分鐘 {REQUESTS_PER_MINUTE} 次，每小時上限 {hourly_limit} 次"
    )
    est_minutes = max(1, (stats.total + REQUESTS_PER_MINUTE - 1) // REQUESTS_PER_MINUTE)
    print(f"預估耗時：約 {est_minutes} 分鐘\n")

    session = requests.Session()
    last_request_at = 0.0
    request_times: deque[float] = deque()

    for i, stock_id in enumerate(symbols, start=1):
        last_request_at = wait_for_rate_limit(
            last_request_at, request_times, hourly_limit
        )

        try:
            request_times.append(time.monotonic())
            row = fetch_taiwan_stock_price(
                session, stock_id, token, start_date, end_date
            )
            if row:
                stats.ok += 1
                results[stock_id] = row
                status = f"OK close={row['close']} ({row['date']})"
            else:
                stats.fail += 1
                stats.errors.append(f"{stock_id}: 區間內無資料")
                status = "EMPTY"
        except Exception as e:
            stats.fail += 1
            stats.errors.append(f"{stock_id}: {e}")
            status = f"ERR ({e})"
            if "429" in str(e):
                print("遇到 429，額外等待 60 秒…")
                time.sleep(60)

        minute_bucket = (i - 1) // REQUESTS_PER_MINUTE + 1
        print(f"[{i:2d}/{stats.total}] 第 {minute_bucket} 分鐘批次 | {stock_id} | {status}")

    duration_sec = time.monotonic() - started
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUTPUT_DIR / f"finmind_tw_{ts}.json"
    payload = {
        "provider": "finmind",
        "market": "TW",
        "dataset": "TaiwanStockPrice",
        "query_start_date": start_date,
        "query_end_date": end_date,
        "symbol_count": stats.total,
        "ok": stats.ok,
        "fail": stats.fail,
        "requests_per_minute_limit": REQUESTS_PER_MINUTE,
        "hourly_limit": hourly_limit,
        "duration_seconds": round(duration_sec, 2),
        "prices": results,
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
