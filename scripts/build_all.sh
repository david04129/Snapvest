#!/bin/bash
# 一次性建立所有 symbols 檔案與 manifest
cd "$(dirname "$0")"

echo "=== 建立 symbols 檔案 ==="

python3 build_symbols_us.py
python3 build_symbols_crypto.py
python3 build_symbols_tw.py || echo "（台股若失敗，請參考 README 放置本地 CSV）"

echo ""
echo "=== 建立 manifest ==="
python3 build_manifest.py

echo ""
echo "完成。輸出目錄: output/"
