-- Crea tabella product_reports. Dipende da: products, users, enum report_reason, report_status

CREATE TABLE product_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      report_reason NOT NULL,
  description text,
  status      report_status NOT NULL DEFAULT 'pending',
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE product_reports IS 'Segnalazioni utenti su dati errati dei prodotti';
COMMENT ON COLUMN product_reports.reason IS 'Motivo: wrong_composition, wrong_price, wrong_brand, duplicate, other';
COMMENT ON COLUMN product_reports.status IS 'Stato moderazione: pending → confirmed/rejected';
