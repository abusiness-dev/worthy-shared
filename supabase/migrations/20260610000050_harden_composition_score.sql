-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 6) — calculate_composition_score difensivo su composition
-- malformata.
--
-- PROBLEMA:
--   La versione corrente (20260412000006) fa jsonb_array_length(comp) (errore se non
--   array) e (value->>'percentage')::numeric senza guard: una percentage mancante →
--   NULL → weighted_sum/total_pct NULL → la funzione RITORNA NULL → worthy_score NULL.
--   I CHECK/trigger di Wave 1.4 bloccano le scritture CLIENT, ma service_role/scraper le
--   bypassano e potrebbe esistere dato storico → lo scoring deve restare robusto.
--
-- SOLUZIONE: guard sul tipo array + skip degli elementi con percentage non-numerica o
--   <= 0. Logica di punteggio fibre INVARIATA. Allineato a calculateComposition.ts.
--   CREATE OR REPLACE preserva l'ACL (REVOKE F8).
-- ════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION calculate_composition_score(comp jsonb)
RETURNS integer
LANGUAGE plpgsql IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  fiber_rec record;
  fiber_name text;
  fiber_pct numeric;
  fiber_score integer;
  weighted_sum numeric := 0;
  total_pct numeric := 0;
  is_elastane boolean;
BEGIN
  -- Guard: array non vuoto (un non-array farebbe fallire jsonb_array_length).
  IF comp IS NULL OR jsonb_typeof(comp) <> 'array' OR jsonb_array_length(comp) = 0 THEN
    RETURN 50;
  END IF;

  FOR fiber_rec IN SELECT * FROM jsonb_array_elements(comp)
  LOOP
    -- Skip difensivo: percentage non numerica o non positiva (composizione malformata).
    IF jsonb_typeof(fiber_rec.value -> 'percentage') <> 'number' THEN
      CONTINUE;
    END IF;
    fiber_pct := (fiber_rec.value ->> 'percentage')::numeric;
    IF fiber_pct IS NULL OR fiber_pct <= 0 THEN
      CONTINUE;
    END IF;

    fiber_name := lower(fiber_rec.value ->> 'fiber');
    is_elastane := fiber_name IN ('elastane', 'elastan', 'spandex');

    IF is_elastane THEN
      IF fiber_pct <= 5 THEN
        CONTINUE;
      ELSIF fiber_pct <= 10 THEN
        fiber_score := 40;
      ELSE
        fiber_score := 20;
      END IF;
    ELSE
      fiber_score := CASE
        WHEN fiber_name = 'cashmere' THEN 98
        WHEN fiber_name IN ('seta', 'silk') THEN 95
        WHEN fiber_name IN ('lana_merino', 'lana merino', 'merino wool', 'merino') THEN 92
        WHEN fiber_name IN ('cotone_supima', 'cotone supima', 'supima cotton') THEN 90
        WHEN fiber_name IN ('cotone_pima', 'cotone pima', 'pima cotton') THEN 90
        WHEN fiber_name IN ('cotone_egiziano', 'cotone egiziano', 'egyptian cotton') THEN 90
        WHEN fiber_name IN ('lino', 'linen') THEN 88
        WHEN fiber_name IN ('cotone_biologico', 'cotone biologico', 'organic cotton') THEN 85
        WHEN fiber_name IN ('lyocell', 'tencel') THEN 82
        WHEN fiber_name IN ('lana', 'wool') THEN 78
        WHEN fiber_name IN ('cotone', 'cotton') THEN 72
        WHEN fiber_name = 'modal' THEN 68
        WHEN fiber_name = 'cupro' THEN 65
        WHEN fiber_name IN ('viscosa', 'viscose', 'rayon') THEN 52
        WHEN fiber_name IN ('nylon', 'nailon', 'polyamide', 'poliammide') THEN 45
        WHEN fiber_name IN ('poliestere_riciclato', 'poliestere riciclato', 'recycled polyester') THEN 42
        WHEN fiber_name IN ('poliestere', 'polyester') THEN 25
        WHEN fiber_name IN ('acrilico', 'acrylic') THEN 15
        ELSE 50
      END;
    END IF;

    weighted_sum := weighted_sum + (fiber_score * fiber_pct);
    total_pct := total_pct + fiber_pct;
  END LOOP;

  IF total_pct = 0 THEN
    RETURN 50;
  END IF;

  RETURN LEAST(100, GREATEST(0, round(weighted_sum / total_pct)));
END;
$$;

COMMENT ON FUNCTION calculate_composition_score IS
  'Score composizione da array JSON di fibre. Difensivo su composition malformata (non-array, percentage non-numerica/<=0 → skip). Replica src/scoring/calculateComposition.ts.';
