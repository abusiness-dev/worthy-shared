-- Abilita Row Level Security su tutte le tabelle e crea le policy

-- ============================================================
-- Abilita RLS
-- ============================================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE mattia_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE scan_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_duplicates ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_worthy ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PRODUCTS
-- ============================================================

CREATE POLICY "products_select_public"
  ON products FOR SELECT
  USING (true);

CREATE POLICY "products_insert_auth"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = contributed_by);

CREATE POLICY "products_update_own_recent"
  ON products FOR UPDATE
  TO authenticated
  USING (auth.uid() = contributed_by AND created_at > now() - interval '24 hours')
  WITH CHECK (auth.uid() = contributed_by);

-- ============================================================
-- BRANDS, CATEGORIES, BADGES — lettura pubblica
-- ============================================================

CREATE POLICY "brands_select_public"
  ON brands FOR SELECT
  USING (true);

CREATE POLICY "categories_select_public"
  ON categories FOR SELECT
  USING (true);

CREATE POLICY "badges_select_public"
  ON badges FOR SELECT
  USING (true);

-- ============================================================
-- USERS
-- ============================================================

CREATE POLICY "users_select_public"
  ON users FOR SELECT
  USING (true);

CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- PRICE_HISTORY — lettura pubblica
-- ============================================================

CREATE POLICY "price_history_select_public"
  ON price_history FOR SELECT
  USING (true);

-- ============================================================
-- MATTIA_REVIEWS — lettura pubblica, scrittura solo server/admin
-- ============================================================

CREATE POLICY "mattia_reviews_select_public"
  ON mattia_reviews FOR SELECT
  USING (true);

-- Nessuna policy INSERT/UPDATE per client: solo service_role può scrivere

-- ============================================================
-- PRODUCT_VOTES — lettura pubblica, insert autenticato
-- ============================================================

CREATE POLICY "product_votes_select_public"
  ON product_votes FOR SELECT
  USING (true);

CREATE POLICY "product_votes_insert_auth"
  ON product_votes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "product_votes_update_own"
  ON product_votes FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- PRODUCT_REPORTS — insert autenticato
-- ============================================================

CREATE POLICY "product_reports_insert_auth"
  ON product_reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "product_reports_select_own"
  ON product_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================
-- SCAN_HISTORY — solo il proprio utente
-- ============================================================

CREATE POLICY "scan_history_select_own"
  ON scan_history FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "scan_history_insert_own"
  ON scan_history FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- SAVED_PRODUCTS — solo il proprio utente
-- ============================================================

CREATE POLICY "saved_products_select_own"
  ON saved_products FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "saved_products_insert_own"
  ON saved_products FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "saved_products_delete_own"
  ON saved_products FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================
-- SAVED_COMPARISONS — solo il proprio utente
-- ============================================================

CREATE POLICY "saved_comparisons_select_own"
  ON saved_comparisons FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "saved_comparisons_insert_own"
  ON saved_comparisons FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "saved_comparisons_delete_own"
  ON saved_comparisons FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================
-- USER_BADGES — lettura pubblica
-- ============================================================

CREATE POLICY "user_badges_select_public"
  ON user_badges FOR SELECT
  USING (true);

-- Nessuna policy INSERT per client: assegnazione solo server-side

-- ============================================================
-- USER_CONSENTS — solo il proprio record
-- ============================================================

CREATE POLICY "user_consents_select_own"
  ON user_consents FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_consents_insert_own"
  ON user_consents FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_consents_update_own"
  ON user_consents FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- PRODUCT_DUPLICATES — nessun accesso client
-- ============================================================

-- Solo service_role può leggere/scrivere duplicati

-- ============================================================
-- AUDIT_LOG — nessun accesso client
-- ============================================================

-- Solo service_role può leggere il log. Append-only, niente UPDATE/DELETE

-- ============================================================
-- DAILY_WORTHY — lettura pubblica
-- ============================================================

CREATE POLICY "daily_worthy_select_public"
  ON daily_worthy FOR SELECT
  USING (true);
