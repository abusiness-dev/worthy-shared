-- Crea tabella product_duplicates. Dipende da: products, users, enum duplicate_status

CREATE TABLE product_duplicates (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id       uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  duplicate_of     uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  similarity_score numeric(5,4) NOT NULL,
  status           duplicate_status NOT NULL DEFAULT 'pending',
  resolved_by      uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  resolved_at      timestamptz,

  CONSTRAINT product_duplicates_different CHECK (product_id <> duplicate_of),
  CONSTRAINT product_duplicates_similarity_range CHECK (similarity_score >= 0 AND similarity_score <= 1)
);

COMMENT ON TABLE product_duplicates IS 'Coppie di prodotti potenzialmente duplicati da risolvere';
COMMENT ON COLUMN product_duplicates.similarity_score IS 'Score di similarità 0.0000-1.0000';
COMMENT ON COLUMN product_duplicates.resolved_by IS 'Moderatore che ha risolto il duplicato';
