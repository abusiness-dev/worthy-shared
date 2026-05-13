-- Security hardening - elimina warning "Security Definer View" del linter Supabase
-- portando user_public_profiles a security_invoker = true + RLS policy esplicite su users.
--
-- Contesto: prima di questa migration, la view aveva il default `security_invoker = false`,
-- ovvero bypassava le RLS policy e i GRANT della tabella `users`. L'unico filtro
-- era ciò che era scritto dentro la view (8 colonne safe + WHERE trust_level != 'banned').
-- Pattern fragile: una modifica futura distratta (aggiunta `email` alla SELECT,
-- JOIN su tabella sensibile, nuova policy users ignorata) avrebbe aperto una
-- fuga di dati senza alcun warning.
--
-- Soluzione defense-in-depth:
--   1. La view ora rispetta RLS della tabella sottostante (security_invoker = on)
--   2. Una policy esplicita su `users` permette anon/authenticated di leggere righe
--      non-bannate
--   3. Un column-level GRANT limita le colonne accessibili a anon/authenticated alle
--      sole 8 colonne safe. I campi sensibili (email, role, ecc.) restano accessibili
--      solo via la function get_my_profile() (per la propria riga) o via service_role.
--
-- Cosa cambia per i client:
--   - from('user_public_profiles').select()                 → invariato (funziona via policy + RLS)
--   - from('users').select('id, display_name, ...')         → ora FUNZIONA anche per altri user (era bloccato)
--   - from('users').select('*').eq('id', auth.uid())        → ROTTO: usa rpc('get_my_profile')
--   - from('users').select('email, role')                   → ROTTO: usa rpc('get_my_profile')
--   - from('users').update({...}).eq('id', auth.uid())      → invariato (UPDATE non revocato)

-- ============================================================
-- 1. La view eredita privilegi del chiamante
-- ============================================================

ALTER VIEW user_public_profiles SET (security_invoker = on);

-- ============================================================
-- 2. Policy: anon/authenticated possono leggere righe non-bannate
--    Convive con users_select_own (auth.uid() = id) in OR
-- ============================================================

CREATE POLICY "users_select_public_safe" ON users
  FOR SELECT
  TO anon, authenticated
  USING (trust_level != 'banned'::trust_level);

COMMENT ON POLICY "users_select_public_safe" ON users IS
  'Permette anon/authenticated di leggere users non-bannati. Le colonne accessibili sono limitate dal column-level GRANT (solo campi safe: id, display_name, avatar_url, points, products_contributed, products_verified, streak_days, created_at). I campi sensibili (email, role, trust_level, is_premium, ecc.) restano accessibili solo alla propria riga via get_my_profile() o via service_role.';

-- ============================================================
-- 3. Column-level GRANT: solo le 8 colonne safe sono leggibili da anon/authenticated
--    Il REVOKE rimuove il default GRANT Supabase su tabella intera.
-- ============================================================

REVOKE SELECT ON users FROM anon, authenticated;

GRANT SELECT (
  id,
  display_name,
  avatar_url,
  points,
  products_contributed,
  products_verified,
  streak_days,
  created_at
) ON users TO anon, authenticated;

-- ============================================================
-- 4. Function per leggere il PROPRIO profilo completo
--    Sostituisce il pattern `from('users').select('*').eq('id', auth.uid())`
--    che dopo il REVOKE non funziona più sui campi sensibili.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id uuid,
  email text,
  display_name text,
  avatar_url text,
  points integer,
  trust_level trust_level,
  role user_role,
  products_contributed integer,
  products_verified integer,
  error_rate numeric,
  streak_days integer,
  last_active_date date,
  is_premium boolean,
  premium_expires_at timestamptz,
  onboarding_completed boolean,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    u.id, u.email, u.display_name, u.avatar_url, u.points,
    u.trust_level, u.role, u.products_contributed, u.products_verified,
    u.error_rate, u.streak_days, u.last_active_date, u.is_premium,
    u.premium_expires_at, u.onboarding_completed, u.created_at, u.updated_at
  FROM users u
  WHERE u.id = auth.uid();
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

COMMENT ON FUNCTION public.get_my_profile() IS
  'Restituisce il profilo completo dell''utente autenticato (incluso email, role, is_premium). Da usare al posto di from(''users'').select(''*'').eq(''id'', auth.uid()) che dopo il column-level REVOKE non funziona più. SECURITY DEFINER perché legge campi sensibili dietro auth.uid() = id.';

-- ============================================================
-- 5. Aggiorna comment della view con la nuova architettura
-- ============================================================

COMMENT ON VIEW user_public_profiles IS
  'Profili pubblici per leaderboard/share. security_invoker = on: la view rispetta RLS della tabella users. La policy users_select_public_safe permette accesso a tutte le righe non-bannate; il column-level GRANT su users limita anon/authenticated a 8 colonne safe (id, display_name, avatar_url, points, products_contributed, products_verified, streak_days, created_at). Sostituisce il design v1 con security_invoker = off (bypass RLS) che il Supabase linter flaggava come anti-pattern.';
