-- QPR v5 — bonus additivo per il manufacturing oltre il cluster.
--
-- Motivazione: con la formula v4 (20260518000001) il manufacturing entra nel
-- QPR via quality_index, ma cluster dominati da un solo brand (es. Abiti ×
-- premium = 78% Suitsupply) si auto-cancellano: Suitsupply manuf 95 viene
-- confrontata con cluster di mediana manuf ≈ Suitsupply stessa → nessun
-- vantaggio. Risultato pre-bonus: Suitsupply Havana QPR 58 invariato.
--
-- Il bonus additivo cattura "filiera in Italia vale di più" in modo
-- assoluto, indipendentemente dalla composizione del cluster:
--
--   qpr_cluster = (formula sigmoid v4, clamp 15-95)
--   bonus       = (manuf - cluster_median_manuf) * 0.3   se manuf NOT NULL
--   qpr_final   = clamp(15, 95, qpr_cluster + bonus)
--
-- Coefficiente 0.3: effetto massimo ±15 punti per scarti di ±50 dal
-- mediano del cluster. Esempi:
--   - Suitsupply manuf 95 in cluster median manuf 88 → bonus +2 (cluster
--     già high-manuf, effetto piccolo: è coerente)
--   - Suitsupply manuf 95 in cluster median manuf 60 (es. dove Massimo
--     Dutti domina) → bonus +10 (qui sì che brilla)
--   - Brand con manuf 30 in cluster median 70 → bonus −12 (penalità)
--   - Brand senza manuf data (Lacoste, Zara, Uniqlo) → bonus 0 (no-op)

-- ============================================================
-- 1. Schema: aggiunge median_manufacturing_score
-- ============================================================

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS median_manufacturing_score numeric(5,2);

ALTER TABLE category_segment_aggregates
  ADD COLUMN IF NOT EXISTS median_manufacturing_score numeric(5,2);

-- Nullable di proposito: NULL = cluster senza prodotti con manuf data → bonus 0.

-- ============================================================
-- 2. Aggiorna recalculate_category_medians
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
  med_manuf   numeric;
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

  -- Mediana manuf calcolata SOLO sui prodotti che hanno il dato (evita
  -- distorsione da NULL).
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_manufacturing)
  INTO med_manuf
  FROM products p
  WHERE p.category_id = p_category_id
    AND p.is_active = true
    AND p.score_manufacturing IS NOT NULL;

  UPDATE categories
  SET median_price               = COALESCE(ROUND(med_price, 2), 0),
      median_composition_score   = COALESCE(ROUND(med_score, 2), 0),
      median_quality_index       = COALESCE(ROUND(med_quality, 2), 0),
      median_manufacturing_score = ROUND(med_manuf, 2)  -- nullable
  WHERE id = p_category_id;
END;
$$;

-- ============================================================
-- 3. Aggiorna recalculate_category_segment_aggregates
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
  med_manuf   numeric;
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

  -- Mediana manuf su soli prodotti con dato
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_manufacturing)
  INTO med_manuf
  FROM products p
  JOIN brands b ON b.id = p.brand_id
  WHERE p.category_id = p_category_id
    AND b.market_segment = p_segment
    AND p.is_active = true
    AND p.score_manufacturing IS NOT NULL;

  INSERT INTO category_segment_aggregates
    (category_id, market_segment, median_price, median_composition_score,
     median_quality_index, median_manufacturing_score, product_count, updated_at)
  VALUES
    (p_category_id, p_segment, ROUND(med_price, 2), ROUND(med_score, 2),
     ROUND(med_quality, 2), ROUND(med_manuf, 2), cnt, now())
  ON CONFLICT (category_id, market_segment) DO UPDATE
  SET median_price               = EXCLUDED.median_price,
      median_composition_score   = EXCLUDED.median_composition_score,
      median_quality_index       = EXCLUDED.median_quality_index,
      median_manufacturing_score = EXCLUDED.median_manufacturing_score,
      product_count              = EXCLUDED.product_count,
      updated_at                 = EXCLUDED.updated_at;
END;
$$;

-- ============================================================
-- 4. Riscrive calculate_qpr_cluster con bonus additivo
-- ============================================================

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
  seg                  market_segment;
  ref_quality          numeric;
  ref_price            numeric;
  ref_manuf            numeric;
  cluster_count        integer;
  quality_idx          numeric;
  raw_qpr              numeric;
  sigmoid_val          numeric;
  qpr_cluster_int      integer;
  manuf_bonus          numeric := 0;
BEGIN
  IF p_price IS NULL OR p_price <= 0 OR p_comp_score IS NULL THEN
    RETURN 50;
  END IF;

  quality_idx := compute_quality_index(p_comp_score, p_manuf_score);

  -- Primary: cluster (category × brand.market_segment)
  IF p_brand_id IS NOT NULL THEN
    SELECT b.market_segment INTO seg FROM brands b WHERE b.id = p_brand_id;

    IF seg IS NOT NULL THEN
      SELECT median_quality_index, median_price, median_manufacturing_score, product_count
      INTO ref_quality, ref_price, ref_manuf, cluster_count
      FROM category_segment_aggregates
      WHERE category_id = p_category_id AND market_segment = seg;
    END IF;
  END IF;

  -- Fallback 1: mediana di categoria
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

  -- Bonus additivo manuf: cattura "Italia vale di più" anche in cluster
  -- self-saturated. Solo se sia il prodotto sia il cluster hanno manuf.
  IF p_manuf_score IS NOT NULL AND ref_manuf IS NOT NULL THEN
    manuf_bonus := (p_manuf_score - ref_manuf) * 0.3;
  END IF;

  RETURN LEAST(95, GREATEST(15, qpr_cluster_int + round(manuf_bonus)::integer));
END;
$$;

COMMENT ON FUNCTION calculate_qpr_cluster IS
  'QPR cluster-based v5. quality_index (2/3 comp + 1/3 manuf) confrontato con la mediana del cluster (category × brand.market_segment), poi sigmoid 0.025, poi BONUS additivo (manuf - cluster_median_manuf) * 0.3, infine clamp [15, 95]. Il bonus assoluto cattura il vantaggio "Italia vale di più" anche nei cluster self-saturated.';

-- ============================================================
-- 5. Backfill: rinfresca aggregati per popolare median_manufacturing_score,
--    poi ricalcola tutti i prodotti via calculate_worthy_score.
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

  RAISE NOTICE 'Backfill v5: aggregati con median_manufacturing_score popolati';
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

  RAISE NOTICE 'Backfill v5: % prodotti ricalcolati con bonus manuf', n;
END $$;

SELECT recalculate_brand_avg_scores();
