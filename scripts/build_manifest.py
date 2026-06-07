#!/usr/bin/env python3
"""
建立 symbols_manifest.json（各市場 epoch.minor）。
"""

import json
from pathlib import Path

from symbol_catalog_diff import MARKETS, OUTPUT_DIR, APP_SYMBOLS_DIR, catalog_filename, read_catalog_file

OUTPUT_MANIFEST = OUTPUT_DIR / "symbols_manifest.json"
APP_MANIFEST = APP_SYMBOLS_DIR / "symbols_manifest.json"


def build_manifest() -> dict:
    manifest = {}
    for market in MARKETS:
        path = OUTPUT_DIR / catalog_filename(market)
        if not path.exists():
            manifest[market] = {"epoch": 1, "minor": 0, "updatedAt": None}
            continue
        data = read_catalog_file(path) or {}
        manifest[market] = {
            "epoch": int(data.get("epoch", 1)),
            "minor": int(data.get("minor", data.get("version", 0))),
            "updatedAt": data.get("updatedAt"),
        }
    return manifest


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = build_manifest()
    for path in (OUTPUT_MANIFEST, APP_MANIFEST):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as handle:
            json.dump(manifest, handle, ensure_ascii=False, indent=2)
    print("✅ symbols_manifest.json 已建立")
    for market, info in manifest.items():
        print(f"   {market}: {info.get('epoch')}.{info.get('minor')}, updatedAt={info.get('updatedAt', 'N/A')}")


if __name__ == "__main__":
    main()
