#!/usr/bin/env python3
"""
獨立測試：FinMind 抓取「外幣對台幣」匯率（台銀牌告，TaiwanExchangeRate）

不修改、不 import Snapvest 主流程。僅寫入 experiments/output/。

環境變數：
  FINMIND_TOKEN  建議設定（600 次/小時；未設定則 300 次/小時）

限速（與 finmind_tw_batch_test.py 相同）：
  - 每分鐘最多 58 次
  - 滾動 1 小時不超過 600（有 token）/ 300（無 token）

執行：
  cd backend/scripts/experiments
  export FINMIND_TOKEN='your_token'
  python3 finmind_fx_twd_test.py
"""
from __future__ import annotations

import json
import math
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
OUTPUT_DIR = SCRIPT_DIR / "output"

FINMIND_DATA_URL = "https://api.finmindtrade.com/api/v4/data"

# 與 finnhub_fx_twd_test 相同 10 種（FinMind 支援共 19 種）
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
HOURLY_LIMIT_WITH_TOKEN = 600
HOURLY_LIMIT_WITHOUT_TOKEN = 300
HOURLY_WINDOW_SEC = 3600.0


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
    if math.isnan(f) or math.isinf(f) or f <= 0:
        return False
    # FinMind 缺資料有時為 -99
    if f < 0:
        return False
    return True


def wait_for_rate_limit(
    last_request_at: float,
    request_times: deque[float],
    hourly_limit: int,
) -> float:
    now = time.monotonic()
    while request_times and now - request_times[0] >= HOURLY_WINDOW_SEC:
        request_times.popleft()
    if len(request_times) >= hourly_limit:
        sleep_sec = HOURLY_WINDOW_SEC - (now - request_times[0]) + 0.1
        if sleep_sec > 0:
            print(f"已達每小時 {hourly_limit} 次上限，等待 {sleep_sec:.0f} 秒…")
            time.sleep(sleep_sec)
        now = time.monotonic()
        while request_times and now - request_times[0] >= HOURLY_WINDOW_SEC:
            request_times.popleft()
    if last_request_at > 0:
        elapsed = now - last_request_at
        if elapsed < MIN_INTERVAL_SEC:
            time.sleep(MIN_INTERVAL_SEC - elapsed)
    return time.monotonic()


def date_range() -> tuple[str, str]:
    end = date.today()
    start = end - timedelta(days=14)
    return start.isoformat(), end.isoformat()


def fetch_taiwan_exchange_rate(
    session: requests.Session,
    currency: str,
    token: str | None,
    start_date: str,
    end_date: str,
) -> dict | None:
    params: dict[str, str] = {
        "dataset": "TaiwanExchangeRate",
        "data_id": currency,
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
    status = body.get("status")
    if status != 200:
        msg = body.get("msg", body)
        raise RuntimeError(f"FinMind status={status}: {msg}")

    rows = body.get("data") or []
    if not rows:
        return None

    last = rows[-1]
    out = {
        "date": last.get("date"),
        "currency": last.get("currency") or currency,
        "cash_buy": last.get("cash_buy"),
        "cash_sell": last.get("cash_sell"),
        "spot_buy": last.get("spot_buy"),
        "spot_sell": last.get("spot_sell"),
    }
    # 參考中價：即期買賣平均（兩邊皆有效時）
    if _is_valid_rate(out["spot_buy"]) and _is_valid_rate(out["spot_sell"]):
        out["spot_mid"] = (float(out["spot_buy"]) + float(out["spot_sell"])) / 2
    elif _is_valid_rate(out["spot_sell"]):
        out["spot_mid"] = float(out["spot_sell"])
    elif _is_valid_rate(out["spot_buy"]):
        out["spot_mid"] = float(out["spot_buy"])
    else:
        out["spot_mid"] = None

    if out["spot_mid"] is None and not (
        _is_valid_rate(out["cash_buy"]) or _is_valid_rate(out["cash_sell"])
    ):
        return None
    return out


def main() -> int:
    token = os.environ.get("FINMIND_TOKEN", "").strip() or None
    hourly_limit = HOURLY_LIMIT_WITH_TOKEN if token else HOURLY_LIMIT_WITHOUT_TOKEN

    stats = RunStats(total=len(FOREIGN_CURRENCIES))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    started = time.monotonic()
    results: dict[str, dict] = {}
    session = requests.Session()
    request_times: deque[float] = deque()
    last_request_at = 0.0
    start_date, end_date = date_range()

    print("FinMind 匯率測試：外幣對台幣（TaiwanExchangeRate，台銀）")
    print(f"幣別：{', '.join(FOREIGN_CURRENCIES)}")
    print(f"查詢區間：{start_date} ~ {end_date}")
    print(
        f"限速：每分鐘 {REQUESTS_PER_MINUTE} 次；"
        f"每小時 ≤ {hourly_limit}（{'有' if token else '無'} token）\n"
    )
    if not token:
        print("提示：未設定 FINMIND_TOKEN，使用 300 次/小時配額。\n")

    for i, currency in enumerate(FOREIGN_CURRENCIES, start=1):
        try:
            last_request_at = wait_for_rate_limit(
                last_request_at, request_times, hourly_limit
            )
            request_times.append(time.monotonic())
            row = fetch_taiwan_exchange_rate(
                session, currency, token, start_date, end_date
            )
            if row and row.get("spot_mid") is not None:
                stats.ok += 1
                mid = row["spot_mid"]
                results[currency] = {
                    **row,
                    "interpretation": f"1 {currency} ≈ {mid:.4f} TWD（即期中價，牌告）",
                    "source_note": "FinMind TaiwanExchangeRate / 台銀",
                }
                status = f"OK  {row['date']} 即期中價 {mid:.4f}"
            else:
                stats.fail += 1
                msg = f"{currency}: 無有效即期/現金匯率"
                stats.errors.append(msg)
                results[currency] = {"error": msg, "raw": row}
                status = "EMPTY"
        except Exception as e:
            stats.fail += 1
            stats.errors.append(f"{currency}: {e}")
            results[currency] = {"error": str(e)}
            status = f"ERR ({e})"
            if "429" in str(e):
                print("遇到 429，額外等待 60 秒…")
                time.sleep(60)

        print(f"[{i:2d}/{stats.total}] {currency} | {status}")

    duration_sec = time.monotonic() - started
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUTPUT_DIR / f"finmind_fx_twd_{ts}.json"

    payload = {
        "provider": "finmind",
        "dataset": "TaiwanExchangeRate",
        "data_source": "台灣銀行牌告",
        "pair_count": stats.total,
        "ok": stats.ok,
        "fail": stats.fail,
        "requests_per_minute_limit": REQUESTS_PER_MINUTE,
        "hourly_limit": hourly_limit,
        "duration_seconds": round(duration_sec, 2),
        "rates": results,
        "errors_sample": stats.errors[:20],
        "vs_snapvest_er_api": (
            "Snapvest 現用 open.er-api（USD 基準矩陣）；"
            "FinMind 為外幣↔TWD 牌告，語意不同，若要取代需改 exchange_rates 寫入邏輯。"
        ),
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n--- 摘要 ---")
    print(f"成功: {stats.ok} / {stats.total}")
    print(f"失敗: {stats.fail}")
    print(f"耗時: {duration_sec:.1f} 秒")
    print(f"結果已寫入: {out_path}")
    if stats.errors:
        print(f"錯誤: {stats.errors[:5]}")
    return 0 if stats.fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
