-- ════════════════════════════════════════════════════════════════════
-- Migration: QPR cluster-based per comparison_tier (al posto di market_segment)
--
-- Ripunta SOLO la dimensione di clustering del QPR da brands.market_segment a
-- brands.comparison_tier (le leghe larghe introdotte in 20260605000003). La
-- FIRMA di calculate_qpr_cluster resta a 5 argomenti — quindi calculate_score_inline
-- e calculate_worthy_score_v2 NON cambiano firma: cambia solo il corpo.
--
-- Tutto il resto della lente QPR è invariato rispetto alla v5 (20260518000002):
--   quality_index = 2/3 composition + 1/3 manufacturing
--   sigmoid coeff 0.025, clamp [15, 95]
--   bonus additivo (manuf - cluster_median_manuf) * 0.3
--   fallback chain: cluster (≥8) → mediana categoria → media categoria → 50
--
-- Nuova tabella category_tier_aggregates (category_id × comparison_tier).
-- La vecchia category_segment_aggregates resta in schema ma NON è più scritta
-- né letta dallo scoring (deprecata).
-- ════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1. Tabella aggregati per lega
-- ============================================================

CREATE TABLE IF NOT EXISTS public.category_tier_aggregates (
  category_id                uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  comparison_tier            text NOT NULL REFERENCES public.comparison_tiers(key),
  median_price               numeric(8,2) NOT NULL,
  median_composition_score   numeric(5,2) NOT NULL,
  median_quality_index       numeric(5,2) NOT NULL,
  median_manufacturing_score numeric(5,2),
  product_count              integer NOT NULL,
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (category_id, comparison_tier)
);

CREATE INDEX IF NOT EXISTS idx_cta_tier
  ON public.category_tier_aggregates (comparison_tier);

COMMENT ON TABLE public.category_tier_aggregates IS
  'Mediane (prezzo, composition, quality_index, manufacturing) per (category × comparison_tier). Riferimento del QPR cluster-based. Sostituisce category_segment_aggregates (deprecata).';

-- ============================================================
-- 2. recalculate_category_tier_aggregates(category, tier)
-- ============================================================

CREATE OR REPLACE FUNCTION public.recalculate_category_tier_aggregates(
  p_category_id uuid,
  p_tier text
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
  med_manuf   numeric;
  cnt         integer;
BEGIN
  IF p_tier IS NULL THEN
    RETURN;
  END IF;

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
    AND b.comparison_tier = p_tier
    AND p.is_active = true;

  IF cnt = 0 THEN
    DELETE FROM category_tier_aggregates
    WHERE category_id = p_category_id AND comparison_tier = p_tier;
    RETURN;
  END IF;

  -- Mediana manuf solo sui prodotti che hanno il dato (evita distorsione da NULL).
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_manufacturing)
  INTO med_manuf
  FROM products p
  JOIN brands b ON b.id = p.brand_id
  WHERE p.category_id = p_category_id
    AND b.comparison_tier = p_tier
    AND p.is_active = true
    AND p.score_manufacturing IS NOT NULL;

  INSERT INTO category_tier_aggregates
    (category_id, comparison_tier, median_price, median_composition_score,
     median_quality_index, median_manufacturing_score, product_count, updated_at)
  VALUES
    (p_category_id, p_tier, ROUND(med_price, 2), ROUND(med_score, 2),
     ROUND(med_quality, 2), ROUND(med_manuf, 2), cnt, now())
  ON CONFLICT (category_id, comparison_tier) DO UPDATE
  SET median_price               = EXCLUDED.median_price,
      median_composition_score   = EXCLUDED.median_composition_score,
      median_quality_index       = EXCLUDED.median_quality_index,
      median_manufacturing_score = EXCLUDED.median_manufacturing_score,
      product_count              = EXCLUDED.product_count,
      updated_at                 = EXCLUDED.updated_at;
END;
$$;

COMMENT ON FUNCTION public.recalculate_category_tier_aggregates IS
  'Ricalcola le mediane (category × comparison_tier) sui prodotti attivi del cluster: price, composition, quality_index, manufacturing. UPSERT o DELETE se vuoto.';

