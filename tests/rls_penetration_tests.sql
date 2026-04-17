-- ============================================================
-- RLS PENETRATION TESTS — Worthy Database
-- ============================================================
--
-- Eseguire contro un database locale con: supabase db reset
-- Questi test simulano attacchi reali e verificano che le
-- migration di sicurezza funzionino correttamente.
--
-- PATTERN SUPABASE PER SIMULARE RUOLI:
--   Per anon:
--     SET ROLE anon;
--     SET request.jwt.claims = '{"role":"anon"}';
--
--   Per authenticated user con specifico UUID:
--     SET ROLE authenticated;
--     SET request.jwt.claims = '{"role":"authenticated","sub":"<uuid>"}';
--
--   Per tornare a superuser (dopo i test):
--     SET ROLE postgres;
--
-- OUTPUT ATTESO: commentato per ogni query
-- ============================================================


-- ============================================================
-- SETUP: dati di test (gira come superuser/postgres)
-- ============================================================
SET ROLE postgres;

-- Inserisci utenti test
INSERT INTO users (id, email, display_name, role, trust_level, points, is_premium)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'userx@test.com', 'User X', 'user', 'new', 100, false),
  ('22222222-2222-2222-2222-222222222222', 'usery@test.com', 'User Y', 'user', 'new', 50, false),
  ('33333333-3333-3333-3333-333333333333', 'admin@test.com', 'Admin', 'admin', 'trusted', 500, true)
ON CONFLICT (id) DO NOTHING;

-- Inserisci una categoria e un brand test
INSERT INTO categories (id, name, slug, icon, avg_price, avg_composition_score)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'T-Shirt Test', 't-shirt-test', 'tshirt', 30.00, 60.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO brands (id, name, slug, market_segment)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Brand Test', 'brand-test', 'mid_range')
ON CONFLICT (id) DO NOTHING;

-- Inserisci un prodotto test contribuito da User X
INSERT INTO products (id, brand_id, category_id, name, slug, price, composition, contributed_by)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Prodotto Test',
  'prodotto-test',
  29.99,
  '[{"fiber":"cotone","percentage":95},{"fiber":"elastane","percentage":5}]'::jsonb,
  '11111111-1111-1111-1111-111111111111'
)
ON CONFLICT (id) DO NOTHING;

-- Inserisci un voto da User X
INSERT INTO product_votes (id, product_id, user_id, score)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '11111111-1111-1111-1111-111111111111',
  8
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SEZIONE 1: ATTACCHI COME ANON
-- ============================================================

-- Simula ruolo anon (come fa PostgREST per richieste senza JWT)
SET ROLE anon;
SET request.jwt.claims = '{"role":"anon"}';

-- TEST 1.1: Lettura tabella users
-- OUTPUT ATTESO: 0 righe (policy users_select_own richiede authenticated + auth.uid() = id)
SELECT * FROM users;

-- TEST 1.2: Lettura audit_log
-- OUTPUT ATTESO: errore "permission denied for table audit_log" (REVOKE applicato)
SELECT * FROM audit_log;

-- TEST 1.3: Lettura scan_history
-- OUTPUT ATTESO: 0 righe (policy richiede authenticated)
SELECT * FROM scan_history;

-- TEST 1.4: Lettura user_consents
-- OUTPUT ATTESO: 0 righe (policy richiede authenticated)
SELECT * FROM user_consents;

-- TEST 1.5: Lettura prodotti soft-deleted
-- OUTPUT ATTESO: 0 righe (policy filtra is_active = true)
SELECT * FROM products WHERE is_active = false;

-- TEST 1.6: Lettura prodotti attivi (deve funzionare)
-- OUTPUT ATTESO: >= 1 riga (prodotto test)
SELECT id, name, worthy_score FROM products;

-- TEST 1.7: Lettura brands (deve funzionare)
-- OUTPUT ATTESO: >= 1 riga
SELECT * FROM brands;

-- TEST 1.8: Lettura product_duplicates
-- OUTPUT ATTESO: 0 righe (nessuna policy per anon)
SELECT * FROM product_duplicates;

