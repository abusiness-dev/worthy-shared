-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 3.1) — indici di copertura FK su tabelle per-utente.
--
-- PROBLEMA:
--   Postgres NON indicizza automaticamente le foreign key. Tre tabelle per-utente
--   (che crescono 1:1 con gli utenti) sono colpite a runtime dai predicati RLS su
--   user_id e dalla GDPR delete/export, ma non hanno l'indice:
--     - saved_comparisons: NESSUN indice (solo PK su id) → seq scan ad ogni lettura
--       della lista "confronti salvati" (RLS SELECT su user_id) e su delete account.
--     - product_votes: solo idx_product_votes_product(product_id) + UNIQUE leading
--       product_id → niente copertura per user_id (RLS UPDATE + delete account).
--     - products.contributed_by: FK ON DELETE SET NULL + RLS insert/update + export
--       GDPR → seq scan dell'intero catalogo ad ogni cancellazione account.
--   (product_reports.user_id è GIÀ coperto dalla UNIQUE(user_id, product_id) di
--    20260530000002, leading user_id → nessun indice aggiuntivo necessario.)
--
-- NOTA DEPLOY: CREATE INDEX (non CONCURRENTLY) perché queste migrazioni vanno
--   applicate PRE-LANCIO, quando le tabelle sono ancora piccole → il build è
--   istantaneo e resta transaction-safe per `supabase db reset`. Per indici
--   AGGIUNTI POST-LANCIO su tabelle ormai grandi vale la regola CONCURRENTLY (vedi
--   "Convenzioni di deploy" nel piano).
-- ════════════════════════════════════════════════════════════════════

-- Lista "confronti salvati" dell'utente (RLS SELECT/DELETE) + delete account.
CREATE INDEX IF NOT EXISTS idx_saved_comparisons_user
  ON public.saved_comparisons (user_id, created_at DESC);

-- RLS UPDATE proprio voto + cascade delete account (tabella alta-scrittura).
CREATE INDEX IF NOT EXISTS idx_product_votes_user
  ON public.product_votes (user_id);

-- FK ON DELETE SET NULL + RLS insert/update + export GDPR. Parziale: i prodotti
-- importati hanno contributed_by NULL (la maggioranza) → indice più piccolo.
CREATE INDEX IF NOT EXISTS idx_products_contributed_by
  ON public.products (contributed_by)
  WHERE contributed_by IS NOT NULL;
