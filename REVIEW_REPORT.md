# Security Review Report — Migration RLS Hardening

**Data**: 2026-04-17
**Reviewer**: Security audit indipendente (adversarial review)
**Scope**: 6 migration SQL + 1 file test di penetrazione
**Premessa**: Parto dal presupposto che questi file abbiano bug. Il mio lavoro e trovarli.

---

## FINDINGS

### FINDING 1 — CRITICO: Lo scoring engine si rompe completamente per utenti autenticati

**File**: `20260417000003_security_fix_products_protect_privileged.sql`
**Righe**: 107-228 (trigger), 244-308 (calculate_worthy_score)

**Problema**: Il design assume che rendere `calculate_worthy_score()` SECURITY DEFINER faccia ritornare TRUE a `is_service_role_or_internal()`. Questo e **FALSO**.

`is_service_role_or_internal()` legge `current_setting('request.jwt.claims', true)::json->>'role'`. Le GUC variable di sessione (`request.jwt.claims`) sono impostate da PostgREST all'inizio della richiesta e **non vengono resettate da SECURITY DEFINER**. SECURITY DEFINER cambia `current_user` per i privilege check, non le GUC di sessione.

**Catena di esecuzione che fallisce:**

```
1. Utente autenticato fa INSERT prodotto
2. BEFORE INSERT trigger → calcola score inline → RETURN NEW → riga inserita
3. AFTER INSERT trigger → trigger_calculate_worthy_score() → chiama calculate_worthy_score()
4. calculate_worthy_score() fa: UPDATE products SET score_composition = ... 
5. Questo UPDATE scatena BEFORE UPDATE trigger: protect_product_privileged_fields()
6. is_service_role_or_internal() legge JWT → role='authenticated' → ritorna FALSE
7. Il trigger detecta che score_composition e cambiato → campo protetto!
8. RAISE EXCEPTION 'Attempt to modify protected fields: score_composition, ...'
9. L'intera operazione viene rollbackata — INSERT del prodotto incluso
```

**Impatto**: OGNI INSERT e OGNI UPDATE di prodotti da parte di utenti autenticati fallisce. L'app e completamente non funzionale.

**Fix proposto**: Usare una session variable come flag di bypass, non SECURITY DEFINER:

```sql
-- In calculate_worthy_score, PRIMA di ogni UPDATE:
PERFORM set_config('app.scoring_in_progress', 'true', true);
-- Il terzo parametro 'true' = local alla transazione corrente

-- In is_service_role_or_internal() O in protect_product_privileged_fields(),
-- aggiungere come PRIMO check:
IF current_setting('app.scoring_in_progress', true) = 'true' THEN
  RETURN TRUE;  -- (o RETURN NEW nel trigger)
END IF;
```

In alternativa, `is_service_role_or_internal()` potrebbe controllare `current_user`:
```sql
-- SECURITY DEFINER cambia current_user al function owner (postgres)
-- PostgREST usa 'authenticator' come session_user e 'authenticated'/'anon' come current_user
IF current_user NOT IN ('anon', 'authenticated', 'authenticator') THEN
  RETURN TRUE;  -- Siamo in un contesto privilegiato (SECURITY DEFINER o superuser)
END IF;
```

---

### FINDING 2 — CRITICO: L'audit log dei tentativi bloccati non viene MAI persistito

**File**: `20260417000002` (riga 86-92), `20260417000003` (riga 208-213), `20260417000006` (riga 55-60, 97-101)
**Pattern presente in**: protect_user_privileged_fields, protect_product_privileged_fields, protect_product_votes_immutable, protect_report_initial_status

**Problema**: In tutti i trigger protettivi, l'ordine e:
```sql
-- 1. Scrivi nel log
PERFORM log_security_event('users', OLD.id, acting_user, blocked_fields);
-- 2. Solleva eccezione
RAISE EXCEPTION 'Attempt to modify protected fields: %', ...
```

La `RAISE EXCEPTION` al punto 2 **rollbacka l'intera transazione**, incluso l'INSERT fatto da `log_security_event` al punto 1. PostgreSQL non supporta autonomous transaction. Quindi il log viene scritto e immediatamente cancellato dal rollback.

**Impatto**: Nessun tentativo di attacco viene mai registrato nell'audit_log. La sezione 6 del pentest (che verifica la presenza di righe `action='blocked'` nell'audit_log) fallira sempre — 0 righe trovate.

L'unica traccia dell'attacco sara nei log HTTP di PostgREST/Supabase Edge (errore 42501), non nell'audit_log del database.

**Fix proposti** (in ordine di semplicita):