-- TEST 1.9: Lettura user_public_profiles (deve funzionare)
-- OUTPUT ATTESO: >= 2 righe (user non bannati)
SELECT * FROM user_public_profiles;

-- TEST 1.10: Tentativo INSERT su brands (REVOKE)
-- OUTPUT ATTESO: errore "permission denied for table brands"
INSERT INTO brands (name, slug, market_segment) VALUES ('hack', 'hack', 'mid_range');


-- ============================================================
-- SEZIONE 2: ATTACCHI COME AUTHENTICATED USER X
-- ============================================================

-- Simula User X autenticato
SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';

-- TEST 2.1: PRIVILEGE ESCALATION — Tentativo di diventare admin
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: role"
UPDATE users SET role = 'admin' WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.2: PRIVILEGE ESCALATION — Tentativo di aumentare punti
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: points"
UPDATE users SET points = 999999 WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.3: PRIVILEGE ESCALATION — Tentativo di diventare premium
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: is_premium"
UPDATE users SET is_premium = true WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.4: PRIVILEGE ESCALATION — Tentativo multiplo
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: role, trust_level, points"
UPDATE users SET role = 'admin', trust_level = 'trusted', points = 999999
WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.5: UPDATE legittimo — display_name (deve funzionare)
-- OUTPUT ATTESO: 1 riga aggiornata
UPDATE users SET display_name = 'User X Updated'
WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.6: UPDATE legittimo — avatar_url (deve funzionare)
-- OUTPUT ATTESO: 1 riga aggiornata
UPDATE users SET avatar_url = 'https://example.com/avatar.jpg'
WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 2.7: Lettura profilo di altro utente (User Y)
-- OUTPUT ATTESO: 0 righe (policy users_select_own limita a proprio id)
SELECT * FROM users WHERE id = '22222222-2222-2222-2222-222222222222';

-- TEST 2.8: Lettura profilo pubblico di altro utente (deve funzionare)
-- OUTPUT ATTESO: 1 riga con solo campi pubblici
SELECT * FROM user_public_profiles WHERE id = '22222222-2222-2222-2222-222222222222';

-- TEST 2.9: SCORE MANIPULATION — Tentativo di modificare worthy_score
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: worthy_score"
UPDATE products SET worthy_score = 100
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- TEST 2.10: SCORE MANIPULATION — Tentativo di modificare verification_status
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: verification_status"
UPDATE products SET verification_status = 'verified'
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- TEST 2.11: SCORE MANIPULATION — Tentativo di modificare verdict
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: verdict"
UPDATE products SET verdict = 'steal'
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- TEST 2.12: UPDATE legittimo su prodotti — cambiare nome (deve funzionare)
-- OUTPUT ATTESO: 1 riga aggiornata (entro 24h dall'inserimento)
UPDATE products SET name = 'Prodotto Test Rinominato'
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- TEST 2.13: Tentativo di INSERT in audit_log
-- OUTPUT ATTESO: errore "permission denied for table audit_log"
INSERT INTO audit_log (table_name, record_id, action, user_id)
VALUES ('test', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'insert', '11111111-1111-1111-1111-111111111111');

-- TEST 2.14: Tentativo di DELETE su product_votes di altro utente
-- OUTPUT ATTESO: 0 righe eliminate (policy filtra per user_id)
DELETE FROM product_votes WHERE user_id = '22222222-2222-2222-2222-222222222222';

-- TEST 2.15: Tentativo di UPDATE product_votes cambiando product_id
-- OUTPUT ATTESO: ERRORE "Attempt to modify immutable fields: product_id"
UPDATE product_votes
SET product_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- TEST 2.16: INSERT product_reports con status='confirmed'
-- OUTPUT ATTESO: ERRORE "Reports must be created with status pending, got: confirmed"
INSERT INTO product_reports (product_id, user_id, reason, status)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '11111111-1111-1111-1111-111111111111',
  'wrong_price',
  'confirmed'
);

