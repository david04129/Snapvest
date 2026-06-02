#!/usr/bin/env python3
"""
Snapvest 股價／匯率更新腳本（Cloud Run / 手動）
- 抓價範圍：僅 tracked_symbols（is_active=true，去重）
- 台股 Fugle intraday/quote；匯率 FinMind 台銀牌告；美股 Finnhub；加密 CoinGecko
- 盤中只寫 snapshots；收盤寫 snapshots + history；加密 00:00 hourly 另寫昨日 history
"""
import json
import math
import os
import time
from collections import deque
from dataclasses import dataclass
from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Callable, Optional, Set
from urllib.parse import quote as url_quote
from zoneinfo import ZoneInfo

# 台灣時區 UTC+8（與 market_session 的 Asia/Taipei 等價；resolve 用 ZoneInfo）
TW_TZ = timezone(timedelta(hours=8))
TW_ZONE = ZoneInfo("Asia/Taipei")
NY_ZONE = ZoneInfo("America/New_York")

try:
    from supabase import create_client, Client
    import yfinance as yf
    import requests
except ImportError:
    print("請先安裝依賴: pip install -r requirements.txt")
    exit(1)

# 從環境變數讀取
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
FINNHUB_API_KEY = os.environ.get("FINNHUB_API_KEY", "").strip()
FINMIND_TOKEN = os.environ.get("FINMIND_TOKEN", "").strip() or None
FUGLE_API_KEY = os.environ.get("FUGLE_API_KEY", "").strip()

COINGECKO_BASE = "https://api.coingecko.com/api/v3"
FINNHUB_QUOTE_URL = "https://finnhub.io/api/v1/quote"
FINMIND_DATA_URL = "https://api.finmindtrade.com/api/v4/data"
FUGLE_STOCK_BASE = "https://api.fugle.tw/marketdata/v1.0/stock"
REQUESTS_PER_MINUTE = 58
MIN_INTERVAL_SEC = 60.0 / REQUESTS_PER_MINUTE
RETRY_PAUSE_SEC = 60
HOURLY_LIMIT_FINMIND = 600 if FINMIND_TOKEN else 300
TRACKED_SYMBOL_FAILURE_DISABLE_THRESHOLD = 5
CRYPTO_ID_MAP_PATH = Path(__file__).parent / "data" / "crypto_coingecko_map.json"
YAHOO_TW_SUFFIX = ".TW"  # 台股 Yahoo symbol 格式
# FinMind 台銀牌告：1 單位外幣 = rate TWD（與台股更新共用 FinMind 配額）
FINMIND_FX_CURRENCIES = ("USD", "EUR", "JPY", "CNY", "HKD", "AUD")
FINMIND_FX_SOURCE = "finmind"


@dataclass
class FetchedQuote:
    price: float
    source: str
    close_date: date


def tw_now() -> datetime:
    return datetime.now(TW_TZ)


def tw_now_iso_seconds() -> str:
    return tw_now().replace(microsecond=0).isoformat()


def tw_now_local_seconds() -> str:
    return tw_now().replace(microsecond=0).strftime("%Y-%m-%d %H:%M:%S")


def tw_calendar_yesterday() -> date:
    """台北曆日的昨日（加密 00:00 日線 history 的 price_date）。"""
    return tw_now().astimezone(TW_ZONE).date() - timedelta(days=1)


def is_tw_midnight_hour(at: Optional[datetime] = None) -> bool:
    at = at or tw_now()
    return at.astimezone(TW_ZONE).hour == 0


def parse_close_date(value) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def _trading_day_on_or_before(
    market: str,
    session_date: date,
    calendar_rows: Optional[dict[tuple[str, date], dict]],
) -> date:
    """若 session_date 休市，往前找最近交易日；無日曆則用週一至週五 fallback。"""
    from market_session import _load_calendar_day

    for offset in range(14):
        candidate = session_date - timedelta(days=offset)
        if calendar_rows is not None:
            is_td, _ = _load_calendar_day(calendar_rows, market, candidate)
            if is_td:
                return candidate
        elif candidate.weekday() < 5:
            return candidate
    return session_date


def resolve_session_close_date(
    market: str,
    *,
    at: Optional[datetime] = None,
    calendar_rows: Optional[dict[tuple[str, date], dict]] = None,
) -> date:
    """
    本輪報價所屬交易日（寫入 current_close_date）。
    台股：台北曆日；美股：紐約曆日（例：週一 23:30 台北盤中 → 週一 ET，不再誤標上週五）。
    """
    at = at or tw_now()
    if market == "crypto":
        return at.astimezone(TW_ZONE).date()

    if market == "us":
        local_date = at.astimezone(NY_ZONE).date()
        cal_market = "us"
    else:
        local_date = at.astimezone(TW_ZONE).date()
        cal_market = "tw"

    return _trading_day_on_or_before(cal_market, local_date, calendar_rows)


