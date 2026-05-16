-- Fuzzy product search via pg_trgm
-- pg_trgm già abilitato in 20260326000019; idx_products_name_trgm già esistente su products.name.
-- Qui aggiungiamo l'indice mancante su brands.name e la RPC search_products_fuzzy
-- usata dalla edge function match-product-by-tag per il fallback "photo-search".

CREATE INDEX IF NOT EXISTS idx_brands_name_trgm
  ON brands USING gin(name gin_trgm_ops);

CREATE OR REPLACE FUNCTION search_products_fuzzy(
  p_brand   text,
  p_product text,
  p_max     int DEFAULT 5
)
RETURNS TABLE (
  product_id uuid,
  slug       text,
  name       text,
  brand_name text,
  photo_url  text,
  sim        numeric
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    p.id,
    p.slug,
    p.name,
    b.name,
    (p.photo_urls)[1],
    GREATEST(similarity(p.name, p_product), similarity(b.name, p_brand))::numeric AS sim
  FROM products p
  JOIN brands   b ON b.id = p.brand_id
  WHERE p.is_active
    AND (p_product <> '' OR p_brand <> '')
    AND (p.name % p_product OR b.name % p_brand)
    AND GREATEST(similarity(p.name, p_product), similarity(b.name, p_brand)) >= 0.20
  ORDER BY sim DESC, p.worthy_score DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_max, 20));
$$;

REVOKE ALL ON FUNCTION search_products_fuzzy(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION search_products_fuzzy(text, text, int)
  TO authenticated, service_role;
