#!/usr/bin/env python3
"""
建置新 symbols 前，將現有清單備份至 scripts/output/archive/。
每種檔案最多保留 KEEP_VERSIONS 份舊版（不含目前正在用的那份）。
"""

import json
import re
import shutil
from pathlib import Path
from typing import Optional

from symbols_paths import APP_SYMBOLS_DIR, BACKEND_CRYPTO_MAP, OUTPUT_DIR

ARCHIVE_DIR = OUTPUT_DIR / "archive"
KEEP_VERSIONS = 2
MARKETS = ("tw", "us", "crypto")

_VERSION_RE = re.compile(r"_v(\d+)_")


def _read_source(path: Path) -> Optional[Path]:
    """優先 output，其次 App Bundle。"""
    if path.exists():
        return path
    app_path = APP_SYMBOLS_DIR / path.name
    if app_path.exists():
        return app_path
    return None


def _archive_name_for_symbols(market: str, data: dict) -> str:
    version = data.get("version", 0)
    updated_at = data.get("updatedAt") or "unknown"
    safe_date = str(updated_at).replace("/", "-")
    return f"symbols_{market}_v{version}_{safe_date}.json"


def _archive_name_for_manifest(data: dict) -> str:
    parts = []
    for market in MARKETS:
        info = data.get(market) or {}
        parts.append(f"{market}{info.get('version', 0)}")
    label = "_".join(parts) if parts else "manifest"
    dates = [str((data.get(m) or {}).get("updatedAt") or "") for m in MARKETS]
    updated_at = max(dates) if any(dates) else "unknown"
    safe_date = updated_at.replace("/", "-") or "unknown"
    return f"symbols_manifest_{label}_{safe_date}.json"


def _archive_name_for_crypto_map(data: dict) -> str:
    count = len(data)
    return f"crypto_coingecko_map_{count}entries.json"


def _rotate(archive_subdir: Path, keep: int = KEEP_VERSIONS) -> None:
    """依檔名中的 version 保留最新 keep 份，刪除更舊的。"""
    if not archive_subdir.exists():
        return

    files = list(archive_subdir.glob("*.json"))
    if len(files) <= keep:
        return

    def sort_key(path: Path) -> tuple[int, float, str]:
        match = _VERSION_RE.search(path.name)
        version = int(match.group(1)) if match else 0
        mtime = path.stat().st_mtime
        return (version, mtime, path.name)

    files.sort(key=sort_key, reverse=True)
    for old in files[keep:]:
        old.unlink()
        print(f"🗑️  移除舊備份: {old.relative_to(OUTPUT_DIR)}")


def _archive_json(src: Path, dst: Path) -> None:
    if dst.exists():
        print(f"⏭️  備份已存在，略過: {dst.relative_to(OUTPUT_DIR)}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"📦 已備份: {dst.relative_to(OUTPUT_DIR)}")


def main() -> int:
    archived = 0

    for market in MARKETS:
        src = _read_source(OUTPUT_DIR / f"symbols_{market}.json")
        if src is None:
            continue
        with open(src, encoding="utf-8") as f:
            data = json.load(f)
        dst = ARCHIVE_DIR / market / _archive_name_for_symbols(market, data)
        _archive_json(src, dst)
        archived += 1
        _rotate(ARCHIVE_DIR / market)

    manifest_src = _read_source(OUTPUT_DIR / "symbols_manifest.json")
    if manifest_src is not None:
        with open(manifest_src, encoding="utf-8") as f:
            manifest = json.load(f)
        dst = ARCHIVE_DIR / "manifest" / _archive_name_for_manifest(manifest)
        _archive_json(manifest_src, dst)
        archived += 1
        _rotate(ARCHIVE_DIR / "manifest")

    if BACKEND_CRYPTO_MAP.exists():
        with open(BACKEND_CRYPTO_MAP, encoding="utf-8") as f:
            crypto_map = json.load(f)
        dst = ARCHIVE_DIR / "crypto_map" / _archive_name_for_crypto_map(crypto_map)
        _archive_json(BACKEND_CRYPTO_MAP, dst)
        archived += 1
        _rotate(ARCHIVE_DIR / "crypto_map")

    if archived == 0:
        print("ℹ️  無現有清單可備份（可能是首次建置）。")
    else:
        print(f"✅ 備份完成（每種最多保留 {KEEP_VERSIONS} 份舊版）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