def is_retryable_error(msg: str) -> bool:
    lowered = msg.lower()
    return "429" in msg or "timeout" in lowered or "timed out" in lowered


def _is_valid_price(val) -> bool:
    """股價／匯率數值檢查（過濾 nan、inf、非正數）"""
    if val is None:
        return False
    try:
        f = float(val)
    except (TypeError, ValueError):
        return False
    if math.isnan(f) or math.isinf(f):
        return False
    return f > 0


def _finmind_spot_mid(row: dict) -> Optional[float]:
    """台銀即期中價；缺資料時 FinMind 可能為 -99。"""
    buy, sell = row.get("spot_buy"), row.get("spot_sell")
    if _is_valid_price(buy) and _is_valid_price(sell):
        return (float(buy) + float(sell)) / 2
    if _is_valid_price(sell):
        return float(sell)
    if _is_valid_price(buy):
        return float(buy)
    return None


def fetch_finmind_exchange_one(
    http: requests.Session,
    currency: str,
) -> tuple[Optional[float], Optional[str], str]:
    """TaiwanExchangeRate：回傳 (twd_per_unit, rate_date, error)。"""
    end = tw_now().date()
    start = end - timedelta(days=14)
    params: dict[str, str] = {
        "dataset": "TaiwanExchangeRate",
        "data_id": currency,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
    }
    if FINMIND_TOKEN:
        params["token"] = FINMIND_TOKEN
    try:
        resp = http.get(FINMIND_DATA_URL, params=params, timeout=30)
        if resp.status_code == 429:
            return None, None, "429"
        resp.raise_for_status()
        body = resp.json()
        if body.get("status") != 200:
            return None, None, str(body.get("msg", body))
        rows = body.get("data") or []
        if not rows:
            return None, None, "empty"
        last = rows[-1]
        mid = _finmind_spot_mid(last)
        if not _is_valid_price(mid):
            return None, None, "invalid_spot"
        rate_date = str(last.get("date") or end.isoformat())[:10]
        return float(mid), rate_date, ""
    except Exception as e:
        return None, None, str(e)


def _raise_on_supabase_error(response, context: str) -> None:
    """Supabase 2.x：RLS 拒絕或 schema 錯誤時 error 不為空，需主動檢查"""
    err = getattr(response, "error", None)
    if err is not None:
        raise RuntimeError(f"{context}: {err}")


def _upsert_one_exchange_rate(supabase: Client, row: dict) -> None:
    """成功抓到新價時寫入；舊 rate 滾入 previous_*。抓不到則不呼叫。"""
    existing = (
        supabase.table("exchange_rates")
        .select("rate, updated_at")
        .eq("from_currency", row["from_currency"])
        .eq("to_currency", row["to_currency"])
        .limit(1)
        .execute()
    )
    _raise_on_supabase_error(existing, f"exchange_rates read {row['from_currency']}")
    if existing.data and existing.data[0].get("rate") is not None:
        prev = existing.data[0]
        row["previous_rate"] = str(prev["rate"])
        row["previous_updated_at"] = prev.get("updated_at")
    resp = supabase.table("exchange_rates").upsert(
        row,
        on_conflict="from_currency,to_currency",
    ).execute()
    _raise_on_supabase_error(resp, f"exchange_rates upsert {row['from_currency']}")


