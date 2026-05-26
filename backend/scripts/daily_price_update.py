#!/usr/bin/env python3
"""
Snapvest 每日股價更新腳本
- 每次股價更新前：備份 hot_stocks（保留 2 日）→ 以 hot_stocks_seed ∪ 全使用者 holdings 覆寫 hot_stocks
- 僅對 hot_stocks 清單抓價（去重，每檔只查一次）
- API: 美股+台股 yfinance, 加密貨幣 CoinGecko
"""
import json
import math
import os
import time
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Optional, Set

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

COINGECKO_BASE = "https://api.coingecko.com/api/v3"
CRYPTO_ID_MAP_PATH = Path(__file__).parent / "data" / "crypto_coingecko_map.json"
YAHOO_TW_SUFFIX = ".TW"  # 台股 Yahoo symbol 格式
# 與 migration 003_exchange_rates.sql 註解一致
EXCHANGE_RATE_API_URL = "https://open.er-api.com/v6/latest/USD"


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


def fetch_usd_exchange_rates() -> dict[str, float]:
    """從 open.er-api.com 取得以 USD 為基準的各幣匯率（1 USD = rate 單位外幣）"""
    resp = requests.get(EXCHANGE_RATE_API_URL, timeout=20)
    resp.raise_for_status()
    payload = resp.json()
    if payload.get("result") != "success":
        raise RuntimeError(f"匯率 API 回應異常: {payload.get('error-type', payload)}")
    rates = payload.get("rates") or {}
    return {k: float(v) for k, v in rates.items() if _is_valid_price(v)}


def _raise_on_supabase_error(response, context: str) -> None:
    """Supabase 2.x：RLS 拒絕或 schema 錯誤時 error 不為空，需主動檢查"""
    err = getattr(response, "error", None)
    if err is not None:
        raise RuntimeError(f"{context}: {err}")


def update_exchange_rates(supabase: Client) -> int:
    """寫入 exchange_rates（from_currency=USD），供 App 讀取"""
    rates = fetch_usd_exchange_rates()
    if not rates:
        raise RuntimeError("匯率 API 無有效資料")

    now = datetime.now(TW_TZ).isoformat()
    rows = [
        {
            "from_currency": "USD",
            "to_currency": to_currency,
            "rate": str(rate),
            "updated_at": now,
        }
        for to_currency, rate in rates.items()
    ]

    chunk_size = 100
    written = 0
    for i in range(0, len(rows), chunk_size):
        chunk = rows[i : i + chunk_size]
        resp = supabase.table("exchange_rates").upsert(
            chunk,
            on_conflict="from_currency,to_currency",
        ).execute()
        _raise_on_supabase_error(resp, f"exchange_rates upsert chunk {i // chunk_size + 1}")
        written += len(chunk)

    # 讓 App 的 shouldFetchPrices() 判定 DB 較新，一併刷新匯率快取
    meta_resp = supabase.table("price_update_metadata").upsert(
        {"id": "global", "last_updated_at": now},
        on_conflict="id",
    ).execute()
    _raise_on_supabase_error(meta_resp, "price_update_metadata upsert")

    twd = rates.get("TWD")
    if twd:
        print(f"  USD/TWD ≈ {twd:.4f}（updated_at={now}）")

    # 寫入後驗證（anon 可讀）
    verify = (
        supabase.table("exchange_rates")
        .select("rate,updated_at")
        .eq("from_currency", "USD")
        .eq("to_currency", "TWD")
        .limit(1)
        .execute()
    )
    _raise_on_supabase_error(verify, "exchange_rates verify read")
    if verify.data:
        row = verify.data[0]
        print(f"  DB 驗證 TWD: rate={row.get('rate')} updated_at={row.get('updated_at')}")
    return written


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


def collect_user_holdings_symbols(supabase: Client) -> list[dict]:
    """所有 user_portfolio_state.holdings 中的標的"""
    symbols_set: set[tuple[str, str]] = set()
    symbols_list: list[dict] = []
    try:
        r = supabase.table("user_portfolio_state").select("holdings").execute()
        _raise_on_supabase_error(r, "user_portfolio_state read")
        order = HOLDINGS_DISPLAY_ORDER_BASE
        for row in r.data or []:
            holdings = row.get("holdings") or []
            if isinstance(holdings, str):
                holdings = json.loads(holdings)
            for h in holdings:
                if not isinstance(h, dict):
                    continue
                asset_type = h.get("asset_type") or h.get("assetType")
                symbol = h.get("symbol")
                if not asset_type or not symbol:
                    continue
                _merge_symbol_row(symbols_set, symbols_list, asset_type, symbol, order)
                order += 1
    except Exception as e:
        print(f"取得 user_portfolio_state.holdings 時出錯: {e}")
    return symbols_list


def build_hot_stocks_catalog(supabase: Client) -> list[dict]:
    """種子 ∪ 全使用者持股，去重"""
    symbols_set: set[tuple[str, str]] = set()
    catalog: list[dict] = []
    for row in collect_seed_symbols(supabase):
        key = (row["asset_type"], row["symbol"])
        if key not in symbols_set:
            symbols_set.add(key)
            catalog.append(row)
    for row in collect_user_holdings_symbols(supabase):
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
    """備份後覆寫 hot_stocks = seed ∪ holdings"""
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

    print(f"  hot_stocks 已重建：{len(catalog)} 檔（種子 + 使用者持股）")
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


