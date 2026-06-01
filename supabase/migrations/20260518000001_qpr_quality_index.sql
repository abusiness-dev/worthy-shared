-- QPR v4 — estende il numeratore del QPR per includere la lente manufacturing
-- (Italia/Portogallo/Giappone vs Cina/Bangladesh).
--
-- Storia: il QPR è passato da v1 (avg categoria, regressione di 20260512) a
-- v2 cluster-based (20260517000004), v3 con sigmoid morbida e clamp 15-95
-- (20260517000005). Tutti basati su composition_score / price. Da oggi:
--
--   quality_index = (comp * 0.50 + manuf * 0.25) / weights_used
--   weights_used = 0.50 + (0.25 se manuf NOT NULL else 0)
--
-- Pesi mutuati dal Worthy Score v2 (50/25/25). Il 25% del QPR è ignorato
-- nel quality_index per evitare auto-riferimento. Rinormalizzazione null-safe:
-- se manuf manca, quality_index collassa su composition (backward compatible
-- con i 611 prodotti senza dato).
--
-- Il riferimento del cluster diventa la mediana del quality_index invece di
-- quella del solo composition_score. Le mediane di composition_score e price
-- restano in schema per retro-compat e debug.
--
-- Copertura odierna: 1351/1962 (68.9%) prodotti hanno score_manufacturing.
-- Brand high-manuf: Suitsupply (avg 90.7), Massimo Dutti (57.2), COS (53.6).
-- Brand senza manuf: Lacoste, Zara, Uniqlo (fallback ai puri composition).

-- ============================================================
-- 1. Helper: compute_quality_index — UNICA fonte di verità
-- ============================================================

CREATE OR REPLACE FUNCTION compute_quality_index(
  p_comp_score  numeric,
  p_manuf_score numeric
)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE
SET search_path = public
AS $$
BEGIN
  IF p_comp_score IS NULL THEN
    RETURN NULL;
  END IF;
  IF p_manuf_score IS NULL THEN
    RETURN p_comp_score::numeric;
  END IF;
  -- (comp*0.50 + manuf*0.25) / 0.75 = (2*comp + manuf) / 3
  RETURN (p_comp_score * 0.50 + p_manuf_score * 0.25) / 0.75;
END;
$$;

COMMENT ON FUNCTION compute_quality_index IS
  'Indice di qualità composito: 2/3 composition + 1/3 manufacturing (pesi mutuati dal Worthy Score v2 con rinormalizzazione su 0.75). Se manufacturing è NULL ritorna composition. Usato come numeratore del QPR e come metrica della mediana del cluster.';

-- ============================================================
-- 2. Schema: aggiunge median_quality_index
-- ============================================================

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS median_quality_index numeric(5,2) NOT NULL DEFAULT 0;

ALTER TABLE category_segment_aggregates
  ADD COLUMN IF NOT EXISTS median_quality_index numeric(5,2) NOT NULL DEFAULT 0;

-- ============================================================
-- 3. Riscrive recalculate_category_medians per popolare anche
--    median_quality_index
-- ============================================================

CREATE OR REPLACE FUNCTION recalculate_category_medians(p_category_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  med_price   numeric;
  med_score   numeric;
  med_quality numeric;
BEGIN
  SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.price),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_composition),
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY compute_quality_index(p.score_composition, p.score_manufacturing)
    )
  INTO med_price, med_score, med_quality
  FROM products p
  WHERE p.category_id = p_category_id AND p.is_active = true;

  UPDATE categories
  SET median_price             = COALESCE(ROUND(med_price, 2), 0),
      median_composition_score = COALESCE(ROUND(med_score, 2), 0),
      median_quality_index     = COALESCE(ROUND(med_quality, 2), 0)
  WHERE id = p_category_id;
END;
$$;

COMMENT ON FUNCTION recalculate_category_medians IS
  'Ricalcola median_price, median_composition_score e median_quality_index di una categoria sui prodotti attivi. Fallback usato dal QPR quando il cluster ha < 8 prodotti.';

-- ============================================================
-- 4. Riscrive recalculate_category_segment_aggregates per popolare
--    median_quality_index nel cluster
-- ============================================================