def update_exchange_rates(
    supabase: Client,
    finmind_times: Optional[deque[float]] = None,
) -> int:
    """FinMind 台銀牌告 → exchange_rates（1 外幣 = rate TWD）；失敗列保留現值。"""
    http = requests.Session()
    times = finmind_times if finmind_times is not None else deque()
    now = tw_now_iso_seconds()
    ok_count = 0
    skip_count = 0
    last_at = 0.0

    for currency in FINMIND_FX_CURRENCIES:
        _finmind_wait_hourly(times)
        last_at = _rate_limit_wait(last_at)
        times.append(time.monotonic())

        twd_per_unit, rate_date, err = fetch_finmind_exchange_one(http, currency)
        if twd_per_unit is not None:
            row = {
                "from_currency": currency,
                "to_currency": "TWD",
                "rate": str(twd_per_unit),
                "updated_at": now,
            }
            _upsert_one_exchange_rate(supabase, row)
            ok_count += 1
            print(
                f"  {currency}/TWD = {twd_per_unit:.6f}"
                + (f"（牌告日 {rate_date}）" if rate_date else "")
            )
        else:
            skip_count += 1
            print(f"  {currency}/TWD 保留現值: {err or 'no_data'}")

    if ok_count == 0:
        probe = (
            supabase.table("exchange_rates")
            .select("from_currency")
            .eq("to_currency", "TWD")
            .in_("from_currency", list(FINMIND_FX_CURRENCIES))
            .limit(1)
            .execute()
        )
        _raise_on_supabase_error(probe, "exchange_rates probe")
        if not probe.data:
            raise RuntimeError("FinMind 匯率無有效資料，且資料庫尚無歷史匯率")
        print(f"  本輪 0 筆更新、{skip_count} 筆略過，沿用資料庫現值／previous")
        return 0

    meta_resp = supabase.table("price_update_metadata").upsert(
        {"id": "global", "last_updated_at": now},
        on_conflict="id",
    ).execute()
    _raise_on_supabase_error(meta_resp, "price_update_metadata upsert")

    verify = (
        supabase.table("exchange_rates")
        .select("rate, updated_at, previous_rate, previous_updated_at")
        .eq("from_currency", "USD")
        .eq("to_currency", "TWD")
        .limit(1)
        .execute()
    )
    _raise_on_supabase_error(verify, "exchange_rates verify read")
    if verify.data:
        row = verify.data[0]
        print(
            f"  DB 驗證 USD/TWD: rate={row.get('rate')} "
            f"prev={row.get('previous_rate')} updated_at={row.get('updated_at')}"
        )
    if skip_count:
        print(f"  匯率摘要: 更新 {ok_count} 筆，保留現值 {skip_count} 筆")
    return ok_count


def get_supabase() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise ValueError("請設定 SUPABASE_URL 和 SUPABASE_SERVICE_ROLE_KEY")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def _normalize_symbol(asset_type: str, symbol: str) -> str:
    """加密貨幣、美股統一大寫；台股保留原樣"""
    if asset_type in ("crypto", "stock_us"):
        return symbol.upper()
    return symbol.strip()


HOLDINGS_DISPLAY_ORDER_BASE = 500


def _merge_symbol_row(
    symbols_set: set[tuple[str, str]],
    symbols_list: list[dict],
    asset_type: str,
    symbol: str,
    display_order: int,
) -> None:
    sym = _normalize_symbol(asset_type, symbol)
    if not sym or asset_type not in ("stock_tw", "stock_us", "crypto"):
        return
    key = (asset_type, sym)
    if key in symbols_set:
        return
    symbols_set.add(key)
    symbols_list.append(
        {"asset_type": asset_type, "symbol": sym, "display_order": display_order}
    )


def collect_tracked_symbols(supabase: Client) -> list[dict]:
    """匿名 tracked_symbols 大池子中的標的（不含任何 user_id / quantity / cost）"""
    symbols_set: set[tuple[str, str]] = set()
    symbols_list: list[dict] = []
    try:
        r = (
            supabase.table("tracked_symbols")
            .select("asset_type, normalized_symbol, symbol, first_seen_at")
            .eq("is_active", True)
            .execute()
        )
        _raise_on_supabase_error(r, "tracked_symbols read")
        order = HOLDINGS_DISPLAY_ORDER_BASE
        for row in r.data or []:
            asset_type = row.get("asset_type")
            symbol = row.get("normalized_symbol") or row.get("symbol")
            if not asset_type or not symbol:
                continue
            _merge_symbol_row(symbols_set, symbols_list, asset_type, symbol, order)
            order += 1
    except Exception as e:
        print(f"取得 tracked_symbols 時出錯: {e}")
    return symbols_list


def get_symbols_for_job(supabase: Client) -> list[dict]:
    """排程抓價清單：tracked_symbols（is_active=true）。"""
    return collect_tracked_symbols(supabase)


def _rate_limit_wait(last_request_at: float) -> float:
    if last_request_at > 0:
        elapsed = time.monotonic() - last_request_at
        if elapsed < MIN_INTERVAL_SEC:
            time.sleep(MIN_INTERVAL_SEC - elapsed)
    return time.monotonic()


def _finmind_wait_hourly(request_times: deque[float]) -> None:
    now = time.monotonic()
    while request_times and now - request_times[0] >= 3600.0:
        request_times.popleft()
    if len(request_times) >= HOURLY_LIMIT_FINMIND:
        sleep_sec = 3600.0 - (now - request_times[0]) + 0.1
        if sleep_sec > 0:
            print(f"  FinMind 達每小時 {HOURLY_LIMIT_FINMIND} 次，等待 {sleep_sec:.0f}s…")
            time.sleep(sleep_sec)


