-- QPR v3 — formula meno fragile.
--
-- Premessa: il fix precedente (20260517000004) ha ripristinato il riferimento
-- cluster-based, ma alcuni cluster sono semanticamente "contaminati" — es. la
-- categoria "Abiti" contiene anche pantaloni, camicie e scarpe singole. La
-- mediana di un cluster bimodale non rappresenta nulla di reale, e la sigmoid
-- centrata in 100 con coefficiente 0.05 penalizza in modo estremo qualsiasi
-- scostamento, producendo QPR a 1 o 4 per capi che intuitivamente meritano
-- 40-70.
--
-- Esempio reale (Abito Havana Perennial Suitsupply, 100% merino, 399€):
--   raw_qpr = (92/399) / (92/149) * 100 = 37.3
--   sigmoid(37.3, coeff=0.05)  =  4  ← bug
--   sigmoid(37.3, coeff=0.025) = 17  ← morbida ma ancora bassa per cluster sporco
--
-- Tre interventi sulla funzione `calculate_qpr_cluster` (modificata
-- in-place, stessa firma):
--   1. Coefficiente sigmoid 0.05 → 0.025 (curva più morbida, scostamenti
--      vengono interpretati con meno aggressività).
--   2. Cluster_count minimo 3 → 8: cluster sotto-popolati cadono nel
--      fallback (mediana categoria), più stabile.
--   3. Floor 15 / Cap 95 sul valore finale: si elimina la coda di QPR
--      estremi 0-14 e 96-100, che semanticamente sono solo artefatti
--      della sigmoid agli estremi e non informano l'utente.
--
-- Backfill: ricalcolo di tutti i prodotti attivi via calculate_worthy_score.

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
  sigmoid_val    numeric;
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

  -- Fallback 1: mediana di categoria (se cluster vuoto o < 8 prodotti).
  -- Soglia alzata da 3 a 8 per evitare cluster statisticamente inaffidabili
  -- (bimodali o piccoli).
  IF cluster_count IS NULL OR cluster_count < 8 THEN
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

  -- Sigmoid centrata in 100 con coefficiente 0.025 (era 0.05): pendenza
  -- dimezzata, scostamenti dal riferimento vengono interpretati con meno
  -- aggressività.
  sigmoid_val := 100.0 / (1.0 + exp(-0.025 * (raw_qpr - 100.0)));

  -- Floor 15 / Cap 95: si rimuovono le code degli estremi della sigmoid,
  -- che non aggiungono informazione utile per l'utente finale.
  RETURN LEAST(95, GREATEST(15, round(sigmoid_val)::integer));
END;
$$;

COMMENT ON FUNCTION calculate_qpr_cluster IS
  'QPR cluster-based v3. Confronta (comp/price) del prodotto con (median_score/median_price) del cluster (category × brand.market_segment). Fallback chain: cluster (≥8 prodotti) → median categoria → media categoria → 50. Sigmoid centrata in 100 con coefficiente 0.025 (curva morbida). Output clampato a [15, 95] per evitare artefatti di coda.';

-- ============================================================
-- Backfill: ricalcola tutti i prodotti attivi con la nuova formula.
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

  RAISE NOTICE 'QPR v3 (sigmoid morbida + cluster≥8 + clamp 15-95): % prodotti ricalcolati', n;
END $$;

SELECT recalculate_brand_avg_scores();
