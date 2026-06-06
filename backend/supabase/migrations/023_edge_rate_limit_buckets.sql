-- Phase B：Edge Function 限流 bucket（僅 service_role 經 RPC 存取）

CREATE TABLE IF NOT EXISTS public.edge_rate_limit_buckets (
  bucket_key text PRIMARY KEY,
  count int NOT NULL DEFAULT 0,
  window_start timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.edge_rate_limit_buckets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.edge_rate_limit_buckets FROM PUBLIC;
GRANT ALL ON TABLE public.edge_rate_limit_buckets TO service_role;

CREATE OR REPLACE FUNCTION public.check_edge_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_seconds integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now();
  v_epoch bigint := floor(extract(epoch FROM v_now))::bigint;
  v_window_start timestamptz;
  v_count integer;
  v_retry integer;
BEGIN
  IF p_limit <= 0 OR p_window_seconds <= 0 THEN
    RETURN jsonb_build_object('allowed', true, 'retry_after_seconds', 0, 'count', 0);
  END IF;

  v_window_start := to_timestamp((v_epoch / p_window_seconds) * p_window_seconds);
  v_retry := p_window_seconds - (v_epoch % p_window_seconds);

  INSERT INTO edge_rate_limit_buckets (bucket_key, count, window_start)
  VALUES (p_bucket_key, 1, v_window_start)
  ON CONFLICT (bucket_key) DO UPDATE SET
    count = CASE
      WHEN edge_rate_limit_buckets.window_start = EXCLUDED.window_start
        THEN edge_rate_limit_buckets.count + 1
      ELSE 1
    END,
    window_start = EXCLUDED.window_start
  RETURNING count INTO v_count;

  IF v_count > p_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'retry_after_seconds', GREATEST(v_retry, 1),
      'count', v_count
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'retry_after_seconds', 0,
    'count', v_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.check_edge_rate_limit(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_edge_rate_limit(text, integer, integer) TO service_role;
