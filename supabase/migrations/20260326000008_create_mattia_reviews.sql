-- Crea tabella mattia_reviews (1:1 con products). Dipende da: products

CREATE TABLE mattia_reviews (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id          uuid NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  video_url           text NOT NULL,
  video_thumbnail_url text,
  score_adjustment    smallint NOT NULL DEFAULT 0,
  review_text         text,
  published_at        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT mattia_reviews_score_adjustment_range CHECK (score_adjustment >= -5 AND score_adjustment <= 5)
);

COMMENT ON TABLE mattia_reviews IS 'Video review di Mattia — relazione 1:1 con products';
COMMENT ON COLUMN mattia_reviews.score_adjustment IS 'Aggiustamento al Worthy Score: da -5 a +5';
COMMENT ON COLUMN mattia_reviews.product_id IS 'UNIQUE — ogni prodotto può avere al massimo una review di Mattia';
