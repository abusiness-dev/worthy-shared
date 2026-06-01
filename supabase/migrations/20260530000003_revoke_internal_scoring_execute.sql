-- ============================================================
-- SECURITY FIX (F8 — defense-in-depth): rimuove l'EXECUTE di default a PUBLIC
-- sulle funzioni di scoring interne.
--
-- PROBLEMA:
--   In PostgreSQL CREATE FUNCTION concede EXECUTE a PUBLIC per default. Nessuna
--   migration aveva fatto REVOKE su calculate_worthy_score / _v2 / calculate_qpr
--   / recalculate_* / ecc. ⇒ erano invocabili come RPC PostgREST da anon e
--   authenticated. calculate_worthy_score è SECURITY DEFINER e scrive su
--   products (via worthy.skip_protection): un anon poteva forzare il ricalcolo/
--   overwrite dello score di QUALSIASI prodotto (impatto limitato — ricalcola il
--   valore corretto, non inietta un valore arbitrario — ma è un percorso di
--   scrittura non autenticato + carico DB).
--
-- PERCHÉ NON ROMPE NULLA:
--   Il ricalcolo avviene tramite trigger. L'unico trigger su questo hot-path che
--   era SECURITY INVOKER è trigger_calculate_worthy_score (AFTER INSERT/UPDATE su
--   products) — chiamando le scoring fn come l'utente invocante, una REVOKE da
--   authenticated lo romperebbe. Qui lo convertiamo a SECURITY DEFINER: l'intera
--   catena di ricalcolo gira come owner (postgres), che mantiene EXECUTE a
--   prescindere dai GRANT. Idem trigger_recalc_v2_on_link_change. Tutti gli altri
--   trigger di scoring (protect_product_privileged_fields, qpr aggregates,
--   recalc_v2) erano GIÀ SECURITY DEFINER. service_role NON viene toccato →
--   worthy-admin (service_role) continua a funzionare.
--
-- ⚠️ P2 / post-lancio. VALIDARE con `supabase db reset` (Docker) prima di
--   `npm run db:push`: un INSERT prodotto da utente authenticated deve andare a
--   buon fine e popolare worthy_score; una chiamata rpc('calculate_worthy_score')
--   come anon/authenticated deve dare "permission denied".
-- ============================================================

-- 1. Converte a SECURITY DEFINER il trigger di ricalcolo (hot-path INSERT/UPDATE
--    products). Corpo identico alla versione dual-write (20260427000012).
CREATE OR REPLACE FUNCTION trigger_calculate_worthy_score()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR
     OLD.composition IS DISTINCT FROM NEW.composition OR
     OLD.price IS DISTINCT FROM NEW.price OR
     OLD.category_id IS DISTINCT FROM NEW.category_id
  THEN
    -- v1: calcolo principale (worthy_score visibile in app)
    PERFORM calculate_worthy_score(NEW.id);

    -- v2: dual-write shadow su score_breakdown.
    BEGIN
      PERFORM calculate_worthy_score_v2(NEW.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'calculate_worthy_score_v2 failed for product %: %', NEW.id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_calculate_worthy_score IS
  'Trigger di scoring (v1 canonico + v2 shadow). SECURITY DEFINER: la catena di ricalcolo gira come owner, indipendente dai GRANT EXECUTE delle scoring fn (vedi F8 / 20260530000003).';

-- 2. Converte a SECURITY DEFINER anche il recalc sui link tables (oggi attivo
--    solo su product_certifications, scrivibile da service_role). Corpo identico
--    alla versione 20260427000012.
CREATE OR REPLACE FUNCTION trigger_recalc_v2_on_link_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_product_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_product_id := OLD.product_id;
  ELSE
    target_product_id := NEW.product_id;
  END IF;

  BEGIN
    PERFORM calculate_worthy_score_v2(target_product_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'calculate_worthy_score_v2 failed on link change for product %: %', target_product_id, SQLERRM;
  END;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- 3. REVOKE EXECUTE da PUBLIC/anon/authenticated su tutte le scoring fn interne.
--    DO-block per regprocedure → robusto a firme e overload. service_role NON
--    incluso (mantiene l'accesso per worthy-admin).
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'calculate_worthy_score',
        'calculate_worthy_score_v2',
        'calculate_qpr',
        'calculate_composition_score',
        'calculate_score_inline',
        'recalculate_brand_avg_scores',
        'recalculate_category_medians',
        'recalculate_category_segment_aggregates',
        'find_potential_duplicates'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated;', r.sig);
    RAISE NOTICE 'F8: REVOKE EXECUTE su %', r.sig;
  END LOOP;
END $$;
