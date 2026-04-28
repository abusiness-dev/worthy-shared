-- Worthy Score v2 - Semplificazione a 4 lenti.
--
-- Rimuove le lenti `origin` (origine fibre) e `technical` (tecnologie tessili)
-- dalla formula. Le due lenti erano basate su dati che la pipeline non
-- popola in modo affidabile, quindi la formula nominale divergeva da quella
-- effettivamente calcolata sui prodotti.
--
-- Pesi NUOVI (somma 1.00):
--   composition    50%   (era material_quality 50% = max(composition,technical))
--   manufacturing  25%   (era 15%)  +10pp
--   qpr            20%   (era 10%)  +10pp
--   sustainability  5%   invariato
--
-- material_quality (fusione composition+technical) sparisce dal breakdown.
-- composition torna a essere lente diretta.
--
-- Cleanup DB (DROP completo):
--   - trigger trg_pfo_recalc_v2, trg_pt_recalc_v2 (i trg_pc_recalc_v2 resta)
--   - colonne products.score_origin, products.score_technical
--   - funzioni calculate_origin_lens, calculate_technical_lens
--   - tabelle product_fiber_origins, product_technologies
--   - tabelle anagrafica fiber_origins, fabric_technologies

-- ============================================================
-- 1. Drop trigger sui link tables che spariranno
-- ============================================================

DROP TRIGGER IF EXISTS trg_pfo_recalc_v2 ON product_fiber_origins;
DROP TRIGGER IF EXISTS trg_pt_recalc_v2  ON product_technologies;

-- ============================================================
-- 2. Riscrivi protect_product_privileged_fields rimuovendo riferimenti
--    a score_origin e score_technical (le colonne stanno per essere droppate)
-- ============================================================

CREATE OR REPLACE FUNCTION protect_product_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  blocked_fields text[] := '{}';
  acting_user uuid;
  scores record;
