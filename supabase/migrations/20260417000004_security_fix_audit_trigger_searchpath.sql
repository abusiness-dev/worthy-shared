-- ============================================================
-- SECURITY FIX: Aggiunge SET search_path a trigger_audit_log()
--
-- VULNERABILITA CHIUSA:
--   V-005 (ALTO): trigger_audit_log() e SECURITY DEFINER senza
--   SET search_path. Un attaccante potrebbe creare oggetti in uno
--   schema con priorita maggiore nel search_path, hijackando le
--   chiamate di funzione all'interno del trigger.
--
-- La funzione handle_new_user() ha gia SET search_path = public, auth.
-- Questa migration corregge l'unica funzione SECURITY DEFINER
-- che mancava del search_path.
--
-- Il corpo e identico alla versione in
-- 20260328000001_fix_audit_trigger_case.sql (con lower(TG_OP)).
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  record_uuid uuid;
  old_json jsonb;
  new_json jsonb;
  action_type audit_action;
  acting_user uuid;
BEGIN
  action_type := lower(TG_OP)::audit_action;

  IF TG_OP = 'DELETE' THEN
    record_uuid := OLD.id;
    old_json := to_jsonb(OLD);
    new_json := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    record_uuid := NEW.id;
    old_json := NULL;
    new_json := to_jsonb(NEW);
  ELSE
    record_uuid := NEW.id;
    old_json := to_jsonb(OLD);
    new_json := to_jsonb(NEW);
  END IF;

  BEGIN
    acting_user := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    acting_user := NULL;
  END;

  INSERT INTO audit_log (table_name, record_id, action, user_id, old_data, new_data)
  VALUES (TG_TABLE_NAME, record_uuid, action_type, acting_user, old_json, new_json);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- I trigger esistenti (trg_products_audit, trg_brands_audit, trg_users_audit)
-- usano gia questa funzione e non devono essere ricreati.
-- CREATE OR REPLACE aggiorna la funzione in-place.