def fetch_fugle_tw_quote(
    http: requests.Session,
    symbol: str,
    session_close: date,
) -> tuple[Optional[FetchedQuote], str]:
    """台股盤中／收盤皆用 Fugle intraday/quote（同一 endpoint）。"""
    if not FUGLE_API_KEY:
        return None, "no_fugle_key"
    url = f"{FUGLE_STOCK_BASE}/intraday/quote/{url_quote(symbol, safe='')}"
    try:
        resp = http.get(
            url,
            headers={"X-API-KEY": FUGLE_API_KEY},
            timeout=30,
        )
        if resp.status_code == 401:
            return None, "401 Unauthorized"
        if resp.status_code == 403:
            return None, "403 Forbidden"
        if resp.status_code == 404:
            return None, f"404 Not Found ({symbol})"
        if resp.status_code == 429:
            return None, "429"
        resp.raise_for_status()
        body = resp.json()
        if not isinstance(body, dict):
            return None, "invalid_json"
        price = None
        if _is_valid_price(body.get("lastPrice")):
            price = float(body["lastPrice"])
        elif _is_valid_price(body.get("closePrice")):
            price = float(body["closePrice"])
        if price is None:
            return None, "invalid_quote"
        close_date = parse_close_date(body.get("date")) or session_close
        return FetchedQuote(price, "fugle", close_date), ""
    except Exception as e:
        return None, str(e)


def fetch_finnhub_one(
    http: requests.Session,
    symbol: str,
    session_close: date,
) -> tuple[Optional[FetchedQuote], str]:
    if not FINNHUB_API_KEY:
        return None, "no_finnhub_key"
    try:
        resp = http.get(
            FINNHUB_QUOTE_URL,
            params={"symbol": symbol, "token": FINNHUB_API_KEY},
            timeout=15,
        )
        if resp.status_code == 429:
            return None, "429"
        resp.raise_for_status()
        data = resp.json()
        price = data.get("c")
        if not _is_valid_price(price):
            return None, "invalid_quote"
        return FetchedQuote(float(price), "finnhub", session_close), ""
    except Exception as e:
        return None, str(e)


def fetch_yahoo_one(s: dict, session_close: date) -> tuple[Optional[FetchedQuote], str]:
    ys = f"{s['symbol']}{YAHOO_TW_SUFFIX}" if s["asset_type"] == "stock_tw" else s["symbol"]
    try:
        ticker = yf.Ticker(ys)
        hist = ticker.history(period="5d")
        if hist.empty or "Close" not in hist.columns:
            return None, "empty"
        price = float(hist["Close"].iloc[-1])
        if not _is_valid_price(price):
            return None, "invalid_close"
        return FetchedQuote(price, "yfinance", session_close), ""
    except Exception as e:
        return None, str(e)


def _fetch_primary_batch(
    symbols: list[dict],
    session_close: date,
    fetch_one: Callable,
    label: str,
    finmind_hourly: Optional[deque[float]] = None,
) -> tuple[dict[tuple[str, str], FetchedQuote], dict[tuple[str, str], str]]:
    ok: dict[tuple[str, str], FetchedQuote] = {}
    fail: dict[tuple[str, str], str] = {}
    if not symbols:
        return ok, fail

    http = requests.Session()
    last_at = 0.0
    for s in symbols:
        key = (s["asset_type"], s["symbol"])
        if finmind_hourly is not None:
            _finmind_wait_hourly(finmind_hourly)
        last_at = _rate_limit_wait(last_at)
        if finmind_hourly is not None:
            finmind_hourly.append(time.monotonic())

        if s["asset_type"] == "stock_tw":
            quote, err = fetch_one(http, s["symbol"], session_close)
        else:
            quote, err = fetch_one(http, s["symbol"], session_close)

        if quote:
            ok[key] = quote
        else:
            fail[key] = err or "unknown"

    print(f"  {label} 第一輪: 成功 {len(ok)} / {len(symbols)}")
    return ok, fail


