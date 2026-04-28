-- Worthy Score v2 - Engine PL/pgSQL.
--
-- Implementa la formula multi-lente con fusione material_quality e
-- graceful degradation:
--
--   material_quality = (technical IS NOT NULL)
--                    ? GREATEST(composition, technical)
--                    : composition
--
--   raw = Σ (component_score × component_weight) PER componenti con dati
--       / Σ (component_weight)                   PER componenti con dati
--   worthy_score_v2 = round(clamp(0, 100, raw + mattia_adjustment))
--
-- Pesi (somma 100%):
--   material        50%  - max(composition, technical) - sempre presente
--   origin          20%  - presente se almeno una fibra ha product_fiber_origins
--   manufacturing   15%  - presente se almeno uno tra country_of_production_iso2,
--                          weaving_iso2, spinning_iso2, dyeing_iso2 è valorizzato
--   qpr             10%  - sempre presente (default 50 in edge case)
--   sustainability  5%   - presente solo se product/brand_certifications
--
-- Razionale fusione composition+technical: testando scenari reali si è
-- verificato che separare le due lenti con peso 40/10 lascia Stone Island
-- 100% PET in fascia "fair" (~50) invece che "worthy" (~80). La fusione via
-- max() con peso 50% riconosce correttamente il valore della lavorazione
-- proprietaria anche quando la fibra di base ha score basso (es. poliestere).
-- Un capo fast fashion 100% PET senza tecnologia esplicita riceve technical=30
-- (commodity) o 60 (heuristic prezzo elevato), quindi max() è sempre definito.
--
-- Le 6 lenti restano esposte separatamente in score_breakdown per il pannello
-- "perché questo score?" UX. La fusione avviene solo nel calcolo del totale.