BEGIN
  IF current_setting('worthy.skip_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.verification_status := 'unverified';
    NEW.scan_count := 0;
    NEW.community_score := NULL;
    NEW.community_votes_count := 0;
    NEW.is_active := true;
    NEW.score_fit := NULL;
    NEW.score_durability := NULL;

    -- v2 sub-score residui dopo la semplificazione a 4 lenti
    NEW.score_manufacturing  := NULL;
    NEW.score_sustainability := NULL;
    NEW.score_confidence     := NULL;
    NEW.score_breakdown      := NULL;

    IF NEW.composition IS NOT NULL AND NEW.price IS NOT NULL AND NEW.category_id IS NOT NULL THEN
      SELECT * INTO scores
      FROM calculate_score_inline(NEW.composition, NEW.price, NEW.category_id);

      NEW.score_composition := scores.comp_score;
      NEW.score_qpr := scores.qpr_score;
      NEW.worthy_score := scores.worthy_score;
      NEW.verdict := scores.final_verdict;
    ELSE
      NEW.score_composition := 0;
      NEW.score_qpr := 0;
      NEW.worthy_score := 0;
      NEW.verdict := 'fair'::verdict;
    END IF;

    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.worthy_score IS DISTINCT FROM OLD.worthy_score THEN
      blocked_fields := array_append(blocked_fields, 'worthy_score');
    END IF;
    IF NEW.score_composition IS DISTINCT FROM OLD.score_composition THEN
      blocked_fields := array_append(blocked_fields, 'score_composition');
    END IF;
    IF NEW.score_qpr IS DISTINCT FROM OLD.score_qpr THEN
      blocked_fields := array_append(blocked_fields, 'score_qpr');
    END IF;
    IF NEW.score_fit IS DISTINCT FROM OLD.score_fit THEN
      blocked_fields := array_append(blocked_fields, 'score_fit');
    END IF;
    IF NEW.score_durability IS DISTINCT FROM OLD.score_durability THEN
      blocked_fields := array_append(blocked_fields, 'score_durability');
    END IF;
    IF NEW.verdict IS DISTINCT FROM OLD.verdict THEN
      blocked_fields := array_append(blocked_fields, 'verdict');
    END IF;
    IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
      blocked_fields := array_append(blocked_fields, 'verification_status');
    END IF;
    IF NEW.scan_count IS DISTINCT FROM OLD.scan_count THEN
      blocked_fields := array_append(blocked_fields, 'scan_count');
    END IF;
    IF NEW.community_score IS DISTINCT FROM OLD.community_score THEN
      blocked_fields := array_append(blocked_fields, 'community_score');
    END IF;
    IF NEW.community_votes_count IS DISTINCT FROM OLD.community_votes_count THEN
      blocked_fields := array_append(blocked_fields, 'community_votes_count');
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      blocked_fields := array_append(blocked_fields, 'is_active');
    END IF;

    IF NEW.score_manufacturing IS DISTINCT FROM OLD.score_manufacturing THEN
      blocked_fields := array_append(blocked_fields, 'score_manufacturing');
    END IF;
    IF NEW.score_sustainability IS DISTINCT FROM OLD.score_sustainability THEN
      blocked_fields := array_append(blocked_fields, 'score_sustainability');
    END IF;
    IF NEW.score_confidence IS DISTINCT FROM OLD.score_confidence THEN
      blocked_fields := array_append(blocked_fields, 'score_confidence');
    END IF;
    IF NEW.score_breakdown IS DISTINCT FROM OLD.score_breakdown THEN
      blocked_fields := array_append(blocked_fields, 'score_breakdown');
    END IF;

    IF array_length(blocked_fields, 1) IS NULL THEN
      RETURN NEW;
    END IF;

    BEGIN
      acting_user := auth.uid();
    EXCEPTION WHEN OTHERS THEN
      acting_user := NULL;
    END;

    PERFORM log_security_event('products', OLD.id, acting_user, blocked_fields);

    RAISE EXCEPTION 'Attempt to modify protected fields: %',
      array_to_string(blocked_fields, ', ')
      USING HINT = 'Score, verification, and is_active fields on products can only be modified by service_role.',
            ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION protect_product_privileged_fields IS
  'BEFORE INSERT/UPDATE trigger: forza defaults su INSERT (incluso azzeramento v2 sub-score), blocca UPDATE su tutti i campi score (v1 + v2 residui dopo la semplificazione a 4 lenti). Bypass via session var worthy.skip_protection o JWT service_role.';

-- ============================================================
-- 3. Riscrivi calculate_worthy_score_v2 per 4 lenti
--    Smette di scrivere su score_origin, score_technical (colonne in drop)
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
  susta_score     numeric;

  weighted_sum    numeric := 0;
  total_weight    numeric := 0;
  raw_score       numeric;
  final_score     integer;
  final_verdict   verdict;
  confidence      numeric;

  weights_full constant numeric := 0.50 + 0.25 + 0.20 + 0.05;
  weights_used numeric := 0;

  breakdown jsonb;
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  -- 1. Lenti raw
  SELECT calculate_composition_score(composition) INTO comp_score
  FROM products WHERE id = p_product_id;

  manuf_score := calculate_manufacturing_lens(p_product_id);
  susta_score := calculate_sustainability_lens(p_product_id);

  -- 2. QPR inline (usa composition direttamente, niente più material_quality)
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

  -- qpr: peso 20%, sempre presente
  weighted_sum := weighted_sum + qpr_score * 0.20;
  total_weight := total_weight + 0.20;
  weights_used := weights_used + 0.20;

  IF susta_score IS NOT NULL THEN
    weighted_sum := weighted_sum + susta_score * 0.05;
    total_weight := total_weight + 0.05;
    weights_used := weights_used + 0.05;
  END IF;

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
      'composition',    jsonb_build_object('score', comp_score,  'used', comp_score  IS NOT NULL),
      'manufacturing',  jsonb_build_object('score', manuf_score, 'used', manuf_score IS NOT NULL),
      'qpr',            jsonb_build_object('score', qpr_score,   'used', qpr_score   IS NOT NULL),
      'sustainability', jsonb_build_object('score', susta_score, 'used', susta_score IS NOT NULL)
    ),
    'weights', jsonb_build_object(
      'composition',    0.50,
      'manufacturing',  0.25,
      'qpr',            0.20,
      'sustainability', 0.05
    ),
    'confidence',        confidence,
    'raw',               round(raw_score, 2),
    'final',             final_score,
    'verdict',           final_verdict
  );

  UPDATE products
  SET
    score_manufacturing  = manuf_score,
    score_sustainability = susta_score,
    score_confidence     = confidence,
    score_breakdown      = breakdown
  WHERE id = p_product_id;

  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN breakdown;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score_v2 IS
  'Worthy Score v2 - 4 lenti (composition 50%, manufacturing 25%, qpr 20%, sustainability 5%) con graceful degradation. Persiste breakdown e sub-score in products.';

-- ============================================================
-- 4. Drop colonne sub-score legate a lenti rimosse
-- ============================================================

ALTER TABLE products DROP COLUMN IF EXISTS score_origin;
ALTER TABLE products DROP COLUMN IF EXISTS score_technical;

-- ============================================================
-- 5. Drop funzioni lente non più usate
-- ============================================================

DROP FUNCTION IF EXISTS calculate_origin_lens(uuid);
DROP FUNCTION IF EXISTS calculate_technical_lens(uuid);

-- ============================================================
-- 6. Drop tabelle di link e anagrafica
--    L'ordine importa: prima link tables (FK verso le anagrafiche), poi anagrafiche.
-- ============================================================

DROP TABLE IF EXISTS product_fiber_origins;
DROP TABLE IF EXISTS product_technologies;
DROP TABLE IF EXISTS fiber_origins;
DROP TABLE IF EXISTS fabric_technologies;

-- ============================================================
-- 7. Backfill: ricalcolo di tutti i prodotti attivi con la nuova formula
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

  RAISE NOTICE 'Worthy Score 4-lens recalculation: % prodotti aggiornati', n;
END $$;

-- Aggiorna le medie aggregate sui brand
SELECT recalculate_brand_avg_scores();
