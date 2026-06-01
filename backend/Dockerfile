# Snapvest 股價排程（Cloud Run Job）
FROM python:3.11-slim

WORKDIR /app

COPY scripts/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# 變更此值可強制 Cloud Build 重跑 COPY（避免舊腳本被 layer cache 沿用）
ARG SCRIPTS_CACHE_BUST=20260603
COPY scripts /app/scripts

WORKDIR /app/scripts

# 預設由 Cloud Scheduler 傳入參數，例如：
# python daily_price_update.py --mode intraday --markets tw
ENTRYPOINT ["python", "daily_price_update.py"]
