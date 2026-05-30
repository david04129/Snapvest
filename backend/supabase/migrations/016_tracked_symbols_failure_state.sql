-- tracked_symbols 防濫用：記錄連續抓價失敗，超過門檻由排程停用。

ALTER TABLE public.tracked_symbols
  ADD COLUMN IF NOT EXISTS failure_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_error TEXT,
  ADD COLUMN IF NOT EXISTS last_failed_at TIMESTAMP;
