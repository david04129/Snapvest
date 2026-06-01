"""
市場盤中／交易日判斷（台北時間為排程基準；美股 regular 用 America/New_York）。

供 daily_price_update、sync_market_calendar、Cloud Run job 使用。
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from typing import Literal, Optional
from zoneinfo import ZoneInfo

TW_TZ = ZoneInfo("Asia/Taipei")
NY_TZ = ZoneInfo("America/New_York")

MarketCode = Literal["tw", "us", "crypto"]

# Regular session（不含盤前盤後）
TW_REGULAR_OPEN = time(9, 0)
TW_REGULAR_CLOSE = time(13, 30)
US_REGULAR_OPEN = time(9, 30)
US_REGULAR_CLOSE = time(16, 0)


@dataclass(frozen=True)
class MarketStatus:
    market: MarketCode
    as_of: datetime
    is_trading_day: bool
    is_regular_session: bool
    is_intraday_active: bool
    session: str  # closed | regular | holiday
    reason: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "market": self.market,
            "asOf": self.as_of.isoformat(),
            "isTradingDay": self.is_trading_day,
            "isRegularSession": self.is_regular_session,
            "isIntradayActive": self.is_intraday_active,
            "session": self.session,
            "reason": self.reason,
        }


def tw_now() -> datetime:
    return datetime.now(TW_TZ)


def _weekday_trading_fallback(market: MarketCode, d: date) -> bool:
    """無日曆資料時：台／美週一至週五視為交易日。"""
    if market == "crypto":
        return True
    return d.weekday() < 5


def _load_calendar_day(
    calendar_rows: Optional[dict[tuple[str, date], dict]],
    market: Literal["tw", "us"],
    d: date,
) -> tuple[bool, Optional[str]]:
    if not calendar_rows:
        return _weekday_trading_fallback(market, d), None
    row = calendar_rows.get((market, d))
    if row is None:
        return _weekday_trading_fallback(market, d), "calendar_missing"
    if not row.get("is_trading_day", True):
        return False, row.get("holiday_name") or "exchange_holiday"
    return True, None


def build_calendar_index(rows: list[dict]) -> dict[tuple[str, date], dict]:
    index: dict[tuple[str, date], dict] = {}
    for row in rows:
        m = row.get("market")
        td = row.get("trade_date")
        if not m or not td:
            continue
        if isinstance(td, str):
            td = date.fromisoformat(td[:10])
        index[(m, td)] = row
    return index


def is_tw_regular_session(at: datetime) -> bool:
    local = at.astimezone(TW_TZ)
    t = local.timetz().replace(tzinfo=None)
    return TW_REGULAR_OPEN <= t <= TW_REGULAR_CLOSE


def is_us_regular_session(at: datetime) -> bool:
    local = at.astimezone(NY_TZ)
    t = local.timetz().replace(tzinfo=None)
    return US_REGULAR_OPEN <= t <= US_REGULAR_CLOSE


def market_status(
    market: MarketCode,
    at: Optional[datetime] = None,
    calendar_rows: Optional[dict[tuple[str, date], dict]] = None,
) -> MarketStatus:
    at = at or tw_now()
    if market == "crypto":
        return MarketStatus(
            market="crypto",
            as_of=at,
            is_trading_day=True,
            is_regular_session=True,
            is_intraday_active=True,
            session="regular",
            reason=None,
        )

    cal_market: Literal["tw", "us"] = market
    local_date = at.astimezone(TW_TZ if market == "tw" else NY_TZ).date()
    is_trading_day, cal_reason = _load_calendar_day(calendar_rows, cal_market, local_date)

    if not is_trading_day:
        return MarketStatus(
            market=market,
            as_of=at,
            is_trading_day=False,
            is_regular_session=False,
            is_intraday_active=False,
            session="holiday",
            reason=cal_reason or "holiday",
        )

    in_regular = (
        is_tw_regular_session(at) if market == "tw" else is_us_regular_session(at)
    )
    if in_regular:
        return MarketStatus(
            market=market,
            as_of=at,
            is_trading_day=True,
            is_regular_session=True,
            is_intraday_active=True,
            session="regular",
            reason=None,
        )

    return MarketStatus(
        market=market,
        as_of=at,
        is_trading_day=True,
        is_regular_session=False,
        is_intraday_active=False,
        session="closed",
        reason="outside_session",
    )


def fetch_calendar_from_supabase(supabase, lookback_days: int = 7, forward_days: int = 60) -> dict:
    """讀取 market_calendar 近期列，供 market_status 使用。"""
    today = tw_now().date()
    start = today - timedelta(days=lookback_days)
    end = today + timedelta(days=forward_days)
    try:
        r = (
            supabase.table("market_calendar")
            .select("market, trade_date, is_trading_day, holiday_name")
            .gte("trade_date", start.isoformat())
            .lte("trade_date", end.isoformat())
            .execute()
        )
        return build_calendar_index(r.data or [])
    except Exception:
        return {}

def should_run_intraday(market: Literal["tw", "us"], supabase=None) -> bool:
    cal = fetch_calendar_from_supabase(supabase) if supabase else None
    return market_status(market, calendar_rows=cal).is_intraday_active
