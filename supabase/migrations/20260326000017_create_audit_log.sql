-- Crea tabella audit_log (append-only). Dipende da: users, enum audit_action

CREATE TABLE audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name  text NOT NULL,
  record_id   uuid NOT NULL,
  action      audit_action NOT NULL,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  old_data    jsonb,
  new_data    jsonb,
  ip_address  inet,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE audit_log IS 'Log append-only di tutte le modifiche ai dati — non eliminare righe';
COMMENT ON COLUMN audit_log.table_name IS 'Nome della tabella modificata';
COMMENT ON COLUMN audit_log.record_id IS 'UUID del record modificato';
COMMENT ON COLUMN audit_log.old_data IS 'Stato precedente del record (null per insert)';
COMMENT ON COLUMN audit_log.new_data IS 'Nuovo stato del record (null per delete)';