CREATE OR REPLACE FUNCTION recalculate_category_segment_aggregates(
  p_category_id uuid,
  p_segment market_segment
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  med_price   numeric;
  med_score   numeric;
  med_quality numeric;
  cnt         integer;
BEGIN
  SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.price),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_composition),
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY compute_quality_index(p.score_composition, p.score_manufacturing)
    ),
    COUNT(*)
  INTO med_price, med_score, med_quality, cnt
  FROM products p
  JOIN brands b ON b.id = p.brand_id
  WHERE p.category_id = p_category_id
    AND b.market_segment = p_segment
    AND p.is_active = true;

  IF cnt = 0 THEN
    DELETE FROM category_segment_aggregates
    WHERE category_id = p_category_id AND market_segment = p_segment;
    RETURN;
  END IF;

  INSERT INTO category_segment_aggregates
    (category_id, market_segment, median_price, median_composition_score,
     median_quality_index, product_count, updated_at)
  VALUES
    (p_category_id, p_segment, ROUND(med_price, 2), ROUND(med_score, 2),
     ROUND(med_quality, 2), cnt, now())
  ON CONFLICT (category_id, market_segment) DO UPDATE
  SET median_price             = EXCLUDED.median_price,
      median_composition_score = EXCLUDED.median_composition_score,
      median_quality_index     = EXCLUDED.median_quality_index,
      product_count            = EXCLUDED.product_count,
      updated_at               = EXCLUDED.updated_at;
END;
$$;

COMMENT ON FUNCTION recalculate_category_segment_aggregates IS
  'Ricalcola le mediane (category × market_segment) sui prodotti attivi del cluster: price, composition_score, quality_index. UPSERT o DELETE se vuoto.';

-- ============================================================
-- 5. Riscrive trigger_recalc_qpr_aggregates per scattare anche su
--    score_manufacturing (oggi reagisce solo a brand/cat/price/composition)
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_recalc_qpr_aggregates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  old_segment market_segment;
  new_segment market_segment;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT b.market_segment INTO new_segment FROM brands b WHERE b.id = NEW.brand_id;
    PERFORM recalculate_category_segment_aggregates(NEW.category_id, new_segment);
    PERFORM recalculate_category_medians(NEW.category_id);

  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.brand_id              IS DISTINCT FROM OLD.brand_id
       OR NEW.category_id        IS DISTINCT FROM OLD.category_id
       OR NEW.price              IS DISTINCT FROM OLD.price
       OR NEW.composition        IS DISTINCT FROM OLD.composition
       OR NEW.is_active          IS DISTINCT FROM OLD.is_active
       OR NEW.score_composition  IS DISTINCT FROM OLD.score_composition
       OR NEW.score_manufacturing IS DISTINCT FROM OLD.score_manufacturing
    THEN
      SELECT b.market_segment INTO old_segment FROM brands b WHERE b.id = OLD.brand_id;
      SELECT b.market_segment INTO new_segment FROM brands b WHERE b.id = NEW.brand_id;

      PERFORM recalculate_category_segment_aggregates(OLD.category_id, old_segment);
      PERFORM recalculate_category_medians(OLD.category_id);

      IF NEW.category_id IS DISTINCT FROM OLD.category_id
         OR new_segment IS DISTINCT FROM old_segment
      THEN
        PERFORM recalculate_category_segment_aggregates(NEW.category_id, new_segment);
        PERFORM recalculate_category_medians(NEW.category_id);
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    SELECT b.market_segment INTO old_segment FROM brands b WHERE b.id = OLD.brand_id;
    PERFORM recalculate_category_segment_aggregates(OLD.category_id, old_segment);
    PERFORM recalculate_category_medians(OLD.category_id);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger DROP+CREATE non necessari: la funzione viene aggiornata in place.

-- ============================================================
-- 6. Riscrive calculate_qpr_cluster — nuova firma con p_manuf_score
-- ============================================================