-- ============================================================
-- 3. Trigger live sui products → aggrega per comparison_tier
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_recalc_qpr_aggregates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  old_tier text;
  new_tier text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT b.comparison_tier INTO new_tier FROM brands b WHERE b.id = NEW.brand_id;
    PERFORM recalculate_category_tier_aggregates(NEW.category_id, new_tier);
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
      SELECT b.comparison_tier INTO old_tier FROM brands b WHERE b.id = OLD.brand_id;
      SELECT b.comparison_tier INTO new_tier FROM brands b WHERE b.id = NEW.brand_id;

      PERFORM recalculate_category_tier_aggregates(OLD.category_id, old_tier);
      PERFORM recalculate_category_medians(OLD.category_id);

      IF NEW.category_id IS DISTINCT FROM OLD.category_id
         OR new_tier IS DISTINCT FROM old_tier
      THEN
        PERFORM recalculate_category_tier_aggregates(NEW.category_id, new_tier);
        PERFORM recalculate_category_medians(NEW.category_id);
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    SELECT b.comparison_tier INTO old_tier FROM brands b WHERE b.id = OLD.brand_id;
    PERFORM recalculate_category_tier_aggregates(OLD.category_id, old_tier);
    PERFORM recalculate_category_medians(OLD.category_id);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- Il trigger trg_products_qpr_aggregates (definito in 20260428000002) punta già
-- a questa funzione: la riscrittura in place è sufficiente.

-- ============================================================
-- 4. calculate_qpr_cluster — stessa firma (5 arg), corpo per comparison_tier
-- ============================================================

CREATE OR REPLACE FUNCTION public.calculate_qpr_cluster(
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
  tier            text;
  ref_quality     numeric;
  ref_price       numeric;
  ref_manuf       numeric;
  cluster_count   integer;
  quality_idx     numeric;
  raw_qpr         numeric;
  sigmoid_val     numeric;
  qpr_cluster_int integer;
  manuf_bonus     numeric := 0;
BEGIN
  IF p_price IS NULL OR p_price <= 0 OR p_comp_score IS NULL THEN
    RETURN 50;
  END IF;

  quality_idx := compute_quality_index(p_comp_score, p_manuf_score);

  -- Primary: cluster (category × brand.comparison_tier)
  IF p_brand_id IS NOT NULL THEN
    SELECT b.comparison_tier INTO tier FROM brands b WHERE b.id = p_brand_id;

    IF tier IS NOT NULL THEN
      SELECT median_quality_index, median_price, median_manufacturing_score, product_count
      INTO ref_quality, ref_price, ref_manuf, cluster_count
      FROM category_tier_aggregates
      WHERE category_id = p_category_id AND comparison_tier = tier;
    END IF;
  END IF;

  -- Fallback 1: mediana di categoria (cluster vuoto o < 8 prodotti)
  IF cluster_count IS NULL OR cluster_count < 8 THEN
    SELECT median_quality_index, median_price, median_manufacturing_score
    INTO ref_quality, ref_price, ref_manuf
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 2: media di categoria (no manuf reference)
  IF ref_price IS NULL OR ref_price <= 0 OR ref_quality IS NULL OR ref_quality <= 0 THEN
    SELECT avg_price, avg_composition_score, NULL::numeric
    INTO ref_price, ref_quality, ref_manuf
    FROM categories
    WHERE id = p_category_id;
  END IF;

  -- Fallback 3: 50 neutro
  IF ref_price IS NULL OR ref_price <= 0 OR ref_quality IS NULL OR ref_quality <= 0 THEN
    RETURN 50;
  END IF;

  raw_qpr := (quality_idx / p_price) / (ref_quality / ref_price) * 100;
  sigmoid_val := 100.0 / (1.0 + exp(-0.025 * (raw_qpr - 100.0)));
  qpr_cluster_int := round(sigmoid_val)::integer;

  IF p_manuf_score IS NOT NULL AND ref_manuf IS NOT NULL THEN
    manuf_bonus := (p_manuf_score - ref_manuf) * 0.3;
  END IF;

  RETURN LEAST(95, GREATEST(15, qpr_cluster_int + round(manuf_bonus)::integer));
END;
$$;

COMMENT ON FUNCTION public.calculate_qpr_cluster IS
  'QPR cluster-based v6. Identico a v5 ma il cluster è (category × brand.comparison_tier) anziché market_segment. quality_index (2/3 comp + 1/3 manuf) vs mediana del cluster, sigmoid 0.025, bonus (manuf - cluster_median_manuf)*0.3, clamp [15,95]. Fallback: cluster (≥8) → mediana categoria → media categoria → 50.';

-- ============================================================
-- 5. Backfill: aggregati per lega + ricalcolo prodotti + brand avg
-- ============================================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM categories LOOP
    PERFORM recalculate_category_medians(r.id);
  END LOOP;

  FOR r IN
    SELECT DISTINCT p.category_id, b.comparison_tier
    FROM products p
    JOIN brands b ON b.id = p.brand_id
    WHERE p.is_active = true
  LOOP
    PERFORM recalculate_category_tier_aggregates(r.category_id, r.comparison_tier);
  END LOOP;

  RAISE NOTICE 'Backfill v6: category_tier_aggregates popolati per comparison_tier';
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

  RAISE NOTICE 'Backfill v6: % prodotti ricalcolati con cluster per comparison_tier', n;
END $$;

SELECT recalculate_brand_avg_scores();
