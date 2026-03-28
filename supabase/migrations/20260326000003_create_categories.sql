-- Crea tabella categories. Nessuna dipendenza

CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL UNIQUE,
  icon        text NOT NULL,
  avg_price   numeric(8,2) NOT NULL DEFAULT 0,
  avg_composition_score numeric(5,2) NOT NULL DEFAULT 0,
  product_count integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE categories IS 'Categorie prodotto (T-Shirt, Jeans, ecc.)';
COMMENT ON COLUMN categories.icon IS 'Emoji usata come icona nella UI';
COMMENT ON COLUMN categories.avg_price IS 'Prezzo medio dei prodotti in questa categoria (calcolato)';
COMMENT ON COLUMN categories.avg_composition_score IS 'Score composizione medio della categoria (usato per calcolo QPR)';
