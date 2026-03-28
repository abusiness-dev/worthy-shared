-- Crea tabella junction user_badges con PK composita. Dipende da: users, badges

CREATE TABLE user_badges (
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id  text NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (user_id, badge_id)
);

COMMENT ON TABLE user_badges IS 'Badge sbloccati dagli utenti — PK composita, no duplicati';
