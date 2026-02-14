#!/usr/bin/env python3
"""
Snapvest 每日股價更新腳本
- 先更新：使用者持有的股票
- 再更新：熱門股票
- 去重，使用 batch API 節省請求
- API: 美股+台股 yfinance, 加密貨幣 CoinGecko
"""
import os
import time
from datetime import datetime
from decimal import Decimal

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
YAHOO_TW_SUFFIX = ".TW"  # 台股 Yahoo symbol 格式


def get_supabase() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise ValueError("請設定 SUPABASE_URL 和 SUPABASE_SERVICE_ROLE_KEY")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def get_symbols_to_update(supabase: Client) -> list[dict]:
    """取得要更新的 symbol 清單：使用者持有 ∪ 熱門，去重"""
    symbols_set = set()  # (asset_type, symbol)
    symbols_list = []

    # 1. 使用者持有（從 transactions 推算 distinct asset_type, symbol where type=buy）
    try:
        # holdings 表若有則從 holdings，否則從 transactions 推算
        r = supabase.table("holdings").select("asset_type, symbol").execute()
        for row in r.data or []:
            key = (row["asset_type"], row["symbol"])
            if key not in symbols_set:
                symbols_set.add(key)
                symbols_list.append({"asset_type": row["asset_type"], "symbol": row["symbol"]})
    except Exception as e:
        print(f"取得 holdings 時出錯（可能表尚未建立）: {e}")

    # 2. 熱門股票
    try:
        r = supabase.table("hot_stocks").select("asset_type, symbol").execute()
        for row in r.data or []:
            key = (row["asset_type"], row["symbol"])
            if key not in symbols_set:
                symbols_set.add(key)
                symbols_list.append({"asset_type": row["asset_type"], "symbol": row["symbol"]})
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


def fetch_crypto_prices_coingecko(symbols: list[dict]) -> dict[tuple, float]:
    """用 CoinGecko 批次抓加密貨幣"""
    result = {}
    cryptos = [s for s in symbols if s["asset_type"] == "crypto"]
    if not cryptos:
        return result

    # CoinGecko id 映射（symbol -> coingecko id）
    id_map = {
        "BTC": "bitcoin", "ETH": "ethereum", "BNB": "binancecoin", "SOL": "solana",
        "XRP": "ripple", "ADA": "cardano", "DOGE": "dogecoin", "AVAX": "avalanche-2",
        "DOT": "polkadot", "LINK": "chainlink", "MATIC": "matic-network",
        "UNI": "uniswap", "ATOM": "cosmos", "LTC": "litecoin"
    }
    ids = []
    mapping = {}
    for s in cryptos:
        cg_id = id_map.get(s["symbol"].upper(), s["symbol"].lower())
        ids.append(cg_id)
        mapping[cg_id] = (s["asset_type"], s["symbol"])

    ids_str = ",".join(ids)
    url = f"{COINGECKO_BASE}/simple/price?ids={ids_str}&vs_currencies=usd"
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        for cg_id, prices in data.items():
            key = mapping.get(cg_id)
            if key and "usd" in prices:
                result[key] = float(prices["usd"])
        time.sleep(1.2)  # CoinGecko 免費版約 10-30/min
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
            existing = supabase.table("asset_price_snapshots").select("current_price").eq("asset_type", row["asset_type"]).eq("symbol", row["symbol"]).execute()
            if existing.data and len(existing.data) > 0 and existing.data[0].get("current_price"):
                row["previous_price"] = str(existing.data[0]["current_price"])
                row["previous_price_date"] = row.get("current_price_date")
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
        {"id": "global", "last_updated_at": datetime.utcnow().isoformat()},
        on_conflict="id"
    ).execute()


def main():
    print(f"[{datetime.now()}] 開始每日股價更新")
    supabase = get_supabase()

    symbols = get_symbols_to_update(supabase)
    print(f"共 {len(symbols)} 檔待更新（已去重）")

    all_prices = {}

    # 美股+台股
    stock_prices = fetch_stock_prices_yahoo(symbols)
    all_prices.update(stock_prices)
    print(f"Yahoo: 取得 {len(stock_prices)} 筆")

    # 加密貨幣
    crypto_prices = fetch_crypto_prices_coingecko(symbols)
    all_prices.update(crypto_prices)
    print(f"CoinGecko: 取得 {len(crypto_prices)} 筆")

    # 組裝 upsert 資料
    currency_map = {"stock_tw": "TWD", "stock_us": "USD", "crypto": "USD"}
    rows = []
    for (asset_type, symbol), price in all_prices.items():
        if price is None or price <= 0:
            continue
        rows.append({
            "asset_type": asset_type,
            "symbol": symbol,
            "currency": currency_map.get(asset_type, "USD"),
            "current_price": str(price),
            "previous_price": None,  # 可由 DB 觸發或在此讀取舊值後填入
            "current_price_date": datetime.utcnow().isoformat(),
            "last_updated": datetime.utcnow().isoformat(),
            "last_successful_update": datetime.utcnow().isoformat(),
        })

    upsert_prices(supabase, rows)
    print(f"已寫入 {len(rows)} 筆至 Supabase")
    print("更新完成")


if __name__ == "__main__":
    main()
