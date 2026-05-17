-- RPC: get_brand_ids_by_gender()
--
-- Sostituisce il pattern client-side che faceva fetch di 10K row da products
-- (select brand_id, gender + limit 10000) solo per dedup-are i brand_id per
-- gender. Quel pattern era pessimo:
--   - banda mobile sprecata
--   - cresce linearmente col catalogo
--   - latenza al cold-start
--
-- Questa RPC fa l'aggregato server-side in una sola lettura, usando
-- l'indice idx_products_gender già esistente (vedi migration
-- 20260330000001_add_gender_to_products.sql).
--
-- Returns: una singola riga con due array di uuid:
--   - men_ids: brand_id con almeno 1 prodotto 'uomo' o 'unisex'
--   - women_ids: brand_id con almeno 1 prodotto 'donna' o 'unisex'
--
-- Sicurezza: SECURITY INVOKER (default) — rispetta le RLS di products.
-- Sia anon che authenticated possono leggere products (catalogo pubblico),
-- quindi la function va bene per entrambi i ruoli.

CREATE OR REPLACE FUNCTION public.get_brand_ids_by_gender()
RETURNS TABLE (men_ids uuid[], women_ids uuid[])
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT
    ARRAY(
      SELECT DISTINCT brand_id
      FROM products
      WHERE is_active = true
        AND gender IN ('uomo', 'unisex')
    ) AS men_ids,
    ARRAY(
      SELECT DISTINCT brand_id
      FROM products
      WHERE is_active = true
        AND gender IN ('donna', 'unisex')
    ) AS women_ids;
$$;

GRANT EXECUTE ON FUNCTION public.get_brand_ids_by_gender() TO anon, authenticated;

COMMENT ON FUNCTION public.get_brand_ids_by_gender() IS
  'Ritorna i brand_id raggruppati per gender match (men_ids: uomo+unisex, women_ids: donna+unisex). Sostituisce il fetch da 10K row che il client faceva in useBrandIdsByGender al cold-start. STABLE: il risultato è deterministico nella stessa transazione.';
