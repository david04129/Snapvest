#!/usr/bin/env python3
"""
將 scripts/output 的 symbols 清單同步至 Supabase symbol_catalog_markets。

規則：
- 與 vn 比 symbol 集合；僅 rename 不 bump
- 有變：vn-1 ← vn，vn ← candidate，minor+1，累積 patch
- 無變：不寫 vn / vn-1 / version
- 異常（筆數、縮水、重複）：整 market 不寫入
- 刻意縮表（如台股移除權證）：`--force tw`

環境變數：SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import date, datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

from symbol_catalog_diff import (
    MARKETS,
    OUTPUT_DIR,
    APP_SYMBOLS_DIR,
    catalog_document,
    catalog_filename,
    diff_symbol_sets,
    merge_patch_entries,
    read_catalog_file,
    sets_equal,
    sync_catalog_to_paths,
    validate_candidate,
)

try:
    from supabase import Client, create_client
except ImportError:
    print("❌ 請安裝 supabase: pip install supabase", file=sys.stderr)
    raise


def taipei_now_seconds() -> str:
    return datetime.now(ZoneInfo("Asia/Taipei")).strftime("%Y-%m-%d %H:%M:%S")


def supabase_client() -> Client:
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        raise RuntimeError("缺少 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY")
    return create_client(url, key)


def fetch_row(client: Client, market: str) -> dict[str, Any] | None:
    resp = (
        client.table("symbol_catalog_markets")
        .select("*")
        .eq("market", market)
        .limit(1)
        .execute()
    )
    data = getattr(resp, "data", None)
    if not data:
        return None
    if isinstance(data, list):
        return data[0] if data else None
    return data


def write_manifest() -> None:
    manifest: dict[str, Any] = {}
    for market in MARKETS:
        data = read_catalog_file(OUTPUT_DIR / catalog_filename(market))
        if not data:
            continue
        manifest[market] = {
            "epoch": int(data.get("epoch", 1)),
            "minor": int(data.get("minor", data.get("version", 0))),
            "updatedAt": data.get("updatedAt"),
        }
    manifest_path = OUTPUT_DIR / "symbols_manifest.json"
    with manifest_path.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
    app_manifest = APP_SYMBOLS_DIR / "symbols_manifest.json"
    with app_manifest.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
    print("✅ symbols_manifest.json 已更新")


def bootstrap_row(client: Client, market: str, candidate: dict[str, Any]) -> bool:
    epoch = int(candidate.get("epoch", 1))
    minor = int(candidate.get("minor", candidate.get("version", 0)))
    items = candidate.get("items") or []
    ok, reason = validate_candidate(market, items, None)
    if not ok:
        print(f"⏭️  {market} bootstrap 略過：{reason}")
        return False

    payload = {
        "market": market,
        "epoch": epoch,
        "minor": minor,
        "updated_at": taipei_now_seconds(),
        "vn_items": items,
        "vn_minus_1_items": None,
        "cumulative_adds": [],
        "cumulative_removes": [],
    }
    client.table("symbol_catalog_markets").upsert(payload, on_conflict="market").execute()
    print(f"✅ {market} bootstrap → {epoch}.{minor}（{len(items)} 筆）")
    return True


def sync_market(client: Client, market: str, *, force: bool = False) -> bool:
    filename = catalog_filename(market)
    candidate_path = OUTPUT_DIR / filename
    candidate = read_catalog_file(candidate_path)
    if not candidate:
        print(f"⏭️  {market}：缺少 {candidate_path}")
        return False

    candidate_items = candidate.get("items") or []
    row = fetch_row(client, market)

    if row is None:
        return bootstrap_row(client, market, candidate)

    vn_items = row.get("vn_items") or []
    ok, reason = validate_candidate(market, candidate_items, None if force else vn_items)
    if not ok:
        print(f"⏭️  {market} 略過寫入：{reason}")
        return False
    if force:
        print(f"⚠️  {market} --force：略過縮水檢查（{len(vn_items)} → {len(candidate_items)} 筆）")

    if sets_equal(market, vn_items, candidate_items):
        row_epoch = int(row["epoch"])
        row_minor = int(row["minor"])
        candidate_epoch = int(candidate.get("epoch", 1))
        candidate_minor = int(candidate.get("minor", candidate.get("version", 0)))
        if candidate_epoch != row_epoch or candidate_minor != row_minor:
            doc = catalog_document(
                epoch=row_epoch,
                minor=row_minor,
                items=vn_items,
                updated_at=candidate.get("updatedAt") or str(date.today()),
                source=candidate.get("source"),
            )
            sync_catalog_to_paths(market, doc)
            print(
                f"—  {market} 無 symbol 變動，DB 維持 {row_epoch}.{row_minor}；"
                f"本機 JSON 從 {candidate_epoch}.{candidate_minor} 對齊回 DB"
            )
            return True

        print(f"—  {market} 無 symbol 變動，維持 {row_epoch}.{row_minor}")
        return False

    adds, removes = diff_symbol_sets(market, vn_items, candidate_items)
    epoch = int(row["epoch"])
    new_minor = int(row["minor"]) + 1
    cumulative_adds = merge_patch_entries(row.get("cumulative_adds") or [], adds, market)
    cumulative_removes = merge_patch_entries(row.get("cumulative_removes") or [], removes, market)

    payload = {
        "market": market,
        "epoch": epoch,
        "minor": new_minor,
        "updated_at": taipei_now_seconds(),
        "vn_minus_1_items": vn_items,
        "vn_items": candidate_items,
        "cumulative_adds": cumulative_adds,
        "cumulative_removes": cumulative_removes,
    }
    client.table("symbol_catalog_markets").upsert(payload, on_conflict="market").execute()

    doc = catalog_document(
        epoch=epoch,
        minor=new_minor,
        items=candidate_items,
        updated_at=str(date.today()),
        source=candidate.get("source"),
    )
    sync_catalog_to_paths(market, doc)

    print(
        f"✅ {market} {row['epoch']}.{row['minor']} → {epoch}.{new_minor} "
        f"(+{len(adds)} −{len(removes)}，vn 共 {len(candidate_items)} 筆)"
    )
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="同步 symbol catalog 至 Supabase")
    parser.add_argument(
        "--force",
        action="append",
        choices=list(MARKETS),
        default=[],
        metavar="MARKET",
        help="略過縮水檢查（tw/us/crypto），用於刻意移除權證等",
    )
    args = parser.parse_args()
    force_markets = set(args.force or [])

    missing = [m for m in MARKETS if not (OUTPUT_DIR / catalog_filename(m)).exists()]
    if missing:
        print(f"❌ 缺少 output：{', '.join(missing)}")
        return 1

    try:
        client = supabase_client()
    except RuntimeError as exc:
        print(f"⏭️  DB sync 略過：{exc}")
        return 0

    changed = False
    for market in MARKETS:
        changed = sync_market(client, market, force=market in force_markets) or changed
    if changed:
        write_manifest()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
