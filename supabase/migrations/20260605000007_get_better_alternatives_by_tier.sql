-- ════════════════════════════════════════════════════════════════════
-- Migration: get_better_alternatives — adiacenza su comparison_tier + filtro
-- is_supported.
--
-- Coerenza col QPR: l'adiacenza di lega delle alternative passa da
-- brands.market_segment (4 valori enum) a brands.comparison_tier (le leghe
-- larghe). Aggiunge il filtro is_supported (sia sul riferimento sia sui
-- candidati): se la categoria del riferimento è esclusa la RPC ritorna 0
-- candidati ("categoria non valutabile"). Espone comparison_tier in output
-- (market_segment resta per retro-compatibilità).
--
-- Return-type change (nuova colonna) → DROP + CREATE.
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.get_better_alternatives(uuid[], int);

CREATE FUNCTION public.get_better_alternatives(
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
    WHERE r.id = ANY(p_ref_ids)
      AND rc.is_supported  -- riferimento in categoria esclusa ⇒ nessun candidato
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
      -- Score gate: mai più basso del riferimento.
      AND p.worthy_score >= refs.ref_score
      -- Floor di qualità assoluto: almeno verdict 'fair'.
      AND p.worthy_score >= 51
      -- Gender compatibile col riferimento (unisex su un lato ⇒ ammesso).
      AND (refs.ref_gender = 'unisex' OR p.gender = 'unisex' OR p.gender = refs.ref_gender)
      -- Lega ±1 (uno dei due ignoto/non mappato ⇒ ammesso, non blocca).
      AND (
        refs.ref_tier_pos IS NULL
        OR array_position(ARRAY['mass_market', 'premium', 'luxury', 'maison']::text[], b.comparison_tier) IS NULL
        OR abs(array_position(ARRAY['mass_market', 'premium', 'luxury', 'maison']::text[], b.comparison_tier) - refs.ref_tier_pos) <= 1
      )
      -- Cap prezzo superiore (nessun cap inferiore: più economico+migliore è desiderato).
      AND (
        refs.ref_price IS NULL OR refs.ref_price <= 0
        OR p.price IS NULL OR p.price <= 0
        OR p.price / refs.ref_price <= 2.5
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
  'Per ogni prodotto in p_ref_ids ritorna i top candidati "alternativa migliore" ammissibili (stessa famiglia categoria SUPPORTATA, gender compatibile, worthy_score >= riferimento, >= 51, lega comparison_tier ±1, prezzo <= 2.5x), ordinati per worthy_score DESC. Il ranking fine è in @worthy/shared.';
