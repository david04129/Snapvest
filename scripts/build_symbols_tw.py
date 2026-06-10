#!/usr/bin/env python3
"""
建立台股 symbols_tw.json（上市全商品 + 上櫃 + 興櫃）
資料來源：
1. 證交所上市全商品日行情: https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL
2. 證交所上市公司: https://dts.twse.com.tw/opendata/t187ap03_L.csv（使用「公司簡稱」欄）
3. 櫃買上櫃股票行情: https://www.tpex.org.tw/web/stock/aftertrading/DAILY_CLOSE_quotes/stk_quote_result.php?l=zh-tw&o=data
4. 櫃買興櫃資本額排名: https://www.tpex.org.tw/web/regular_emerging/financereport/emerging_capitals_rank/list_result.php?l=zh-tw&type=l_list&o=data
5. ETF 補充：腳本內 TW_ETF_SUPPLEMENT（保底用）
"""

import csv
import json
import urllib.request
from datetime import date
from pathlib import Path
from typing import Optional

from symbols_paths import OUTPUT_DIR, SCRIPTS_DIR, catalog_document, read_catalog_meta

DATA_DIR = SCRIPTS_DIR / "data"
TWSE_STOCK_DAY_ALL_URL = "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL"
TWSE_LISTED_URL = "https://dts.twse.com.tw/opendata/t187ap03_L.csv"
# 上櫃股票行情（櫃買）
TPEX_OTC_QUOTE_URL = "https://www.tpex.org.tw/web/stock/aftertrading/DAILY_CLOSE_quotes/stk_quote_result.php?l=zh-tw&o=data"
# 興櫃資本額排名（櫃買）
TPEX_EMERGING_URL = "https://www.tpex.org.tw/web/regular_emerging/financereport/emerging_capitals_rank/list_result.php?l=zh-tw&type=l_list&o=data"

LOCAL_CSV_PATHS = [
    DATA_DIR / "tw_listed.csv",
    DATA_DIR / "tw_securities.csv",
    DATA_DIR / "t187ap03_L.csv",
]


def fetch_url(url: str, use_https_redirect: bool = False) -> Optional[str]:
    """下載 URL 內容，嘗試 UTF-8 與 Big5 編碼"""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Snapvest/1.0"})
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read()
        for enc in ("utf-8", "big5", "cp950"):
            try:
                return raw.decode(enc)
            except UnicodeDecodeError:
                continue
        return raw.decode("utf-8", errors="replace")
    except Exception as e:
        print(f"   ⚠️ 下載失敗: {e}")
        return None


def parse_listed_csv(content: str) -> list[dict]:
    """解析上市公司 CSV：出表日期、公司代號、公司名稱、公司簡稱、..."""
    return _parse_tw_csv_generic(
        content,
        symbol_col=1,
        name_col=3,
        fallback_name_col=2,
    )


def parse_twse_stock_day_all(content: str) -> list[dict]:
    """解析證交所上市全商品日行情 JSON：Code、Name、..."""
    try:
        rows = json.loads(content)
    except json.JSONDecodeError:
        return []

    items = []
    seen = set()
    if not isinstance(rows, list):
        return items

    for row in rows:
        if not isinstance(row, dict):
            continue
        symbol = str(row.get("Code", "")).strip().upper()
        name = str(row.get("Name", "")).strip()
        if not symbol or not name:
            continue
        if not _is_valid_tw_symbol(symbol, name):
            continue
        if symbol in seen:
            continue
        seen.add(symbol)
        items.append({"symbol": symbol, "name": name})

    return items


def parse_otc_csv(content: str) -> list[dict]:
    """解析上櫃行情 CSV：資料日期、代號、名稱、收盤、..."""
    return _parse_tw_csv_generic(content, symbol_col=1, name_col=2)


def parse_emerging_csv(content: str) -> list[dict]:
    """解析興櫃資本額 CSV：資料日期、排名、公司代號、公司名稱、..."""
    return _parse_tw_csv_generic(content, symbol_col=2, name_col=3)


def _is_valid_tw_symbol(symbol: str, name: str, max_len: int = 6) -> bool:
    """過濾：保留 4-6 碼英數字台股商品；權證不排除，由資料來源決定。"""
    if len(symbol) < 4 or len(symbol) > max_len:
        return False
    if not symbol.isalnum():
        return False
    return True