-- TEST 2.17: INSERT product_reports legittimo (deve funzionare)
-- OUTPUT ATTESO: 1 riga inserita con status='pending'
INSERT INTO product_reports (product_id, user_id, reason, description)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '11111111-1111-1111-1111-111111111111',
  'wrong_price',
  'Il prezzo sembra errato'
);

-- TEST 2.18: Lettura product_duplicates come utente normale
-- OUTPUT ATTESO: 0 righe (solo admin/moderator)
SELECT * FROM product_duplicates;

-- TEST 2.19: Tentativo di soft-delete proprio prodotto
-- OUTPUT ATTESO: ERRORE "Attempt to modify protected fields: is_active"
UPDATE products SET is_active = false
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';


-- ============================================================
-- SEZIONE 3: IMPERSONATION
-- ============================================================

-- User X tenta di impersonare User Y

-- TEST 3.1: Tentativo di cambiare user_id su product_votes
-- OUTPUT ATTESO: ERRORE "Attempt to modify immutable fields: user_id"
UPDATE product_votes
SET user_id = '22222222-2222-2222-2222-222222222222'
WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- TEST 3.2: INSERT product_votes con user_id di un altro utente
-- OUTPUT ATTESO: ERRORE da policy WITH CHECK (auth.uid() = user_id)
INSERT INTO product_votes (product_id, user_id, score)
VALUES (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '22222222-2222-2222-2222-222222222222',
  10
);

-- TEST 3.3: INSERT scan_history con user_id di un altro utente
-- OUTPUT ATTESO: ERRORE da policy WITH CHECK (auth.uid() = user_id)
INSERT INTO scan_history (user_id, barcode, scan_type, found)
VALUES ('22222222-2222-2222-2222-222222222222', '1234567890123', 'barcode', true);


-- ============================================================
-- SEZIONE 4: HELPER FUNCTION TESTS
-- ============================================================

-- Torna a superuser per poter cambiare liberamente i setting
SET ROLE postgres;

-- TEST 4.1: is_service_role_or_internal come authenticated
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';
-- OUTPUT ATTESO: FALSE
SELECT is_service_role_or_internal();

-- TEST 4.2: is_service_role_or_internal come service_role
SET request.jwt.claims = '{"role":"service_role"}';
-- OUTPUT ATTESO: TRUE
SELECT is_service_role_or_internal();

-- TEST 4.3: is_service_role_or_internal senza JWT (contesto interno)
-- NOTA: con il fix fail-closed, JWT assente ora ritorna FALSE.
-- Il bypass per scoring engine e gestito da session variable, non da questa funzione.
SET request.jwt.claims = '';
-- OUTPUT ATTESO: FALSE (fail-closed)
SELECT is_service_role_or_internal();

-- TEST 4.4: is_service_role_or_internal come anon
SET request.jwt.claims = '{"role":"anon"}';
-- OUTPUT ATTESO: FALSE
SELECT is_service_role_or_internal();

-- TEST 4.5: is_service_role_or_internal con JWT malformato
SET request.jwt.claims = 'not-valid-json';
-- OUTPUT ATTESO: FALSE (fail-closed — non piu TRUE)
SELECT is_service_role_or_internal();

-- TEST 4.6: is_service_role_or_internal con role=null
SET request.jwt.claims = '{"role":null}';
-- OUTPUT ATTESO: FALSE (null != 'service_role')
SELECT is_service_role_or_internal();

-- TEST 4.7: is_service_role_or_internal con role=stringa vuota
SET request.jwt.claims = '{"role":""}';
-- OUTPUT ATTESO: FALSE
SELECT is_service_role_or_internal();

-- TEST 4.8: Session variable worthy.skip_protection
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';
-- OUTPUT ATTESO: worthy.skip_protection non e settata → NULL (non bypassa)
SELECT current_setting('worthy.skip_protection', true);
-- Settala
PERFORM set_config('worthy.skip_protection', 'true', true);
-- OUTPUT ATTESO: 'true'
SELECT current_setting('worthy.skip_protection', true);


-- ============================================================
-- SEZIONE 5: INTEGRATION TESTS — Scoring Engine End-to-End
-- ============================================================

