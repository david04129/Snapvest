#!/usr/bin/env python3
"""
建立美股 symbols_us.json
資料來源：NASDAQ nasdaqtraded.txt（含 NASDAQ、NYSE、AMEX）
"""

import json
import urllib.request
from datetime import date
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent / "output"
NASDAQ_URL = "https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqtraded.txt"


def fetch_nasdaq_file() -> str:
    """從 NASDAQ 下載 symbol 清單"""
    with urllib.request.urlopen(NASDAQ_URL, timeout=30) as response:
        return response.read().decode("utf-8")


def parse_nasdaq_content(content: str) -> list[dict]:
    """解析 nasdaqtraded.txt，提取 symbol 和 name"""
    lines = content.strip().split("\n")
    # 第一行是標題: Nasdaq Traded|Symbol|Security Name|...
    # 欄位: 0=Nasdaq Traded, 1=Symbol, 2=Security Name, 3=Listing Exchange, 4=Market Category, 5=ETF
    items = []
    seen = set()

    for i, line in enumerate(lines):
        if i == 0:
            continue  # 跳過標題
        parts = line.split("|")
        if len(parts) < 3:
            continue
        symbol = parts[1].strip()
        name = parts[2].strip()
        if not symbol or not name:
            continue
        # 跳過重複 symbol（有些有不同類型）
        if symbol in seen:
            continue
        seen.add(symbol)
        items.append({"symbol": symbol, "name": name})

    # 依 symbol 排序
    items.sort(key=lambda x: x["symbol"].upper())
    return items


def build_symbols_us(version: int = 1) -> dict:
    """建立 symbols_us.json 內容"""
    content = fetch_nasdaq_file()
    items = parse_nasdaq_content(content)
    return {
        "version": version,
        "updatedAt": str(date.today()),
        "items": items,
    }


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "symbols_us.json"

    # 若已有檔案，讀取 version 並 +1
    version = 1
    if output_path.exists():
        try:
            with open(output_path, encoding="utf-8") as f:
                existing = json.load(f)
                version = existing.get("version", 1) + 1
        except (json.JSONDecodeError, KeyError):
            pass

    data = build_symbols_us(version=version)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ symbols_us.json: {len(data['items'])} 筆, version={data['version']}")


if __name__ == "__main__":
    main()
