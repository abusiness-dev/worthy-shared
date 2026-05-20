-- Fix: body delle 2 RPC introdotte nel PR #2 con references schema-qualificate.
--
-- Le migration 20260517000010 e 20260517000011 usavano `products` / `categories`
-- senza schema. Funzionano via `supabase db push` perché il CLI setta search_path
-- a livello session, ma falliscono in SQL Editor (e in qualsiasi context dove
-- check_function_bodies parsa il body con un search_path che non include public).
--
-- Fix: CREATE OR REPLACE con `public.products` / `public.categories`.
-- Idempotente: non droppa nulla, sovrascrive solo il body delle 2 funzioni.

CREATE OR REPLACE FUNCTION public.get_brand_ids_by_gender()
RETURNS TABLE (men_ids uuid[], women_ids uuid[])
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT
    ARRAY(
      SELECT DISTINCT brand_id
      FROM public.products
      WHERE is_active = true
        AND gender IN ('uomo', 'unisex')
    ) AS men_ids,
    ARRAY(
      SELECT DISTINCT brand_id
      FROM public.products
      WHERE is_active = true
        AND gender IN ('donna', 'unisex')
    ) AS women_ids;
$$;

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
    FROM public.categories
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
    FROM public.products p
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

-- GRANT è già su, ma re-emit per essere idempotenti.
GRANT EXECUTE ON FUNCTION public.get_brand_ids_by_gender() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_onboarding_home(int) TO anon, authenticated;