**Opzione A — dblink (disponibile in Supabase)**:
```sql
-- In log_security_event, usare dblink per INSERT in una connessione separata
PERFORM dblink('dbname=' || current_database(),
  format('INSERT INTO audit_log (...) VALUES (%L, %L, ...)', p_table, p_record_id, ...));
```
dblink apre una connessione indipendente con la propria transazione. Il RAISE EXCEPTION successivo non rollbacka l'INSERT nel dblink. Richiede `CREATE EXTENSION IF NOT EXISTS dblink`.

**Opzione B — RETURN NULL invece di RAISE EXCEPTION**:
```sql
PERFORM log_security_event(...);
RETURN NULL;  -- Scarta silenziosamente la riga (0 rows affected, no error)
```
In un BEFORE trigger, `RETURN NULL` scarta l'operazione senza eccezione. La transazione committa normalmente e il log persiste. Lo svantaggio: il client riceve "0 rows updated" senza messaggio di errore — meno chiaro per i developer. Ma il log e salvo.

**Opzione C — Log esterno via NOTIFY**:
```sql
PERFORM pg_notify('security_events', json_build_object(...)::text);
RAISE EXCEPTION ...;
```
Il NOTIFY sopravvive al rollback se emesso prima dell'eccezione? **NO**, anche NOTIFY viene rollbackato. Questa opzione non funziona.

**Opzione D — Accettare la perdita del log**:
Documentare che il log nel database non e possibile con RAISE EXCEPTION. Affidarsi ai log HTTP di Supabase/PostgREST per tracciare errori 42501. Rimuovere la chiamata a `log_security_event` dai trigger per evitare confusione. Piu onesto e piu semplice.

---

### FINDING 3 — ALTO: `is_service_role_or_internal()` e fail-open

**File**: `20260417000001_security_fix_helper_and_enum.sql`, righe 30-35

```sql
BEGIN
  jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
EXCEPTION WHEN OTHERS THEN
  jwt_role := NULL;  -- ← NULL → la funzione ritorna TRUE
END;
```

**Problema**: `EXCEPTION WHEN OTHERS` cattura QUALSIASI eccezione, non solo errori di parsing JSON. Se si verifica un errore imprevisto (out of memory, cancellation, bug interno), la funzione ritorna TRUE, concedendo accesso privilegiato.

Questo e un design **fail-open**: qualsiasi errore imprevisto = accesso concesso. Il design corretto per una funzione di sicurezza e **fail-closed**: qualsiasi errore imprevisto = accesso negato.

**Impatto**: Basso in condizioni normali, ma violerebbe qualsiasi audit di sicurezza formale. Un attaccante che riesce a provocare un'eccezione specifica durante il parsing potrebbe bypassare tutti i trigger protettivi.

**Fix**:
```sql
BEGIN
  jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
EXCEPTION WHEN OTHERS THEN
  jwt_role := 'fail_closed';  -- Un valore che non matcha 'service_role'
END;

-- Alla fine: ritorna TRUE solo per condizioni esplicitamente note
RETURN jwt_role = 'service_role';
-- NON piu: jwt_role IS NULL OR jwt_role = 'service_role'
```

Per il caso "nessun JWT" (cron/SECURITY DEFINER), usare un check separato PRIMA del try/catch:
```sql
-- Se il setting non esiste affatto, ritorna NULL (non eccezione)
IF current_setting('request.jwt.claims', true) IS NULL THEN
  RETURN TRUE;  -- Nessun JWT = contesto interno
END IF;
-- Se esiste ma e malformato, fail-closed
BEGIN
  jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;  -- Fail closed
END;
```

---

### FINDING 4 — ALTO: `is_service_role_or_internal()` ritorna TRUE per JWT con role=null

**File**: `20260417000001_security_fix_helper_and_enum.sql`, riga 41

```sql
RETURN jwt_role IS NULL OR jwt_role = 'service_role';
```

**Problema**: Se il JWT contiene `{"role": null}`, il `->>'role'` ritorna SQL NULL. La condizione `jwt_role IS NULL` e vera, e la funzione ritorna TRUE.

PostgREST non dovrebbe generare JWT con `role: null`, ma:
- Un JWT manipolato potrebbe contenere questo claim
- Se il JWT secret e debole o compromesso, un attaccante potrebbe forgiare un JWT con `role: null`
- La differenza semantica tra "assenza di JWT" e "JWT con role=null" deve essere gestita

**Fix**: Usare il fix proposto nel Finding 3 — separare "JWT assente" da "JWT presente ma con valore anomalo".

---

### FINDING 5 — MEDIO: La view `user_public_profiles` bypassa RLS senza `security_barrier`

