-- Worthy Score v2 - Rimozione lente Sustainability (4 lenti → 3 lenti).
--
-- In questa fase non vogliamo che la lente sustainability (5%) entri più nel
-- Worthy Score. Il 5% liberato va interamente alla lente qpr.
--
-- Pesi NUOVI (somma 1.00):
--   composition    50%   invariato
--   manufacturing  25%   invariato
--   qpr            25%   (era 20%)  +5pp
--
-- Cosa resta in piedi e perché:
--   - Tabelle certifications, product_certifications, brand_certifications:
--     usate da UI brand-transparency e dallo scraper, fuori dallo scoring.
--   - Colonna products.score_sustainability: resta in schema, azzerata a NULL.
--   - Bonus made_in_italy_100 (+8 a manufacturing): resta. Il trigger
--     trg_pc_recalc_v2 su product_certifications viene MANTENUTO perché
--     inserimenti/cancellazioni di made_in_italy_100 devono ancora ricalcolare
--     il breakdown via la lente manufacturing.
--
-- Cleanup SQL:
--   - DROP FUNCTION calculate_sustainability_lens
--   - UPDATE products SET score_sustainability = NULL
--   - Backfill di tutti i prodotti attivi con la nuova formula 3 lenti

-- ============================================================
-- 1. Riscrivi calculate_worthy_score_v2 per 3 lenti
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score_v2(p_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  comp_score      integer;
  manuf_score     numeric;
  qpr_score       integer;

  weighted_sum    numeric := 0;
  total_weight    numeric := 0;
  raw_score       numeric;
  final_score     integer;
  final_verdict   verdict;
  confidence      numeric;

  weights_full constant numeric := 0.50 + 0.25 + 0.25;
  weights_used numeric := 0;

  breakdown jsonb;
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  -- 1. Lenti raw
  SELECT calculate_composition_score(composition) INTO comp_score
  FROM products WHERE id = p_product_id;

  manuf_score := calculate_manufacturing_lens(p_product_id);

  -- 2. QPR inline (usa composition direttamente)
  DECLARE
    cat_avg_score numeric;
    cat_avg_price numeric;
    prod_price    numeric;
    raw_qpr       numeric;
  BEGIN
    SELECT c.avg_composition_score, c.avg_price, p.price
    INTO cat_avg_score, cat_avg_price, prod_price
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.id = p_product_id;

    IF prod_price > 0 AND cat_avg_price > 0 AND cat_avg_score > 0 THEN
      raw_qpr := (comp_score / prod_price) / (cat_avg_score / cat_avg_price) * 100;
      qpr_score := LEAST(100, GREATEST(0, round(
        100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
      )))::integer;
    ELSE
      qpr_score := 50;
    END IF;
  END;

  -- 3. Aggregazione pesata (rinormalizzazione delle componenti null)

  -- composition: peso 50%, sempre presente
  weighted_sum := weighted_sum + comp_score * 0.50;
  total_weight := total_weight + 0.50;
  weights_used := weights_used + 0.50;

  IF manuf_score IS NOT NULL THEN
    weighted_sum := weighted_sum + manuf_score * 0.25;
    total_weight := total_weight + 0.25;
    weights_used := weights_used + 0.25;
  END IF;

  -- qpr: peso 25%, sempre presente
  weighted_sum := weighted_sum + qpr_score * 0.25;
  total_weight := total_weight + 0.25;
  weights_used := weights_used + 0.25;

  raw_score := weighted_sum / total_weight;
  final_score := LEAST(100, GREATEST(0, round(raw_score)::integer));

  final_verdict := CASE
    WHEN final_score >= 86 THEN 'steal'::verdict
    WHEN final_score >= 71 THEN 'worthy'::verdict
    WHEN final_score >= 51 THEN 'fair'::verdict
    WHEN final_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  confidence := round((weights_used / weights_full) * 100);

  breakdown := jsonb_build_object(
    'version', 'v2.0',
    'lenses', jsonb_build_object(
      'composition',   jsonb_build_object('score', comp_score,  'used', comp_score  IS NOT NULL),
      'manufacturing', jsonb_build_object('score', manuf_score, 'used', manuf_score IS NOT NULL),
      'qpr',           jsonb_build_object('score', qpr_score,   'used', qpr_score   IS NOT NULL)
    ),
    'weights', jsonb_build_object(
      'composition',   0.50,
      'manufacturing', 0.25,
      'qpr',           0.25
    ),
    'confidence',        confidence,
    'raw',               round(raw_score, 2),
    'final',             final_score,
    'verdict',           final_verdict
  );

  UPDATE products
  SET
    score_manufacturing  = manuf_score,
    score_sustainability = NULL,
    score_confidence     = confidence,
    score_breakdown      = breakdown
  WHERE id = p_product_id;

  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN breakdown;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score_v2 IS
  'Worthy Score v2 - 3 lenti (composition 50%, manufacturing 25%, qpr 25%) con graceful degradation. Persiste breakdown e sub-score in products. score_sustainability resta in schema ma sempre NULL (lente rimossa).';

-- ============================================================
-- 2. Drop funzione lente non più usata
-- ============================================================

DROP FUNCTION IF EXISTS calculate_sustainability_lens(uuid);

-- NOTA: il trigger trg_pc_recalc_v2 su product_certifications viene MANTENUTO.
-- Anche se le certificazioni non muovono più la lente sustainability (che è
-- stata rimossa), il bonus made_in_italy_100 continua a influenzare la lente
-- manufacturing (+8 punti), quindi inserimenti/cancellazioni di certificazioni
-- product-level devono ancora triggerare il ricalcolo del breakdown.

-- ============================================================
-- 3. Cleanup colonna score_sustainability (resta in schema, sempre NULL)
--    L'UPDATE deve bypassare il BEFORE trigger protect_product_privileged_fields
--    che blocca le scritture su score_sustainability fuori da service_role.
-- ============================================================

DO $$
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  UPDATE products
  SET score_sustainability = NULL
  WHERE score_sustainability IS NOT NULL;

  PERFORM set_config('worthy.skip_protection', 'false', true);
END $$;

-- ============================================================
-- 4. Backfill: ricalcolo di tutti i prodotti attivi con la nuova formula
--    calculate_worthy_score è wrapper su v2 (vedi 20260427000015), quindi
--    aggiorna sia worthy_score (canonico) sia il breakdown.
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Worthy Score 3-lens recalculation: % prodotti aggiornati', n;
END $$;

-- Aggiorna le medie aggregate sui brand
SELECT recalculate_brand_avg_scores();
