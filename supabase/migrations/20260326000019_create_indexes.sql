-- Crea tutti gli indici per performance delle query principali

-- Barcode univoco (partial: solo se presente)
CREATE UNIQUE INDEX idx_products_ean_barcode
  ON products(ean_barcode)
  WHERE ean_barcode IS NOT NULL;

-- Prodotti per brand ordinati per score (solo attivi)
CREATE INDEX idx_products_brand_score
  ON products(brand_id, worthy_score DESC)
  WHERE is_active = true;

-- Prodotti per categoria ordinati per score (solo attivi)
CREATE INDEX idx_products_category_score
  ON products(category_id, worthy_score DESC)
  WHERE is_active = true;

-- Ricerca full-text fuzzy sul nome prodotto con trigrammi
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_products_name_trgm
  ON products USING gin(name gin_trgm_ops);

-- Scansioni per prodotto ordinate per data (usato per trending)
CREATE INDEX idx_scan_history_product_date
  ON scan_history(product_id, created_at DESC);

-- Audit log: lookup per tabella + record
CREATE INDEX idx_audit_log_table_record
  ON audit_log(table_name, record_id);

-- Audit log: ordinamento cronologico
CREATE INDEX idx_audit_log_created
  ON audit_log(created_at DESC);

-- Slug lookup rapido per prodotti
CREATE INDEX idx_products_slug
  ON products(slug);

-- Voti per prodotto (per calcolo media)
CREATE INDEX idx_product_votes_product
  ON product_votes(product_id);

-- Storico prezzi per prodotto
CREATE INDEX idx_price_history_product
  ON price_history(product_id, recorded_at DESC);

-- Report pendenti (per dashboard admin)
CREATE INDEX idx_product_reports_pending
  ON product_reports(status, created_at DESC)
  WHERE status = 'pending';

-- Duplicati pendenti
CREATE INDEX idx_product_duplicates_pending
  ON product_duplicates(status)
  WHERE status = 'pending';