def fetch_stock_prices_yahoo(symbols: list[dict]) -> dict[tuple, float]:
    """用 yfinance 抓美股+台股（逐檔抓取較穩定）"""
    result = {}
    stock_symbols = [s for s in symbols if s["asset_type"] in ("stock_tw", "stock_us")]
    if not stock_symbols:
        return result

    for s in stock_symbols:
        ys = f"{s['symbol']}{YAHOO_TW_SUFFIX}" if s["asset_type"] == "stock_tw" else s["symbol"]
        key = (s["asset_type"], s["symbol"])
        try:
            ticker = yf.Ticker(ys)
            hist = ticker.history(period="1d")
            if not hist.empty and "Close" in hist.columns:
                result[key] = float(hist["Close"].iloc[-1])
        except Exception as e:
            print(f"  {ys}: {e}")
        time.sleep(0.3)
    return result


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
    """寫入或更新 asset_price_snapshots，保留 previous_price 邏輯"""
    if not updates:
        return
    for row in updates:
        try:
            # 若已存在，將舊的 current_price 當作 previous_price
            existing = supabase.table("asset_price_snapshots").select("current_price, current_price_date").eq("asset_type", row["asset_type"]).eq("symbol", row["symbol"]).execute()
            if existing.data and len(existing.data) > 0 and existing.data[0].get("current_price"):
                row["previous_price"] = str(existing.data[0]["current_price"])
                row["previous_price_date"] = existing.data[0].get("current_price_date")  # 使用 DB 舊值
            supabase.table("asset_price_snapshots").upsert(
                row,
                on_conflict="asset_type,symbol",
                ignore_duplicates=False
            ).execute()
        except Exception as e:
            print(f"寫入 {row.get('asset_type')}/{row.get('symbol')} 失敗: {e}")
        time.sleep(0.05)
    # 更新 global 最後更新時間
    supabase.table("price_update_metadata").upsert(
        {"id": "global", "last_updated_at": datetime.now(TW_TZ).isoformat()},
        on_conflict="id"
    ).execute()


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
    print(f"[{datetime.now()}] 開始股價更新（markets={label}）")
    supabase = get_supabase()

    print("重建 hot_stocks 清單（seed ∪ 使用者持股）…")
    rebuild_hot_stocks(supabase)

    symbols = filter_symbols_by_markets(get_symbols_to_update(supabase), markets)
    print(f"共 {len(symbols)} 檔待更新（已去重）")
    if not symbols:
        print("無符合條件的標的，結束")
        return

    all_prices = {}
    include_stocks = markets is None or "tw" in markets or "us" in markets
    include_crypto = markets is None or "crypto" in markets
    stock_prices: dict[tuple, float] = {}
    crypto_prices: dict[tuple, float] = {}

    if include_stocks:
        stock_prices = fetch_stock_prices_yahoo(symbols)
        all_prices.update(stock_prices)
        print(f"Yahoo: 取得 {len(stock_prices)} 筆")

    if include_crypto:
        crypto_prices = fetch_crypto_prices_coingecko(symbols)
        all_prices.update(crypto_prices)
        print(f"CoinGecko: 取得 {len(crypto_prices)} 筆")

    # 組裝 upsert 資料（price_source 標記本輪實際寫入來源）
    currency_map = {"stock_tw": "TWD", "stock_us": "USD", "crypto": "USD"}
    rows = []
    stock_keys = set(stock_prices.keys()) if include_stocks else set()
    crypto_keys = set(crypto_prices.keys()) if include_crypto else set()
    for (asset_type, symbol), price in all_prices.items():
        if price is None or price <= 0:
            continue
        key = (asset_type, symbol)
        if key in crypto_keys:
            source = "coingecko"
        elif key in stock_keys:
            source = "yfinance"
        else:
            source = "unknown"
        rows.append({
            "asset_type": asset_type,
            "symbol": symbol,
            "currency": currency_map.get(asset_type, "USD"),
            "current_price": str(price),
            "previous_price": None,  # 可由 DB 觸發或在此讀取舊值後填入
            "current_price_date": datetime.now(TW_TZ).isoformat(),
            "last_updated": datetime.now(TW_TZ).isoformat(),
            "last_successful_update": datetime.now(TW_TZ).isoformat(),
            "price_source": source,
        })

    upsert_prices(supabase, rows)
    print(f"已寫入 {len(rows)} 筆至 Supabase")
    print("更新完成")


def main() -> None:
    """更新匯率 + 全部市場股價（本機手動或 workflow_dispatch 用）"""
    print(f"[{datetime.now()}] 開始完整更新（匯率 + 全部股價）")
    supabase = get_supabase()
    n_rates = update_exchange_rates(supabase)
    print(f"匯率: 已 upsert {n_rates} 筆至 exchange_rates")
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
