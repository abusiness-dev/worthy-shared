-- Worthy Score v2 - Tabelle di giunzione product/brand → origini, tecnologie, certificazioni.
--
-- Tutte le relazioni N:M con cascade delete sul lato product/brand. Cancellare
-- una origine/tecnologia/certificazione (lato lookup) non è cascade ma
-- ON DELETE RESTRICT: vogliamo proteggerci da cancellazioni accidentali della
-- lookup table.
--
-- product_fiber_origins ha (product_id, fiber_id) come PK perché ogni fibra
-- del prodotto può avere al massimo UNA origine. fiber_id è ridondante (è già
-- in fiber_origins via FK) ma serve a vincolare l'unicità per fibra senza
-- joinare la lookup ad ogni insert.

-- ============================================================
-- product_fiber_origins
-- ============================================================

CREATE TABLE product_fiber_origins (
  product_id      uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  fiber_id        text NOT NULL,
  fiber_origin_id text NOT NULL REFERENCES fiber_origins(id) ON DELETE RESTRICT,
  PRIMARY KEY (product_id, fiber_id)
);

CREATE INDEX idx_product_fiber_origins_origin ON product_fiber_origins(fiber_origin_id);

COMMENT ON TABLE product_fiber_origins IS 'Origine specifica per ogni fibra del prodotto. Una sola origine per fibra (PK product_id+fiber_id).';

-- ============================================================
-- product_technologies
-- ============================================================

CREATE TABLE product_technologies (
  product_id    uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  technology_id text NOT NULL REFERENCES fabric_technologies(id) ON DELETE RESTRICT,
  PRIMARY KEY (product_id, technology_id)
);

CREATE INDEX idx_product_technologies_tech ON product_technologies(technology_id);

COMMENT ON TABLE product_technologies IS 'Tecnologie tessili associate al prodotto (Polartec, GORE-TEX, Stone Island Lab, ...). Alimenta technical_lens.';

-- ============================================================
-- product_certifications
-- ============================================================

CREATE TABLE product_certifications (
  product_id       uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  certification_id text NOT NULL REFERENCES certifications(id) ON DELETE RESTRICT,
  PRIMARY KEY (product_id, certification_id)
);

CREATE INDEX idx_product_certifications_cert ON product_certifications(certification_id);

COMMENT ON TABLE product_certifications IS 'Certificazioni a livello di SINGOLO prodotto (OEKO-TEX, Made in Italy 100%, GOTS sul capo, ...).';

-- ============================================================
-- brand_certifications
-- ============================================================

CREATE TABLE brand_certifications (
  brand_id         uuid NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  certification_id text NOT NULL REFERENCES certifications(id) ON DELETE RESTRICT,
  PRIMARY KEY (brand_id, certification_id)
);

CREATE INDEX idx_brand_certifications_cert ON brand_certifications(certification_id);

COMMENT ON TABLE brand_certifications IS 'Certificazioni registry-level del brand (B Corp, 1% for the Planet, Bluesign Partner, ...). Si propagano a tutti i prodotti del brand nel sustainability_lens.';
