-- ============================================================
-- SECURITY FIX: Helper functions + enum per audit blocchi
-- Prerequisito per tutte le altre migration di sicurezza.
--
-- NOTA ENUM: ALTER TYPE ADD VALUE non puo essere eseguito in un
-- blocco transazionale. Supabase CLI gestisce questo automaticamente
-- eseguendolo fuori dalla transazione. DEVE essere il primo statement.
-- ============================================================

-- Nuovo valore enum per loggare tentativi di modifica bloccati
-- (mantenuto anche se nella strategia attuale log_security_event NON scrive
-- piu in audit_log — l'enum e comunque riferito da altre parti del codice
-- e potrebbe tornare utile se post-lancio si migra a pg_net + Edge Function.)
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'blocked';

-- ============================================================
-- is_service_role_or_internal()
--
-- Ritorna TRUE SOLO se il JWT contiene role='service_role'.
-- Usata come fallback dai trigger protettivi per consentire
-- operazioni admin via service_role key (worthy-admin).
--
-- DESIGN: fail-closed. Qualsiasi errore o valore imprevisto
-- ritorna FALSE (nega accesso). Solo il match esplicito con
-- 'service_role' ritorna TRUE.
--
-- Il bypass per lo scoring engine e gestito da session variable
-- (worthy.skip_protection), NON da questa funzione.
-- ============================================================

CREATE OR REPLACE FUNCTION is_service_role_or_internal()
RETURNS boolean
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  claims_raw text;
  jwt_role text;
BEGIN
  -- Step 1: leggi il raw setting. Ritorna NULL se non esiste.
  claims_raw := current_setting('request.jwt.claims', true);

  -- Nessun JWT presente: contesto interno (cron, migration, SECURITY DEFINER).
  -- NOTA: i trigger ora usano session variable per questo caso,
  -- quindi qui ritorniamo FALSE (fail-closed). I trigger hanno
  -- il loro bypass esplicito.
  IF claims_raw IS NULL OR claims_raw = '' THEN
    RETURN FALSE;
  END IF;

  -- Step 2: parse JSON ed estrai role. Se fallisce, fail-closed.
  BEGIN
    jwt_role := claims_raw::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    -- JSON malformato o errore imprevisto → nega accesso
    RETURN FALSE;
  END;

  -- Step 3: solo 'service_role' esplicito ritorna TRUE.
  -- NULL, '', 'authenticated', 'anon', qualsiasi altro valore → FALSE.
  RETURN jwt_role = 'service_role';
END;
$$;

COMMENT ON FUNCTION is_service_role_or_internal IS
  'Ritorna TRUE solo per JWT con role=service_role. Fail-closed: errori e valori imprevisti ritornano FALSE. Usata dai trigger come fallback per operazioni admin via PostgREST.';

-- ============================================================
-- log_security_event()
--
-- SCOPO: Emette un log strutturato di un tentativo di modifica bloccato.
--
-- STRATEGIA ATTUALE (Opzione C — solo log Postgres):
--   Il log viene emesso via RAISE WARNING con un payload JSON consistente.
--   Il messaggio finisce nei log PostgreSQL, visibili su:
--     - Supabase Dashboard → Logs → Postgres (Cloud)
--     - docker logs / supabase logs (locale)
--
--   Format:  SECURITY_EVENT_BLOCKED {json-payload}
--   Grep:    supabase logs | grep SECURITY_EVENT_BLOCKED
--   Parse:   il payload dopo il prefisso e JSON valido
--
-- RATIONALE: la PROTEZIONE (RAISE EXCEPTION nei trigger chiamanti) e
-- indipendente dal log. L'attacco viene bloccato a prescindere; il log
-- e solo per audit/forensics. Scegliendo RAISE WARNING evitiamo:
--   - dblink loopback (richiede credenziali non disponibili ovunque)
--   - pg_net + Edge Function (infrastruttura non necessaria al lancio)
-- Trade-off: per query strutturate serve accedere ai Postgres logs,
-- non a una tabella SQL. Accettabile al lancio.
--
-- MIGRATION PATH (post-lancio se serve audit queryabile):
--   vedere docs/SECURITY_LOG_ALTERNATIVES.md — migrare a pg_net +
--   Edge Function che inserisce in audit_log via service_role.
--
-- SECURITY DEFINER: preservato per coerenza con i chiamanti (trigger
-- che fanno PERFORM log_security_event) e per evitare che un futuro
-- refactor verso INSERT in tabella venga bloccato da RLS.
-- ============================================================

CREATE OR REPLACE FUNCTION log_security_event(
  p_table text,
  p_record_id uuid,
  p_user_id uuid,
  p_blocked_fields text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payload jsonb;
BEGIN
  -- Validazione input
  IF p_table IS NULL OR p_table = '' THEN
    RAISE EXCEPTION 'log_security_event: p_table cannot be null or empty';
  END IF;

  IF p_blocked_fields IS NULL OR array_length(p_blocked_fields, 1) IS NULL
     OR array_length(p_blocked_fields, 1) = 0 THEN
    RAISE EXCEPTION 'log_security_event: p_blocked_fields cannot be null or empty';
  END IF;

  payload := jsonb_build_object(
    'event_type', 'blocked',
    'table', p_table,
    'record_id', p_record_id,
    'user_id', p_user_id,
    'blocked_fields', p_blocked_fields,
    'at', now()
  );

  -- Format: SECURITY_EVENT_BLOCKED {json-payload}
  -- Grep with: supabase logs | grep SECURITY_EVENT_BLOCKED
  -- Migration path: see docs/SECURITY_LOG_ALTERNATIVES.md
  RAISE WARNING 'SECURITY_EVENT_BLOCKED %', payload::text;
END;
$$;

COMMENT ON FUNCTION log_security_event IS
  'Emette RAISE WARNING con payload JSON (prefisso SECURITY_EVENT_BLOCKED) nei log Postgres. Sopravvive a RAISE EXCEPTION del trigger chiamante perche i log Postgres non partecipano alla transazione. Upgrade path a pg_net + Edge Function in docs/SECURITY_LOG_ALTERNATIVES.md.';

-- Restrizione accesso: nessun ruolo client puo chiamarla direttamente.
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM anon;
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM authenticated;