def _parse_tw_csv_generic(
    content: str,
    symbol_col: int,
    name_col: int,
    max_symbol_len: int = 6,
    fallback_name_col: Optional[int] = None,
) -> list[dict]:
    """通用解析：依欄位索引提取 symbol、name（可選 fallback 欄位）"""
    content = content.lstrip("\ufeff")
    lines = content.strip().split("\n")
    if not lines:
        return []

    items = []
    seen = set()
    for delim in (",", "\t", ";", " "):
        try:
            reader = csv.reader(lines, delimiter=delim)
            rows = list(reader)
        except Exception:
            continue
        if not rows:
            continue

        first = rows[0]
        if len(first) <= max(symbol_col, name_col):
            continue
        col_sym = str(first[symbol_col]).strip()
        col_name = str(first[name_col]).strip()
        is_header = not col_sym.isdigit() and (
            "代號" in col_sym or "代碼" in col_sym or "公司" in col_sym or "代號" in col_name
        )
        start = 1 if is_header else 0

        items = []
        seen = set()
        for row in rows[start:]:
            if len(row) <= max(symbol_col, name_col):
                continue
            symbol = str(row[symbol_col]).strip().upper()
            name = str(row[name_col]).strip()
            if not name and fallback_name_col is not None and len(row) > fallback_name_col:
                name = str(row[fallback_name_col]).strip()
            if not symbol or not name:
                continue
            if not _is_valid_tw_symbol(symbol, name, max_symbol_len):
                continue
            if symbol in seen:
                continue
            seen.add(symbol)
            items.append({"symbol": symbol, "name": name})

        if items:
            break

    return items


def fetch_listed() -> list[dict]:
    """取得上市公司"""
    content = fetch_url(TWSE_LISTED_URL)
    if content and not content.strip().startswith("<"):
        parsed = parse_listed_csv(content)
        if parsed:
            return parsed
    for path in LOCAL_CSV_PATHS:
        if path.exists():
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                content = path.read_text(encoding="big5")
            if content:
                parsed = parse_listed_csv(content)
                if parsed:
                    print(f"   📁 上市：使用本地檔 {path.name}")
                    return parsed
    return []


def fetch_twse_stock_day_all() -> list[dict]:
    """取得證交所上市全商品日行情（含 ETF、權證與字母代號商品）"""
    content = fetch_url(TWSE_STOCK_DAY_ALL_URL)
    if content and content.strip().startswith("["):
        return parse_twse_stock_day_all(content)
    return []


def fetch_otc() -> list[dict]:
    """取得上櫃股票"""
    content = fetch_url(TPEX_OTC_QUOTE_URL)
    if content and not content.strip().startswith("<"):
        return parse_otc_csv(content)
    return []


def fetch_emerging() -> list[dict]:
    """取得興櫃股票"""
    content = fetch_url(TPEX_EMERGING_URL)
    if content and not content.strip().startswith("<"):
        return parse_emerging_csv(content)
    return []


# 熱門台股 ETF 補充清單（證交所上市公司清單可能不包含 ETF，且含英文字母的代號會被過濾）
# 包含：一般 ETF、槓桿型正2（第六碼L）、反向型反1（第六碼R）、其它（第六碼U等）
TW_ETF_SUPPLEMENT = [
    # 一般 ETF
    ("0050", "元大台灣50"),
    ("0051", "元大中型100"),
    ("0052", "富邦台灣科技"),
    ("0053", "元大電子"),
    ("0054", "元大台商50"),
    ("0055", "元大MSCI金融"),
    ("0056", "元大高股息"),
    ("0057", "元大MSCI臺灣"),
    ("0058", "富邦摩臺"),
    ("0060", "元大台灣高息低波"),
    ("0061", "元大寶滬深"),
    ("006208", "富邦台50"),
    ("00646", "元大S&P500"),
    ("00692", "富邦公司治理"),
    ("00693", "國泰臺灣加權"),
    ("00713", "元大台灣高息低波"),
    ("00730", "富邦臺灣加權"),
    ("00731", "FH富時高息低波"),
    ("00850", "元大臺灣ESG永續"),
    ("00851", "台新MSCI中國"),
    ("00861", "元大全球未來通訊"),
    ("00875", "國泰北美科技"),
    ("00876", "元大台灣高息低波"),
    ("00878", "國泰永續高股息"),
    ("00888", "永豐台灣ESG"),
    ("00890", "富邦臺灣加權"),
    ("00891", "國泰中國A50"),
    ("00893", "國泰智能電動車"),
    ("00900", "富邦特選高股息30"),
    ("00905", "群益臺灣加權"),
    ("00907", "永豐臺灣加權"),
    ("00912", "群益臺灣加權"),
    ("00919", "群益臺灣加權"),
    ("00922", "國泰臺灣加權"),
    ("00923", "群益臺灣加權"),
    ("00924", "群益臺灣加權"),
    ("00927", "群益臺灣加權"),
    ("00928", "中信上櫃ESG 30"),
    ("00929", "復華台灣科技優息"),
    ("00930", "永豐臺灣加權"),
    ("00935", "國泰臺灣加權"),
    ("00939", "統一臺灣高息動能"),
    ("00940", "元大臺灣價值高息"),
    ("00941", "中信上游半導體"),
    ("00943", "兆豐臺灣晶圓製造"),
    ("00944", "野村臺灣趨勢動能高息"),
    # 槓桿型正2（第六碼 L）
    ("00631L", "元大台灣50正2"),
    ("00633L", "富邦上証正2"),
    ("00637L", "元大滬深300正2"),
    ("00647L", "元大S&P500正2"),
    ("00650L", "富邦日本正2"),
    ("00651L", "國泰日本正2"),
    ("00663L", "國泰臺灣加權正2"),
    ("00665L", "富邦臺灣加權正2"),
    ("00667L", "國泰日經225正2"),
    ("00670L", "富邦NASDAQ正2"),
    ("00672L", "元大S&P石油正2"),
    ("00675L", "富邦香港正2"),
    ("00680L", "元大美債20正2"),
    ("00683L", "元大美元指數正2"),
    ("00685L", "元大日本正2"),
    ("00688L", "國泰20年美債正2"),
    ("00708L", "富邦VIX正2"),
    ("00715L", "期街口布蘭特油正2"),
    # 反向型反1（第六碼 R）
    ("00632R", "元大台灣50反1"),
    ("00634R", "富邦上証反1"),
    ("00638R", "元大滬深300反1"),
    ("00648R", "元大S&P500反1"),
    ("00652R", "富邦日本反1"),
    ("00656R", "國泰中國A50反1"),
    ("00664R", "國泰臺灣加權反1"),
    ("00666R", "富邦臺灣加權反1"),
    ("00668R", "國泰日經225反1"),
    ("00669R", "國泰美國道瓊反1"),
    ("00671R", "富邦NASDAQ反1"),
    ("00673R", "元大S&P石油反1"),
    ("00674R", "群益臺灣加權反1"),
    ("00676R", "富邦香港反1"),
    ("00681R", "元大美債20反1"),
    ("00684R", "元大美元指數反1"),
    ("00686R", "元大日本反1"),
    ("00689R", "國泰20年美債反1"),
    ("00709R", "富邦VIX反1"),
    ("00716R", "期街口布蘭特油反1"),
    # 其它（第六碼 U 等）
    ("00677U", "富邦VIX"),
    ("00682U", "元大美元指數"),
    ("00635U", "元大S&P原油正2"),
]


