-- Crea tabella saved_products con unique (user_id, product_id). Dipende da: products, users

CREATE TABLE saved_products (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT saved_products_unique UNIQUE (user_id, product_id)
);

COMMENT ON TABLE saved_products IS 'Prodotti salvati/preferiti dagli utenti';