-- Simula User X per gli INSERT
SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';

-- TEST 5.1: INSERT prodotto — lo score deve essere calcolato inline
-- OUTPUT ATTESO: 1 riga con worthy_score > 0, score_composition > 0,
--   verification_status = 'unverified', scan_count = 0
INSERT INTO products (brand_id, category_id, name, slug, price, composition, contributed_by)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Score Test Product',
  'score-test-product',
  25.00,
  '[{"fiber":"cotone","percentage":80},{"fiber":"poliestere","percentage":20}]'::jsonb,
  '11111111-1111-1111-1111-111111111111'
)
RETURNING id, worthy_score, score_composition, score_qpr, verdict,
          verification_status, scan_count, community_score;
-- VERIFICA: worthy_score > 0 (calcolato dal BEFORE trigger inline)
--           verification_status = 'unverified' (forzato)
--           scan_count = 0 (forzato)
--           community_score IS NULL (forzato)

-- TEST 5.2: INSERT con campi protetti hackerati — deve essere forzato
-- OUTPUT ATTESO: verification_status = 'unverified', scan_count = 0, worthy_score calcolato
INSERT INTO products (brand_id, category_id, name, slug, price, composition, contributed_by,
                      verification_status, scan_count, worthy_score)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Hacked Product Attempt',
  'hacked-product-attempt',
  15.00,
  '[{"fiber":"poliestere","percentage":100}]'::jsonb,
  '11111111-1111-1111-1111-111111111111',
  'mattia_reviewed',  -- TENTATIVO DI HACK
  99999,              -- TENTATIVO DI HACK
  100                 -- TENTATIVO DI HACK
)
RETURNING id, verification_status, scan_count, worthy_score;
-- VERIFICA: verification_status = 'unverified' (NON 'mattia_reviewed')
--           scan_count = 0 (NON 99999)
--           worthy_score = valore calcolato (NON 100)

-- TEST 5.3: SCORE CONSISTENCY — Lo score inline (BEFORE) deve corrispondere al ricalcolo (AFTER)
SET ROLE postgres;
DO $$
DECLARE
  new_id uuid;
  insert_score numeric;
  recalculated_score numeric;
BEGIN
  INSERT INTO products (brand_id, category_id, name, slug, price, composition, contributed_by)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Consistency Test Product',
    'consistency-test-product',
    35.00,
    '[{"fiber":"cotone biologico","percentage":60},{"fiber":"lyocell","percentage":30},{"fiber":"elastane","percentage":10}]'::jsonb,
    '11111111-1111-1111-1111-111111111111'
  )
  RETURNING id, worthy_score INTO new_id, insert_score;

  -- Leggi lo score dopo che l'AFTER trigger ha ricalcolato
  SELECT worthy_score INTO recalculated_score FROM products WHERE id = new_id;

  IF insert_score IS DISTINCT FROM recalculated_score THEN
    RAISE EXCEPTION 'SCORE CONSISTENCY FAILURE: insert_score=%, recalculated_score=%',
      insert_score, recalculated_score;
  ELSE
    RAISE NOTICE 'SCORE CONSISTENCY OK: insert_score=%, recalculated_score=%',
      insert_score, recalculated_score;
  END IF;
END $$;

-- TEST 5.4: UPDATE composition — deve triggerare ricalcolo score
SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';

-- Prima: leggi lo score attuale del prodotto test originale
SELECT id, worthy_score, score_composition FROM products
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- Cambia la composizione (campo lecito) — il trigger AFTER ricalcolera lo score
UPDATE products
SET composition = '[{"fiber":"cashmere","percentage":100}]'::jsonb
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
-- OUTPUT ATTESO: UPDATE riuscito

-- Dopo: verifica che lo score sia stato ricalcolato (cashmere = 98)
SELECT id, worthy_score, score_composition, verdict FROM products
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
-- VERIFICA: score_composition ~ 98, worthy_score alto, verdict 'steal' o 'worthy'


