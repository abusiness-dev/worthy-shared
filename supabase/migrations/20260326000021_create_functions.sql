-- Crea funzioni SQL: scoring, QPR, worthy score, duplicate detection

-- ============================================================
-- calculate_composition_score(jsonb) → integer
-- Replica la logica di src/scoring/calculateComposition.ts
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_composition_score(comp jsonb)
RETURNS integer
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  fiber_rec record;
  fiber_name text;
  fiber_pct numeric;
  fiber_score integer;
  weighted_sum numeric := 0;
  total_pct numeric := 0;
  is_neutral boolean;
BEGIN
  IF comp IS NULL OR jsonb_array_length(comp) = 0 THEN
    RETURN 50;
  END IF;

  FOR fiber_rec IN SELECT * FROM jsonb_array_elements(comp)
  LOOP
    fiber_name := lower(fiber_rec.value ->> 'fiber');
    fiber_pct  := (fiber_rec.value ->> 'percentage')::numeric;

    -- Fibre neutre sotto il 5% vengono escluse
    is_neutral := fiber_name IN ('elastane', 'spandex', 'elastan');
    IF is_neutral AND fiber_pct <= 5 THEN
      CONTINUE;
    END IF;

    -- Mapping fibre → punteggio
    fiber_score := CASE
      WHEN fiber_name = 'cashmere' THEN 98
      WHEN fiber_name IN ('seta', 'silk') THEN 95
      WHEN fiber_name IN ('lana merino', 'merino wool', 'merino') THEN 92
      WHEN fiber_name IN ('cotone supima', 'supima cotton') THEN 90
      WHEN fiber_name IN ('cotone pima', 'pima cotton') THEN 90
      WHEN fiber_name IN ('cotone egiziano', 'egyptian cotton') THEN 90
      WHEN fiber_name IN ('lino', 'linen') THEN 88
      WHEN fiber_name IN ('cotone biologico', 'organic cotton') THEN 85
      WHEN fiber_name IN ('lyocell', 'tencel') THEN 80
      WHEN fiber_name IN ('cotone', 'cotton') THEN 75
      WHEN fiber_name = 'modal' THEN 72
      WHEN fiber_name IN ('viscosa', 'rayon', 'viscose') THEN 55
      WHEN fiber_name IN ('nylon', 'nailon', 'polyamide', 'poliammide') THEN 50
      WHEN fiber_name IN ('poliestere riciclato', 'recycled polyester') THEN 48
      WHEN fiber_name IN ('poliestere', 'polyester') THEN 30
      WHEN fiber_name IN ('acrilico', 'acrylic') THEN 20
      ELSE 50
    END;

    weighted_sum := weighted_sum + (fiber_score * fiber_pct);
    total_pct := total_pct + fiber_pct;
  END LOOP;

  IF total_pct = 0 THEN
    RETURN 50;
  END IF;

  RETURN LEAST(100, GREATEST(0, round(weighted_sum / total_pct)));
END;
$$;

COMMENT ON FUNCTION calculate_composition_score IS 'Calcola score composizione da array JSON di fibre. Replica logica TypeScript.';

-- ============================================================
-- calculate_qpr(uuid) → integer
-- Calcola il QPR per un prodotto usando le medie della sua categoria
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_qpr(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  p_comp_score numeric;
  p_price numeric;
  cat_avg_score numeric;
  cat_avg_price numeric;
  raw_qpr numeric;
BEGIN
  SELECT
    p.score_composition, p.price,
    c.avg_composition_score, c.avg_price
  INTO p_comp_score, p_price, cat_avg_score, cat_avg_price
  FROM products p
  JOIN categories c ON c.id = p.category_id
  WHERE p.id = p_product_id;

  IF p_price <= 0 OR cat_avg_price <= 0 OR cat_avg_score <= 0 THEN
    RETURN 50;
  END IF;

  -- raw = (compScore/price) / (avgCatScore/avgCatPrice) × 100
  raw_qpr := (p_comp_score / p_price) / (cat_avg_score / cat_avg_price) * 100;

  -- Normalizzazione con sigmoid: 100 / (1 + exp(-0.05 * (x - 100)))
  RETURN LEAST(100, GREATEST(0, round(
    100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
  )));
END;
$$;

COMMENT ON FUNCTION calculate_qpr IS 'Calcola rapporto qualità/prezzo normalizzato con sigmoid per un prodotto';

-- ============================================================
-- calculate_worthy_score(uuid) → integer
-- Calcola lo score finale e aggiorna il record del prodotto
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  comp_score integer;
  qpr_score integer;
  fit numeric;
  durability numeric;
  mattia_adj integer;
  raw_score numeric;
  final_score integer;
  final_verdict verdict;
BEGIN
  -- Calcola sub-score composizione dal JSON
  SELECT calculate_composition_score(p.composition)
  INTO comp_score
  FROM products p
  WHERE p.id = p_product_id;

  -- Aggiorna score_composition prima del calcolo QPR
  UPDATE products SET score_composition = comp_score WHERE id = p_product_id;

  -- Calcola QPR
  qpr_score := calculate_qpr(p_product_id);

  -- Leggi fit e durability dalla community + mattia adjustment
  SELECT
    COALESCE(p.score_fit, 50),
    COALESCE(p.score_durability, 50),
    COALESCE(mr.score_adjustment, 0)
  INTO fit, durability, mattia_adj
  FROM products p
  LEFT JOIN mattia_reviews mr ON mr.product_id = p.id
  WHERE p.id = p_product_id;

  -- Formula: comp*0.35 + qpr*0.30 + fit*0.15 + durability*0.15 + mattia
  raw_score := comp_score * 0.35 + qpr_score * 0.30 + fit * 0.15 + durability * 0.15 + mattia_adj;
  final_score := LEAST(100, GREATEST(0, round(raw_score)));

  -- Verdict
  final_verdict := CASE
    WHEN final_score >= 86 THEN 'steal'::verdict
    WHEN final_score >= 71 THEN 'worthy'::verdict
    WHEN final_score >= 51 THEN 'fair'::verdict
    WHEN final_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  -- Aggiorna il prodotto
  UPDATE products
  SET
    score_composition = comp_score,
    score_qpr = qpr_score,
    worthy_score = final_score,
    verdict = final_verdict
  WHERE id = p_product_id;

  RETURN final_score;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score IS 'Calcola e aggiorna worthy_score, sub-score e verdict per un prodotto';

-- ============================================================
-- find_potential_duplicates(uuid, text, uuid) → TABLE
-- Cerca prodotti potenzialmente duplicati per barcode o nome simile
-- ============================================================

CREATE OR REPLACE FUNCTION find_potential_duplicates(
  p_product_id uuid,
  p_name text,
  p_brand_id uuid
)
RETURNS TABLE(found_product_id uuid, name_similarity decimal)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    similarity(p.name, p_name)::decimal
  FROM products p
  WHERE p.id <> p_product_id
    AND p.brand_id = p_brand_id
    AND p.is_active = true
    AND similarity(p.name, p_name) > 0.4
  ORDER BY similarity(p.name, p_name) DESC
  LIMIT 10;
END;
$$;

COMMENT ON FUNCTION find_potential_duplicates IS 'Trova prodotti dello stesso brand con nome simile (similarity > 0.4)';
