-- User preferences per onboarding: salva i brand e le categorie preferite dall'utente
-- durante il flusso di onboarding, e traccia il completamento del flusso stesso.
-- Tabelle join N:N con cascading delete su user e brand/category.

-- ============================================================
-- Flag onboarding completato sulla tabella users
-- ============================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN users.onboarding_completed IS 'True quando l''utente ha completato il flusso di onboarding (scelta brand + categorie preferite)';

-- ============================================================
-- user_brand_preferences
-- ============================================================

CREATE TABLE user_brand_preferences (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  brand_id   uuid NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, brand_id)
);

COMMENT ON TABLE user_brand_preferences IS 'Brand preferiti dall''utente, scelti in onboarding o nelle impostazioni';

CREATE INDEX idx_user_brand_prefs_user ON user_brand_preferences(user_id);

-- ============================================================
-- user_category_preferences
-- ============================================================

CREATE TABLE user_category_preferences (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, category_id)
);

COMMENT ON TABLE user_category_preferences IS 'Categorie preferite dall''utente, scelte in onboarding o nelle impostazioni';

CREATE INDEX idx_user_category_prefs_user ON user_category_preferences(user_id);

-- ============================================================
-- RLS: l'utente può leggere/creare/cancellare solo le proprie preferenze
-- ============================================================

ALTER TABLE user_brand_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_category_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_brand_prefs_select_own"
  ON user_brand_preferences FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_brand_prefs_insert_own"
  ON user_brand_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_brand_prefs_delete_own"
  ON user_brand_preferences FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_category_prefs_select_own"
  ON user_category_preferences FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_category_prefs_insert_own"
  ON user_category_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_category_prefs_delete_own"
  ON user_category_preferences FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
