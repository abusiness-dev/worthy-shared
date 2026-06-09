-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 1.1) — RLS/REVOKE sulle tabelle di riferimento
-- del QPR cluster-based.
--
-- PROBLEMA:
--   category_tier_aggregates (20260605000004) e comparison_tiers (20260605000003)
--   sono state create SENZA `ENABLE ROW LEVEL SECURITY` e SENZA REVOKE. Con i
--   GRANT PostgREST di default sui ruoli anon/authenticated, un utente autenticato
--   può INSERT/UPDATE/DELETE direttamente via PostgREST le mediane che guidano il
--   fair-price (QPR) di INTERE categorie/leghe → avvelenamento dello scoring
--   mostrato a tutti. Il predecessore category_segment_aggregates era invece
--   protetto (vedi 20260513000001:95-101).
--
-- SOLUZIONE (allineata a 20260513000001):
--   RLS ON + policy SELECT pubblica (lettura ok) + REVOKE INSERT/UPDATE/DELETE da
--   anon/authenticated. I trigger SECURITY DEFINER (owner=postgres) continuano a
--   UPSERT bypassando la RLS. Idempotente.
--
-- VALIDARE con `supabase db reset`: come authenticated, un INSERT/UPDATE su queste
--   tabelle via PostgREST deve dare "permission denied"; il SELECT resta ok; lo
--   scoring engine (trigger) continua a popolare gli aggregati.
-- ════════════════════════════════════════════════════════════════════

-- category_tier_aggregates -------------------------------------------------
ALTER TABLE public.category_tier_aggregates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS category_tier_aggregates_select_public ON public.category_tier_aggregates;
CREATE POLICY category_tier_aggregates_select_public
  ON public.category_tier_aggregates FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.category_tier_aggregates FROM anon, authenticated;

-- comparison_tiers ---------------------------------------------------------
ALTER TABLE public.comparison_tiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS comparison_tiers_select_public ON public.comparison_tiers;
CREATE POLICY comparison_tiers_select_public
  ON public.comparison_tiers FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.comparison_tiers FROM anon, authenticated;
