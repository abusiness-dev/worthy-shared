-- Crea tabella saved_comparisons. Dipende da: users

CREATE TABLE saved_comparisons (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_ids uuid[] NOT NULL,
  title       text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE saved_comparisons IS 'Confronti tra prodotti salvati dagli utenti';
COMMENT ON COLUMN saved_comparisons.product_ids IS 'Array di UUID dei prodotti confrontati';
