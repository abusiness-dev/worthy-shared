-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 7) — find_potential_duplicates usa l'operatore trigram %.
--
-- PROBLEMA: la versione 20260326000021 usa similarity(p.name, p_name) > 0.4 nel WHERE
--   (calcola similarity 3 volte/riga e NON attiva il gin index idx_products_name_trgm
--   → seq scan dei prodotti del brand). search_products_fuzzy mostra il pattern corretto.
--
-- SOLUZIONE: predicato p.name % p_name (attiva il gin index), similarity calcolata UNA
--   volta in subquery. Stessa soglia effettiva (> 0.4) e stesso output. È REVOKE da
--   client (F8): chiamabile solo via service_role. CREATE OR REPLACE preserva l'ACL.
-- ════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION find_potential_duplicates(
  p_product_id uuid,
  p_name text,
  p_brand_id uuid
)
RETURNS TABLE(found_product_id uuid, name_similarity decimal)
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT s.id, s.sim
  FROM (
    SELECT p.id, similarity(p.name, p_name)::decimal AS sim
    FROM public.products p
    WHERE p.id <> p_product_id
      AND p.brand_id = p_brand_id
      AND p.is_active = true
      AND p.name % p_name          -- attiva idx_products_name_trgm (gin)
  ) s
  WHERE s.sim > 0.4
  ORDER BY s.sim DESC
  LIMIT 10;
$$;

COMMENT ON FUNCTION find_potential_duplicates IS
  'Trova prodotti dello stesso brand con nome simile (similarity > 0.4) usando l''operatore trigram % (gin index). Solo service_role (REVOKE F8).';