def fetch_stocks_for_market(
    asset_type: str,
    symbols: list[dict],
    session_close: date,
    finmind_times: Optional[deque[float]] = None,
    *,
    yfinance_fallback: bool = True,
) -> dict[tuple[str, str], FetchedQuote]:
    """Primary → 等 60s → retry 可重試失敗 →（美股可選）yfinance 補其餘。"""
    market_symbols = [s for s in symbols if s["asset_type"] == asset_type]
    if not market_symbols:
        return {}

    if asset_type == "stock_tw":
        label = "Fugle"
        finmind_times = None
        if not FUGLE_API_KEY:
            print("  未設定 FUGLE_API_KEY，略過台股更新")
            return {}
        fetch_one = fetch_fugle_tw_quote
        yfinance_fallback = False
    else:
        label = "Finnhub"
        finmind_times = None
        if not FINNHUB_API_KEY:
            print("  未設定 FINNHUB_API_KEY，美股將直接嘗試 yfinance fallback")
        fetch_one = fetch_finnhub_one

    ok, fail = _fetch_primary_batch(
        market_symbols, session_close, fetch_one, label, finmind_times
    )

    if fail:
        print(f"  {label} 等待 {RETRY_PAUSE_SEC}s 後重試失敗檔…")
        time.sleep(RETRY_PAUSE_SEC)
        retry_list = [
            s
            for s in market_symbols
            if (s["asset_type"], s["symbol"]) in fail
            and is_retryable_error(fail[(s["asset_type"], s["symbol"])])
        ]
        if retry_list:
            ok2, fail2 = _fetch_primary_batch(
                retry_list, session_close, fetch_one, f"{label} retry", finmind_times
            )
            ok.update(ok2)
            for k, v in fail2.items():
                fail[k] = v
            for k in ok2:
                fail.pop(k, None)
        print(f"  {label} 重試後累計成功 {len(ok)} / {len(market_symbols)}")

    still_missing = [
        s
        for s in market_symbols
        if (s["asset_type"], s["symbol"]) not in ok
    ]
    if still_missing:
        if yfinance_fallback:
            print(f"  yfinance fallback: {len(still_missing)} 檔")
            for s in still_missing:
                key = (s["asset_type"], s["symbol"])
                quote, err = fetch_yahoo_one(s, session_close)
                if quote:
                    ok[key] = quote
                else:
                    print(f"    {s['symbol']}: {err}")
                time.sleep(0.3)
        else:
            print(
                f"  略過 yfinance（保留 DB 現有價，共 {len(still_missing)} 檔）"
            )
            for s in still_missing:
                key = (s["asset_type"], s["symbol"])
                reason = fail.get(key, "unknown")
                print(f"    {s['symbol']}: {label} 失敗 ({reason})")

    return ok


