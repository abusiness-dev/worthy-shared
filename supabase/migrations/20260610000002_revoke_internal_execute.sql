-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 1.2) — completa F8: REVOKE EXECUTE sulle funzioni
-- interne introdotte DOPO 20260530000003.
--
-- PROBLEMA:
--   Il DO-block F8 (20260530000003:106-116) revoca l'EXECUTE di default a PUBLIC
--   su 9 funzioni di scoring, ma NON copre 3 funzioni introdotte/riscritte dopo:
--     - recalculate_category_tier_aggregates  (SECURITY DEFINER + SCRIVE su
--       category_tier_aggregates → un anon/authenticated potrebbe forzare ricalcoli
--       /UPSERT non autenticati = carico DB + scrittura indiretta sugli aggregati);
--     - compute_quality_index (IMMUTABLE, pura) e calculate_qpr_cluster (STABLE,
--       read-only): rischio minore (information disclosure), ma coerenza di policy.
--   La voce recalculate_category_segment_aggregates resta nel set ma è ormai
--   deprecata (no-op se già revocata).
--
-- SOLUZIONE: stesso pattern DO-block/regprocedure (robusto a overload). service_role
--   NON toccato. Idempotente.
--
-- VALIDARE: rpc('recalculate_category_tier_aggregates', ...) come authenticated →
--   "permission denied"; i trigger di scoring continuano a funzionare (girano come
--   owner).
-- ════════════════════════════════════════════════════════════════════

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
        'recalculate_category_tier_aggregates',
        'compute_quality_index',
        'calculate_qpr_cluster',
        'recalculate_category_segment_aggregates'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated;', r.sig);
    RAISE NOTICE 'F8 (cont.): REVOKE EXECUTE su %', r.sig;
  END LOOP;
END $$;
