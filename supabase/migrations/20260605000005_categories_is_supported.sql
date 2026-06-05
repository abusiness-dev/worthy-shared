-- ════════════════════════════════════════════════════════════════════
-- Migration: esclusione categorie non adatte al Worthy Score
--
-- Worthy valuta capi tessili con metriche di composizione/filiera/QPR. Categorie
-- come calzature, intimo/calze, costumi e accessori (pelle/mix, design-driven)
-- non sono valutabili in modo significativo e vengono ESCLUSE:
--   - non selezionabili (dropdown app filtra is_supported);
--   - non inseribili (trigger di rifiuto, vale per qualunque ruolo);
--   - non mostrate come alternative (vedi 20260605000007);
--   - i prodotti legacy in queste categorie vengono rimossi (vedi 20260605000006).
--
-- Meccanismo: colonna categories.is_supported boolean NOT NULL DEFAULT true.
-- Idempotente.
-- ════════════════════════════════════════════════════════════════════

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS is_supported boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.categories.is_supported IS
  'false ⇒ categoria non valutabile dal Worthy Score (calzature, intimo, calze, costumi, accessori, activewear). Non selezionabile, non inseribile, esclusa dalle alternative.';

-- Categorie escluse (calzature, intimo/calze, costumi, accessori, activewear).
UPDATE public.categories
SET is_supported = false
WHERE slug IN (
  -- calzature
  'sneakers', 'scarpe-eleganti',
  -- intimo e calze
  'intimo', 'calzini',
  -- costumi
  'costume',
  -- accessori
  'accessori', 'cappelli', 'sciarpe', 'cinture', 'borse',
  -- activewear
  'top-sportivo', 'leggings', 'tuta'
);

CREATE INDEX IF NOT EXISTS idx_categories_is_supported
  ON public.categories (is_supported);

-- ============================================================
-- Trigger: rifiuta INSERT/UPDATE di prodotti in categorie non supportate.
-- Vale per QUALUNQUE ruolo (anche service_role/scraper): le categorie escluse
-- non devono mai esistere a catalogo.
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_unsupported_category()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  supported boolean;
BEGIN
  SELECT is_supported INTO supported
  FROM categories
  WHERE id = NEW.category_id;

  IF supported IS NOT NULL AND supported = false THEN
    RAISE EXCEPTION 'Category % is not supported by Worthy Score', NEW.category_id
      USING HINT = 'Calzature, intimo, calze, costumi, accessori e activewear non sono valutabili.',
            ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_products_reject_unsupported_category ON public.products;
CREATE TRIGGER trg_products_reject_unsupported_category
  BEFORE INSERT OR UPDATE OF category_id ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.reject_unsupported_category();

COMMENT ON FUNCTION public.reject_unsupported_category IS
  'Blocca INSERT/UPDATE di prodotti in categorie con is_supported = false. Nessun bypass per ruolo.';
