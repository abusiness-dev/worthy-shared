-- ============================================================
-- SECURITY FIX (F5): anti-spam su product_reports.
--
-- PROBLEMA:
--   product_reports non ha rate-limit né unicità: un utente authenticated può
--   inserire un numero illimitato di segnalazioni (anche duplicate sullo stesso
--   prodotto), floodando la coda di moderazione.
--
-- SOLUZIONE:
--   UNIQUE(user_id, product_id) → una segnalazione per utente per prodotto.
--   Cap semplice e dichiarativo: un attaccante è limitato a 1 report/prodotto e
--   deve creare molti account per scalare (vedi anche hardening auth, F6).
--   La status resta forzata a 'pending' dal trigger protect_report_initial_status
--   (20260417000006).
--
-- NB: prima di aggiungere il constraint, deduplica eventuali righe storiche
--   (mantiene la più vecchia per coppia user_id+product_id) così la migration
--   non fallisce su dati esistenti.
-- ============================================================

-- 1. Dedup difensivo: tiene la segnalazione più vecchia per (user_id, product_id)
DELETE FROM product_reports
WHERE id IN (
  SELECT id FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY user_id, product_id
             ORDER BY created_at, id
           ) AS rn
    FROM product_reports
  ) ranked
  WHERE ranked.rn > 1
);

-- 2. Unicità: una segnalazione per utente per prodotto
ALTER TABLE product_reports
  ADD CONSTRAINT product_reports_unique_user_product UNIQUE (user_id, product_id);

COMMENT ON CONSTRAINT product_reports_unique_user_product ON product_reports IS
  'Anti-spam: un solo report per utente per prodotto. Lo stato moderazione resta gestito da service_role (status forzato pending su INSERT client).';
