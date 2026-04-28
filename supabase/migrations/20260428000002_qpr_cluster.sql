-- Worthy Score - QPR per cluster (categoria × market_segment).
--
-- Sostituisce il riferimento del QPR (oggi: media della categoria) con la
-- median del cluster (categoria × market_segment del brand). Loro Piana
-- cappotto si confronta solo con altri cappotti maison, Zara cappotto solo
-- con altri cappotti fast_fashion. Il fair-price diventa contestuale.
--
-- Modifiche:
--   1. Consolida l'enum market_segment a 4 valori puliti.
--   2. Aggiunge categories.median_price e median_composition_score (fallback).
--   3. Crea category_segment_aggregates con (category_id, market_segment).
--   4. Funzioni di ricalcolo aggregate via percentile_cont(0.5).
--   5. Trigger sui prodotti per ricalcolo live.
--   6. Riscrive il QPR inline in calculate_worthy_score_v2 con lookup cluster
--      e fallback alla median di categoria se cluster ha < 3 prodotti.
--   7. Backfill: aggregate iniziale + ricalcolo di tutti i prodotti.

-- ============================================================
-- 1. Consolidamento enum market_segment a 4 valori
--    7 valori → 4: ultra_fast, fast_fashion, premium, maison
--    La materialized view brand_rankings dipende da brands.market_segment;
--    va droppata, riallineata la colonna, e ricreata identica.
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS brand_rankings;

CREATE TYPE market_segment_v2 AS ENUM ('ultra_fast', 'fast_fashion', 'premium', 'maison');

ALTER TABLE brands
  ALTER COLUMN market_segment TYPE market_segment_v2 USING (
    CASE market_segment::text
      WHEN 'ultra_fast'    THEN 'ultra_fast'
      WHEN 'fast'          THEN 'fast_fashion'
      WHEN 'fast_fashion'  THEN 'fast_fashion'
      WHEN 'premium_fast'  THEN 'premium'
      WHEN 'mid_range'     THEN 'premium'
      WHEN 'premium'       THEN 'premium'
      WHEN 'maison'        THEN 'maison'
    END::market_segment_v2
  );

DROP TYPE market_segment;
ALTER TYPE market_segment_v2 RENAME TO market_segment;

-- Ricrea brand_rankings (definizione identica a 20260326000023)
CREATE MATERIALIZED VIEW brand_rankings AS
SELECT
  b.id AS brand_id,
  b.name AS brand_name,
  b.slug AS brand_slug,
  b.market_segment,
  COUNT(p.id) AS product_count,
  COALESCE(round(AVG(p.worthy_score), 2), 0) AS avg_score,
  SUM(p.scan_count) AS total_scans,
  CASE
    WHEN AVG(p.worthy_score) >= 86 THEN 'steal'::verdict
    WHEN AVG(p.worthy_score) >= 71 THEN 'worthy'::verdict
    WHEN AVG(p.worthy_score) >= 51 THEN 'fair'::verdict
    WHEN AVG(p.worthy_score) >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END AS avg_verdict
FROM brands b
LEFT JOIN products p ON p.brand_id = b.id AND p.is_active = true
GROUP BY b.id, b.name, b.slug, b.market_segment
ORDER BY avg_score DESC;

CREATE UNIQUE INDEX idx_brand_rankings_brand_id ON brand_rankings(brand_id);

COMMENT ON MATERIALIZED VIEW brand_rankings IS 'Classifica brand per Worthy Score medio — refresh ogni 15 minuti';

-- ============================================================
-- 2. categories: aggiunge median_price e median_composition_score
--    Fallback usato dal QPR quando il cluster ha < 3 prodotti.
-- ============================================================

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS median_price numeric(8,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS median_composition_score numeric(5,2) NOT NULL DEFAULT 0;

-- ============================================================
-- 3. Tabella category_segment_aggregates
--    PRIMARY KEY (category_id, market_segment).
--    Persiste le mediane per cluster. Aggiornata da trigger sui products.
-- ============================================================

CREATE TABLE IF NOT EXISTS category_segment_aggregates (
  category_id              uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  market_segment           market_segment NOT NULL,
  median_price             numeric(8,2) NOT NULL,
  median_composition_score numeric(5,2) NOT NULL,
  product_count            integer NOT NULL,
  updated_at               timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (category_id, market_segment)
);

CREATE INDEX IF NOT EXISTS idx_csa_segment ON category_segment_aggregates(market_segment);

COMMENT ON TABLE category_segment_aggregates IS
  'Mediane di prezzo e composition_score per (category × market_segment), usate come riferimento dal QPR cluster-based.';

-- ============================================================
-- 4. Funzioni di ricalcolo
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
  med_price numeric;
  med_score numeric;
  cnt       integer;
BEGIN
  SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.price),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_composition),
    COUNT(*)
  INTO med_price, med_score, cnt
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
    (category_id, market_segment, median_price, median_composition_score, product_count, updated_at)
  VALUES
    (p_category_id, p_segment, ROUND(med_price, 2), ROUND(med_score, 2), cnt, now())
  ON CONFLICT (category_id, market_segment) DO UPDATE
  SET median_price             = EXCLUDED.median_price,
      median_composition_score = EXCLUDED.median_composition_score,
      product_count            = EXCLUDED.product_count,
      updated_at               = EXCLUDED.updated_at;