**File**: `20260417000005_security_fix_users_select_restrict.sql`, righe 41-51

```sql
CREATE OR REPLACE VIEW user_public_profiles AS
SELECT id, display_name, avatar_url, points, ...
FROM users;
```

**Problema 1**: Nessun `WITH (security_invoker = true)`. La view gira come il view owner (postgres/superuser) e bypassa la RLS di `users`. Questo e **intenzionale** (la view deve mostrare profili pubblici a tutti), ma non e documentato e non ha safety net.

**Problema 2**: Nessun `WITH (security_barrier = true)`. Senza security_barrier, il query planner potrebbe ottimizzare predicati utente nella view in modi che leakano informazioni. In pratica il rischio e basso perche la view non espone campi sensibili, ma e una best practice mancante.

**Problema 3**: Nessun filtro `WHERE trust_level != 'banned'`. Un utente bannato e ancora visibile nella vista pubblica. Se il ban deve rendere l'utente "invisibile", manca il filtro.

**Fix**:
```sql
CREATE OR REPLACE VIEW user_public_profiles
WITH (security_barrier = true) AS
SELECT id, display_name, avatar_url, points, products_contributed, products_verified, streak_days, created_at
FROM users
WHERE trust_level != 'banned';  -- Opzionale ma consigliato
```

---

### FINDING 6 — MEDIO: La simulazione anon nel pentest e completamente rotta

**File**: `tests/rls_penetration_tests.sql`, righe 75-79

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"role":"anon"}';
RESET ROLE;
```

**Problema**: `RESET ROLE` ritorna al ruolo di sessione, che in un test locale e tipicamente `postgres` (superuser). I test 1.1-1.8 girano come superuser, non come anon. Tutti i test passano banalmente perche il superuser bypassa RLS.

Per simulare correttamente il ruolo anon:
```sql
SET LOCAL ROLE anon;
SET LOCAL request.jwt.claims = '{"role":"anon"}';
```

Senza questa correzione, la sezione 1 del pentest non testa nulla. Tutti i risultati attesi ("0 righe", "permission denied") sono sbagliati — il superuser vedrebbe tutte le righe senza errori.

---

### FINDING 7 — MEDIO: `is_active` non protetto su UPDATE prodotti

**File**: `20260417000003_security_fix_products_protect_privileged.sql`

**Osservazione**: Il campo `is_active` viene forzato a `true` su INSERT (riga 129), ma NON e nella lista dei campi protetti su UPDATE (righe 156-194). Un utente autenticato puo fare:
```sql
UPDATE products SET is_active = false WHERE contributed_by = auth.uid();
```
Entro le 24h, questo soft-delete il proprio prodotto. Potrebbe essere intenzionale (gli utenti possono rimuovere i propri contributi), ma non e documentato ne testato.

**Se non intenzionale, fix**: Aggiungere alla lista UPDATE:
```sql
IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
  blocked_fields := array_append(blocked_fields, 'is_active');
