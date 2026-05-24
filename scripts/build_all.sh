#!/bin/bash
# 建立所有 symbols 檔案、manifest，並同步至 App Bundle
set -euo pipefail
cd "$(dirname "$0")"

echo "=== 建立 symbols 檔案 ==="

python3 build_symbols_us.py
python3 build_symbols_crypto.py
python3 build_symbols_tw.py

echo ""
echo "=== 建立 manifest ==="
python3 build_manifest.py

echo ""
echo "=== 同步至 App Bundle ==="
python3 sync_symbols_outputs.py

echo ""
echo "完成。輸出：scripts/output/ 與 Snapvest/Snapvest/Resources/Symbols/"
