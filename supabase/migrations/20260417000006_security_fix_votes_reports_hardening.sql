-- ============================================================
-- SECURITY FIX: Hardening product_votes, product_reports,
-- policy admin per realtime, REVOKE defense-in-depth,
-- filtro is_active su products SELECT
--
-- VULNERABILITA CHIUSE:
--   V-006 (ALTO): defense-in-depth REVOKE su audit_log
--   V-007 (ALTO): product_votes UPDATE permette cambio product_id
--   V-008 (MEDIO): product_reports INSERT con status arbitrario
--   V-009 (MEDIO): products SELECT mostra soft-deleted
--
-- FIX AGGIUNTIVI:
--   - Policy SELECT per admin/moderator su product_duplicates
--     e product_reports (fix bug realtime in worthy-admin)
-- ============================================================


-- ============================================================
-- 1. PRODUCT_VOTES: proteggi product_id e user_id da UPDATE
-- ============================================================

CREATE OR REPLACE FUNCTION protect_product_votes_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  blocked_fields text[] := '{}';
  acting_user uuid;
BEGIN
  -- Bypass per service_role
  IF is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  IF NEW.product_id IS DISTINCT FROM OLD.product_id THEN
    blocked_fields := array_append(blocked_fields, 'product_id');
  END IF;

  IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    blocked_fields := array_append(blocked_fields, 'user_id');
  END IF;

  IF array_length(blocked_fields, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    acting_user := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    acting_user := NULL;
  END;

  PERFORM log_security_event('product_votes', OLD.id, acting_user, blocked_fields);

  RAISE EXCEPTION 'Attempt to modify immutable fields: %',
    array_to_string(blocked_fields, ', ')
    USING HINT = 'product_id and user_id on product_votes cannot be changed after creation.',
          ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_product_votes_protect ON product_votes;
CREATE TRIGGER trg_product_votes_protect
  BEFORE UPDATE ON product_votes
  FOR EACH ROW
  EXECUTE FUNCTION protect_product_votes_immutable();


-- ============================================================
-- 2. PRODUCT_REPORTS: forza status='pending' su INSERT
-- ============================================================

CREATE OR REPLACE FUNCTION protect_report_initial_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user uuid;
BEGIN
  -- Bypass per service_role (admin puo inserire con status diverso)
  IF is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  -- Se l'utente tenta di inserire con status diverso da 'pending'
  IF NEW.status IS DISTINCT FROM 'pending'::report_status THEN
    BEGIN
      acting_user := auth.uid();
    EXCEPTION WHEN OTHERS THEN
      acting_user := NULL;
    END;

    PERFORM log_security_event('product_reports', NEW.id, acting_user, ARRAY['status']);

    RAISE EXCEPTION 'Reports must be created with status pending, got: %', NEW.status
      USING HINT = 'Only service_role can create reports with non-pending status.',
            ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_product_reports_status ON product_reports;
CREATE TRIGGER trg_product_reports_status
  BEFORE INSERT ON product_reports
  FOR EACH ROW
  EXECUTE FUNCTION protect_report_initial_status();


-- ============================================================
-- 3. POLICY ADMIN per realtime worthy-admin
-- Permette a admin/moderator autenticati di leggere
-- product_duplicates e product_reports via anon key
-- (fix bug pre-esistente in use-realtime-counts.ts)
-- ============================================================

-- Admin/moderator possono leggere TUTTI i duplicati
CREATE POLICY "product_duplicates_select_admin"
  ON product_duplicates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
        AND u.role IN ('admin', 'moderator')
    )
  );

-- Admin/moderator possono leggere TUTTI i report
-- (la policy esistente product_reports_select_own resta per utenti normali)
CREATE POLICY "product_reports_select_admin"
  ON product_reports FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
        AND u.role IN ('admin', 'moderator')
    )
  );


-- ============================================================
-- 4. REVOKE defense-in-depth
-- ============================================================

-- audit_log: nessun client (anon o authenticated) deve accedere
-- I trigger che scrivono sono SECURITY DEFINER e bypassano i GRANT.
-- worthy-admin accede via service_role che bypassa anche i GRANT.
REVOKE ALL ON audit_log FROM anon, authenticated;

-- Tabelle reference: solo lettura da client, scrittura solo server
REVOKE INSERT, UPDATE, DELETE ON brands FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON categories FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON badges FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON daily_worthy FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON mattia_reviews FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON price_history FROM anon, authenticated;


-- ============================================================
-- 5. FIX products_select_public: filtra soft-deleted
-- ============================================================

DROP POLICY IF EXISTS "products_select_public" ON products;
CREATE POLICY "products_select_public"
  ON products FOR SELECT
  USING (is_active = true);
