-- Crea tabella price_history. Dipende da: products

CREATE TABLE price_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  price       numeric(8,2) NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  source      price_source NOT NULL DEFAULT 'user'
);

COMMENT ON TABLE price_history IS 'Storico prezzi per ogni prodotto, traccia variazioni nel tempo';
COMMENT ON COLUMN price_history.source IS 'Origine del dato prezzo: user, scraper, affiliate_feed';
