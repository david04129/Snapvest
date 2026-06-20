#!/usr/bin/env python3
"""GitHub Actions：輸出 symbols 建置摘要至 GITHUB_STEP_SUMMARY。"""

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    lines = ["## Symbols 更新摘要", "", "- 台股来源：**Fugle** tickers（TWSE + TPEx, EQUITY）", ""]
    for name in ("tw", "us", "crypto"):
        path = ROOT / "scripts" / "output" / f"symbols_{name}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        lines.append(
            f"- **{path.name}**: {data.get('epoch', 1)}.{data.get('minor', data.get('version'))}, "
            f"items={len(data.get('items', []))}, updatedAt={data.get('updatedAt')}"
        )

    map_path = ROOT / "backend" / "scripts" / "data" / "crypto_coingecko_map.json"
    if map_path.exists():
        count = len(json.loads(map_path.read_text(encoding="utf-8")))
        lines.append(f"- **crypto_coingecko_map.json**: {count} 筆")

    text = "\n".join(lines) + "\n"
    print(text)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        Path(summary_path).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
