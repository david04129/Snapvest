#!/usr/bin/env python3
"""
發 App 大版時：將 catalog 推進新 epoch（例如 2.0），只保留 vn，清空 vn-1 與累積 patch。

用法：
  SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \\
    python3 publish_symbol_catalog_epoch.py --epoch 2
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from typing import Any

from symbol_catalog_diff import (
    MARKETS,
    OUTPUT_DIR,
    APP_SYMBOLS_DIR,
    catalog_document,
    catalog_filename,
    read_catalog_file,
    sync_catalog_to_paths,
    validate_candidate,
)
from sync_symbol_catalog_to_db import supabase_client, taipei_now_seconds


def publish_market(client, market: str, epoch: int) -> bool:
    path = OUTPUT_DIR / catalog_filename(market)
    data = read_catalog_file(path)
    if not data:
        print(f"❌ 缺少 {path}")
        return False

    items = data.get("items") or []
    ok, reason = validate_candidate(market, items, None)
    if not ok:
        print(f"❌ {market}：{reason}")
        return False

    payload = {
        "market": market,
        "epoch": epoch,
        "minor": 0,
        "updated_at": taipei_now_seconds(),
        "vn_items": items,
        "vn_minus_1_items": None,
        "cumulative_adds": [],
        "cumulative_removes": [],
    }
    client.table("symbol_catalog_markets").upsert(payload, on_conflict="market").execute()

    doc = catalog_document(
        epoch=epoch,
        minor=0,
        items=items,
        updated_at=str(date.today()),
        source=data.get("source"),
    )
    sync_catalog_to_paths(market, doc)
    print(f"✅ {market} 發布 epoch {epoch}.0（{len(items)} 筆）")
    return True


def write_manifest(epoch: int) -> None:
    manifest: dict[str, Any] = {}
    for market in MARKETS:
        data = read_catalog_file(OUTPUT_DIR / catalog_filename(market))
        if data:
            manifest[market] = {
                "epoch": epoch,
                "minor": 0,
                "updatedAt": data.get("updatedAt"),
            }
    for base in (OUTPUT_DIR, APP_SYMBOLS_DIR):
        path = base / "symbols_manifest.json"
        with path.open("w", encoding="utf-8") as handle:
            json.dump(manifest, handle, ensure_ascii=False, indent=2)
    print("✅ symbols_manifest.json 已更新")


def main() -> int:
    parser = argparse.ArgumentParser(description="發布 symbol catalog 新 epoch")
    parser.add_argument("--epoch", type=int, required=True)
    args = parser.parse_args()
    if args.epoch < 1:
        print("epoch 須 >= 1")
        return 1

    client = supabase_client()
    ok_all = all(publish_market(client, market, args.epoch) for market in MARKETS)
    if ok_all:
        write_manifest(args.epoch)
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
