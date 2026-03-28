-- Crea tabella products. Dipende da: brands, categories, users, enum verification_status, verdict

CREATE TABLE products (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ean_barcode           text,
  brand_id              uuid NOT NULL REFERENCES brands(id),
  category_id           uuid NOT NULL REFERENCES categories(id),
  name                  text NOT NULL,
  slug                  text NOT NULL UNIQUE,
  price                 numeric(8,2) NOT NULL,
  composition           jsonb NOT NULL,
  country_of_production text,
  care_instructions     text,
  photo_urls            text[] NOT NULL DEFAULT '{}',
  label_photo_url       text,
  worthy_score          numeric(5,2) NOT NULL DEFAULT 0,
  score_composition     numeric(5,2) NOT NULL DEFAULT 0,
  score_qpr             numeric(5,2) NOT NULL DEFAULT 0,
  score_fit             numeric(5,2),
  score_durability      numeric(5,2),
  verdict               verdict NOT NULL DEFAULT 'fair',
  community_score       numeric(5,2),
  community_votes_count integer NOT NULL DEFAULT 0,
  verification_status   verification_status NOT NULL DEFAULT 'unverified',
  scan_count            integer NOT NULL DEFAULT 0,
  contributed_by        uuid REFERENCES users(id) ON DELETE SET NULL,
  affiliate_url         text,
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT products_price_positive CHECK (price > 0),
  CONSTRAINT products_worthy_score_range CHECK (worthy_score >= 0 AND worthy_score <= 100),
  CONSTRAINT products_score_composition_range CHECK (score_composition >= 0 AND score_composition <= 100),
  CONSTRAINT products_score_qpr_range CHECK (score_qpr >= 0 AND score_qpr <= 100)
);

COMMENT ON TABLE products IS 'Prodotti di moda analizzati da Worthy con score e composizione';
COMMENT ON COLUMN products.ean_barcode IS 'Codice EAN-13 o UPC — può essere null per prodotti inseriti manualmente';
COMMENT ON COLUMN products.composition IS 'Array JSON di {fiber, percentage}, es. [{"fiber":"cotone","percentage":70}]';
COMMENT ON COLUMN products.worthy_score IS 'Score finale 0-100 calcolato dallo scoring engine';
COMMENT ON COLUMN products.score_composition IS 'Sub-score composizione materiali (0-100)';
COMMENT ON COLUMN products.score_qpr IS 'Sub-score rapporto qualità/prezzo (0-100)';
COMMENT ON COLUMN products.score_fit IS 'Sub-score vestibilità dalla community (0-100, null se nessun voto)';
COMMENT ON COLUMN products.score_durability IS 'Sub-score durabilità dalla community (0-100, null se nessun voto)';
COMMENT ON COLUMN products.verdict IS 'Verdetto derivato dal worthy_score: steal/worthy/fair/meh/not_worthy';
COMMENT ON COLUMN products.community_score IS 'Media voti community (null se nessun voto)';
COMMENT ON COLUMN products.contributed_by IS 'UUID dell utente che ha inserito il prodotto (null se importato)';
COMMENT ON COLUMN products.verification_status IS 'Stato verifica: unverified → verified → mattia_reviewed';
