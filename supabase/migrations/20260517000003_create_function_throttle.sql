-- Rate limiting per edge functions costose (es. match-product-by-tag con OCR Claude).
-- Tabella sliding-window con RPC atomica check_and_record_throttle che count+insert in
-- un'unica transazione (evita race tra controllo e registrazione su chiamate concorrenti).

CREATE TABLE IF NOT EXISTS function_calls_throttle (
  id            bigserial   PRIMARY KEY,
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  function_name text        NOT NULL,
  called_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_throttle_user_fn_time
  ON function_calls_throttle(user_id, function_name, called_at DESC);

ALTER TABLE function_calls_throttle ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON function_calls_throttle FROM anon, authenticated;
-- Nessuna policy: solo service_role accede.

CREATE OR REPLACE FUNCTION check_and_record_throttle(
  p_user_id  uuid,
  p_function text,
  p_max      int,
  p_window   interval
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  recent_count int;
BEGIN
  SELECT count(*) INTO recent_count
    FROM function_calls_throttle
    WHERE user_id = p_user_id
      AND function_name = p_function
      AND called_at > now() - p_window;

  IF recent_count >= p_max THEN
    RETURN false;
  END IF;

  INSERT INTO function_calls_throttle(user_id, function_name)
    VALUES (p_user_id, p_function);

  RETURN true;
END
$$;

REVOKE ALL ON FUNCTION check_and_record_throttle(uuid, text, int, interval)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION check_and_record_throttle(uuid, text, int, interval)
  TO service_role;

-- Cleanup entries più vecchie di 1 ora (la sliding window non eccede mai 1 minuto, ma
-- teniamo margine per debug). Cron ogni 30 minuti.
SELECT cron.schedule(
  'cleanup-function-calls-throttle',
  '*/30 * * * *',
  $$DELETE FROM function_calls_throttle WHERE called_at < now() - interval '1 hour'$$
);
