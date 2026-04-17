-- ============================================================
-- SECURITY FIX: Helper functions + enum per audit blocchi
-- Prerequisito per tutte le altre migration di sicurezza.
--
-- NOTA ENUM: ALTER TYPE ADD VALUE non puo essere eseguito in un
-- blocco transazionale. Supabase CLI gestisce questo automaticamente
-- eseguendolo fuori dalla transazione. DEVE essere il primo statement.
-- ============================================================

-- Nuovo valore enum per loggare tentativi di modifica bloccati
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'blocked';

-- dblink per autonomous transaction nel logging eventi di sicurezza
CREATE EXTENSION IF NOT EXISTS dblink;

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
-- SCOPO: Logga un tentativo di modifica bloccato nell'audit_log.
--
-- RATIONALE DBLINK: I trigger protettivi fanno RAISE EXCEPTION dopo
-- aver chiamato questa funzione. In PostgreSQL, RAISE EXCEPTION
-- rollbacka l'intera transazione, inclusi eventuali INSERT normali.
-- dblink apre una connessione loopback separata con la propria
-- transazione: l'INSERT via dblink committa indipendentemente e
-- sopravvive al rollback della transazione principale.
--
-- ATTENZIONE SUPABASE CLOUD: Il dblink loopback ('dbname=' || current_database())
-- NON e stato testato su Supabase Cloud al momento della scrittura
-- (2026-04-17). Su Supabase locale (supabase start) funziona perche
-- il container Docker usa trust auth per connessioni locali. Su Cloud,
-- il pg_hba.conf potrebbe richiedere credenziali esplicite.
--
-- SE DBLINK FALLISCE SISTEMATICAMENTE:
--   1. Verificare dashboard Supabase → Logs → Postgres per errori dblink
--   2. Il fallback RAISE WARNING logga l'errore nei log PostgreSQL
--      (visibili in dashboard → Logs → Postgres)
--   3. Un pg_notify best-effort viene emesso nel catch (rollbackato
--      dalla RAISE EXCEPTION del trigger, ma utile in contesti senza
--      exception come futuro refactor)
--   4. Migrare a pg_net se dblink non funziona. Vedere
--      docs/SECURITY_LOG_ALTERNATIVES.md per il piano B completo.
--
-- SECURITY DEFINER: necessario per aprire la connessione dblink
-- come function owner (postgres) con accesso locale.
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
    'blocked_fields', to_jsonb(p_blocked_fields),
    'blocked_at', now()::text,
    'reason', 'Attempted modification of protected fields'
  );

  -- Usa dblink per INSERT in una transazione autonoma.
  -- Il RAISE EXCEPTION nel trigger chiamante NON rollbacka questo INSERT.
  -- La connessione loopback usa l'identita del function owner (postgres).
  BEGIN
    PERFORM dblink_exec(
      'dbname=' || current_database(),
      format(
        $dblink$INSERT INTO public.audit_log
          (table_name, record_id, action, user_id, new_data, created_at)
        VALUES (%L, %L, 'blocked', %L, %L::jsonb, now())$dblink$,
        p_table,
        p_record_id,
        p_user_id,
        payload::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- Se dblink fallisce (connessione rifiutata, estensione mancante, ecc.)
    -- non bloccare il trigger — il RAISE EXCEPTION protegge comunque.
    -- Il log si perde, ma l'attacco e comunque bloccato.
    RAISE WARNING 'log_security_event: dblink failed (audit entry lost): %', SQLERRM;

    -- Best-effort: emetti NOTIFY con i dettagli dell'evento.
    -- NOTA: questo NOTIFY verra rollbackato dalla RAISE EXCEPTION del
    -- trigger chiamante (PostgreSQL committa NOTIFY solo al commit).
    -- Tuttavia e utile in contesti dove il trigger non fa RAISE (futuro
    -- refactor) o come segnale diagnostico durante lo sviluppo.
    BEGIN
      PERFORM pg_notify(
        'security_event_audit_failed',
        jsonb_build_object(
          'table', p_table,
          'record_id', p_record_id,
          'user_id', p_user_id,
          'blocked_fields', p_blocked_fields,
          'error', SQLERRM,
          'at', now()
        )::text
      );
    EXCEPTION WHEN OTHERS THEN
      -- Se anche pg_notify fallisce, non bloccare nulla.
      NULL;
    END;
  END;
END;
$$;

COMMENT ON FUNCTION log_security_event IS
  'Logga un tentativo bloccato via dblink (autonomous transaction). Il log persiste anche se il trigger fa RAISE EXCEPTION. Action hardcoded a blocked.';

-- Restrizione accesso: nessun ruolo client puo chiamarla direttamente.
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM anon;
REVOKE ALL ON FUNCTION log_security_event(text, uuid, uuid, text[]) FROM authenticated;
