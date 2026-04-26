-- ════════════════════════════════════════════════════════════════════
-- REVIEW: prodotti candidati a riassegnazione di categoria
--
-- Scopo: prima di applicare la migration `20260427000001_reassign_*`,
-- vedere quanti prodotti verranno riassegnati e quali sub-categoria
-- otterranno, in base al match regex sul nome del prodotto.
--
-- Esecuzione: copia/incolla nel SQL editor di Supabase.
-- Output: una riga per ogni prodotto che verrebbe spostato + flag confidence.
-- ════════════════════════════════════════════════════════════════════

WITH reassignments AS (
  SELECT
    p.id,
    p.name AS product_name,
    b.name AS brand_name,
    c_old.slug AS current_category,
    -- Calcolo della sub-categoria proposta secondo le stesse regole della migration
    CASE
      -- ────────────────────────────────────────────────────────────────
      -- Da 'jeans': se il nome contiene chino/cargo/jogger/eleganti
      --             il prodotto NON è un jeans → sposta nella famiglia pantaloni.
      --             Altrimenti raffina jeans-slim/regular/wide.
      -- ────────────────────────────────────────────────────────────────
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(chino|chinos)\M'                       THEN 'chinos'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(cargo)\M'                              THEN 'cargo'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(jogger|jogging|sweatpant)\M'           THEN 'jogger'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(elegant|sartori|tailored|dress\s*pant)\M' THEN 'pantaloni-eleganti'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(slim|skinny|tapered)\M'                THEN 'jeans-slim'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(wide|baggy|loose|relaxed|barrel)\M'    THEN 'jeans-wide'
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(regular|straight|classic)\M'           THEN 'jeans-regular'
      -- ────────────────────────────────────────────────────────────────
      -- Da 'pantaloni': raffina la sub
      -- ────────────────────────────────────────────────────────────────
      WHEN c_old.slug = 'pantaloni' AND p.name ~* '\m(chino|chinos)\M'                   THEN 'chinos'
      WHEN c_old.slug = 'pantaloni' AND p.name ~* '\m(cargo)\M'                          THEN 'cargo'
      WHEN c_old.slug = 'pantaloni' AND p.name ~* '\m(jogger|jogging|sweatpant|tuta)\M'  THEN 'jogger'
      WHEN c_old.slug = 'pantaloni' AND p.name ~* '\m(elegant|sartori|tailored|dress\s*pant|chino\s*formal)\M' THEN 'pantaloni-eleganti'
      -- ────────────────────────────────────────────────────────────────
      -- Da 't-shirt'
      -- ────────────────────────────────────────────────────────────────
      WHEN c_old.slug = 't-shirt' AND p.name ~* '\m(polo)\M'                             THEN 'polo'
      WHEN c_old.slug = 't-shirt' AND p.name ~* '\m(canotta|tank)\M'                     THEN 'canotta'
      WHEN c_old.slug = 't-shirt' AND p.name ~* '\m(oversize|oversized)\M'               THEN 't-shirt-oversize'
      WHEN c_old.slug = 't-shirt' AND p.name ~* '\m(basic|essential|plain)\M'            THEN 't-shirt-basic'
      -- ────────────────────────────────────────────────────────────────
      -- Da 'felpe'
      -- ────────────────────────────────────────────────────────────────
      WHEN c_old.slug = 'felpe' AND p.name ~* '\m(cardigan)\M'                           THEN 'cardigan'
      WHEN c_old.slug = 'felpe' AND p.name ~* '\m(maglione|sweater|knit|pullover)\M'     THEN 'maglione'
      WHEN c_old.slug = 'felpe' AND p.name ~* '\m(hood|cappuccio|hoodie)\M'              THEN 'felpa-cappuccio'
      WHEN c_old.slug = 'felpe' AND p.name ~* '\m(crew|girocollo|crewneck)\M'            THEN 'felpa-girocollo'
      -- ────────────────────────────────────────────────────────────────
      -- Da 'giacche'
      -- ────────────────────────────────────────────────────────────────
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(trench)\M'                           THEN 'trench'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(cappotto|coat|overcoat)\M'           THEN 'cappotto'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(piumino|down|puffer)\M'              THEN 'piumino'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(blazer)\M'                           THEN 'blazer'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(parka)\M'                            THEN 'parka'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(bomber)\M'                           THEN 'bomber'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(giubbotto)\M'                        THEN 'giubbotto'
      ELSE NULL
    END AS proposed_sub_slug
  FROM products p
  JOIN categories c_old ON p.category_id = c_old.id
  JOIN brands b ON p.brand_id = b.id
  WHERE c_old.slug IN ('jeans', 'pantaloni', 't-shirt', 'felpe', 'giacche')
    AND p.is_active = true
)
SELECT
  current_category,
  proposed_sub_slug,
  COUNT(*) AS prodotti_coinvolti,
  -- Esempi (max 5) per la review visiva
  array_agg(brand_name || ' — ' || product_name ORDER BY product_name) FILTER (WHERE proposed_sub_slug IS NOT NULL) AS esempi
FROM reassignments
WHERE proposed_sub_slug IS NOT NULL
GROUP BY current_category, proposed_sub_slug
ORDER BY current_category, prodotti_coinvolti DESC;

-- ─────────────────────────────────────────────────────────────────────
-- Sezione 2: prodotti che NON ricevono nessuna proposta (resteranno nelle
-- categorie generiche). Utile per controllo qualità — se troppi sono in
-- una categoria generica, il mapping va arricchito.
-- ─────────────────────────────────────────────────────────────────────
WITH reassignments AS (
  SELECT
    p.id,
    p.name AS product_name,
    b.name AS brand_name,
    c_old.slug AS current_category,
    CASE
      WHEN c_old.slug = 'jeans' AND p.name ~* '\m(chino|chinos|cargo|jogger|jogging|sweatpant|elegant|sartori|tailored|dress\s*pant|slim|skinny|tapered|wide|baggy|loose|relaxed|barrel|regular|straight|classic)\M' THEN 'matched'
      WHEN c_old.slug = 'pantaloni' AND p.name ~* '\m(chino|chinos|cargo|jogger|jogging|sweatpant|tuta|elegant|sartori|tailored|dress\s*pant)\M' THEN 'matched'
      WHEN c_old.slug = 't-shirt' AND p.name ~* '\m(polo|canotta|tank|oversize|oversized|basic|essential|plain)\M' THEN 'matched'
      WHEN c_old.slug = 'felpe' AND p.name ~* '\m(cardigan|maglione|sweater|knit|pullover|hood|cappuccio|hoodie|crew|girocollo|crewneck)\M' THEN 'matched'
      WHEN c_old.slug = 'giacche' AND p.name ~* '\m(trench|cappotto|coat|overcoat|piumino|down|puffer|blazer|parka|bomber|giubbotto)\M' THEN 'matched'
      ELSE 'unmatched'
    END AS status
  FROM products p
  JOIN categories c_old ON p.category_id = c_old.id
  JOIN brands b ON p.brand_id = b.id
  WHERE c_old.slug IN ('jeans', 'pantaloni', 't-shirt', 'felpe', 'giacche')
    AND p.is_active = true
)
SELECT
  current_category,
  status,
  COUNT(*) AS totale,
  array_agg(brand_name || ' — ' || product_name ORDER BY product_name) FILTER (WHERE status = 'unmatched') AS esempi_unmatched
FROM reassignments
GROUP BY current_category, status
ORDER BY current_category, status;
