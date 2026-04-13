-- Allinea le funzioni SQL di scoring al nuovo scoring engine TypeScript:
--   - Nuova tabella fibre (cotone 72, modal 68, lyocell/tencel 82, poliestere 25, ecc.)
--   - Aggiunte: lana 78, cupro 65
--   - Regola elastane a 3 soglie: ≤5% ignorato, 6-10% score 40, >10% score 20
--   - Formula finale: comp*0.7 + qpr*0.3 + mattia, senza fit/durability
--   - score_fit e score_durability vengono settati a NULL sui nuovi calcoli
-- Le colonne DB score_fit e score_durability restano in tabella per compatibilità.

-- ============================================================
-- calculate_composition_score(jsonb) → integer
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_composition_score(comp jsonb)
RETURNS integer
LANGUAGE plpgsql IMMUTABLE
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
  IF comp IS NULL OR jsonb_array_length(comp) = 0 THEN
    RETURN 50;
  END IF;

  FOR fiber_rec IN SELECT * FROM jsonb_array_elements(comp)
  LOOP
    fiber_name := lower(fiber_rec.value ->> 'fiber');
    fiber_pct  := (fiber_rec.value ->> 'percentage')::numeric;

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

COMMENT ON FUNCTION calculate_composition_score IS 'Calcola score composizione da array JSON di fibre. Replica logica TypeScript (scoring engine v2).';

-- ============================================================
-- calculate_worthy_score(uuid) → integer
-- Nuova formula: comp*0.7 + qpr*0.3 + mattia. score_fit/durability settati a NULL.
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  comp_score integer;
  qpr_score integer;
  mattia_adj integer;
  raw_score numeric;
  final_score integer;
  final_verdict verdict;
BEGIN
  -- Calcola score composizione dal JSON
  SELECT calculate_composition_score(p.composition)
  INTO comp_score
  FROM products p
  WHERE p.id = p_product_id;

  -- Aggiorna score_composition prima del calcolo QPR (calculate_qpr lo legge)
  UPDATE products SET score_composition = comp_score WHERE id = p_product_id;

  -- Calcola QPR (formula invariata)
  qpr_score := calculate_qpr(p_product_id);

  -- Recupera mattia adjustment se presente
  SELECT COALESCE(mr.score_adjustment, 0)
  INTO mattia_adj
  FROM products p
  LEFT JOIN mattia_reviews mr ON mr.product_id = p.id
  WHERE p.id = p_product_id;

  IF mattia_adj IS NULL THEN
    mattia_adj := 0;
  END IF;

  -- Formula nuova: comp*0.7 + qpr*0.3 + mattia
  raw_score := comp_score * 0.7 + qpr_score * 0.3 + mattia_adj;
  final_score := LEAST(100, GREATEST(0, round(raw_score)));

  final_verdict := CASE
    WHEN final_score >= 86 THEN 'steal'::verdict
    WHEN final_score >= 71 THEN 'worthy'::verdict
    WHEN final_score >= 51 THEN 'fair'::verdict
    WHEN final_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  UPDATE products
  SET
    score_composition = comp_score,
    score_qpr = qpr_score,
    score_fit = NULL,
    score_durability = NULL,
    worthy_score = final_score,
    verdict = final_verdict
  WHERE id = p_product_id;

  RETURN final_score;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score IS 'Calcola worthy_score e verdict con formula 70/30 (composition/qpr) + Mattia. score_fit e score_durability sempre NULL.';

-- ============================================================
-- recalculate_brand_avg_scores() → void
-- Aggiorna brands.avg_worthy_score e brands.product_count come media dei worthy_score
-- dei prodotti attivi del brand. Brand senza prodotti → 0.
-- ============================================================

CREATE OR REPLACE FUNCTION recalculate_brand_avg_scores()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE brands b
  SET
    avg_worthy_score = COALESCE(stats.avg_score, 0),
    product_count    = COALESCE(stats.cnt, 0)
  FROM (
    SELECT brand_id,
           AVG(worthy_score)::numeric(5,2) AS avg_score,
           COUNT(*)                        AS cnt
    FROM products
    WHERE is_active = true
    GROUP BY brand_id
  ) stats
  WHERE b.id = stats.brand_id;

  -- Azzera brand che non hanno più prodotti attivi
  UPDATE brands
  SET avg_worthy_score = 0, product_count = 0
  WHERE id NOT IN (SELECT DISTINCT brand_id FROM products WHERE is_active = true);
END;
$$;

COMMENT ON FUNCTION recalculate_brand_avg_scores IS 'Ricalcola avg_worthy_score e product_count per tutti i brand basandosi sui prodotti attivi.';

-- ============================================================
-- Ricalcolo massivo di tutti i prodotti esistenti
-- Non possiamo affidarci a UPDATE products SET updated_at = now() perché il
-- trigger di scoring reagisce solo a cambi di composition/price/category_id,
-- quindi chiamiamo la funzione direttamente per ogni prodotto attivo.
-- ============================================================

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM products LOOP
    PERFORM calculate_worthy_score(r.id);
  END LOOP;
END $$;

-- Propaga le medie sui brand
SELECT recalculate_brand_avg_scores();
