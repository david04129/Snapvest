#!/usr/bin/env python3
"""
Snapvest 每日批次（GitHub Actions 使用）
- 股價：asset_price_snapshots
- 匯率：exchange_rates（open.er-api.com）

實作與 daily_price_update.py 共用；此檔保留給 CI 與 verify_price_validation 匯入。
"""
from daily_price_update import _is_valid_price, main

__all__ = ["_is_valid_price", "main"]

if __name__ == "__main__":
    main()
