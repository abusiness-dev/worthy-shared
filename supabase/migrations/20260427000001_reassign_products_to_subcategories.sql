-- ════════════════════════════════════════════════════════════════════
-- Migration: riassegna prodotti dalle categorie generiche legacy
-- (`jeans`, `pantaloni`, `t-shirt`, `felpe`, `giacche`) alle sub-categoria
-- corretta in base al match regex sul nome del prodotto.
--
-- Idempotente: gli UPDATE filtrano sul `category_id` attuale, quindi una
-- seconda esecuzione non altera prodotti già spostati.
--
-- Per validare l'effetto prima dell'apply, eseguire prima:
--   `worthy-shared/scripts/review-category-reassignments.sql`
-- ════════════════════════════════════════════════════════════════════

-- Helper CTE per recuperare gli id delle categorie target una sola volta.
-- Eseguito inline in ogni UPDATE per restare in un singolo file SQL,
-- senza creare oggetti permanenti.

-- ─── Da 'jeans' ────────────────────────────────────────────────────
-- Prodotti che NON sono jeans → spostati nella famiglia pantaloni
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'chinos')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(chino|chinos)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'cargo')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(cargo)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'jogger')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(jogger|jogging|sweatpant)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'pantaloni-eleganti')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(elegant|sartori|tailored|dress\s*pant)\M';

-- Veri jeans → raffinati in slim / wide / regular (default rimane in 'jeans')
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'jeans-slim')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(slim|skinny|tapered)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'jeans-wide')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(wide|baggy|loose|relaxed|barrel)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'jeans-regular')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'jeans')
  AND name ~* '\m(regular|straight|classic)\M';

-- ─── Da 'pantaloni' ────────────────────────────────────────────────
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'chinos')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'pantaloni')
  AND name ~* '\m(chino|chinos)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'cargo')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'pantaloni')
  AND name ~* '\m(cargo)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'jogger')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'pantaloni')
  AND name ~* '\m(jogger|jogging|sweatpant|tuta)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'pantaloni-eleganti')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'pantaloni')
  AND name ~* '\m(elegant|sartori|tailored|dress\s*pant|chino\s*formal)\M';

-- ─── Da 't-shirt' ──────────────────────────────────────────────────
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'polo')
WHERE category_id = (SELECT id FROM categories WHERE slug = 't-shirt')
  AND name ~* '\m(polo)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'canotta')
WHERE category_id = (SELECT id FROM categories WHERE slug = 't-shirt')
  AND name ~* '\m(canotta|tank)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 't-shirt-oversize')
WHERE category_id = (SELECT id FROM categories WHERE slug = 't-shirt')
  AND name ~* '\m(oversize|oversized)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 't-shirt-basic')
WHERE category_id = (SELECT id FROM categories WHERE slug = 't-shirt')
  AND name ~* '\m(basic|essential|plain)\M';

-- ─── Da 'felpe' ────────────────────────────────────────────────────
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'cardigan')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'felpe')
  AND name ~* '\m(cardigan)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'maglione')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'felpe')
  AND name ~* '\m(maglione|sweater|knit|pullover)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'felpa-cappuccio')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'felpe')
  AND name ~* '\m(hood|cappuccio|hoodie)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'felpa-girocollo')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'felpe')
  AND name ~* '\m(crew|girocollo|crewneck)\M';

-- ─── Da 'giacche' ──────────────────────────────────────────────────
-- Ordine pensato per evitare overlap (es. 'giubbotto' non deve catturare
-- prima che blazer/parka/bomber abbiano avuto chance di matchare).
UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'trench')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(trench)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'cappotto')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(cappotto|coat|overcoat)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'piumino')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(piumino|down|puffer)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'blazer')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(blazer)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'parka')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(parka)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'bomber')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(bomber)\M';

UPDATE products SET category_id = (SELECT id FROM categories WHERE slug = 'giubbotto')
WHERE category_id = (SELECT id FROM categories WHERE slug = 'giacche')
  AND name ~* '\m(giubbotto)\M';

-- ─── Sanity check finale ───────────────────────────────────────────
-- Ricalcola product_count statico sulle categorie (campo legacy in `categories`).
UPDATE categories c
SET product_count = sub.cnt
FROM (
  SELECT category_id, COUNT(*) AS cnt
  FROM products
  WHERE is_active = true
  GROUP BY category_id
) sub
WHERE c.id = sub.category_id;

-- Categorie senza prodotti attivi → product_count = 0
UPDATE categories
SET product_count = 0
WHERE id NOT IN (
  SELECT DISTINCT category_id FROM products WHERE is_active = true
);

-- Refresh della materialized view ranking (se esiste). Nessun errore se assente.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'brand_rankings') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY brand_rankings;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- CONCURRENTLY richiede un unique index; in caso fallisca, fa un refresh non-concurrent.
  REFRESH MATERIALIZED VIEW brand_rankings;
END $$;
