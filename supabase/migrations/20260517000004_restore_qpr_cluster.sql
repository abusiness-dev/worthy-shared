-- Ripristino del QPR cluster-based — fix regressione introdotta in 20260512.
--
-- Storia:
--   - 20260428000002 ha introdotto il QPR cluster-based: confronto contro la
--     mediana di (category × brand.market_segment), con fallback alla mediana
--     della categoria se il cluster ha < 3 prodotti.
--   - 20260512000001 (rimozione lente sustainability) ha riscritto
--     calculate_worthy_score_v2 per 3 lenti, ma ha PERSO la logica cluster:
--     è tornata a usare categories.avg_composition_score / avg_price (medie
--     aritmetiche su tutta la categoria).
--
-- Effetto della regressione: categorie eterogenee (es. "Felpe" con sia Shein
-- a 15€ sia Loro Piana a 800€) producono riferimenti medi schiacciati verso
-- il basso. Un capo premium (cashmere 95, prezzo 250€) finisce con QPR ≈ 1-3
-- invece di ≈ 70-80.
--
-- Misura pre-fix (2026-05-17): su 1962 prodotti attivi, 642 hanno QPR ≤ 5 e
-- 507 hanno composition ≥ 70 ma QPR ≤ 20 — il 26% del catalogo è penalizzato
-- ingiustamente.
--
-- Questa migration:
--   1. Introduce un helper unico `calculate_qpr_cluster()` con fallback chain
--      esplicito (cluster → median categoria → media categoria → 50).
--   2. Riscrive `calculate_worthy_score_v2` per usare l'helper (3 lenti
--      vigenti: composition 50% / manufacturing 25% / qpr 25%).
--   3. Sostituisce `calculate_score_inline` con una versione che accetta
--      `brand_id` e usa lo stesso helper (chiude il TODO storico "unificare
--      con calculate_worthy_score"). Aggiorna il trigger BEFORE INSERT
--      `protect_product_privileged_fields` per passare NEW.brand_id.
--   4. Backfill: rinfresca aggregati cluster + mediane categoria, poi
--      ricalcola tutti i prodotti attivi, infine ri-aggrega i brand.

-- ============================================================
-- 1. Helper unico: calculate_qpr_cluster()
--    Restituisce integer 0-100.
--    brand_id può essere NULL (skip cluster, vai diretto al fallback).
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_qpr_cluster(
  p_comp_score  integer,
  p_brand_id    uuid,
  p_category_id uuid,
  p_price       numeric
)
RETURNS integer
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  seg            market_segment;
  ref_price      numeric;
  ref_score      numeric;
  cluster_count  integer;
  raw_qpr        numeric;
BEGIN
  IF p_price IS NULL OR p_price <= 0 OR p_comp_score IS NULL THEN
    RETURN 50;
  END IF;

  -- Primary: cluster (category × brand.market_segment), se brand_id noto
  IF p_brand_id IS NOT NULL THEN
    SELECT b.market_segment INTO seg FROM brands b WHERE b.id = p_brand_id;

    IF seg IS NOT NULL THEN
      SELECT median_price, median_composition_score, product_count
      INTO ref_price, ref_score, cluster_count
      FROM category_segment_aggregates
      WHERE category_id = p_category_id AND market_segment = seg;
    END IF;
  END IF;

  -- Fallback 1: mediana di categoria (se cluster vuoto o < 3 prodotti)
  IF cluster_count IS NULL OR cluster_count < 3 THEN
    SELECT median_price, median_composition_score
    INTO ref_price, ref_score
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 2: media di categoria (safety net retrocompatibile)
  IF ref_price IS NULL OR ref_price <= 0 OR ref_score IS NULL OR ref_score <= 0 THEN
    SELECT avg_price, avg_composition_score
    INTO ref_price, ref_score
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 3: 50 neutro
  IF ref_price IS NULL OR ref_price <= 0 OR ref_score IS NULL OR ref_score <= 0 THEN
    RETURN 50;
  END IF;

  raw_qpr := (p_comp_score::numeric / p_price) / (ref_score / ref_price) * 100;

  RETURN LEAST(100, GREATEST(0, round(
    100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
  )))::integer;
END;
$$;

COMMENT ON FUNCTION calculate_qpr_cluster IS
  'QPR cluster-based: confronta (comp/price) del prodotto con (median_score/median_price) del cluster (category × brand.market_segment). Fallback chain: cluster → median categoria → media categoria → 50. Sigmoid centrata in 100 con pendenza 0.05. Unica fonte di verità per la lente QPR.';

-- ============================================================
-- 2. Riscrive calculate_worthy_score_v2 per usare l'helper
--    Pesi vigenti (3 lenti): composition 50% / manufacturing 25% / qpr 25%
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

  prod_brand_id   uuid;
  prod_cat_id     uuid;
  prod_price      numeric;

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

  -- 1. Carica i dati del prodotto
  SELECT
    calculate_composition_score(p.composition),
    p.brand_id,
    p.category_id,
    p.price
  INTO comp_score, prod_brand_id, prod_cat_id, prod_price
  FROM products p
  WHERE p.id = p_product_id;

  manuf_score := calculate_manufacturing_lens(p_product_id);

  -- 2. QPR via helper unico (cluster-based + fallback chain)
  qpr_score := calculate_qpr_cluster(comp_score, prod_brand_id, prod_cat_id, prod_price);

  -- 3. Aggregazione pesata (rinormalizzazione delle componenti null)
  weighted_sum := weighted_sum + comp_score * 0.50;
  total_weight := total_weight + 0.50;
  weights_used := weights_used + 0.50;

  IF manuf_score IS NOT NULL THEN
    weighted_sum := weighted_sum + manuf_score * 0.25;
    total_weight := total_weight + 0.25;
    weights_used := weights_used + 0.25;
  END IF;

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
  'Worthy Score v2 — 3 lenti (composition 50%, manufacturing 25%, qpr 25%). QPR cluster-based via calculate_qpr_cluster(). Persiste breakdown e sub-score in products. score_sustainability sempre NULL (lente rimossa).';

-- ============================================================
-- 3. Sostituzione calculate_score_inline con firma a 4 parametri
--    Aggiunge p_brand_id per permettere il cluster lookup.
--    Cambio di firma → DROP + CREATE.
-- ============================================================

DROP FUNCTION IF EXISTS calculate_score_inline(jsonb, numeric, uuid);

CREATE OR REPLACE FUNCTION calculate_score_inline(
  p_composition jsonb,
  p_price       numeric,
  p_category_id uuid,
  p_brand_id    uuid DEFAULT NULL
)
RETURNS TABLE(
  comp_score    integer,
  qpr_score     integer,
  worthy_score  integer,
  final_verdict verdict
)
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_comp  integer;
  v_qpr   integer;
  v_score integer;
  v_verd  verdict;
  raw_score numeric;
BEGIN
  v_comp := calculate_composition_score(p_composition);
  v_qpr  := calculate_qpr_cluster(v_comp, p_brand_id, p_category_id, p_price);

  -- Stessa aggregazione 3-lenti di calculate_worthy_score_v2, ma senza la
  -- lente manufacturing (non disponibile inline su un prodotto non ancora
  -- inserito): si rinormalizza sui pesi presenti.
  --   composition (0.50) + qpr (0.25) = 0.75 → /0.75 = *4/3
  raw_score := (v_comp * 0.50 + v_qpr * 0.25) / 0.75;
  v_score := LEAST(100, GREATEST(0, round(raw_score)::integer));

  v_verd := CASE
    WHEN v_score >= 86 THEN 'steal'::verdict
    WHEN v_score >= 71 THEN 'worthy'::verdict
    WHEN v_score >= 51 THEN 'fair'::verdict
    WHEN v_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  comp_score    := v_comp;
  qpr_score     := v_qpr;
  worthy_score  := v_score;
  final_verdict := v_verd;
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION calculate_score_inline IS
  'Calcola score inline (BEFORE INSERT trigger) usando calculate_qpr_cluster. Senza la lente manufacturing, rinormalizza i pesi composition+qpr su 0.75. Subito dopo l''INSERT il trigger AFTER chiama calculate_worthy_score che ricalcola con tutte e 3 le lenti.';

-- ============================================================
-- 4. Aggiorna il trigger BEFORE INSERT per passare brand_id
--    Resto invariato — stessa logica di protezione di 20260428000001.
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

    NEW.score_manufacturing  := NULL;
    NEW.score_sustainability := NULL;
    NEW.score_confidence     := NULL;
    NEW.score_breakdown      := NULL;

    IF NEW.composition IS NOT NULL AND NEW.price IS NOT NULL AND NEW.category_id IS NOT NULL THEN
      SELECT * INTO scores
      FROM calculate_score_inline(NEW.composition, NEW.price, NEW.category_id, NEW.brand_id);

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

-- ============================================================
-- 5. Backfill — 3 step
-- ============================================================

-- 5a. Rinfresca aggregati cluster e mediane di categoria.
--     Il trigger live (trg_products_qpr_aggregates) li mantiene aggiornati su
--     ogni cambio, ma forziamo una passata completa per sicurezza.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM categories LOOP
    PERFORM recalculate_category_medians(r.id);
  END LOOP;

  FOR r IN
    SELECT DISTINCT p.category_id, b.market_segment
    FROM products p
    JOIN brands b ON b.id = p.brand_id
    WHERE p.is_active = true
  LOOP
    PERFORM recalculate_category_segment_aggregates(r.category_id, r.market_segment);
  END LOOP;

  RAISE NOTICE 'Backfill QPR: aggregati cluster e mediane categoria rinfrescati';
END $$;

-- 5b. Ricalcola tutti i prodotti attivi con la nuova formula.
DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Backfill QPR: % prodotti ricalcolati con cluster-based', n;
END $$;

-- 5c. Aggrega medie sui brand.
SELECT recalculate_brand_avg_scores();
