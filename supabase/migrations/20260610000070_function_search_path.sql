-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (linter) — fissa search_path sulle ultime 3 funzioni NOSTRE
-- che ne erano prive (Supabase linter: function_search_path_mutable).
--
-- Tutte e 3 sono SECURITY INVOKER (prosecdef=false), quindi il rischio reale è basso
-- (girano coi privilegi del chiamante), ma fissare il search_path è la best practice
-- e pulisce i warning del linter. ALTER FUNCTION SET non riscrive il corpo.
--
-- Le altre funzioni "mutable" segnalate dal linter (gin_*, gtrgm_*, similarity*,
-- word_similarity*, set_limit, show_*) appartengono all'estensione pg_trgm in public e
-- NON sono nostre: non si toccano (eventuale fix = spostare l'estensione di schema,
-- fuori scope).
-- ════════════════════════════════════════════════════════════════════

ALTER FUNCTION public.calculate_manufacturing_lens(uuid)  SET search_path = public, pg_temp;
ALTER FUNCTION public.recalculate_brand_avg_scores()      SET search_path = public, pg_temp;
ALTER FUNCTION public.normalize_country_to_iso2(text)     SET search_path = public, pg_temp;
