-- Supporto N EAN per 1 prodotto (varianti colore Lacoste con EAN distinti).
-- ean_barcode resta primary/UNIQUE; gli EAN secondari finiscono qui.
-- Lookup pattern:
--   SELECT * FROM products
--   WHERE ean_barcode = $1 OR $1 = ANY(additional_eans);

ALTER TABLE products
  ADD COLUMN additional_eans text[] NOT NULL DEFAULT '{}';

CREATE INDEX idx_products_additional_eans
  ON products USING gin(additional_eans);

COMMENT ON COLUMN products.additional_eans IS
  'EAN aggiuntivi per varianti (es. colori) dello stesso modello. Lookup: ean_barcode = $1 OR $1 = ANY(additional_eans).';
