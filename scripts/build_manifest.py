#!/usr/bin/env python3
"""
建立 symbols_manifest.json
供 App 檢查各市場的 symbols 是否有更新。
"""

import json
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent / "output"

# 後端 Base URL（上傳到 Supabase Storage 後請修改此處）
# 例：https://xxxx.supabase.co/storage/v1/object/public/symbols
BASE_URL = "https://your-backend.com/symbols"


def build_manifest() -> dict:
    """從現有的 symbols_*.json 讀取 version，組出 manifest"""
    manifest = {}
    for market in ("tw", "us", "crypto"):
        path = OUTPUT_DIR / f"symbols_{market}.json"
        if not path.exists():
            manifest[market] = {"version": 0, "updatedAt": None, "url": f"{BASE_URL}/symbols_{market}.json"}
            continue
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            version = data.get("version", 0)
            updated_at = data.get("updatedAt")
            manifest[market] = {
                "version": version,
                "updatedAt": updated_at,
                "url": f"{BASE_URL}/symbols_{market}.json",
            }
        except (json.JSONDecodeError, KeyError) as e:
            manifest[market] = {
                "version": 0,
                "updatedAt": None,
                "url": f"{BASE_URL}/symbols_{market}.json",
                "error": str(e),
            }
    return manifest


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = build_manifest()
    output_path = OUTPUT_DIR / "symbols_manifest.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print("✅ symbols_manifest.json 已建立")
    for market, info in manifest.items():
        print(f"   {market}: version={info.get('version', 0)}, updatedAt={info.get('updatedAt', 'N/A')}")


if __name__ == "__main__":
    main()
