#!/usr/bin/env python3
"""
僅更新 Supabase exchange_rates（不更新股價）
用法:
  export SUPABASE_URL=...
  export SUPABASE_SERVICE_ROLE_KEY=...
  python3 backend/scripts/update_exchange_rates_only.py
"""
from daily_price_update import get_supabase, update_exchange_rates


def main() -> None:
    supabase = get_supabase()
    n = update_exchange_rates(supabase)
    print(f"完成：已 upsert {n} 筆匯率")


if __name__ == "__main__":
    main()
