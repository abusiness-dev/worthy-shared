-- Worthy Score v2 - Backfill shadow score su tutti i prodotti esistenti.
--
-- Per ogni prodotto attivo, chiama calculate_worthy_score_v2 che popola:
--   score_origin, score_manufacturing, score_technical, score_sustainability,
--   score_confidence, score_breakdown
--
-- NON tocca worthy_score / score_composition / score_qpr / verdict (restano v1).
-- Durante F3 (dual-write) i due engine convivono. Il confronto v1 vs v2 si
-- fa interrogando score_breakdown.final.
--
-- Idempotente: ri-eseguire produce lo stesso risultato.
-- Sicuro: i prodotti senza dati v2 (origin/manufacturing/technical/sustainability)
-- ricevono uno score con confidence ridotta (es. 60%), coerente con la
-- graceful degradation dell'algoritmo.

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score_v2(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Worthy Score v2 backfill completato: % prodotti elaborati', n;
END $$;
