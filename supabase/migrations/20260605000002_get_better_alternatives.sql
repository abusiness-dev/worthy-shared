-- ════════════════════════════════════════════════════════════════════
-- Migration: RPC get_better_alternatives — candidati "alternativa migliore"
-- filtrati server-side, in modo deterministico e senza troncamento client.
--
-- Fonte di verità UNICA degli hard-filter (categoria/famiglia, gender, score
-- gate, floor 'fair', segmento ±1, cap prezzo). Il ranking fine (fibra/nome/
-- prezzo/segmento + bonus stesso-brand) resta in @worthy/shared (rankBestCandidates),
-- applicato dal client sui candidati restituiti.
--
-- Prende un array di id-riferimento (1 per la pagina prodotto, N per il tab) e
-- ritorna per ciascuno i top candidati ammissibili ordinati per worthy_score.
-- Schema-qualificato: il body LANGUAGE sql è parsato al create-time.
-- ════════════════════════════════════════════════════════════════════

-- Indice di supporto: estrazione per categoria ordinata per score, solo attivi.
CREATE INDEX IF NOT EXISTS idx_products_category_score_active
  ON public.products (category_id, worthy_score DESC)
  WHERE is_active;

CREATE OR REPLACE FUNCTION public.get_better_alternatives(
  p_ref_ids   uuid[],
  p_limit_per int DEFAULT 24
)
RETURNS TABLE (
  ref_id         uuid,
  id             uuid,
  name           text,
  slug           text,
  gender         public.gender,
  brand_id       uuid,
  brand_name     text,
  brand_slug     text,
  market_segment public.market_segment,
  category_id    uuid,
  category_name  text,
  category_slug  text,
  category_family text,
  worthy_score   numeric,
  verdict        public.verdict,
  price          numeric,
  composition    jsonb,
  photo_urls     text[]
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
      array_position(ARRAY['ultra_fast', 'fast_fashion', 'premium', 'maison']::text[], rb.market_segment::text) AS ref_seg_pos
    FROM public.products r
    JOIN public.categories rc ON rc.id = r.category_id
    JOIN public.brands     rb ON rb.id = r.brand_id
    WHERE r.id = ANY(p_ref_ids)
  ),
  ranked AS (
    SELECT
      refs.ref_id,
      p.id, p.name, p.slug, p.gender, p.brand_id,
      b.name AS brand_name, b.slug AS brand_slug, b.market_segment,
      p.category_id, c.name AS category_name, c.slug AS category_slug,
      COALESCE(c.family, c.slug) AS category_family,
      p.worthy_score, p.verdict, p.price, p.composition, p.photo_urls,
      row_number() OVER (
        PARTITION BY refs.ref_id
        ORDER BY p.worthy_score DESC, p.id
      ) AS rn
    FROM refs
    JOIN public.categories c ON COALESCE(c.family, c.slug) = refs.ref_family
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
      -- Segmento ±1 (uno dei due ignoto/non mappato ⇒ ammesso, non blocca).
      AND (
        refs.ref_seg_pos IS NULL
        OR array_position(ARRAY['ultra_fast', 'fast_fashion', 'premium', 'maison']::text[], b.market_segment::text) IS NULL
        OR abs(array_position(ARRAY['ultra_fast', 'fast_fashion', 'premium', 'maison']::text[], b.market_segment::text) - refs.ref_seg_pos) <= 1
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
    market_segment, category_id, category_name, category_slug, category_family,
    worthy_score, verdict, price, composition, photo_urls
  FROM ranked
  WHERE rn <= GREATEST(1, LEAST(p_limit_per, 100));
$$;

REVOKE ALL ON FUNCTION public.get_better_alternatives(uuid[], int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_better_alternatives(uuid[], int)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.get_better_alternatives(uuid[], int) IS
  'Per ogni prodotto in p_ref_ids ritorna i top candidati "alternativa migliore" ammissibili (stessa famiglia categoria, gender compatibile, worthy_score >= riferimento, >= 51, segmento ±1, prezzo <= 2.5x), ordinati per worthy_score DESC. Il ranking fine è in @worthy/shared.';
