"""scripts 建置 symbols 時共用的路徑與 version 讀取。"""

import json
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
OUTPUT_DIR = SCRIPTS_DIR / "output"
APP_SYMBOLS_DIR = ROOT / "Snapvest" / "Snapvest" / "Resources" / "Symbols"
BACKEND_CRYPTO_MAP = ROOT / "backend" / "scripts" / "data" / "crypto_coingecko_map.json"


def next_version(filename: str) -> int:
    """從 output 或 App Bundle 讀取 version，回傳 +1。"""
    version = 0
    for base in (OUTPUT_DIR, APP_SYMBOLS_DIR):
        path = base / filename
        if not path.exists():
            continue
        try:
            with open(path, encoding="utf-8") as f:
                existing = json.load(f)
            version = max(version, int(existing.get("version", 0)))
        except (json.JSONDecodeError, KeyError, OSError, TypeError, ValueError):
            continue
    return version + 1
