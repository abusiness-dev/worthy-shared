-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 7) — housekeeping: indici ridondanti/morti, indici FK
-- opzionali, search_path mancante, policy daily_worthy.
-- ════════════════════════════════════════════════════════════════════

-- 1. Indici ridondanti/morti -------------------------------------------------
-- Duplicato funzionale di idx_products_category_score (stesse colonne, stesso
-- predicato is_active): il planner usa l'altro. Tenere uno solo.
DROP INDEX IF EXISTS idx_products_category_score_active;

-- Boolean a 2 valori su tabella di poche decine di righe: il planner fa sempre
-- seq scan → indice inutile.
DROP INDEX IF EXISTS idx_categories_is_supported;

-- 2. Indici FK opzionali su tabelle a BASSA scrittura ------------------------
-- Costo di mantenimento trascurabile (scritture rare), migliorano i CASCADE/SET NULL
-- e i lookup admin. Tabelle piccole pre-lancio → CREATE INDEX semplice.
CREATE INDEX IF NOT EXISTS idx_audit_log_user
  ON public.audit_log (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_brand_id
  ON public.products (brand_id);
CREATE INDEX IF NOT EXISTS idx_daily_worthy_product
  ON public.daily_worthy (product_id);
CREATE INDEX IF NOT EXISTS idx_product_duplicates_product
  ON public.product_duplicates (product_id);
CREATE INDEX IF NOT EXISTS idx_product_duplicates_dup_of
  ON public.product_duplicates (duplicate_of);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge
  ON public.user_badges (badge_id);

-- 3. trigger_set_updated_at: aggiunge SET search_path (unica trigger-fn rimasta senza)
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 4. daily_worthy: non esporre l'editoriale di date FUTURE (se pre-caricate da admin)
DROP POLICY IF EXISTS "daily_worthy_select_public" ON public.daily_worthy;
CREATE POLICY "daily_worthy_select_public"
  ON public.daily_worthy FOR SELECT
  USING (featured_date <= current_date);
