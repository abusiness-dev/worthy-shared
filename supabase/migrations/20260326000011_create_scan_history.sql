-- Crea tabella scan_history. Dipende da: products, users, enum scan_type

CREATE TABLE scan_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id  uuid REFERENCES products(id) ON DELETE SET NULL,
  barcode     text NOT NULL,
  scan_type   scan_type NOT NULL,
  found       boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE scan_history IS 'Cronologia scansioni utente — traccia ogni scan anche se il prodotto non esiste';
COMMENT ON COLUMN scan_history.product_id IS 'Null se il prodotto non è stato trovato nel database';
COMMENT ON COLUMN scan_history.found IS 'true se il barcode ha trovato un prodotto esistente';
