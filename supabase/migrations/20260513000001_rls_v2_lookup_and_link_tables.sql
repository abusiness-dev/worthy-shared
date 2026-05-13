-- Security hardening - Abilita RLS sulle 5 tabelle v2 che ne erano sprovviste.
--
-- Contesto: il Supabase Security Advisor (11/05/2026) ha rilevato che le
-- seguenti tabelle nello schema `public` non avevano Row Level Security
-- abilitato. Erano state create dalle migration v2 del 27-28 aprile 2026,
-- successive al PR di RLS hardening del 17 aprile, e quindi non coperte.
--
-- Tabelle interessate:
--   - countries                      (anagrafica ISO2 + manufacturing_score)
--   - certifications                 (anagrafica certificazioni tessili)
--   - product_certifications         (link N:M product↔certification)
--   - brand_certifications           (link N:M brand↔certification)
--   - category_segment_aggregates    (median QPR cluster categoria × market_segment)
--
-- Modello di accesso:
--   - SELECT: pubblico (USING true). Dati legittimamente pubblici, usati per
--     spiegabilità score, badge prodotto/brand e cluster QPR.
--   - INSERT/UPDATE/DELETE: revocate ad anon e authenticated. Le scritture
--     avvengono solo via:
--       * service_role (scraper, dashboard admin) - bypassa RLS by design
--       * trigger SECURITY DEFINER (es. trigger_recalc_qpr_aggregates per
--         category_segment_aggregates, trigger_recalc_v2_on_link_change per
--         product_certifications)
--
-- Pattern allineato a quello già usato per `brands`, `categories`, `fibers`
-- nelle migration 20260326000020 e 20260417000006.
--
-- Niente cambi lato TypeScript / app: il client anon mantiene accesso SELECT;
-- service_role mantiene accesso pieno.

-- ============================================================
-- 1. countries (anagrafica ISO2 + manufacturing_score)
-- ============================================================

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "countries_select_public" ON countries
  FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON countries FROM anon, authenticated;

COMMENT ON POLICY "countries_select_public" ON countries IS
  'Lookup pubblica anagrafica paesi. Write solo via service_role.';

-- ============================================================
-- 2. certifications (anagrafica certificazioni tessili)
-- ============================================================

ALTER TABLE certifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "certifications_select_public" ON certifications
  FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON certifications FROM anon, authenticated;

COMMENT ON POLICY "certifications_select_public" ON certifications IS
  'Lookup pubblica certificazioni. Write solo via service_role.';

-- ============================================================
-- 3. product_certifications (link N:M product↔certification)
-- ============================================================

ALTER TABLE product_certifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_certifications_select_public" ON product_certifications
  FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON product_certifications FROM anon, authenticated;

COMMENT ON POLICY "product_certifications_select_public" ON product_certifications IS
  'Read pubblico per esposizione badge/score. Write solo via service_role (scraper) o trigger SECURITY DEFINER (recalc breakdown).';

-- ============================================================
-- 4. brand_certifications (link N:M brand↔certification)
-- ============================================================

ALTER TABLE brand_certifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "brand_certifications_select_public" ON brand_certifications
  FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON brand_certifications FROM anon, authenticated;

COMMENT ON POLICY "brand_certifications_select_public" ON brand_certifications IS
  'Read pubblico per esposizione badge brand. Write solo via service_role (seed) o trigger.';

-- ============================================================
-- 5. category_segment_aggregates (median QPR cluster-based)
-- ============================================================

ALTER TABLE category_segment_aggregates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "category_segment_aggregates_select_public" ON category_segment_aggregates
  FOR SELECT
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON category_segment_aggregates FROM anon, authenticated;

COMMENT ON POLICY "category_segment_aggregates_select_public" ON category_segment_aggregates IS
  'Read pubblico per spiegabilità QPR (categoria × market_segment). Write solo via trigger trg_products_qpr_aggregates SECURITY DEFINER.';

-- ============================================================
-- 6. Documenta false-positive del linter su user_public_profiles
-- ============================================================

COMMENT ON VIEW user_public_profiles IS
  'Profili pubblici per leaderboard/share. La view bypassa intenzionalmente l''RLS di public.users (security_invoker = false di default) per esporre i soli campi safe (id, display_name, avatar_url, points, products_contributed, products_verified, streak_days, created_at) ad anon+authenticated. Il filtro trust_level != ''banned'' è applicato in WHERE. Il Supabase linter segnala "Security Definer View" come false positive: il design è verificato, NON convertire a security_invoker = true (vanificherebbe leaderboard per anon).';
