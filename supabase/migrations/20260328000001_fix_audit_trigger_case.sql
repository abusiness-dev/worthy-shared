-- Fix: TG_OP restituisce 'INSERT'/'UPDATE'/'DELETE' in maiuscolo,
-- ma l'enum audit_action usa valori minuscoli

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
