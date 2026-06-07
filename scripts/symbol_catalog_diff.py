"""Symbol catalog：版本讀取、symbol key 正規化、集合 diff。"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
OUTPUT_DIR = SCRIPTS_DIR / "output"
APP_SYMBOLS_DIR = ROOT / "Snapvest" / "Snapvest" / "Resources" / "Symbols"
BACKEND_CRYPTO_MAP = ROOT / "backend" / "scripts" / "data" / "crypto_coingecko_map.json"

MARKETS = ("tw", "us", "crypto")

MIN_ITEM_COUNTS: dict[str, int] = {
    "tw": 800,
    "us": 2000,
    "crypto": 200,
}

MAX_SHRINK_RATIO = 0.08


def catalog_filename(market: str) -> str:
    return f"symbols_{market}.json"


def read_catalog_file(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError):
        return None


def read_catalog_meta(filename: str) -> tuple[int, int]:
    epoch, minor = 1, 0
    found = False
    for base in (OUTPUT_DIR, APP_SYMBOLS_DIR):
        data = read_catalog_file(base / filename)
        if not data:
            continue
        found = True
        if "epoch" in data and "minor" in data:
            epoch = max(epoch, int(data["epoch"]))
            minor = max(minor, int(data["minor"]))
        elif "version" in data:
            epoch = 1
            minor = max(minor, int(data["version"]))
    if not found:
        return 1, 0
    return epoch, minor


def catalog_document(
    *,
    epoch: int,
    minor: int,
    items: list[dict[str, Any]],
    updated_at: str,
    source: str | None = None,
) -> dict[str, Any]:
    doc: dict[str, Any] = {
        "epoch": epoch,
        "minor": minor,
        "version": minor,
        "updatedAt": updated_at,
        "items": items,
    }
    if source:
        doc["source"] = source
    return doc


def symbol_key(market: str, symbol: str) -> str:
    raw = str(symbol).strip()
    if market == "crypto":
        return raw.lower()
    if market == "us":
        return raw.upper()
    return raw


def items_to_map(market: str, items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for item in items:
        sym = item.get("symbol")
        if not sym:
            continue
        key = symbol_key(market, str(sym))
        if not key:
            continue
        out[key] = item
    return out


def diff_symbol_sets(
    market: str,
    previous_items: list[dict[str, Any]],
    candidate_items: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    prev_map = items_to_map(market, previous_items)
    cand_map = items_to_map(market, candidate_items)
    prev_keys = set(prev_map)
    cand_keys = set(cand_map)

    adds: list[dict[str, Any]] = []
    for key in sorted(cand_keys - prev_keys):
        item = cand_map[key]
        entry: dict[str, Any] = {
            "symbol": item.get("symbol"),
            "name": item.get("name") or item.get("symbol"),
        }
        if market == "crypto" and item.get("coingeckoId"):
            entry["coingeckoId"] = item["coingeckoId"]
        adds.append(entry)

    removes = [{"symbol": prev_map[key]["symbol"]} for key in sorted(prev_keys - cand_keys)]
    return adds, removes


def sets_equal(market: str, left: list[dict[str, Any]], right: list[dict[str, Any]]) -> bool:
    return set(items_to_map(market, left)) == set(items_to_map(market, right))


def merge_patch_entries(
    existing: list[dict[str, Any]],
    new_entries: list[dict[str, Any]],
    market: str,
) -> list[dict[str, Any]]:
    merged = items_to_map(market, existing)
    for entry in new_entries:
        sym = entry.get("symbol")
        if not sym:
            continue
        merged[symbol_key(market, str(sym))] = entry
    if market == "crypto":
        return sorted(merged.values(), key=lambda x: str(x.get("symbol", "")).lower())
    if market == "us":
        return sorted(merged.values(), key=lambda x: str(x.get("symbol", "")).upper())
    return sorted(merged.values(), key=lambda x: str(x.get("symbol", "")))


def validate_candidate(
    market: str,
    candidate_items: list[dict[str, Any]],
    vn_items: list[dict[str, Any]] | None,
) -> tuple[bool, str]:
    count = len(candidate_items)
    minimum = MIN_ITEM_COUNTS.get(market, 1)
    if count < minimum:
        return False, f"{market}: 筆數 {count} 低於下限 {minimum}"

    keys = [symbol_key(market, str(i.get("symbol", ""))) for i in candidate_items]
    if len(keys) != len(set(keys)):
        return False, f"{market}: candidate 含重複 symbol"

    if vn_items:
        vn_count = len(items_to_map(market, vn_items))
        if vn_count > 0 and count < vn_count * (1 - MAX_SHRINK_RATIO):
            return (
                False,
                f"{market}: 筆數從 {vn_count} 降到 {count}，超過 {MAX_SHRINK_RATIO:.0%} 縮水",
            )

    return True, "ok"


def write_catalog_json(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2)


def sync_catalog_to_paths(market: str, document: dict[str, Any]) -> None:
    filename = catalog_filename(market)
    write_catalog_json(OUTPUT_DIR / filename, document)
    write_catalog_json(APP_SYMBOLS_DIR / filename, document)
