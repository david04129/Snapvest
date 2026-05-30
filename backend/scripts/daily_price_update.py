#!/usr/bin/env python3
"""
Snapvest 每日股價更新腳本
- 每次股價更新前：備份 hot_stocks（保留 2 日）→ 以 hot_stocks_seed ∪ 匿名 tracked_symbols 覆寫 hot_stocks
- 僅對 hot_stocks 清單抓價（去重，每檔只查一次）
- 台股 FinMind、匯率 FinMind 台銀牌告（6 幣→TWD，與台股同輪）；美股 Finnhub；失敗 → 等 60s 重試 → yfinance 補洞
- 加密 CoinGecko（曆日快照）
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

# 台灣時區 UTC+8
TW_TZ = timezone(timedelta(hours=8))

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

COINGECKO_BASE = "https://api.coingecko.com/api/v3"
FINNHUB_QUOTE_URL = "https://finnhub.io/api/v1/quote"
FINMIND_DATA_URL = "https://api.finmindtrade.com/api/v4/data"
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


def parse_close_date(value) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def last_weekday(cal: date, max_lookback: int = 10) -> date:
    d = cal
    for _ in range(max_lookback):
        if d.weekday() < 5:
            return d
        d -= timedelta(days=1)
    return cal


def resolve_session_close_date(market: str) -> date:
    """本輪排程宣告的收盤所屬日（不含國定假日，假日由 API 空值 → fallback）。"""
    today = tw_now().date()
    if market == "tw":
        return last_weekday(today)
    if market == "us":
        return last_weekday(today - timedelta(days=1))
    return today


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


def collect_seed_symbols(supabase: Client) -> list[dict]:
    """種子熱門股（hot_stocks_seed，不受每日覆寫影響）"""
    symbols_set: set[tuple[str, str]] = set()
    symbols_list: list[dict] = []
    try:
        r = supabase.table("hot_stocks_seed").select("asset_type, symbol, display_order").execute()
        _raise_on_supabase_error(r, "hot_stocks_seed read")
        for row in r.data or []:
            _merge_symbol_row(
                symbols_set,
                symbols_list,
                row["asset_type"],
                row["symbol"],
                int(row.get("display_order") or 0),
            )
    except Exception as e:
        print(f"取得 hot_stocks_seed 時出錯: {e}")
    return symbols_list


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


def build_hot_stocks_catalog(supabase: Client) -> list[dict]:
    """種子 ∪ 匿名 tracked_symbols，去重"""
    symbols_set: set[tuple[str, str]] = set()
    catalog: list[dict] = []
    for row in collect_seed_symbols(supabase):
        key = (row["asset_type"], row["symbol"])
        if key not in symbols_set:
            symbols_set.add(key)
            catalog.append(row)
    for row in collect_tracked_symbols(supabase):
        key = (row["asset_type"], row["symbol"])
        if key not in symbols_set:
            symbols_set.add(key)
            catalog.append(row)
    return catalog


def backup_hot_stocks(supabase: Client) -> int:
    """將目前 hot_stocks 寫入備份表，僅保留最近 2 日"""
    today = datetime.now(TW_TZ).date()
    today_str = today.isoformat()
    keep_from = (today - timedelta(days=1)).isoformat()

    current = supabase.table("hot_stocks").select("asset_type, symbol, display_order").execute()
    _raise_on_supabase_error(current, "hot_stocks read for backup")
    rows = current.data or []

    supabase.table("hot_stocks_backup").delete().eq("backup_date", today_str).execute()
    if rows:
        backup_rows = [
            {
                "backup_date": today_str,
                "asset_type": row["asset_type"],
                "symbol": row["symbol"],
                "display_order": row.get("display_order") or 0,
            }
            for row in rows
        ]
        for i in range(0, len(backup_rows), 100):
            chunk = backup_rows[i : i + 100]
            resp = supabase.table("hot_stocks_backup").upsert(chunk).execute()
            _raise_on_supabase_error(resp, "hot_stocks_backup upsert")

    prune = supabase.table("hot_stocks_backup").delete().lt("backup_date", keep_from).execute()
    _raise_on_supabase_error(prune, "hot_stocks_backup prune")

    print(f"  hot_stocks 備份 {len(rows)} 筆（backup_date={today_str}，保留 >= {keep_from}）")
    return len(rows)


def rebuild_hot_stocks(supabase: Client) -> list[dict]:
    """備份後覆寫 hot_stocks = seed ∪ tracked_symbols"""
    backup_hot_stocks(supabase)
    catalog = build_hot_stocks_catalog(supabase)

    delete_resp = (
        supabase.table("hot_stocks")
        .delete()
        .in_("asset_type", ["stock_tw", "stock_us", "crypto"])
        .execute()
    )
    _raise_on_supabase_error(delete_resp, "hot_stocks delete")

    if catalog:
        for i in range(0, len(catalog), 100):
            chunk = catalog[i : i + 100]
            insert_resp = supabase.table("hot_stocks").upsert(
                chunk,
                on_conflict="asset_type,symbol",
            ).execute()
            _raise_on_supabase_error(insert_resp, "hot_stocks upsert")

    print(f"  hot_stocks 已重建：{len(catalog)} 檔（種子 + 匿名追蹤池）")
    return catalog


def get_symbols_to_update(supabase: Client) -> list[dict]:
    """讀取重建後的 hot_stocks（即今日待更新清單）"""
    symbols_list: list[dict] = []
    try:
        r = supabase.table("hot_stocks").select("asset_type, symbol").execute()
        _raise_on_supabase_error(r, "hot_stocks read")
        for row in r.data or []:
            sym = _normalize_symbol(row["asset_type"], row["symbol"])
            symbols_list.append({"asset_type": row["asset_type"], "symbol": sym})
    except Exception as e:
        print(f"取得 hot_stocks 時出錯: {e}")
    return symbols_list


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


def fetch_finmind_one(
    http: requests.Session,
    stock_id: str,
    session_close: date,
) -> tuple[Optional[FetchedQuote], str]:
    ds = session_close.isoformat()
    params: dict[str, str] = {
        "dataset": "TaiwanStockPrice",
        "data_id": stock_id,
        "start_date": ds,
        "end_date": ds,
    }
    if FINMIND_TOKEN:
        params["token"] = FINMIND_TOKEN
    try:
        resp = http.get(FINMIND_DATA_URL, params=params, timeout=30)
        if resp.status_code == 429:
            return None, "429"
        resp.raise_for_status()
        body = resp.json()
        if body.get("status") != 200:
            return None, str(body.get("msg", body))
        rows = body.get("data") or []
        if not rows:
            return None, "empty"
        last = rows[-1]
        close = last.get("close")
        if not _is_valid_price(close):
            return None, "invalid_close"
        row_date = parse_close_date(last.get("date")) or session_close
        return FetchedQuote(float(close), "finmind", row_date), ""
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
) -> dict[tuple[str, str], FetchedQuote]:
    """Primary → 等 60s → retry 可重試失敗 → yfinance 補其餘。"""
    market_symbols = [s for s in symbols if s["asset_type"] == asset_type]
    if not market_symbols:
        return {}

    label = "FinMind" if asset_type == "stock_tw" else "Finnhub"
    if asset_type == "stock_tw":
        if finmind_times is None:
            finmind_times = deque()
    else:
        finmind_times = None

    if asset_type == "stock_tw":
        if not FINMIND_TOKEN:
            print("  未設定 FINMIND_TOKEN，台股將直接嘗試 yfinance fallback")
        fetch_one = fetch_finmind_one
    else:
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
        print(f"  yfinance fallback: {len(still_missing)} 檔")
        for s in still_missing:
            key = (s["asset_type"], s["symbol"])
            quote, err = fetch_yahoo_one(s, session_close)
            if quote:
                ok[key] = quote
            else:
                print(f"    {s['symbol']}: {err}")
            time.sleep(0.3)

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


def upsert_prices(supabase: Client, updates: list[dict]):
    """寫入 asset_price_snapshots；舊 current 滾入 previous_*"""
    if not updates:
        return
    for row in updates:
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


def run_price_update(markets: Optional[Set[str]] = None) -> None:
    """更新股價。markets: {'tw','us','crypto'} 子集；None = 全部。不含匯率。"""
    label = ",".join(sorted(markets)) if markets else "all"
    print(f"[{tw_now().isoformat()}] 開始股價更新（markets={label}）")
    supabase = get_supabase()

    print("重建 hot_stocks 清單（seed ∪ 匿名 tracked_symbols）…")
    rebuild_hot_stocks(supabase)

    symbols = filter_symbols_by_markets(get_symbols_to_update(supabase), markets)
    print(f"共 {len(symbols)} 檔待更新（已去重）")
    if not symbols:
        print("無符合條件的標的，結束")
        return

    include_tw = markets is None or "tw" in markets
    include_us = markets is None or "us" in markets
    include_crypto = markets is None or "crypto" in markets

    quotes: dict[tuple[str, str], FetchedQuote] = {}
    finmind_times: Optional[deque[float]] = deque() if include_tw else None

    if include_tw:
        print("更新匯率（FinMind 台銀牌告，與台股同輪）…")
        n_rates = update_exchange_rates(supabase, finmind_times)
        print(f"匯率: 已 upsert {n_rates} 筆（{', '.join(FINMIND_FX_CURRENCIES)} → TWD）")

        tw_close = resolve_session_close_date("tw")
        print(f"本輪台股收盤日: {tw_close.isoformat()}")
        quotes.update(
            fetch_stocks_for_market("stock_tw", symbols, tw_close, finmind_times)
        )

    if include_us:
        us_close = resolve_session_close_date("us")
        print(f"本輪美股收盤日: {us_close.isoformat()}")
        quotes.update(fetch_stocks_for_market("stock_us", symbols, us_close))

    if include_crypto:
        crypto_close = resolve_session_close_date("crypto")
        print(f"本輪加密快照曆日: {crypto_close.isoformat()}")
        for key, price in fetch_crypto_prices_coingecko(symbols).items():
            if _is_valid_price(price):
                quotes[key] = FetchedQuote(float(price), "coingecko", crypto_close)

    updated_at = tw_now_local_seconds()
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
        })

    attempted_symbols = symbols
    successful_keys = set(quotes.keys())
    upsert_prices(supabase, rows)
    upsert_price_history(supabase, rows)
    mark_tracked_symbols_synced(supabase, rows, updated_at)
    mark_tracked_symbols_failed(supabase, attempted_symbols, successful_keys, updated_at)
    print(f"已寫入 {len(rows)} 筆至 Supabase（更新時間 {updated_at}）")
    print("更新完成")


def main() -> None:
    """完整更新（匯率隨台股；美股／加密另跑）— workflow_dispatch 用"""
    print(f"[{datetime.now()}] 開始完整更新（全部市場；匯率於台股步驟）")
    run_price_update(markets=None)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Snapvest 每日股價／匯率更新")
    parser.add_argument("--exchange-only", action="store_true", help="只更新匯率")
    parser.add_argument(
        "--rebuild-catalog-only",
        action="store_true",
        help="只備份並重建 hot_stocks（不抓外部股價）",
    )
    parser.add_argument(
        "--markets",
        metavar="LIST",
        help="只更新指定市場，逗號分隔：tw, us, crypto（不含匯率）",
    )
    args = parser.parse_args()

    if args.exchange_only:
        supabase = get_supabase()
        n = update_exchange_rates(supabase)
        print(f"完成：已 upsert {n} 筆匯率")
    elif args.rebuild_catalog_only:
        supabase = get_supabase()
        rebuild_hot_stocks(supabase)
        print("完成：hot_stocks 已重建")
    elif args.markets:
        run_price_update(markets=parse_markets_arg(args.markets))
    else:
        main()