def build_symbols_tw() -> Optional[dict]:
    """合併上市、上櫃、興櫃、ETF 補充，去重後排序"""
    all_items = []
    symbol_to_name = {}

    # 0. 台股 ETF 補充（證交所清單不含含字母代號之 ETF，如 00631L；0050 等也可能不在上市 CSV）
    for sym, name in TW_ETF_SUPPLEMENT:
        if sym not in symbol_to_name:
            symbol_to_name[sym] = name
    print(f"   ETF 補充: {len(TW_ETF_SUPPLEMENT)} 筆")

    # 1. 證交所上市全商品（含 ETF、權證與字母代號商品）
    twse_all = fetch_twse_stock_day_all()
    for item in twse_all:
        symbol_to_name[item["symbol"]] = item["name"]
    all_items.extend(twse_all)
    print(f"   上市全商品: {len(twse_all)} 筆")

    # 2. 上市公司（補公司簡稱；若同代號存在，保留全商品行情名稱）
    listed = fetch_listed()
    listed_new = [x for x in listed if x["symbol"] not in symbol_to_name]
    for item in listed_new:
        symbol_to_name[item["symbol"]] = item["name"]
    all_items.extend(listed_new)
    print(f"   上市公司: {len(listed_new)} 筆（新增）")

    # 3. 上櫃（排除已存在）
    otc = fetch_otc()
    otc_new = [x for x in otc if x["symbol"] not in symbol_to_name]
    for item in otc_new:
        symbol_to_name[item["symbol"]] = item["name"]
    all_items.extend(otc_new)
    print(f"   上櫃: {len(otc_new)} 筆（新增）")

    # 4. 興櫃（排除已存在）
    emerging = fetch_emerging()
    emerging_new = [x for x in emerging if x["symbol"] not in symbol_to_name]
    for item in emerging_new:
        symbol_to_name[item["symbol"]] = item["name"]
    all_items.extend(emerging_new)
    print(f"   興櫃: {len(emerging_new)} 筆（新增）")

    if not symbol_to_name:
        print("❌ 台股：無法取得任何資料")
        return None

    # 合併並去重（以 symbol 為 key，後面的覆蓋前面的）
    merged = [{"symbol": s, "name": n} for s, n in symbol_to_name.items()]
    merged.sort(key=lambda x: (x["symbol"].zfill(6), x["symbol"]))

    epoch, minor = read_catalog_meta("symbols_tw.json")
    return catalog_document(
        epoch=epoch,
        minor=minor,
        items=merged,
        updated_at=str(date.today()),
    )


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "symbols_tw.json"
    print("台股：正在取得上市、上櫃、興櫃...")
    data = build_symbols_tw()
    if data is None:
        return 1

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ symbols_tw.json: {len(data['items'])} 筆, {data['epoch']}.{data['minor']}")
    return 0


if __name__ == "__main__":
    exit(main())
