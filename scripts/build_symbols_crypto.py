#!/usr/bin/env python3
"""
建立加密貨幣 symbols_crypto.json
資料來源：CoinGecko API /coins/list
"""

import json
import urllib.request
from datetime import date
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent / "output"
COINGECKO_URL = "https://api.coingecko.com/api/v3/coins/list"


def fetch_coingecko_list() -> list:
    """從 CoinGecko API 取得幣別清單"""
    with urllib.request.urlopen(COINGECKO_URL, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def transform_to_items(coins: list) -> list[dict]:
    """轉換為 {symbol, name} 格式，symbol 去重（取第一個）"""
    symbol_to_item = {}
    for coin in coins:
        symbol = coin.get("symbol", "").strip().lower()
        name = coin.get("name", "").strip()
        if not symbol or not name:
            continue
        # 同 symbol 可能有多個（不同鏈），取第一個
        if symbol not in symbol_to_item:
            symbol_to_item[symbol] = {"symbol": symbol, "name": name}

    items = sorted(symbol_to_item.values(), key=lambda x: x["symbol"])
    return items


def build_symbols_crypto(version: int = 1) -> dict:
    """建立 symbols_crypto.json 內容"""
    coins = fetch_coingecko_list()
    items = transform_to_items(coins)
    return {
        "version": version,
        "updatedAt": str(date.today()),
        "items": items,
    }


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "symbols_crypto.json"

    # 若已有檔案，讀取 version 並 +1
    version = 1
    if output_path.exists():
        try:
            with open(output_path, encoding="utf-8") as f:
                existing = json.load(f)
                version = existing.get("version", 1) + 1
        except (json.JSONDecodeError, KeyError):
            pass

    data = build_symbols_crypto(version=version)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ symbols_crypto.json: {len(data['items'])} 筆, version={data['version']}")


if __name__ == "__main__":
    main()
