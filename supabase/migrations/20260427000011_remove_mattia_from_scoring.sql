-- Worthy Score - Rimozione completa di Mattia adjustment dalla formula.
--
-- mattia_reviews.score_adjustment NON viene più letto né dal calcolo v1 né v2.
-- La colonna e la tabella restano per compatibilità (le review video con
-- video_url sono contenuto utile, indipendente dallo score). Il trigger
-- protect_product_privileged_fields continua a proteggere worthy_score.
--
-- Le funzioni calculate_worthy_score (v1) e calculate_worthy_score_v2 vengono
-- riscritte senza il parametro mattia_adj, e tutti i prodotti attivi vengono
-- ricalcolati per allineare lo storico al nuovo algoritmo.

-- ============================================================
-- v1: calculate_worthy_score senza Mattia
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  comp_score integer;
  qpr_score integer;
  raw_score numeric;
  final_score integer;
  final_verdict verdict;
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  SELECT calculate_composition_score(p.composition)
  INTO comp_score
  FROM products p
  WHERE p.id = p_product_id;

  UPDATE products SET score_composition = comp_score WHERE id = p_product_id;
  qpr_score := calculate_qpr(p_product_id);

  -- Formula: comp*0.7 + qpr*0.3 (Mattia rimosso)
  raw_score := comp_score * 0.7 + qpr_score * 0.3;
  final_score := LEAST(100, GREATEST(0, round(raw_score)::integer));

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

  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN final_score;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score IS
  'Calcola worthy_score con formula 70/30 (composition/qpr). Mattia adjustment rimosso dal calcolo. SECURITY DEFINER per RLS bypass.';

-- ============================================================
-- v2: calculate_worthy_score_v2 senza Mattia
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score_v2(p_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  comp_score      integer;
  tech_score      numeric;
  origin_score    numeric;
  manuf_score     numeric;
  qpr_score       integer;
  susta_score     numeric;

  material_quality numeric;

  weighted_sum    numeric := 0;
  total_weight    numeric := 0;
  raw_score       numeric;
  final_score     integer;
  final_verdict   verdict;
  confidence      numeric;

  weights_full constant numeric := 0.50 + 0.20 + 0.15 + 0.10 + 0.05;
  weights_used numeric := 0;

  breakdown jsonb;
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  -- 1. Lenti raw (esposte nel breakdown per spiegabilità)
  SELECT calculate_composition_score(composition) INTO comp_score
  FROM products WHERE id = p_product_id;

  tech_score   := calculate_technical_lens(p_product_id);
  origin_score := calculate_origin_lens(p_product_id);
  manuf_score  := calculate_manufacturing_lens(p_product_id);
  susta_score  := calculate_sustainability_lens(p_product_id);

  -- 2. material_quality: fusione composition + technical via max()
  IF tech_score IS NOT NULL THEN
    material_quality := GREATEST(comp_score, tech_score);
  ELSE
    material_quality := comp_score;
  END IF;

  -- 3. QPR inline usando material_quality come perceived quality
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
      raw_qpr := (material_quality / prod_price) / (cat_avg_score / cat_avg_price) * 100;
      qpr_score := LEAST(100, GREATEST(0, round(
        100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
      )))::integer;
    ELSE
      qpr_score := 50;
    END IF;
  END;

  -- 4. Aggregazione pesata (rinormalizzazione delle componenti null)
  weighted_sum := weighted_sum + material_quality * 0.50;
  total_weight := total_weight + 0.50;
  weights_used := weights_used + 0.50;

  IF origin_score IS NOT NULL THEN
    weighted_sum := weighted_sum + origin_score * 0.20;
    total_weight := total_weight + 0.20;
    weights_used := weights_used + 0.20;
  END IF;

  IF manuf_score IS NOT NULL THEN
    weighted_sum := weighted_sum + manuf_score * 0.15;
    total_weight := total_weight + 0.15;
    weights_used := weights_used + 0.15;
  END IF;

  IF qpr_score IS NOT NULL THEN
    weighted_sum := weighted_sum + qpr_score * 0.10;
    total_weight := total_weight + 0.10;
    weights_used := weights_used + 0.10;
  END IF;

  IF susta_score IS NOT NULL THEN
    weighted_sum := weighted_sum + susta_score * 0.05;
    total_weight := total_weight + 0.05;
    weights_used := weights_used + 0.05;
  END IF;

  -- Mattia rimosso: niente +mattia_adj
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
      'composition',    jsonb_build_object('score', comp_score,   'used', comp_score   IS NOT NULL),
      'technical',      jsonb_build_object('score', tech_score,   'used', tech_score   IS NOT NULL),
      'origin',         jsonb_build_object('score', origin_score, 'used', origin_score IS NOT NULL),
      'manufacturing',  jsonb_build_object('score', manuf_score,  'used', manuf_score  IS NOT NULL),
      'qpr',            jsonb_build_object('score', qpr_score,    'used', qpr_score    IS NOT NULL),
      'sustainability', jsonb_build_object('score', susta_score,  'used', susta_score  IS NOT NULL)
    ),
    'material_quality', jsonb_build_object(
      'score', round(material_quality, 2),
      'weight', 0.50,
      'used', true
    ),
    'weights', jsonb_build_object(
      'material',       0.50,
      'origin',         0.20,
      'manufacturing',  0.15,
      'qpr',            0.10,
      'sustainability', 0.05
    ),
    'confidence',        confidence,
    'raw',               round(raw_score, 2),
    'final',             final_score,
    'verdict',           final_verdict
  );

  UPDATE products
  SET
    score_origin         = origin_score,
    score_manufacturing  = manuf_score,
    score_technical      = tech_score,
    score_sustainability = susta_score,
    score_confidence     = confidence,
    score_breakdown      = breakdown
  WHERE id = p_product_id;

  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN breakdown;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score_v2 IS
  'Worthy Score v2 - orchestratore multi-lente. Mattia adjustment rimosso. material_quality=max(composition,technical). Persistenza shadow su score_breakdown durante F3.';

-- ============================================================
-- Ricalcolo massivo: tutti i prodotti attivi vengono allineati al nuovo
-- algoritmo (v1 senza Mattia + v2 senza Mattia in shadow).
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    PERFORM calculate_worthy_score_v2(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Ricalcolo post-rimozione Mattia: % prodotti aggiornati', n;
END $$;

-- Aggiorna le medie aggregate sui brand (worthy_score può essere cambiato)
SELECT recalculate_brand_avg_scores();
