-- Crea tabella users. Dipende da: enum trust_level, user_role
-- Il campo id referenzia auth.users(id) di Supabase Auth

CREATE TABLE users (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text NOT NULL UNIQUE,
  display_name        text,
  avatar_url          text,
  points              integer NOT NULL DEFAULT 0,
  trust_level         trust_level NOT NULL DEFAULT 'new',
  role                user_role NOT NULL DEFAULT 'user',
  products_contributed integer NOT NULL DEFAULT 0,
  products_verified    integer NOT NULL DEFAULT 0,
  error_rate          numeric(5,4) NOT NULL DEFAULT 0,
  streak_days         integer NOT NULL DEFAULT 0,
  last_active_date    date,
  is_premium          boolean NOT NULL DEFAULT false,
  premium_expires_at  timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE users IS 'Profilo utente Worthy, estende auth.users di Supabase';
COMMENT ON COLUMN users.trust_level IS 'Livello di fiducia: new → contributor → trusted. banned = bloccato';
COMMENT ON COLUMN users.error_rate IS 'Percentuale di contributi rifiutati (0.0000 - 1.0000)';
COMMENT ON COLUMN users.streak_days IS 'Giorni consecutivi di attività';
COMMENT ON COLUMN users.products_contributed IS 'Conteggio prodotti inseriti (calcolato)';
COMMENT ON COLUMN users.products_verified IS 'Conteggio prodotti verificati/confermati (calcolato)';
