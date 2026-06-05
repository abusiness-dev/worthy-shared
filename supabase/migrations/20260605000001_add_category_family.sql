-- ════════════════════════════════════════════════════════════════════
-- Migration: famiglia di categoria (categories.family)
--
-- Problema: la tassonomia è sdoppiata. Le categorie "legacy" (t-shirt, felpe,
-- jeans, pantaloni, giacche, camicie, shorts) coesistono con le sotto-categorie
-- fini introdotte da 20260427000001_reassign_products_to_subcategories. I prodotti
-- che non hanno matchato la regex di riassegnazione sono RIMASTI nello slug legacy,
-- quindi il match delle "alternative" per category_id esatto frammenta il pool
-- (un capo in 't-shirt' non vede mai i candidati in 't-shirt-basic').
--
-- Soluzione: una colonna `family` che raggruppa ciascun parent legacy con le sue
-- sotto-categorie (le stesse relazioni parent→child già usate dalla migration di
-- riassegnazione). Le categorie non raggruppate restano family = NULL e il
-- matching fa fallback allo slug esatto (COALESCE nella RPC get_better_alternatives).
--
-- Idempotente: gli UPDATE sono per slug; ri-eseguire non cambia nulla.
-- ════════════════════════════════════════════════════════════════════

ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS family text;

COMMENT ON COLUMN public.categories.family IS
  'Famiglia di categoria per il matching delle alternative: raggruppa il parent legacy con le sue sotto-categorie. NULL ⇒ la categoria matcha solo se stessa (fallback allo slug).';

-- T-shirt & top leggeri (parent legacy: t-shirt)
UPDATE public.categories SET family = 't-shirt'
WHERE slug IN ('t-shirt', 't-shirt-basic', 't-shirt-oversize', 'polo', 'canotta');

-- Camicie (slug duplicato legacy/singolare)
UPDATE public.categories SET family = 'camicie'
WHERE slug IN ('camicie', 'camicia');

-- Felpe & maglieria (parent legacy: felpe)
UPDATE public.categories SET family = 'felpe'
WHERE slug IN ('felpe', 'felpa-cappuccio', 'felpa-girocollo', 'maglione', 'cardigan');

-- Jeans (parent legacy: jeans)
UPDATE public.categories SET family = 'jeans'
WHERE slug IN ('jeans', 'jeans-slim', 'jeans-regular', 'jeans-wide');

-- Pantaloni (parent legacy: pantaloni)
UPDATE public.categories SET family = 'pantaloni'
WHERE slug IN ('pantaloni', 'chinos', 'cargo', 'jogger', 'pantaloni-eleganti');

-- Giacche & capispalla (parent legacy: giacche)
UPDATE public.categories SET family = 'giacche'
WHERE slug IN ('giacche', 'bomber', 'parka', 'blazer', 'piumino', 'giubbotto', 'trench', 'cappotto');

-- Shorts
UPDATE public.categories SET family = 'shorts'
WHERE slug IN ('shorts', 'shorts-sportivi');

-- NB: tutte le altre categorie (sneakers, scarpe-eleganti, intimo, calzini,
-- accessori, cappelli, sciarpe, cinture, borse, costume, leggings, tuta,
-- top-sportivo, ...) restano family = NULL → matchano solo se stesse.

CREATE INDEX IF NOT EXISTS idx_categories_family ON public.categories (family);
