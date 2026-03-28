-- Crea tabella badges. Nessuna dipendenza

CREATE TABLE badges (
  id              text PRIMARY KEY,
  name            text NOT NULL,
  description     text NOT NULL,
  icon            text NOT NULL,
  points_required integer NOT NULL DEFAULT 0,
  benefit         text NOT NULL
);

COMMENT ON TABLE badges IS 'Definizione dei badge gamification sbloccabili dagli utenti';
COMMENT ON COLUMN badges.id IS 'Chiave stringa leggibile (es. fashion_scout, style_expert)';
COMMENT ON COLUMN badges.points_required IS 'Punti necessari per sbloccare il badge (0 = assegnato manualmente)';
