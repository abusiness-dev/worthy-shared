-- Crea tabella brands. Dipende da: enum market_segment

CREATE TABLE brands (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL UNIQUE,
  logo_url    text,
  description text,
  origin_country text,
  market_segment market_segment NOT NULL,
  avg_worthy_score numeric(5,2) NOT NULL DEFAULT 0,
  product_count  integer NOT NULL DEFAULT 0,
  total_scans    integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE brands IS 'Brand di moda tracciati dalla piattaforma Worthy';
COMMENT ON COLUMN brands.slug IS 'Identificativo URL-safe univoco del brand';
COMMENT ON COLUMN brands.market_segment IS 'Segmento di mercato: ultra_fast, fast, premium_fast, mid_range';
COMMENT ON COLUMN brands.avg_worthy_score IS 'Media dei Worthy Score di tutti i prodotti del brand (calcolato)';
