"""scripts 建置 symbols 時共用的路徑與 version 讀取。"""

from symbol_catalog_diff import (
    APP_SYMBOLS_DIR,
    BACKEND_CRYPTO_MAP,
    OUTPUT_DIR,
    ROOT,
    SCRIPTS_DIR,
    catalog_document,
    read_catalog_meta,
)


def next_version(filename: str) -> int:
    """Legacy：回傳 minor（不再自動 +1；build 保留現版 epoch/minor）。"""
    _epoch, minor = read_catalog_meta(filename)
    return minor
