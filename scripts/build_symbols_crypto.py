#!/usr/bin/env python3
"""
建立加密貨幣 symbols_crypto.json
資料來源：CoinGecko API /coins/markets（依市值排序取 Top 500）
"""

import json
import time
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path

from symbols_paths import BACKEND_CRYPTO_MAP, OUTPUT_DIR, catalog_document, read_catalog_meta
COINGECKO_MARKETS_BASE = "https://api.coingecko.com/api/v3/coins/markets"
TOP_N = 500
PER_PAGE = 100  # 免費 API 單次上限通常為 100


def fetch_coingecko_top_markets() -> list:
    """從 CoinGecko 分頁取得市值前 TOP_N 名"""
    all_coins: list = []
    page = 1
    while len(all_coins) < TOP_N:
        url = (
            f"{COINGECKO_MARKETS_BASE}?vs_currency=usd&order=market_cap_desc"
            f"&per_page={PER_PAGE}&page={page}&sparkline=false"
        )
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Snapvest-SymbolBuilder/1.0", "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=90) as response:
                batch = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429 and page > 1:
                print(f"   第 {page} 頁限流，等待 60 秒後重試...")
                time.sleep(60)
                continue
            raise
        if not batch:
            break
        all_coins.extend(batch)
        if len(batch) < PER_PAGE:
            break
        page += 1
        if len(all_coins) < TOP_N:
            time.sleep(1.5)
    return all_coins[:TOP_N]


def transform_to_items(coins: list) -> list[dict]:
    """轉換為 {symbol, name, coingeckoId}；同 symbol 保留市值較高者（API 已排序）"""
    symbol_to_item: dict[str, dict] = {}
    for coin in coins:
        symbol = (coin.get("symbol") or "").strip().lower()
        name = (coin.get("name") or "").strip()
        cg_id = (coin.get("id") or "").strip()
        if not symbol or not name or not cg_id:
            continue
        if symbol not in symbol_to_item:
            symbol_to_item[symbol] = {
                "symbol": symbol,
                "name": name,
                "coingeckoId": cg_id,
            }

    items = sorted(symbol_to_item.values(), key=lambda x: x["symbol"])
    return items


def build_coingecko_map(items: list[dict]) -> dict[str, str]:
    """symbol（大寫）→ CoinGecko id，供後端每日更新與 Edge Function 參考"""
    return {item["symbol"].upper(): item["coingeckoId"] for item in items}


def build_symbols_crypto() -> dict:
    """建立 symbols_crypto.json 內容"""
    markets = fetch_coingecko_top_markets()
    items = transform_to_items(markets)
    epoch, minor = read_catalog_meta("symbols_crypto.json")
    doc = catalog_document(
        epoch=epoch,
        minor=minor,
        items=items,
        updated_at=str(date.today()),
        source=f"coingecko_markets_top_{TOP_N}",
    )
    return doc


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "symbols_crypto.json"
    print(f"加密貨幣：正在取得 CoinGecko 市值 Top {TOP_N}...")
    data = build_symbols_crypto()
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    cg_map = build_coingecko_map(data["items"])
    BACKEND_CRYPTO_MAP.parent.mkdir(parents=True, exist_ok=True)
    with open(BACKEND_CRYPTO_MAP, "w", encoding="utf-8") as f:
        json.dump(cg_map, f, ensure_ascii=False, indent=2, sort_keys=True)

    unique_symbols = len(data["items"])
    print(f"✅ symbols_crypto.json: {unique_symbols} 筆（去重後）, {data['epoch']}.{data['minor']}")
    print(f"✅ crypto_coingecko_map.json: {len(cg_map)} 筆 → {BACKEND_CRYPTO_MAP.relative_to(Path(__file__).parent.parent)}")
    if unique_symbols < TOP_N - 50:
        print(f"   ⚠️ 筆數少於預期，可能 API 限流或回應不完整")


if __name__ == "__main__":
    main()
