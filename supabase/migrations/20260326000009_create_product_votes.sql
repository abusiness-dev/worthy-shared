-- Crea tabella product_votes con unique (product_id, user_id). Dipende da: products, users

CREATE TABLE product_votes (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id       uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score            smallint NOT NULL,
  fit_score        smallint,
  durability_score smallint,
  comment          text,
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_votes_unique_vote UNIQUE (product_id, user_id),
  CONSTRAINT product_votes_score_range CHECK (score >= 1 AND score <= 10),
  CONSTRAINT product_votes_fit_range CHECK (fit_score IS NULL OR (fit_score >= 1 AND fit_score <= 10)),
  CONSTRAINT product_votes_durability_range CHECK (durability_score IS NULL OR (durability_score >= 1 AND durability_score <= 10))
);

COMMENT ON TABLE product_votes IS 'Voti della community sui prodotti — un voto per utente per prodotto';
COMMENT ON COLUMN product_votes.score IS 'Voto generale 1-10';
COMMENT ON COLUMN product_votes.fit_score IS 'Voto vestibilità 1-10 (opzionale)';
COMMENT ON COLUMN product_votes.durability_score IS 'Voto durabilità 1-10 (opzionale)';
