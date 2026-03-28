-- Crea trigger: auto-update updated_at, calcolo score, audit log

-- ============================================================
-- Funzione generica: auto-update updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Trigger updated_at su products
CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

-- Trigger updated_at su users
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

-- Trigger updated_at su user_consents
CREATE TRIGGER trg_user_consents_updated_at
  BEFORE UPDATE ON user_consents
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================
-- Trigger: ricalcola worthy_score dopo INSERT/UPDATE su products
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_calculate_worthy_score()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Ricalcola solo se cambiano campi rilevanti per lo scoring
  IF TG_OP = 'INSERT' OR
     OLD.composition IS DISTINCT FROM NEW.composition OR
     OLD.price IS DISTINCT FROM NEW.price OR
     OLD.category_id IS DISTINCT FROM NEW.category_id
  THEN
    PERFORM calculate_worthy_score(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_calculate_score
  AFTER INSERT OR UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_worthy_score();

-- ============================================================
-- Funzione generica: audit log
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  record_uuid uuid;
  old_json jsonb;
  new_json jsonb;
  action_type audit_action;
  acting_user uuid;
BEGIN
  action_type := TG_OP::text::audit_action;

  -- Determina record ID e dati
  IF TG_OP = 'DELETE' THEN
    record_uuid := OLD.id;
    old_json := to_jsonb(OLD);
    new_json := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    record_uuid := NEW.id;
    old_json := NULL;
    new_json := to_jsonb(NEW);
  ELSE -- UPDATE
    record_uuid := NEW.id;
    old_json := to_jsonb(OLD);
    new_json := to_jsonb(NEW);
  END IF;

  -- Tenta di ottenere l'utente corrente da auth.uid()
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

-- Audit log su products
CREATE TRIGGER trg_products_audit
  AFTER INSERT OR UPDATE OR DELETE ON products
  FOR EACH ROW
  EXECUTE FUNCTION trigger_audit_log();

-- Audit log su brands
CREATE TRIGGER trg_brands_audit
  AFTER INSERT OR UPDATE OR DELETE ON brands
  FOR EACH ROW
  EXECUTE FUNCTION trigger_audit_log();

-- Audit log su users
CREATE TRIGGER trg_users_audit
  AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW
  EXECUTE FUNCTION trigger_audit_log();
