-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 3.2) — wrapping di auth.uid() in (select auth.uid())
-- nelle policy RLS user-scoped (ottimizzazione InitPlan).
--
-- PROBLEMA:
--   Tutte le policy user-scoped usano auth.uid() "nudo": Postgres lo ri-valuta PER
--   RIGA. Avvolgendolo in (select auth.uid()) il planner lo promuove a InitPlan
--   (valutato UNA volta per query). Nessun cambio di semantica/sicurezza.
--
-- SCOPE: solo le policy che contengono auth.uid(). NON toccate:
--   - products_select_public (is_active = true), users_select_public_safe
--     (trust_level != 'banned'), policy lookup/link v2 USING(true): non usano auth.uid().
--   - users_select_own resta ACCANTO a users_select_public_safe (NON è ridondante:
--     un utente bannato deve poter leggere il proprio profilo completo).
--
-- Idempotente: DROP POLICY IF EXISTS + CREATE con definizione identica salvo il wrap.
-- VALIDARE con `supabase db reset` + smoke test RLS (un utente vede solo le proprie righe).
-- ════════════════════════════════════════════════════════════════════

-- ---------- products ----------
DROP POLICY IF EXISTS "products_insert_auth" ON public.products;
CREATE POLICY "products_insert_auth"
  ON public.products FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = contributed_by);

DROP POLICY IF EXISTS "products_update_own_recent" ON public.products;
CREATE POLICY "products_update_own_recent"
  ON public.products FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = contributed_by AND created_at > now() - interval '24 hours')
  WITH CHECK ((select auth.uid()) = contributed_by);

-- ---------- users ----------
DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "users_select_own" ON public.users;
CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = id);

-- ---------- product_votes ----------
DROP POLICY IF EXISTS "product_votes_insert_auth" ON public.product_votes;
CREATE POLICY "product_votes_insert_auth"
  ON public.product_votes FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "product_votes_update_own" ON public.product_votes;
CREATE POLICY "product_votes_update_own"
  ON public.product_votes FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- ---------- product_reports ----------
DROP POLICY IF EXISTS "product_reports_insert_auth" ON public.product_reports;
CREATE POLICY "product_reports_insert_auth"
  ON public.product_reports FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "product_reports_select_own" ON public.product_reports;
CREATE POLICY "product_reports_select_own"
  ON public.product_reports FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "product_reports_select_admin" ON public.product_reports;
CREATE POLICY "product_reports_select_admin"
  ON public.product_reports FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = (select auth.uid())
        AND u.role IN ('admin', 'moderator')
    )
  );

-- ---------- product_duplicates ----------
DROP POLICY IF EXISTS "product_duplicates_select_admin" ON public.product_duplicates;
CREATE POLICY "product_duplicates_select_admin"
  ON public.product_duplicates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = (select auth.uid())
        AND u.role IN ('admin', 'moderator')
    )
  );

-- ---------- scan_history ----------
DROP POLICY IF EXISTS "scan_history_select_own" ON public.scan_history;
CREATE POLICY "scan_history_select_own"
  ON public.scan_history FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "scan_history_insert_own" ON public.scan_history;
CREATE POLICY "scan_history_insert_own"
  ON public.scan_history FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "scan_history_delete_own" ON public.scan_history;
CREATE POLICY "scan_history_delete_own"
  ON public.scan_history FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ---------- saved_products ----------
DROP POLICY IF EXISTS "saved_products_select_own" ON public.saved_products;
CREATE POLICY "saved_products_select_own"
  ON public.saved_products FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "saved_products_insert_own" ON public.saved_products;
CREATE POLICY "saved_products_insert_own"
  ON public.saved_products FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "saved_products_delete_own" ON public.saved_products;
CREATE POLICY "saved_products_delete_own"
  ON public.saved_products FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ---------- saved_comparisons ----------
DROP POLICY IF EXISTS "saved_comparisons_select_own" ON public.saved_comparisons;
CREATE POLICY "saved_comparisons_select_own"
  ON public.saved_comparisons FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "saved_comparisons_insert_own" ON public.saved_comparisons;
CREATE POLICY "saved_comparisons_insert_own"
  ON public.saved_comparisons FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "saved_comparisons_delete_own" ON public.saved_comparisons;
CREATE POLICY "saved_comparisons_delete_own"
  ON public.saved_comparisons FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ---------- user_consents ----------
DROP POLICY IF EXISTS "user_consents_select_own" ON public.user_consents;
CREATE POLICY "user_consents_select_own"
  ON public.user_consents FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_consents_insert_own" ON public.user_consents;
CREATE POLICY "user_consents_insert_own"
  ON public.user_consents FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_consents_update_own" ON public.user_consents;
CREATE POLICY "user_consents_update_own"
  ON public.user_consents FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- ---------- user_brand_preferences ----------
DROP POLICY IF EXISTS "user_brand_prefs_select_own" ON public.user_brand_preferences;
CREATE POLICY "user_brand_prefs_select_own"
  ON public.user_brand_preferences FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_brand_prefs_insert_own" ON public.user_brand_preferences;
CREATE POLICY "user_brand_prefs_insert_own"
  ON public.user_brand_preferences FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_brand_prefs_delete_own" ON public.user_brand_preferences;
CREATE POLICY "user_brand_prefs_delete_own"
  ON public.user_brand_preferences FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ---------- user_category_preferences ----------
DROP POLICY IF EXISTS "user_category_prefs_select_own" ON public.user_category_preferences;
CREATE POLICY "user_category_prefs_select_own"
  ON public.user_category_preferences FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_category_prefs_insert_own" ON public.user_category_preferences;
CREATE POLICY "user_category_prefs_insert_own"
  ON public.user_category_preferences FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_category_prefs_delete_own" ON public.user_category_preferences;
CREATE POLICY "user_category_prefs_delete_own"
  ON public.user_category_preferences FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = user_id);

-- ---------- storage.objects (bucket avatars) ----------
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );
