#!/usr/bin/env python3
"""
建立台股 symbols_tw.json（Fugle 可交易清單）

主要來源（預設）：
  GET https://api.fugle.tw/marketdata/v1.0/stock/intraday/tickers
  - exchange=TWSE  上市（含 ETF、創新板子集）
  - exchange=TPEx  上櫃 + 興櫃
  type=EQUITY（不含權證）

清單上的代號皆為 Fugle 當前可報價標的，已排除下市／不存在者。

環境變數：FUGLE_API_KEY（必填，除非 --legacy）

備援（--legacy）：證交所 + 櫃買 CSV + ETF 手動補充（舊流程）
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path
from typing import Optional

from symbols_paths import OUTPUT_DIR, SCRIPTS_DIR, catalog_document, read_catalog_meta

DATA_DIR = SCRIPTS_DIR / "data"
FUGLE_TICKERS_URL = "https://api.fugle.tw/marketdata/v1.0/stock/intraday/tickers"
TWSE_STOCK_DAY_ALL_URL = "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL"
TWSE_LISTED_URL = "https://dts.twse.com.tw/opendata/t187ap03_L.csv"
TPEX_OTC_QUOTE_URL = "https://www.tpex.org.tw/web/stock/aftertrading/DAILY_CLOSE_quotes/stk_quote_result.php?l=zh-tw&o=data"
TPEX_EMERGING_URL = "https://www.tpex.org.tw/web/regular_emerging/financereport/emerging_capitals_rank/list_result.php?l=zh-tw&type=l_list&o=data"

LOCAL_CSV_PATHS = [
    DATA_DIR / "tw_listed.csv",
    DATA_DIR / "tw_securities.csv",
    DATA_DIR / "t187ap03_L.csv",
]


def fetch_url(url: str) -> Optional[str]:
    """下載 URL 內容，嘗試 UTF-8 與 Big5 編碼"""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Snapvest/1.0"})
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
        for enc in ("utf-8", "big5", "cp950"):
            try:
                return raw.decode(enc)
            except UnicodeDecodeError:
                continue
        return raw.decode("utf-8", errors="replace")
    except Exception as e:
        print(f"   ⚠️ 下載失敗: {e}")
        return None


def fetch_fugle_tickers(exchange: str, api_key: str) -> list[dict]:
    """Fugle intraday/tickers → [{symbol, name}, ...]"""
    params = urllib.parse.urlencode({"type": "EQUITY", "exchange": exchange})
    url = f"{FUGLE_TICKERS_URL}?{params}"
    req = urllib.request.Request(
        url,
        headers={"X-API-KEY": api_key, "User-Agent": "Snapvest/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"   ❌ Fugle {exchange} HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}")
        return []
    except Exception as e:
        print(f"   ❌ Fugle {exchange} 請求失敗: {e}")
        return []

    rows = body.get("data") or []
    items: list[dict] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        symbol = str(row.get("symbol", "")).strip().upper()
        name = str(row.get("name", "")).strip()
        if symbol and name:
            items.append({"symbol": symbol, "name": name})
    return items


def _is_warrant(symbol: str, name: str) -> bool:
    """排除權證（7xxxxx 等）；保留 ETF（00631L / 00981A 等）。"""
    if len(symbol) == 6 and symbol[0] == "7" and symbol.isalnum():
        return True
    warrant_keywords = ("認購", "認售", "權證", "牛證", "熊證", "購01", "購02", "購03", "售01", "售02", "售03")
    if any(keyword in name for keyword in warrant_keywords):
        return True
    return False


def _is_valid_tw_symbol(symbol: str, name: str, max_len: int = 6) -> bool:
    """過濾：保留 4-6 碼英數字台股商品；排除權證。"""
    if len(symbol) < 4 or len(symbol) > max_len:
        return False
    if not symbol.isalnum():
        return False
    if _is_warrant(symbol, name):
        return False
    return True


def merge_symbol_items(
    symbol_to_name: dict[str, str],
    items: list[dict],
    *,
    overwrite: bool = False,
) -> int:
    added = 0
    for item in items:
        symbol = item["symbol"]
        name = item["name"]
        if not _is_valid_tw_symbol(symbol, name):
            continue
        if overwrite or symbol not in symbol_to_name:
            if symbol not in symbol_to_name:
                added += 1
            symbol_to_name[symbol] = name
    return added


def build_symbols_tw_fugle(*, catalog_minor: Optional[int] = None) -> Optional[dict]:
    """Fugle TWSE + TPEx 可交易清單（上市、上櫃、興櫃、ETF）。"""
    api_key = os.environ.get("FUGLE_API_KEY", "").strip()
    if not api_key:
        print("❌ 未設定 FUGLE_API_KEY")
        return None

    symbol_to_name: dict[str, str] = {}

    twse = fetch_fugle_tickers("TWSE", api_key)
    twse_added = merge_symbol_items(symbol_to_name, twse, overwrite=True)
    print(f"   Fugle TWSE（上市）: {len(twse)} 筆（納入 {twse_added}）")

    tpex = fetch_fugle_tickers("TPEx", api_key)
    tpex_added = merge_symbol_items(symbol_to_name, tpex)
    print(f"   Fugle TPEx（上櫃+興櫃）: {len(tpex)} 筆（新增 {tpex_added}）")

    if not symbol_to_name:
        print("❌ Fugle 未回傳任何台股標的")
        return None

    merged = [{"symbol": s, "name": n} for s, n in symbol_to_name.items()]
    merged.sort(key=lambda x: (x["symbol"].zfill(6), x["symbol"]))

    epoch, _minor = read_catalog_meta("symbols_tw.json")
    minor = catalog_minor if catalog_minor is not None else _minor
    return catalog_document(
        epoch=epoch,
        minor=minor,
        items=merged,
        updated_at=str(date.today()),
    )


# --- Legacy 備援（證交所 + 櫃買 CSV）---


def _parse_tw_csv_generic(
    content: str,
    symbol_col: int,
    name_col: int,
    max_symbol_len: int = 6,
    fallback_name_col: Optional[int] = None,
) -> list[dict]:
    content = content.lstrip("\ufeff")
    lines = content.strip().split("\n")
    if not lines:
        return []

    items = []
    for delim in (",", "\t", ";", " "):
        try:
            reader = csv.reader(lines, delimiter=delim)
            rows = list(reader)
        except Exception:
            continue
        if not rows:
            continue

        first = rows[0]
        if len(first) <= max(symbol_col, name_col):
            continue
        col_sym = str(first[symbol_col]).strip()
        is_header = not col_sym.isdigit() and (
            "代號" in col_sym or "代碼" in col_sym or "公司" in col_sym
        )
        start = 1 if is_header else 0

        items = []
        seen = set()
        for row in rows[start:]:
            if len(row) <= max(symbol_col, name_col):
                continue
            symbol = str(row[symbol_col]).strip().upper()
            name = str(row[name_col]).strip()
            if not name and fallback_name_col is not None and len(row) > fallback_name_col:
                name = str(row[fallback_name_col]).strip()
            if not symbol or not name:
                continue
            if not _is_valid_tw_symbol(symbol, name, max_symbol_len):
                continue
            if symbol in seen:
                continue
            seen.add(symbol)
            items.append({"symbol": symbol, "name": name})

        if items:
            break

    return items


def parse_listed_csv(content: str) -> list[dict]:
    return _parse_tw_csv_generic(content, symbol_col=1, name_col=3, fallback_name_col=2)


def parse_otc_csv(content: str) -> list[dict]:
    return _parse_tw_csv_generic(content, symbol_col=1, name_col=2)


def parse_emerging_csv(content: str) -> list[dict]:
    return _parse_tw_csv_generic(content, symbol_col=2, name_col=3)


def parse_twse_stock_day_all(content: str) -> list[dict]:
    try:
        rows = json.loads(content)
    except json.JSONDecodeError:
        return []

    items = []
    seen = set()
    if not isinstance(rows, list):
        return items

    for row in rows:
        if not isinstance(row, dict):
            continue
        symbol = str(row.get("Code", "")).strip().upper()
        name = str(row.get("Name", "")).strip()
        if not symbol or not name:
            continue
        if not _is_valid_tw_symbol(symbol, name):
            continue
        if symbol in seen:
            continue
        seen.add(symbol)
        items.append({"symbol": symbol, "name": name})

    return items


def fetch_listed() -> list[dict]:
    content = fetch_url(TWSE_LISTED_URL)
    if content and not content.strip().startswith("<"):
        parsed = parse_listed_csv(content)
        if parsed:
            return parsed
    for path in LOCAL_CSV_PATHS:
        if path.exists():
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                content = path.read_text(encoding="big5")
            if content:
                parsed = parse_listed_csv(content)
                if parsed:
                    print(f"   📁 上市：使用本地檔 {path.name}")
                    return parsed
    return []


def fetch_twse_stock_day_all() -> list[dict]:
    content = fetch_url(TWSE_STOCK_DAY_ALL_URL)
    if content and content.strip().startswith("["):
        return parse_twse_stock_day_all(content)
    return []


def fetch_otc() -> list[dict]:
    content = fetch_url(TPEX_OTC_QUOTE_URL)
    if content and not content.strip().startswith("<"):
        return parse_otc_csv(content)
    return []


def fetch_emerging() -> list[dict]:
    content = fetch_url(TPEX_EMERGING_URL)
    if content and not content.strip().startswith("<"):
        return parse_emerging_csv(content)
    return []


def build_symbols_tw_legacy(*, catalog_minor: Optional[int] = None) -> Optional[dict]:
    """舊流程：證交所 + 櫃買 CSV（含已下市標的）。"""
    symbol_to_name: dict[str, str] = {}

    listed = fetch_listed()
    listed_added = merge_symbol_items(symbol_to_name, listed, overwrite=True)
    print(f"   上市公司: {len(listed)} 筆（新增 {listed_added}）")

    otc = fetch_otc()
    otc_added = merge_symbol_items(symbol_to_name, otc)
    print(f"   上櫃: {len(otc)} 筆（新增 {otc_added}）")

    emerging = fetch_emerging()
    emerging_added = merge_symbol_items(symbol_to_name, emerging)
    print(f"   興櫃: {len(emerging)} 筆（新增 {emerging_added}）")

    twse_all = fetch_twse_stock_day_all()
    twse_added = merge_symbol_items(symbol_to_name, twse_all)
    print(f"   上市全商品: {len(twse_all)} 筆（新增 {twse_added}，已排除權證）")

    if not symbol_to_name:
        print("❌ 台股：無法取得任何資料")
        return None

    merged = [{"symbol": s, "name": n} for s, n in symbol_to_name.items()]
    merged.sort(key=lambda x: (x["symbol"].zfill(6), x["symbol"]))

    epoch, _minor = read_catalog_meta("symbols_tw.json")
    minor = catalog_minor if catalog_minor is not None else _minor
    return catalog_document(
        epoch=epoch,
        minor=minor,
        items=merged,
        updated_at=str(date.today()),
    )


def build_symbols_tw(*, catalog_minor: Optional[int] = None, legacy: bool = False) -> Optional[dict]:
    if legacy:
        return build_symbols_tw_legacy(catalog_minor=catalog_minor)
    return build_symbols_tw_fugle(catalog_minor=catalog_minor)


def main() -> int:
    parser = argparse.ArgumentParser(description="建立台股 symbols_tw.json")
    parser.add_argument(
        "--legacy",
        action="store_true",
        help="使用證交所/櫃買 CSV 舊流程（非 Fugle）",
    )
    parser.add_argument(
        "--minor",
        type=int,
        default=None,
        help="catalog minor 版本（預設沿用 output 現值）",
    )
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "symbols_tw.json"

    if args.legacy:
        print("台股：legacy 模式（證交所 + 櫃買 CSV）...")
    else:
        print("台股：Fugle 可交易清單（TWSE + TPEx, type=EQUITY）...")

    data = build_symbols_tw(catalog_minor=args.minor, legacy=args.legacy)
    if data is None:
        return 1

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ symbols_tw.json: {len(data['items'])} 筆, {data['epoch']}.{data['minor']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