END IF;
```

---

### FINDING 8 — INFO: Inconsistenza `pg_temp` nel search_path delle funzioni SECURITY DEFINER

**File**: migration 1, 2, 3, 4, 6

| Funzione | search_path |
|----------|------------|
| is_service_role_or_internal | public, pg_temp |
| log_security_event | public, pg_temp |
| protect_user_privileged_fields | public, pg_temp |
| protect_product_privileged_fields | public, pg_temp |
| calculate_score_inline | public (no pg_temp) |
| calculate_worthy_score | public (no pg_temp) |
| trigger_audit_log | public, pg_temp |
| protect_product_votes_immutable | public, pg_temp |
| protect_report_initial_status | public, pg_temp |

L'inclusione di `pg_temp` e inconsistente. Per funzioni SECURITY DEFINER, includerlo e leggermente peggio di non includerlo (permetterebbe oggetti temporanei nella risoluzione dei nomi), ma in pratica PostgreSQL non supporta CREATE TEMP FUNCTION, quindi il rischio e limitato a temp table shadowing. Raccomandazione: standardizzare su `SET search_path = public` per tutte le SECURITY DEFINER, rimuovere `pg_temp`.

---

### FINDING 9 — INFO: Nessun test per REVOKE su tabelle reference

**File**: `tests/rls_penetration_tests.sql`

Nessun test verifica che `INSERT INTO brands(...)` o `UPDATE categories SET ...` fallisca per anon/authenticated dopo il REVOKE nella migration 6. Gap di copertura per V-006.

---

## FALSE POSITIVES CONSIDERATI

### FP-1: "La view user_public_profiles bypassa RLS — e un bug?"

**Conclusione: Non e un bug.** Il bypass e intenzionale. La view esiste PROPRIO per esporre un sottoinsieme di campi a tutti, aggirando la policy `users_select_own` che limita alla propria riga. Se usassimo `security_invoker = true`, la view sarebbe inutile (anon vedrebbe 0 righe, authenticated solo la propria). Tuttavia, merita `security_barrier = true` e un filtro per utenti bannati (Finding 5).

### FP-2: "products_select_public senza clausola TO — troppo permissiva?"

**Conclusione: Corretto.** La policy `USING (is_active = true)` senza `TO` si applica a tutti i ruoli. I prodotti attivi sono dati pubblici del catalogo. service_role bypassa comunque RLS. Nessun problema.

### FP-3: "Le admin policy su product_duplicates/product_reports fanno subquery su users — RLS potrebbe bloccarla?"

**Conclusione: Funziona correttamente.** La subquery `EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'moderator'))` e soggetta alla RLS di users. Ma `users_select_own` permette SELECT dove `auth.uid() = id`, e la subquery filtra proprio `u.id = auth.uid()`, quindi l'utente vede sempre la propria riga e puo verificare il proprio ruolo. Se e admin → EXISTS ritorna true → accesso concesso. Se non e admin → EXISTS ritorna false → 0 righe. Corretto.

### FP-4: "`calculate_worthy_score` fa due UPDATE sulla stessa riga — ricorsione infinita?"

**Conclusione: Nessuna ricorsione.** L'AFTER trigger `trigger_calculate_worthy_score` controlla `IF TG_OP = 'INSERT' OR OLD.composition IS DISTINCT FROM NEW.composition OR ...`. Gli UPDATE interni cambiano solo score fields, non composition/price/category_id. Quindi il secondo giro dell'AFTER trigger non richiama `calculate_worthy_score`. Nessuna ricorsione. (Ma gli UPDATE sono comunque bloccati dal Finding 1 in contesto authenticated.)

### FP-5: "Dynamic SQL con `array_to_string(blocked_fields, ', ')` nel RAISE EXCEPTION"

**Conclusione: Non e dynamic SQL.** `array_to_string` ritorna un valore di testo usato come parametro del messaggio d'errore, non come SQL eseguito. Nessun rischio di injection. I nomi dei campi nell'array sono hardcoded nel trigger (`'role'`, `'trust_level'`, ecc.), non forniti dall'utente.

---

## SUMMARY

| Severita | Conteggio | Findings |
|----------|-----------|----------|
| CRITICO | 2 | #1 (scoring engine rotto), #2 (audit log rollbackato) |
| ALTO | 2 | #3 (fail-open), #4 (role=null bypass) |
| MEDIO | 3 | #5 (view security_barrier), #6 (pentest anon rotto), #7 (is_active non protetto) |
| INFO | 2 | #8 (pg_temp inconsistente), #9 (test coverage gap) |
| **TOTALE** | **9** | |

---

## VERDETTO FINALE

**Applicheresti queste migration in produzione per un'app con 50k utenti day-1 con media exposure?**

**NO. Non in questo stato.**

Le migration contengono un bug show-stopper (Finding 1) che renderebbe l'app completamente non funzionale: nessun utente autenticato potrebbe inserire o aggiornare prodotti. Il primo utente che prova a contribuire un prodotto vedrebbe un errore 500.

Il secondo bug critico (Finding 2) e meno visibile ma altrettanto grave dal punto di vista dell'audit: il sistema di logging dei tentativi di attacco non funziona. Nessun tentativo di privilege escalation verrebbe mai registrato. Per un'app con 50k utenti e attenzione mediatica, questo e inaccettabile — qualsiasi incidente di sicurezza post-lancio non avrebbe trail forense nel database.

**Cosa serve prima del deploy:**

1. **[Bloccante]** Fixare il bypass dello scoring engine (Finding 1) — usare `set_config('app.scoring_in_progress', ...)` o controllare `current_user` in `is_service_role_or_internal()`
2. **[Bloccante]** Decidere una strategia per l'audit log (Finding 2) — dblink, RETURN NULL, o accettare la perdita e affidarsi ai log HTTP
3. **[Fortemente raccomandato]** Rendere `is_service_role_or_internal()` fail-closed (Findings 3 e 4)
4. **[Raccomandato]** Fixare la simulazione anon nel pentest (Finding 6) e rieseguire tutti i test
5. **[Raccomandato]** Aggiungere `security_barrier = true` alla view (Finding 5)

Dopo questi fix, le migration sarebbero solide e pronte per produzione. L'architettura di base (trigger protettivi + helper function + vista pubblica) e corretta. I fix richiesti sono chirurgici e non cambiano il design.
