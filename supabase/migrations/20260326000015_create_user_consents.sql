-- Crea tabella user_consents. Dipende da: users

CREATE TABLE user_consents (
  user_id            uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  tos_accepted       boolean NOT NULL DEFAULT false,
  tos_accepted_at    timestamptz,
  tos_version        text,
  push_notifications boolean NOT NULL DEFAULT false,
  push_consent_at    timestamptz,
  analytics_consent  boolean NOT NULL DEFAULT false,
  analytics_consent_at timestamptz,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE user_consents IS 'Consensi GDPR e preferenze notifiche — una riga per utente';
COMMENT ON COLUMN user_consents.tos_version IS 'Versione dei ToS accettati (es. "1.0", "2.0")';
