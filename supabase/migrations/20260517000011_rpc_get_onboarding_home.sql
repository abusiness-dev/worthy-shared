-- RPC: get_onboarding_home(p_limit int)
--
-- Sostituisce il pattern N+1 di useOnboardingCategories nel client:
--   1. fetch top N categorie con product_count > 0
--   2. per OGNI categoria, fetch del top-1 prodotto via Promise.all
--
-- Con 8 categorie diventano 9 round-trip Supabase al primo render dell'onboarding.
--
-- Questa RPC fa tutto in una sola query usando ROW_NUMBER() partitioned per
-- category_id. L'ordine output rispetta quello di categories.product_count DESC.
--
-- Returns: una riga per ogni top-categoria, con (eventualmente) il top-1 prodotto
-- inline. Se una categoria non ha prodotti attivi nonostante product_count > 0
-- (drift di stato), product_id sarà NULL.
--
-- Sicurezza: SECURITY INVOKER (default). Categories e products sono pubblici.

CREATE OR REPLACE FUNCTION public.get_onboarding_home(p_limit int DEFAULT 8)
RETURNS TABLE (
  category_id uuid,
  category_name text,
  category_slug text,
  icon text,
  product_id uuid,
  product_name text,
  worthy_score numeric,
  image_url text
)
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  WITH top_cats AS (
    SELECT
      id, name, slug, icon, product_count,
      ROW_NUMBER() OVER (ORDER BY product_count DESC, name ASC) AS pos
    FROM categories
    WHERE product_count > 0
    ORDER BY product_count DESC, name ASC
    LIMIT p_limit
  ),
  ranked AS (
    SELECT
      p.id, p.name, p.category_id, p.worthy_score, p.photo_urls,
      ROW_NUMBER() OVER (
        PARTITION BY p.category_id
        ORDER BY p.worthy_score DESC NULLS LAST, p.id
      ) AS rn
    FROM products p
    WHERE p.is_active = true
      AND p.category_id IN (SELECT id FROM top_cats)
  )
  SELECT
    tc.id AS category_id,
    tc.name AS category_name,
    tc.slug AS category_slug,
    tc.icon,
    r.id AS product_id,
    r.name AS product_name,
    COALESCE(r.worthy_score, 0)::numeric AS worthy_score,
    CASE
      WHEN r.photo_urls IS NOT NULL AND array_length(r.photo_urls, 1) > 0
      THEN (r.photo_urls)[1]
      ELSE NULL
    END AS image_url
  FROM top_cats tc
  LEFT JOIN ranked r ON r.category_id = tc.id AND r.rn = 1
  ORDER BY tc.pos;
$$;

GRANT EXECUTE ON FUNCTION public.get_onboarding_home(int) TO anon, authenticated;

COMMENT ON FUNCTION public.get_onboarding_home(int) IS
  'Top N categorie attive con il prodotto top-1 (per worthy_score) di ciascuna. Sostituisce il pattern N+1 di useOnboardingCategories (1 query categorie + N query per top prodotto). STABLE.';