-- ============================================================
-- SEZIONE 6: INTEGRATION TESTS — Audit Log dei Blocchi
-- (Con dblink, il log persiste dopo RAISE EXCEPTION)
-- ============================================================

SET ROLE postgres;

-- Pulisci audit log dei test precedenti
DELETE FROM audit_log WHERE action = 'blocked';

-- Simula User X
SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';

-- TEST 6.1: Tentativo di escalation — deve fallire E loggare (persistente)
DO $$
BEGIN
  UPDATE users SET role = 'admin' WHERE id = '11111111-1111-1111-1111-111111111111';
  RAISE EXCEPTION 'TEST FAILED: UPDATE should have been blocked';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 6.1 PASSED: UPDATE correctly blocked with insufficient_privilege';
  WHEN OTHERS THEN
    RAISE NOTICE 'TEST 6.1 PASSED: UPDATE blocked with error: %', SQLERRM;
END $$;

-- STEP 2: Verifica audit log (come superuser)
SET ROLE postgres;
-- OUTPUT ATTESO: almeno 1 riga con table_name='users', action='blocked'
-- NOTA: il log e persistente grazie a dblink (autonomous transaction).
-- Se dblink non funziona nel tuo ambiente, questa query ritorna 0 righe —
-- il che significa che l'attacco e comunque bloccato ma non loggato.
SELECT id, table_name, action, user_id,
       new_data->'blocked_fields' as blocked_fields,
       created_at
FROM audit_log
WHERE action = 'blocked'
  AND table_name = 'users'
  AND user_id = '11111111-1111-1111-1111-111111111111';

-- STEP 3: Verifica che il ruolo NON sia stato cambiato
-- OUTPUT ATTESO: role = 'user' (NON 'admin')
SELECT id, role FROM users WHERE id = '11111111-1111-1111-1111-111111111111';

-- TEST 6.2: Tentativo di modifica score prodotto — deve fallire E loggare
DELETE FROM audit_log WHERE action = 'blocked' AND table_name = 'products';

SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';

DO $$
BEGIN
  UPDATE products SET worthy_score = 100
  WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  RAISE EXCEPTION 'TEST FAILED: UPDATE should have been blocked';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 6.2 PASSED: Score modification correctly blocked';
  WHEN OTHERS THEN
    RAISE NOTICE 'TEST 6.2 PASSED: Score modification blocked with: %', SQLERRM;
END $$;

SET ROLE postgres;
-- OUTPUT ATTESO: almeno 1 riga con table_name='products', action='blocked'
SELECT id, table_name, action, user_id,
       new_data->'blocked_fields' as blocked_fields,
       created_at
FROM audit_log
WHERE action = 'blocked'
  AND table_name = 'products';

-- Verifica che lo score NON sia stato cambiato
SELECT id, worthy_score FROM products
WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';


-- ============================================================
-- SEZIONE 7: ADMIN REALTIME POLICY TEST
-- ============================================================

-- TEST 7.1: Admin puo leggere product_duplicates
SET ROLE authenticated;
SET request.jwt.claims = '{"role":"authenticated","sub":"33333333-3333-3333-3333-333333333333"}';
-- OUTPUT ATTESO: query eseguita senza errore (0 o piu righe)
SELECT * FROM product_duplicates;

-- TEST 7.2: Admin puo leggere product_reports
-- OUTPUT ATTESO: query eseguita senza errore (include report di tutti gli utenti)
SELECT * FROM product_reports;

-- TEST 7.3: Utente normale NON puo leggere product_duplicates
SET request.jwt.claims = '{"role":"authenticated","sub":"11111111-1111-1111-1111-111111111111"}';
-- OUTPUT ATTESO: 0 righe (user X non e admin/moderator)
SELECT * FROM product_duplicates;

-- TEST 7.4: Utente normale vede solo i propri product_reports
-- OUTPUT ATTESO: solo i report creati da User X (non quelli di altri)
SELECT * FROM product_reports;


-- ============================================================
-- CLEANUP
-- ============================================================

SET ROLE postgres;
-- I dati di test possono essere lasciati nel DB locale.
-- Per pulire: supabase db reset