-- ============================================================
-- Origin lens (peso 20%)
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_origin_lens(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  weighted_sum numeric := 0;
  total_pct    numeric := 0;
  fiber_rec    record;
  fiber_name   text;
  fiber_pct    numeric;
  origin_score smallint;
BEGIN
  FOR fiber_rec IN
    SELECT value FROM products p, jsonb_array_elements(p.composition) value
    WHERE p.id = p_product_id
  LOOP
    fiber_name := lower(fiber_rec.value ->> 'fiber');
    fiber_pct  := (fiber_rec.value ->> 'percentage')::numeric;

    -- Skip elastane sotto 5% (coerenza con composition_lens)
    IF fiber_name IN ('elastane','elastan','spandex') AND fiber_pct <= 5 THEN
      CONTINUE;
    END IF;

    -- Lookup origine specifica per (product, fiber)
    SELECT fo.origin_score INTO origin_score
    FROM product_fiber_origins pfo
    JOIN fiber_origins fo ON fo.id = pfo.fiber_origin_id
    WHERE pfo.product_id = p_product_id AND pfo.fiber_id = fiber_name;

    IF origin_score IS NOT NULL THEN
      weighted_sum := weighted_sum + (origin_score * fiber_pct);
      total_pct    := total_pct + fiber_pct;
    END IF;
  END LOOP;

  IF total_pct = 0 THEN
    RETURN NULL;  -- Nessuna fibra ha origine: lente esclusa dalla rinormalizzazione
  END IF;

  RETURN LEAST(100, GREATEST(0, weighted_sum / total_pct));
END;
$$;

COMMENT ON FUNCTION calculate_origin_lens IS 'Lente Origin (peso 20%): media pesata degli origin_score sulle fibre con product_fiber_origins. NULL se nessuna fibra ha origine (graceful degradation).';

-- ============================================================
-- Manufacturing lens (peso 15%)
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_manufacturing_lens(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  prod              record;
  weighted_sum      numeric := 0;
  total_weight      numeric := 0;
  step_score        smallint;
  step_weight       numeric;
  has_made_in_italy boolean;
  result            numeric;
BEGIN
  SELECT
    country_of_production_iso2,
    weaving_iso2,
    spinning_iso2,
    dyeing_iso2
  INTO prod
  FROM products
  WHERE id = p_product_id;

  -- Country of production (last substantial transformation): peso 0.50
  IF prod.country_of_production_iso2 IS NOT NULL THEN
    SELECT manufacturing_score INTO step_score FROM countries WHERE iso2 = prod.country_of_production_iso2;
    IF step_score IS NOT NULL THEN
      weighted_sum := weighted_sum + step_score * 0.50;
      total_weight := total_weight + 0.50;
    END IF;
  END IF;

  -- Weaving: peso 0.25
  IF prod.weaving_iso2 IS NOT NULL THEN
    SELECT manufacturing_score INTO step_score FROM countries WHERE iso2 = prod.weaving_iso2;
    IF step_score IS NOT NULL THEN
      weighted_sum := weighted_sum + step_score * 0.25;
      total_weight := total_weight + 0.25;
    END IF;
  END IF;

  -- Spinning: peso 0.15
  IF prod.spinning_iso2 IS NOT NULL THEN
    SELECT manufacturing_score INTO step_score FROM countries WHERE iso2 = prod.spinning_iso2;
    IF step_score IS NOT NULL THEN
      weighted_sum := weighted_sum + step_score * 0.15;
      total_weight := total_weight + 0.15;
    END IF;
  END IF;

  -- Dyeing: peso 0.10
  IF prod.dyeing_iso2 IS NOT NULL THEN
    SELECT manufacturing_score INTO step_score FROM countries WHERE iso2 = prod.dyeing_iso2;
    IF step_score IS NOT NULL THEN
      weighted_sum := weighted_sum + step_score * 0.10;
      total_weight := total_weight + 0.10;
    END IF;
  END IF;

  IF total_weight = 0 THEN
    RETURN NULL;  -- Nessun dato manifattura
  END IF;

  result := weighted_sum / total_weight;

  -- Bonus +8 per certificazione "100% Made in Italy"
  SELECT EXISTS (
    SELECT 1 FROM product_certifications
    WHERE product_id = p_product_id AND certification_id = 'made_in_italy_100'
  ) INTO has_made_in_italy;

  IF has_made_in_italy THEN
    result := result + 8;
  END IF;

  RETURN LEAST(100, GREATEST(0, result));
END;
$$;

COMMENT ON FUNCTION calculate_manufacturing_lens IS 'Lente Manufacturing (peso 15%): media pesata sui 4 step di filiera (country 0.50, weaving 0.25, spinning 0.15, dyeing 0.10). +8 se Made in Italy 100%. NULL se tutti gli step sono NULL.';

-- ============================================================
-- Technical lens (peso 10%)
-- ============================================================
--
-- Logica:
--   1. Se il prodotto ha N tecnologie: score = max(technology_score)
--   2. Altrimenti, heuristic per capi 100% sintetici (PET o nylon vergine):
--      - prezzo > 3× categoria avg → 60 (probabilmente tecnico non taggato)
--      - altrimenti                → 30 (commodity)
--   3. Altrimenti (capo naturale senza tecnologie esplicite): NULL (lente non rilevante).

CREATE OR REPLACE FUNCTION calculate_technical_lens(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  max_tech_score smallint;
  prod           record;
  cat_avg_price  numeric;
  is_synthetic   boolean;
  synthetic_pct  numeric;
BEGIN
  -- 1. Se ha tecnologie esplicite: max
  SELECT MAX(ft.technology_score) INTO max_tech_score
  FROM product_technologies pt
  JOIN fabric_technologies ft ON ft.id = pt.technology_id
  WHERE pt.product_id = p_product_id;

  IF max_tech_score IS NOT NULL THEN
    RETURN max_tech_score;
  END IF;

  -- 2. Heuristic per 100% sintetico
  SELECT p.price, c.avg_price
  INTO prod
  FROM products p
  JOIN categories c ON c.id = p.category_id
  WHERE p.id = p_product_id;

  -- Calcolo percentuale sintetica (poliestere + nylon + acrilico)
  SELECT COALESCE(SUM((value ->> 'percentage')::numeric), 0)
  INTO synthetic_pct
  FROM products p, jsonb_array_elements(p.composition) value
  WHERE p.id = p_product_id
    AND lower(value ->> 'fiber') IN ('polyester','poliestere','nylon','poliammide','polyamide','nailon','acrylic','acrilico');

  is_synthetic := synthetic_pct >= 95;  -- soglia "praticamente 100% sintetico"

  IF is_synthetic THEN
    cat_avg_price := COALESCE(prod.avg_price, 0);
    IF cat_avg_price > 0 AND prod.price > cat_avg_price * 3 THEN
      RETURN 60;  -- probabilmente tecnico non ancora taggato
    ELSE
      RETURN 30;  -- commodity sintetico
    END IF;
  END IF;

  -- 3. Capo naturale senza tecnologie esplicite: lente non rilevante
  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION calculate_technical_lens IS 'Lente Technical (peso 10%): max degli score tecnologie esplicite; in assenza, heuristic 60/30 per capi 100% sintetici basata sul rapporto prezzo/categoria; NULL per capi naturali senza tecnologie.';

-- ============================================================
-- Sustainability lens (peso 5%)
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_sustainability_lens(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  product_brand_id uuid;
  total_bonus      smallint := 0;
  has_any          boolean;
BEGIN
  SELECT brand_id INTO product_brand_id FROM products WHERE id = p_product_id;

  -- Somma bonus product-level
  SELECT COALESCE(SUM(c.bonus_points), 0)
  INTO total_bonus
  FROM product_certifications pc
  JOIN certifications c ON c.id = pc.certification_id
  WHERE pc.product_id = p_product_id;

  -- Aggiunge bonus brand-level (B Corp, 1% for the Planet, ecc.)
  total_bonus := total_bonus + COALESCE((
    SELECT SUM(c.bonus_points)
    FROM brand_certifications bc
    JOIN certifications c ON c.id = bc.certification_id
    WHERE bc.brand_id = product_brand_id
  ), 0);

  -- Se nessuna certificazione, lente esclusa (graceful)
  SELECT EXISTS (
    SELECT 1 FROM product_certifications WHERE product_id = p_product_id
    UNION ALL
    SELECT 1 FROM brand_certifications WHERE brand_id = product_brand_id
  ) INTO has_any;

  IF NOT has_any THEN
    RETURN NULL;
  END IF;

  RETURN LEAST(100, GREATEST(0, total_bonus));
END;
$$;

COMMENT ON FUNCTION calculate_sustainability_lens IS 'Lente Sustainability (peso 5%): somma bonus product+brand certifications, capped 100. NULL se nessuna certificazione (lente esclusa).';

-- ============================================================
-- Orchestrator: calculate_worthy_score_v2
-- ============================================================
--
-- Ritorna un jsonb con:
--   { score, verdict, confidence, breakdown: {...}, raw, mattia_adjustment }
--
-- IMPORTANTE: in fase F3 (dual-write) questa funzione viene chiamata in shadow:
-- popola products.score_breakdown ma NON sovrascrive worthy_score (che resta v1).
-- In F5 (switch) si farà UPDATE calculate_worthy_score per delegare a v2.

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
  mattia_adj      integer;

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
  -- Bypass del trigger protect_product_privileged_fields per UPDATE sui sub-score
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
  -- (NON sovrascrive products.score_composition, che è lo score v1).
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

  -- material: peso 50%, sempre presente
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

  -- qpr: peso 10%, sempre presente (default 50 in edge case)
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

  -- Mattia adjustment
  SELECT COALESCE(score_adjustment, 0) INTO mattia_adj
  FROM mattia_reviews WHERE product_id = p_product_id;
  IF mattia_adj IS NULL THEN mattia_adj := 0; END IF;

  raw_score := weighted_sum / total_weight + mattia_adj;
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
    'mattia_adjustment', mattia_adj,
    'confidence',        confidence,
    'raw',               round(raw_score, 2),
    'final',             final_score,
    'verdict',           final_verdict
  );

  -- Persistenza shadow: sub-score + breakdown. NON tocca worthy_score (resta v1) durante F3.
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

COMMENT ON FUNCTION calculate_worthy_score_v2 IS 'Worthy Score v2 - orchestratore multi-lente con graceful degradation. Persistenza shadow su score_breakdown durante F3; non tocca worthy_score finché F5.';