END;
$$;

COMMENT ON FUNCTION recalculate_category_segment_aggregates IS
  'Ricalcola le mediane (category × market_segment) usando percentile_cont(0.5) sui prodotti attivi del cluster. UPSERT o DELETE se vuoto.';

CREATE OR REPLACE FUNCTION recalculate_category_medians(p_category_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  med_price numeric;
  med_score numeric;
BEGIN
  SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.price),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY p.score_composition)
  INTO med_price, med_score
  FROM products p
  WHERE p.category_id = p_category_id AND p.is_active = true;

  UPDATE categories
  SET median_price             = COALESCE(ROUND(med_price, 2), 0),
      median_composition_score = COALESCE(ROUND(med_score, 2), 0)
  WHERE id = p_category_id;
END;
$$;

COMMENT ON FUNCTION recalculate_category_medians IS
  'Ricalcola median_price e median_composition_score di una categoria su prodotti attivi. Fallback per il QPR quando il cluster ha < 3 prodotti.';

-- ============================================================
-- 5. Trigger sui products: aggiorna gli aggregate quando cambiano
--    brand_id, category_id, price, composition, is_active.
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
  -- Determina i segmenti coinvolti via JOIN su brands
  IF TG_OP = 'INSERT' THEN
    SELECT b.market_segment INTO new_segment FROM brands b WHERE b.id = NEW.brand_id;
    PERFORM recalculate_category_segment_aggregates(NEW.category_id, new_segment);
    PERFORM recalculate_category_medians(NEW.category_id);

  ELSIF TG_OP = 'UPDATE' THEN
    -- Solo se cambia qualcosa di rilevante
    IF NEW.brand_id        IS DISTINCT FROM OLD.brand_id
       OR NEW.category_id  IS DISTINCT FROM OLD.category_id
       OR NEW.price        IS DISTINCT FROM OLD.price
       OR NEW.composition  IS DISTINCT FROM OLD.composition
       OR NEW.is_active    IS DISTINCT FROM OLD.is_active
       OR NEW.score_composition IS DISTINCT FROM OLD.score_composition
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

DROP TRIGGER IF EXISTS trg_products_qpr_aggregates ON products;
CREATE TRIGGER trg_products_qpr_aggregates
  AFTER INSERT OR UPDATE OR DELETE ON products
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_qpr_aggregates();

-- ============================================================
-- 6. Riscrive calculate_worthy_score_v2 con QPR cluster-based
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

  -- 2. QPR cluster-based: cerca median in (categoria × segmento brand);
  --    fallback alla median dell'intera categoria se cluster < 3.
  DECLARE
    seg            market_segment;
    cat_id         uuid;
    prod_price     numeric;
    ref_price      numeric;
    ref_score      numeric;
    cluster_count  integer;
    raw_qpr        numeric;
  BEGIN
    SELECT p.price, p.category_id, b.market_segment
    INTO prod_price, cat_id, seg
    FROM products p
    JOIN brands b ON b.id = p.brand_id
    WHERE p.id = p_product_id;

    SELECT median_price, median_composition_score, product_count
    INTO ref_price, ref_score, cluster_count
    FROM category_segment_aggregates
    WHERE category_id = cat_id AND market_segment = seg;

    -- Fallback alla categoria se cluster < 3 (anche se NULL)
    IF cluster_count IS NULL OR cluster_count < 3 THEN
      SELECT median_price, median_composition_score
      INTO ref_price, ref_score
      FROM categories
      WHERE id = cat_id;
    END IF;

    IF prod_price > 0 AND ref_price > 0 AND ref_score > 0 THEN
      raw_qpr := (comp_score::numeric / prod_price) / (ref_score / ref_price) * 100;
      qpr_score := LEAST(100, GREATEST(0, round(
        100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
      )))::integer;
    ELSE
      qpr_score := 50;
    END IF;
  END;

  -- 3. Aggregazione pesata (rinormalizzazione delle componenti null)

  weighted_sum := weighted_sum + comp_score * 0.50;
  total_weight := total_weight + 0.50;
  weights_used := weights_used + 0.50;

  IF manuf_score IS NOT NULL THEN
    weighted_sum := weighted_sum + manuf_score * 0.25;
    total_weight := total_weight + 0.25;
    weights_used := weights_used + 0.25;
  END IF;

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
  'Worthy Score v2 - 4 lenti (composition 50%, manufacturing 25%, qpr 20%, sustainability 5%). QPR cluster-based: confronto con median di (category × brand market_segment), fallback alla median della categoria se cluster < 3 prodotti.';

-- ============================================================
-- 7. Backfill iniziale degli aggregate
--    Step A: median per categoria (fallback).
--    Step B: median per (categoria × segmento) — solo cluster popolati.
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

  RAISE NOTICE 'Aggregati QPR popolati';
END $$;

-- ============================================================
-- 8. Backfill: ricalcola tutti i prodotti attivi con la nuova formula QPR
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

  RAISE NOTICE 'QPR cluster recalculation: % prodotti aggiornati', n;
END $$;

SELECT recalculate_brand_avg_scores();
