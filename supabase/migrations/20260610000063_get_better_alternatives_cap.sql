-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 7) — get_better_alternatives: cap del fan-out + filtro
-- prezzo sargable.
--
-- PROBLEMA (vs 20260605000007):
--   - p_ref_ids senza cap di cardinalità: un client che passa una wishlist grande fa
--     fan-out N × dimensione-famiglia senza tetto.
--   - cap prezzo non-sargable: p.price / refs.ref_price <= 2.5 (divisione per riga).
--
-- SOLUZIONE: slice p_ref_ids[1:50] (cap 50 riferimenti per chiamata) + riscrittura
--   sargable p.price <= refs.ref_price * 2.5. Logica/colonne invariate. CREATE OR
--   REPLACE (stesso return type) preserva l'ACL; re-emettiamo GRANT/REVOKE per sicurezza.
-- ════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_better_alternatives(
  p_ref_ids   uuid[],
  p_limit_per int DEFAULT 24
)
RETURNS TABLE (
  ref_id          uuid,
  id              uuid,
  name            text,
  slug            text,
  gender          public.gender,
  brand_id        uuid,
  brand_name      text,
  brand_slug      text,
  market_segment  public.market_segment,
  comparison_tier text,
  category_id     uuid,
  category_name   text,
  category_slug   text,
  category_family text,
  worthy_score    numeric,
  verdict         public.verdict,
  price           numeric,
  composition     jsonb,
  photo_urls      text[]
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH refs AS (
    SELECT
      r.id                            AS ref_id,
      COALESCE(rc.family, rc.slug)    AS ref_family,
      r.gender                        AS ref_gender,
      r.worthy_score                  AS ref_score,
      r.price                         AS ref_price,
      array_position(ARRAY['mass_market', 'premium', 'luxury', 'maison']::text[], rb.comparison_tier) AS ref_tier_pos
    FROM public.products r
    JOIN public.categories rc ON rc.id = r.category_id
    JOIN public.brands     rb ON rb.id = r.brand_id
    WHERE r.id = ANY(p_ref_ids[1:50])  -- CAP: al massimo 50 riferimenti per chiamata
      AND rc.is_supported
  ),
  ranked AS (
    SELECT
      refs.ref_id,
      p.id, p.name, p.slug, p.gender, p.brand_id,
      b.name AS brand_name, b.slug AS brand_slug, b.market_segment, b.comparison_tier,
      p.category_id, c.name AS category_name, c.slug AS category_slug,
      COALESCE(c.family, c.slug) AS category_family,
      p.worthy_score, p.verdict, p.price, p.composition, p.photo_urls,
      row_number() OVER (
        PARTITION BY refs.ref_id
        ORDER BY p.worthy_score DESC, p.id
      ) AS rn
    FROM refs
    JOIN public.categories c ON COALESCE(c.family, c.slug) = refs.ref_family AND c.is_supported
    JOIN public.products   p ON p.category_id = c.id
    JOIN public.brands     b ON b.id = p.brand_id
    WHERE p.is_active
      AND p.id <> refs.ref_id
      AND p.worthy_score >= refs.ref_score
      AND p.worthy_score >= 51
      AND (refs.ref_gender = 'unisex' OR p.gender = 'unisex' OR p.gender = refs.ref_gender)
      AND (
        refs.ref_tier_pos IS NULL
        OR array_position(ARRAY['mass_market', 'premium', 'luxury', 'maison']::text[], b.comparison_tier) IS NULL
        OR abs(array_position(ARRAY['mass_market', 'premium', 'luxury', 'maison']::text[], b.comparison_tier) - refs.ref_tier_pos) <= 1
      )
      -- Cap prezzo superiore in forma SARGABLE (no divisione per riga).
      AND (
        refs.ref_price IS NULL OR refs.ref_price <= 0
        OR p.price IS NULL OR p.price <= 0
        OR p.price <= refs.ref_price * 2.5
      )
  )
  SELECT
    ref_id, id, name, slug, gender, brand_id, brand_name, brand_slug,
    market_segment, comparison_tier, category_id, category_name, category_slug,
    category_family, worthy_score, verdict, price, composition, photo_urls
  FROM ranked
  WHERE rn <= GREATEST(1, LEAST(p_limit_per, 100));
$$;

REVOKE ALL ON FUNCTION public.get_better_alternatives(uuid[], int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_better_alternatives(uuid[], int)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.get_better_alternatives(uuid[], int) IS
  'Per ogni prodotto in p_ref_ids (cap 50) ritorna i top candidati "alternativa migliore" (stessa famiglia categoria SUPPORTATA, gender compatibile, worthy_score >= riferimento, >= 51, lega comparison_tier ±1, prezzo <= 2.5x in forma sargable), ordinati per worthy_score DESC.';
