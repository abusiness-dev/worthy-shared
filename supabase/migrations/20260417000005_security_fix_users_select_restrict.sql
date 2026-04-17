-- ============================================================
-- SECURITY FIX: Restringe SELECT sulla tabella users
--
-- VULNERABILITA CHIUSA:
--   V-001 (CRITICO): users_select_public con USING(true) espone
--   TUTTI i campi di TUTTI gli utenti a chiunque (incluso anon).
--   Dati esposti: email, role, trust_level, is_premium, error_rate,
--   premium_expires_at, last_active_date, points.
--   Violazione GDPR (email) e rischio sicurezza (admin discovery).
--
-- NUOVO COMPORTAMENTO:
--   - Utente autenticato: vede SOLO il proprio record completo
--   - Anon/authenticated per altri utenti: usa la vista
--     user_public_profiles che espone solo campi sicuri
--   - service_role: bypassa RLS come sempre
--
-- IMPATTO APP:
--   - worthy-app: nessun impatto (query gia filtrano per auth.uid())
--   - worthy-admin: nessun impatto (usa service_role)
--   - Future feature (leaderboard, profili pubblici): usare la vista
-- ============================================================

-- Rimuove la policy troppo permissiva
DROP POLICY IF EXISTS "users_select_public" ON users;

-- L'utente autenticato puo leggere SOLO il proprio profilo completo
CREATE POLICY "users_select_own"
  ON users FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- ============================================================
-- Vista pubblica: espone solo campi non sensibili
-- Disponibile a anon e authenticated per profili di altri utenti
--
-- security_barrier = true: impedisce al query planner di pushare
-- predicati utente nella view, prevenendo side-channel leaks.
--
-- security_invoker NON viene usato: la view deve bypassare
-- intenzionalmente la RLS di users per mostrare profili pubblici
-- a tutti. Con security_invoker = true, anon vedrebbe 0 righe
-- e authenticated solo la propria — vanificando lo scopo della vista.
--
-- Filtro trust_level: utenti bannati non appaiono nella vista.
--
-- CAMPI ESCLUSI dalla vista:
--   email, role, trust_level, is_premium, premium_expires_at,
--   error_rate, last_active_date, updated_at, onboarding_completed
-- ============================================================

CREATE OR REPLACE VIEW user_public_profiles
WITH (security_barrier = true) AS
SELECT
  id,
  display_name,
  avatar_url,
  points,
  products_contributed,
  products_verified,
  streak_days,
  created_at
FROM users
WHERE trust_level != 'banned';

COMMENT ON VIEW user_public_profiles IS
  'Vista pubblica dei profili utente. Solo campi non sensibili, esclusi utenti bannati. Bypassa RLS intenzionalmente (security_invoker=false). Usare per leaderboard e profili pubblici.';

-- Permetti lettura a tutti i ruoli
GRANT SELECT ON user_public_profiles TO anon, authenticated;
