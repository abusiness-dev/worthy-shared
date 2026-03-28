-- Crea tabella daily_worthy. Dipende da: products

CREATE TABLE daily_worthy (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id     uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  featured_date  date NOT NULL,
  editorial_note text,
  position       integer NOT NULL DEFAULT 1,
  created_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT daily_worthy_unique_position UNIQUE (featured_date, position)
);

COMMENT ON TABLE daily_worthy IS 'Prodotti in evidenza giornalieri selezionati dalla redazione (fase 2)';
COMMENT ON COLUMN daily_worthy.featured_date IS 'Data in cui il prodotto è in evidenza';
COMMENT ON COLUMN daily_worthy.position IS 'Ordine di visualizzazione per la stessa data';
