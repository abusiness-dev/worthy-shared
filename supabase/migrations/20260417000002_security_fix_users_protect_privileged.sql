-- ============================================================
-- SECURITY FIX: Protegge campi privilegiati della tabella users
--
-- VULNERABILITA CHIUSE:
--   V-002 (CRITICO): users_update_own consente UPDATE su TUTTE
--   le colonne, inclusi role, trust_level, points, is_premium.
--
-- BYPASS (OR logic — qualsiasi condizione basta):
--   1. Session variable worthy.skip_user_protection = 'true'
--      (per future RPC admin-only functions)
--   2. is_service_role_or_internal() = TRUE
--      (per worthy-admin via service_role key PostgREST)
--
-- COMPORTAMENTO:
--   - Se un campo protetto viene modificato da un utente non
--     autorizzato: logga il tentativo in audit_log (via dblink,
--     persistente) e RAISE EXCEPTION.
--   - Se nessun campo protetto e modificato: UPDATE procede.
--
-- CAMPI PROTETTI:
--   role, trust_level, points, is_premium, premium_expires_at,
--   error_rate, products_contributed, products_verified, email
-- ============================================================

CREATE OR REPLACE FUNCTION protect_user_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  blocked_fields text[] := '{}';
  acting_user uuid;
BEGIN
  -- Bypass 1: session variable (per future RPC admin functions)
  -- Bypass 2: service_role JWT (worthy-admin via PostgREST)
  IF current_setting('worthy.skip_user_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  -- Controlla ogni campo protetto
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    blocked_fields := array_append(blocked_fields, 'role');
  END IF;

  IF NEW.trust_level IS DISTINCT FROM OLD.trust_level THEN
    blocked_fields := array_append(blocked_fields, 'trust_level');
  END IF;

  IF NEW.points IS DISTINCT FROM OLD.points THEN
    blocked_fields := array_append(blocked_fields, 'points');
  END IF;

  IF NEW.is_premium IS DISTINCT FROM OLD.is_premium THEN
    blocked_fields := array_append(blocked_fields, 'is_premium');
  END IF;

  IF NEW.premium_expires_at IS DISTINCT FROM OLD.premium_expires_at THEN
    blocked_fields := array_append(blocked_fields, 'premium_expires_at');
  END IF;

  IF NEW.error_rate IS DISTINCT FROM OLD.error_rate THEN
    blocked_fields := array_append(blocked_fields, 'error_rate');
  END IF;

  IF NEW.products_contributed IS DISTINCT FROM OLD.products_contributed THEN
    blocked_fields := array_append(blocked_fields, 'products_contributed');
  END IF;

  IF NEW.products_verified IS DISTINCT FROM OLD.products_verified THEN
    blocked_fields := array_append(blocked_fields, 'products_verified');
  END IF;

  IF NEW.email IS DISTINCT FROM OLD.email THEN
    blocked_fields := array_append(blocked_fields, 'email');
  END IF;

  -- Se nessun campo protetto modificato, UPDATE procede
  IF array_length(blocked_fields, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  -- Tenta di ottenere l'utente corrente per il log
  BEGIN
    acting_user := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    acting_user := NULL;
  END;

  -- Logga il tentativo bloccato (via dblink — persiste dopo RAISE EXCEPTION)
  PERFORM log_security_event('users', OLD.id, acting_user, blocked_fields);

  -- Blocca l'operazione con errore visibile
  RAISE EXCEPTION 'Attempt to modify protected fields: %',
    array_to_string(blocked_fields, ', ')
    USING HINT = 'Protected fields on users table can only be modified by service_role or admin RPC.',
          ERRCODE = '42501'; -- insufficient_privilege

END;
$$;

COMMENT ON FUNCTION protect_user_privileged_fields IS
  'BEFORE UPDATE trigger: blocca modifiche a campi privilegiati. Bypass via session var worthy.skip_user_protection o JWT service_role.';

-- Crea il trigger (drop prima per idempotenza)
DROP TRIGGER IF EXISTS trg_users_protect_fields ON users;
CREATE TRIGGER trg_users_protect_fields
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION protect_user_privileged_fields();