DROP FUNCTION IF EXISTS calculate_qpr_cluster(integer, uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION calculate_qpr_cluster(
  p_comp_score  integer,
  p_manuf_score numeric,
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
  ref_quality    numeric;
  ref_price      numeric;
  cluster_count  integer;
  quality_idx    numeric;
  raw_qpr        numeric;
  sigmoid_val    numeric;
BEGIN
  IF p_price IS NULL OR p_price <= 0 OR p_comp_score IS NULL THEN
    RETURN 50;
  END IF;

  quality_idx := compute_quality_index(p_comp_score, p_manuf_score);

  -- Primary: cluster (category × brand.market_segment)
  IF p_brand_id IS NOT NULL THEN
    SELECT b.market_segment INTO seg FROM brands b WHERE b.id = p_brand_id;

    IF seg IS NOT NULL THEN
      SELECT median_quality_index, median_price, product_count
      INTO ref_quality, ref_price, cluster_count
      FROM category_segment_aggregates
      WHERE category_id = p_category_id AND market_segment = seg;
    END IF;
  END IF;

  -- Fallback 1: mediana di categoria (se cluster vuoto o < 8 prodotti)
  IF cluster_count IS NULL OR cluster_count < 8 THEN
    SELECT median_quality_index, median_price
    INTO ref_quality, ref_price
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 2: media di categoria (safety net retrocompatibile)
  IF ref_price IS NULL OR ref_price <= 0 OR ref_quality IS NULL OR ref_quality <= 0 THEN
    SELECT avg_price, avg_composition_score
    INTO ref_price, ref_quality
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 3: 50 neutro
  IF ref_price IS NULL OR ref_price <= 0 OR ref_quality IS NULL OR ref_quality <= 0 THEN
    RETURN 50;
  END IF;

  raw_qpr := (quality_idx / p_price) / (ref_quality / ref_price) * 100;

  sigmoid_val := 100.0 / (1.0 + exp(-0.025 * (raw_qpr - 100.0)));

  RETURN LEAST(95, GREATEST(15, round(sigmoid_val)::integer));
END;
$$;

COMMENT ON FUNCTION calculate_qpr_cluster IS
  'QPR cluster-based v4. Confronta (quality_index/price) del prodotto con (median_quality_index/median_price) del cluster (category × brand.market_segment). quality_index = 2/3 composition + 1/3 manufacturing (rinormalizzato se manuf NULL). Fallback chain: cluster (≥8) → median categoria → media categoria → 50. Sigmoid coeff 0.025, clamp [15, 95].';

-- ============================================================
-- 7. Riscrive calculate_worthy_score_v2 per passare manuf_score al QPR
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

  SELECT
    calculate_composition_score(p.composition),
    p.brand_id,
    p.category_id,
    p.price
  INTO comp_score, prod_brand_id, prod_cat_id, prod_price
  FROM products p
  WHERE p.id = p_product_id;

  manuf_score := calculate_manufacturing_lens(p_product_id);

  -- QPR ora include manufacturing nel quality_index
  qpr_score := calculate_qpr_cluster(comp_score, manuf_score, prod_brand_id, prod_cat_id, prod_price);

  -- Aggregazione pesata 3 lenti
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
  'Worthy Score v2 — 3 lenti (composition 50%, manufacturing 25%, qpr 25%). Il QPR ora include manufacturing nel quality_index (v4 cluster-based). Persiste breakdown e sub-score in products.';

-- NB: calculate_score_inline (BEFORE INSERT trigger) NON viene modificata.
-- Continua a calcolare il QPR con manuf=NULL implicito (fallback a sola
-- composition nel quality_index). Subito dopo l'INSERT scatta il trigger
-- AFTER trg_products_calculate_score che chiama calculate_worthy_score, il
-- quale ricalcola con manuf incluso. A transazione completa lo score è
-- corretto.

-- ============================================================
-- 8. Backfill
--    a. Rinfresca mediane (categoria + cluster) per popolare i nuovi
--       median_quality_index.
--    b. Ricalcola tutti i prodotti attivi via calculate_worthy_score
--       (chiama internamente v2 → calcola QPR con il nuovo riferimento).
--    c. Aggrega medie sui brand.
-- ============================================================

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

  RAISE NOTICE 'Backfill v4: aggregati cluster e mediane categoria popolati con median_quality_index';
END $$;

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Backfill v4: % prodotti ricalcolati con QPR quality_index', n;
END $$;

SELECT recalculate_brand_avg_scores();