def load_crypto_coingecko_map() -> dict[str, str]:
    """symbol（大寫）→ CoinGecko id；由 scripts/build_symbols_crypto.py 產生"""
    fallback = {
        "BTC": "bitcoin", "ETH": "ethereum", "BNB": "binancecoin", "SOL": "solana",
        "XRP": "ripple", "ADA": "cardano", "DOGE": "dogecoin", "AVAX": "avalanche-2",
        "DOT": "polkadot", "LINK": "chainlink", "MATIC": "matic-network",
        "UNI": "uniswap", "USDC": "usd-coin", "USDT": "tether",
    }
    if not CRYPTO_ID_MAP_PATH.exists():
        print(f"  ⚠️ 未找到 {CRYPTO_ID_MAP_PATH.name}，請執行 scripts/build_symbols_crypto.py")
        return fallback
    try:
        with open(CRYPTO_ID_MAP_PATH, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and data:
            return {k.upper(): v for k, v in data.items()}
    except (json.JSONDecodeError, OSError) as e:
        print(f"  ⚠️ 讀取 crypto 映射失敗: {e}")
    return fallback


def fetch_crypto_prices_coingecko(symbols: list[dict]) -> dict[tuple, float]:
    """用 CoinGecko 批次抓加密貨幣（需正確的 CoinGecko id，非 ticker）"""
    result = {}
    cryptos = [s for s in symbols if s["asset_type"] == "crypto"]
    if not cryptos:
        return result

    id_map = load_crypto_coingecko_map()
    ids = []
    mapping = {}
    skipped = []
    for s in cryptos:
        sym = s["symbol"].upper()
        cg_id = id_map.get(sym)
        if not cg_id:
            skipped.append(sym)
            continue
        ids.append(cg_id)
        mapping[cg_id] = (s["asset_type"], s["symbol"])

    if skipped:
        print(f"  CoinGecko 略過 {len(skipped)} 筆（無映射）: {', '.join(skipped[:8])}{'...' if len(skipped) > 8 else ''}")

    if not ids:
        return result

    # CoinGecko 單次 ids 不宜過多，分批請求
    batch_size = 100
    for i in range(0, len(ids), batch_size):
        batch = ids[i : i + batch_size]
        ids_str = ",".join(batch)
        url = f"{COINGECKO_BASE}/simple/price?ids={ids_str}&vs_currencies=usd"
        try:
            resp = requests.get(url, timeout=30, headers={"User-Agent": "Snapvest-DailyPrice/1.0"})
            resp.raise_for_status()
            data = resp.json()
            for cg_id, prices in data.items():
                key = mapping.get(cg_id)
                if key and "usd" in prices:
                    result[key] = float(prices["usd"])
            time.sleep(1.2)
        except Exception as e:
            print(f"CoinGecko 請求失敗: {e}")

    return result


def upsert_prices(supabase: Client, updates: list[dict], default_price_kind: Optional[str] = None):
    """寫入 asset_price_snapshots；舊 current 滾入 previous_*"""
    if not updates:
        return
    for row in updates:
        if default_price_kind and not row.get("price_kind"):
            row["price_kind"] = default_price_kind
        try:
            existing = (
                supabase.table("asset_price_snapshots")
                .select(
                    "current_price, current_close_date, current_updated_at, current_price_source"
                )
                .eq("asset_type", row["asset_type"])
                .eq("symbol", row["symbol"])
                .execute()
            )
            if existing.data and existing.data[0].get("current_price"):
                prev = existing.data[0]
                row["previous_price"] = str(prev["current_price"])
                row["previous_close_date"] = prev.get("current_close_date")
                row["previous_updated_at"] = prev.get("current_updated_at")
                row["previous_price_source"] = prev.get("current_price_source")
            supabase.table("asset_price_snapshots").upsert(
                row,
                on_conflict="asset_type,symbol",
                ignore_duplicates=False,
            ).execute()
        except Exception as e:
            print(f"寫入 {row.get('asset_type')}/{row.get('symbol')} 失敗: {e}")
        time.sleep(0.05)
    supabase.table("price_update_metadata").upsert(
        {"id": "global", "last_updated_at": tw_now_iso_seconds()},
        on_conflict="id",
    ).execute()


def upsert_price_history(supabase: Client, updates: list[dict]) -> None:
    """將每輪成功抓到的日價格寫入歷史表，供 App 補點使用。"""
    if not updates:
        return
    rows = [
        {
            "asset_type": row["asset_type"],
            "symbol": row["symbol"],
            "price_date": row["current_close_date"],
            "close_price": row["current_price"],
            "currency": row["currency"],
            "source": row.get("current_price_source"),
            "updated_at": row["current_updated_at"],
        }
        for row in updates
    ]
    for i in range(0, len(rows), 100):
        chunk = rows[i : i + 100]
        try:
            resp = supabase.table("asset_price_history").upsert(
                chunk,
                on_conflict="asset_type,symbol,price_date",
            ).execute()
            _raise_on_supabase_error(resp, "asset_price_history upsert")
        except Exception as e:
            print(f"寫入 asset_price_history 失敗: {e}")
        time.sleep(0.05)


def mark_tracked_symbols_synced(supabase: Client, updates: list[dict], synced_at: str) -> None:
    """標記匿名追蹤池中本輪成功同步的 symbol。"""
    for row in updates:
        try:
            supabase.table("tracked_symbols").update(
                {
                    "last_price_synced_at": synced_at,
                    "failure_count": 0,
                    "last_error": None,
                    "last_failed_at": None,
                    "is_active": True,
                }
            ).eq("asset_type", row["asset_type"]).eq(
                "normalized_symbol", row["symbol"]
            ).execute()
        except Exception as e:
            print(f"標記 tracked_symbols {row.get('asset_type')}/{row.get('symbol')} 失敗: {e}")
        time.sleep(0.02)


def mark_tracked_symbols_failed(
    supabase: Client,
    attempted_symbols: list[dict],
    successful_keys: set[tuple[str, str]],
    failed_at: str,
) -> None:
    """記錄本輪有嘗試但未成功寫價的匿名 symbols；連續失敗達門檻後停用。"""
    for row in attempted_symbols:
        asset_type = row["asset_type"]
        symbol = row["symbol"]
        if (asset_type, symbol) in successful_keys:
            continue

        try:
            existing = (
                supabase.table("tracked_symbols")
                .select("failure_count")
                .eq("asset_type", asset_type)
                .eq("normalized_symbol", symbol)
                .maybe_single()
                .execute()
            )
            _raise_on_supabase_error(existing, f"tracked_symbols read failure_count {asset_type}/{symbol}")
            if not existing.data:
                continue

            next_failure_count = int(existing.data.get("failure_count") or 0) + 1
            should_disable = next_failure_count >= TRACKED_SYMBOL_FAILURE_DISABLE_THRESHOLD
            update_row = {
                "failure_count": next_failure_count,
                "last_error": "price_update_failed",
                "last_failed_at": failed_at,
            }
            if should_disable:
                update_row["is_active"] = False

            resp = (
                supabase.table("tracked_symbols")
                .update(update_row)
                .eq("asset_type", asset_type)
                .eq("normalized_symbol", symbol)
                .execute()
            )
            _raise_on_supabase_error(resp, f"tracked_symbols failure update {asset_type}/{symbol}")
            if should_disable:
                print(f"  停用 tracked symbol: {asset_type}/{symbol}（連續失敗 {next_failure_count} 次）")
        except Exception as e:
            print(f"記錄 tracked_symbols 失敗狀態 {asset_type}/{symbol} 失敗: {e}")
        time.sleep(0.02)


MARKET_ALIASES = {
    "tw": "stock_tw",
    "us": "stock_us",
    "crypto": "crypto",
}


def parse_markets_arg(markets_str: Optional[str]) -> Optional[Set[str]]:
    """解析 --markets tw,crypto → {'tw','crypto'}；None 表示全部"""
    if not markets_str or not markets_str.strip():
        return None
    parts = {p.strip().lower() for p in markets_str.split(",") if p.strip()}
    unknown = parts - set(MARKET_ALIASES)
    if unknown:
        raise ValueError(f"不支援的 markets: {unknown}，請用 tw, us, crypto")
    return parts


def filter_symbols_by_markets(symbols: list[dict], markets: Optional[Set[str]]) -> list[dict]:
    if markets is None:
        return symbols
    allowed = {MARKET_ALIASES[m] for m in markets}
    return [s for s in symbols if s["asset_type"] in allowed]


def _quotes_to_rows(
    quotes: dict[tuple[str, str], FetchedQuote],
    updated_at: str,
    price_kind: str,
) -> list[dict]:
    currency_map = {"stock_tw": "TWD", "stock_us": "USD", "crypto": "USD"}
    rows = []
    for (asset_type, symbol), q in quotes.items():
        rows.append({
            "asset_type": asset_type,
            "symbol": symbol,
            "currency": currency_map.get(asset_type, "USD"),
            "current_price": str(q.price),
            "current_close_date": q.close_date.isoformat(),
            "current_updated_at": updated_at,
            "current_price_source": q.source,
            "price_kind": price_kind,
        })
    return rows


def _crypto_history_rows_for_yesterday(snapshot_rows: list[dict]) -> list[dict]:
    """00:00 加密 hourly 後：將剛抓到的價寫入 history，price_date = 台北昨日。"""
    price_date = tw_calendar_yesterday().isoformat()
    history_rows: list[dict] = []
    for row in snapshot_rows:
        if row.get("asset_type") != "crypto":
            continue
        history_rows.append({
            **row,
            "current_close_date": price_date,
        })
    return history_rows


def _fetch_quotes_for_symbols(
    symbols: list[dict],
    markets: Optional[Set[str]],
    calendar_rows: Optional[dict[tuple[str, date], dict]] = None,
) -> dict[tuple[str, str], FetchedQuote]:
    include_tw = markets is None or "tw" in markets
    include_us = markets is None or "us" in markets
    include_crypto = markets is None or "crypto" in markets
    quotes: dict[tuple[str, str], FetchedQuote] = {}

    if include_tw:
        tw_close = resolve_session_close_date("tw", calendar_rows=calendar_rows)
        print(f"本輪台股交易日: {tw_close.isoformat()}（Fugle intraday/quote）")
        quotes.update(fetch_stocks_for_market("stock_tw", symbols, tw_close))
    if include_us:
        us_close = resolve_session_close_date("us", calendar_rows=calendar_rows)
        print(f"本輪美股交易日: {us_close.isoformat()}")
        quotes.update(fetch_stocks_for_market("stock_us", symbols, us_close))
    if include_crypto:
        crypto_close = resolve_session_close_date("crypto", calendar_rows=calendar_rows)
        print(f"本輪加密曆日: {crypto_close.isoformat()}")
        for key, price in fetch_crypto_prices_coingecko(symbols).items():
            if _is_valid_price(price):
                quotes[key] = FetchedQuote(float(price), "coingecko", crypto_close)
    return quotes


def run_price_job(
    mode: str,
    markets: Optional[Set[str]] = None,
    skip_intraday_if_closed: bool = True,
) -> None:
    """
    mode:
      intraday — 只寫 snapshots（price_kind=intraday），不寫 history
      close — snapshots + history（price_kind=close）
      crypto_hourly — snapshots（intraday）；台北 00:00 另寫昨日 history
    """
    from market_session import fetch_calendar_from_supabase, market_status

    label = ",".join(sorted(markets)) if markets else "all"
    print(f"[{tw_now().isoformat()}] mode={mode} markets={label} symbols=tracked_symbols")
    supabase = get_supabase()

    calendar = fetch_calendar_from_supabase(supabase)
    if skip_intraday_if_closed and mode == "intraday":
        requested = markets if markets is not None else {"tw", "us"}
        active = set()
        for m in requested:
            if m in ("tw", "us") and market_status(m, calendar_rows=calendar).is_intraday_active:
                active.add(m)
        if not active:
            print("台／美皆非盤中，結束")
            return
        markets = active
        print(f"盤中市場: {','.join(sorted(markets))}")

    symbols = filter_symbols_by_markets(get_symbols_for_job(supabase), markets)
    print(f"共 {len(symbols)} 檔待更新")
    if not symbols:
        print("無符合條件的標的，結束")
        return

    finmind_times: Optional[deque[float]] = deque()
    include_tw = markets is None or "tw" in markets

    if mode == "close" and include_tw:
        print("更新匯率（FinMind 台銀牌告）…")
        n_rates = update_exchange_rates(supabase, finmind_times)
        print(f"匯率: 已 upsert {n_rates} 筆")

    quotes = _fetch_quotes_for_symbols(
        symbols,
        markets,
        calendar_rows=calendar,
    )
    updated_at = tw_now_local_seconds()

    if mode in ("intraday", "crypto_hourly"):
        price_kind = "intraday"
        rows = _quotes_to_rows(quotes, updated_at, price_kind)
        upsert_prices(supabase, rows, default_price_kind=price_kind)
        mark_tracked_symbols_synced(supabase, rows, updated_at)
        mark_tracked_symbols_failed(supabase, symbols, set(quotes.keys()), updated_at)
        if mode == "crypto_hourly" and is_tw_midnight_hour():
            history_rows = _crypto_history_rows_for_yesterday(rows)
            upsert_price_history(supabase, history_rows)
            y = tw_calendar_yesterday().isoformat()
            print(
                f"已寫入 {len(rows)} 筆 snapshot（{price_kind}）；"
                f"加密 00:00 日線 history {len(history_rows)} 筆（price_date={y}）"
            )
        else:
            print(f"已寫入 {len(rows)} 筆 snapshot（{price_kind}，無 history）")
        return

    if mode == "close":
        price_kind = "close"
        rows = _quotes_to_rows(quotes, updated_at, price_kind)
        upsert_prices(supabase, rows, default_price_kind=price_kind)
        upsert_price_history(supabase, rows)
        mark_tracked_symbols_synced(supabase, rows, updated_at)
        mark_tracked_symbols_failed(supabase, symbols, set(quotes.keys()), updated_at)
        print(f"已寫入 {len(rows)} 筆 snapshot + history（收盤）")
        return

    raise ValueError(f"未知 mode: {mode}")


def run_price_update(markets: Optional[Set[str]] = None) -> None:
    """向後相容：GitHub 低頻備援（tracked_symbols 收盤價 + history）。"""
    run_price_job("close", markets=markets, skip_intraday_if_closed=False)


def main() -> None:
    """完整更新（匯率隨台股；美股／加密另跑）— workflow_dispatch 用"""
    print(f"[{datetime.now()}] 開始完整更新（全部市場；匯率於台股步驟）")
    run_price_update(markets=None)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Snapvest 股價／匯率更新")
    parser.add_argument(
        "--mode",
        choices=[
            "intraday",
            "close",
            "crypto_hourly",
            "exchange",
            "calendar",
        ],
        help="執行模式（Cloud Run / 手動）",
    )
    parser.add_argument("--exchange-only", action="store_true", help="只更新匯率（同 --mode exchange）")
    parser.add_argument(
        "--markets",
        metavar="LIST",
        help="市場：tw, us, crypto",
    )
    parser.add_argument(
        "--no-skip-closed",
        action="store_true",
        help="intraday 時不因休市略過（除錯用）",
    )
    args = parser.parse_args()

    if args.exchange_only or args.mode == "exchange":
        supabase = get_supabase()
        n = update_exchange_rates(supabase)
        print(f"完成：已 upsert {n} 筆匯率")
    elif args.mode == "calendar":
        import sys
        from sync_market_calendar import main as sync_cal_main

        # 子腳本會再 parse argv；須清掉 --mode calendar 避免 unrecognized arguments
        sys.argv = ["sync_market_calendar.py"]
        raise SystemExit(sync_cal_main())
    elif args.mode:
        markets = parse_markets_arg(args.markets) if args.markets else None
        if args.mode == "crypto_hourly":
            markets = markets or {"crypto"}
        run_price_job(
            args.mode,
            markets=markets,
            skip_intraday_if_closed=not args.no_skip_closed,
        )
    elif args.markets:
        run_price_update(markets=parse_markets_arg(args.markets))
    else:
        main()
