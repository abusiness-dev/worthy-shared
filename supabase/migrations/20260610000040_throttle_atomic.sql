-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 5) — rende check_and_record_throttle realmente atomico.
--
-- PROBLEMA:
--   check_and_record_throttle (20260517000003) fa SELECT count(*) poi INSERT senza
--   serializzazione. Sotto READ COMMITTED due chiamate concorrenti dello stesso utente
--   leggono lo stesso count e inseriscono entrambe → modesto overshoot del rate-limit
--   durante un burst realmente concorrente (es. double-tap: 10/min → 12-15).
--
-- SOLUZIONE:
--   pg_advisory_xact_lock per-(utente,funzione) come PRIMA istruzione: serializza le
--   chiamate concorrenti dello stesso utente sulla stessa funzione; il lock si rilascia
--   a fine transazione. Preserva la sliding window esistente. Firma e grant invariati.
-- ════════════════════════════════════════════════════════════════════

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
  -- Serializza le chiamate concorrenti dello stesso (utente,funzione) in questa
  -- transazione: elimina la race count→insert. Lock advisory auto-rilasciato a fine tx.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text || '|' || p_function, 0));

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
