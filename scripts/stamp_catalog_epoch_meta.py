#!/usr/bin/env python3
"""為現有 symbols JSON 補上 epoch/minor（legacy version → epoch=1, minor=version）。"""

import json
from pathlib import Path

from symbol_catalog_diff import APP_SYMBOLS_DIR, MARKETS, OUTPUT_DIR, catalog_filename

ROOT = Path(__file__).resolve().parent.parent


def stamp_file(path: Path) -> bool:
    if not path.exists():
        return False
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if "epoch" in data and "minor" in data:
        return False
    minor = int(data.get("version", 0))
    data["epoch"] = 1
    data["minor"] = minor
    data["version"] = minor
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
    return True


def main() -> int:
    changed = 0
    for market in MARKETS:
        for base in (OUTPUT_DIR, APP_SYMBOLS_DIR):
            path = base / catalog_filename(market)
            if stamp_file(path):
                print(f"✅ {path.relative_to(ROOT)} → 1.{json.load(path.open())['minor']}")
                changed += 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
