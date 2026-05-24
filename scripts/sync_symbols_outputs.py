#!/usr/bin/env python3
"""
將 scripts/output 的 symbols JSON 同步至 App Bundle。
發 App 新版前可執行 build_all.sh，或等每月 GitHub Actions 自動 commit。
"""

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
APP_SYMBOLS_DIR = ROOT / "Snapvest" / "Snapvest" / "Resources" / "Symbols"

MARKETS = ("tw", "us", "crypto")


def sync_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def main() -> int:
    missing = [m for m in MARKETS if not (OUTPUT_DIR / f"symbols_{m}.json").exists()]
    if missing:
        print(f"❌ 缺少 symbols 檔案: {', '.join(missing)}")
        return 1

    for market in MARKETS:
        src = OUTPUT_DIR / f"symbols_{market}.json"
        dst = APP_SYMBOLS_DIR / f"symbols_{market}.json"
        sync_file(src, dst)
        with open(src, encoding="utf-8") as f:
            data = json.load(f)
        count = len(data.get("items", []))
        print(
            f"✅ {dst.relative_to(ROOT)} "
            f"← version={data.get('version')} updatedAt={data.get('updatedAt')} ({count} 筆)"
        )

    manifest_src = OUTPUT_DIR / "symbols_manifest.json"
    if manifest_src.exists():
        sync_file(manifest_src, APP_SYMBOLS_DIR / "symbols_manifest.json")
        print(f"✅ {APP_SYMBOLS_DIR.relative_to(ROOT)}/symbols_manifest.json")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
