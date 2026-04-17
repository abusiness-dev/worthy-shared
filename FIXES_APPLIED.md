# Fix Applicati — Security Review Findings

**Data**: 2026-04-17
**Base**: REVIEW_REPORT.md (9 findings: 2 critici, 2 alti, 3 medi, 2 info)

---

## FIX 1 — CRITICO (Finding 1): Scoring engine rotto

**Problema**: `calculate_worthy_score()` SECURITY DEFINER non bypassa `is_service_role_or_internal()` perche le GUC di sessione (`request.jwt.claims`) non vengono resettate da SECURITY DEFINER. Ogni INSERT/UPDATE prodotto da utente autenticato fallisce.

**Soluzione**: Session variable `worthy.skip_protection`.

**File modificati**:

### `20260417000003` — protect_product_privileged_fields()
- **Prima**: `IF is_service_role_or_internal() THEN RETURN NEW;`
- **Dopo**: `IF current_setting('worthy.skip_protection', true) = 'true' OR is_service_role_or_internal() THEN RETURN NEW;`
- La session variable e il bypass primario (per lo scoring engine). `is_service_role_or_internal()` resta come fallback per service_role API calls (worthy-admin).

### `20260417000003` — calculate_worthy_score()
- **Prima**: nessun set_config
- **Dopo**: `PERFORM set_config('worthy.skip_protection', 'true', true);` all'inizio, `PERFORM set_config('worthy.skip_protection', 'false', true);` alla fine
- Il terzo parametro `true` rende il setting LOCAL alla transazione.

### `20260417000002` — protect_user_privileged_fields()
- **Prima**: `IF is_service_role_or_internal() THEN RETURN NEW;`
- **Dopo**: `IF current_setting('worthy.skip_user_protection', true) = 'true' OR is_service_role_or_internal() THEN RETURN NEW;`
- Session variable `worthy.skip_user_protection` per future RPC admin.

---

## FIX 2 — CRITICO (Finding 2): Audit log mai persistito

**Problema**: `RAISE EXCEPTION` dopo `log_security_event` rollbacka l'INSERT. Il log si perde.

**Soluzione**: dblink per autonomous transaction.

**File modificato**: `20260417000001`

### log_security_event()
- **Prima**: `INSERT INTO audit_log (...)` (nella stessa transazione)
- **Dopo**: `PERFORM dblink_exec('dbname=' || current_database(), format(...))` (connessione loopback autonoma)
- Aggiunto `CREATE EXTENSION IF NOT EXISTS dblink;` all'inizio della migration
- Error handler robusto: se dblink fallisce, RAISE WARNING ma non blocca il trigger
- L'INSERT via dblink committa nella propria transazione e sopravvive al RAISE EXCEPTION del trigger

---

## FIX 3 — ALTO (Finding 3): fail-open → fail-closed

**Problema**: `EXCEPTION WHEN OTHERS → jwt_role := NULL → ritorna TRUE`. Qualsiasi errore concede accesso.

**Soluzione**: Fail-closed design.

**File modificato**: `20260417000001` — is_service_role_or_internal()

- **Prima**: eccezione → jwt_role = NULL → `NULL IS NULL` → TRUE
- **Dopo**: eccezione → `RETURN FALSE` diretto. Solo `jwt_role = 'service_role'` ritorna TRUE.
- Check a due step: (1) se claims raw e NULL/vuoto → FALSE, (2) parse JSON, se fallisce → FALSE
- Rimosso `jwt_role IS NULL OR` dalla condizione di ritorno

---

## FIX 4 — ALTO (Finding 4): JWT role=null bypass

**Problema**: `{"role": null}` → json->>'role' ritorna SQL NULL → `NULL IS NULL` → TRUE.

**Soluzione**: Incluso nel fix 3. La condizione ora e `RETURN jwt_role = 'service_role'`. NULL = 'service_role' e FALSE in SQL.

**Nota su `is_service_role_or_internal()` — resta o va rimossa?**: RESTA. E ancora usata da:
- `20260417000002`: protect_user_privileged_fields (fallback per service_role)
- `20260417000003`: protect_product_privileged_fields (fallback per service_role)
- `20260417000006`: protect_product_votes_immutable (unico bypass)
- `20260417000006`: protect_report_initial_status (unico bypass)

---

## FIX 5 — MEDIO (Finding 5): View hardening

**File modificato**: `20260417000005`

- **Prima**: `CREATE OR REPLACE VIEW user_public_profiles AS SELECT ... FROM users;`
- **Dopo**: `CREATE OR REPLACE VIEW user_public_profiles WITH (security_barrier = true) AS SELECT ... FROM users WHERE trust_level != 'banned';`
- `security_barrier = true`: impedisce predicate pushdown che potrebbe leakare info
- `WHERE trust_level != 'banned'`: utenti bannati invisibili nella vista pubblica
- `security_invoker` **intenzionalmente NON aggiunto**: con security_invoker = true, la view rispetterebbe RLS di users → anon vedrebbe 0 righe, authenticated solo la propria → vanifica lo scopo della vista

---

## FIX 6 — MEDIO (Finding 6): Pentest simulation rotta

**File modificato**: `tests/rls_penetration_tests.sql`

- **Prima**: `SET LOCAL ROLE authenticated; ... RESET ROLE;` per simulare anon (sbagliato — RESET ROLE torna a superuser)
- **Dopo**: `SET ROLE anon; SET request.jwt.claims = '{"role":"anon"}';` (corretto pattern Supabase)
- Tutti i `RESET ROLE` sostituiti con `SET ROLE postgres` o `SET ROLE authenticated` espliciti
- Rimosso `SET LOCAL` (non necessario per test manuali)
- Aggiunti test 1.9 (user_public_profiles), 1.10 (REVOKE brands), 2.19 (is_active protection), 4.6 (role=null), 4.7 (role=''), 4.8 (session variable)
- Sezione 6 aggiornata con note su persistenza dblink

---

## FIX 7 — MEDIO (Finding 7): is_active non protetto su UPDATE

**File modificato**: `20260417000003` — protect_product_privileged_fields(), branch UPDATE

- **Prima**: is_active assente dalla lista campi protetti su UPDATE
- **Dopo**: aggiunto check `IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN blocked_fields := array_append(blocked_fields, 'is_active')`
- is_active era gia forzato a true su INSERT (riga 129). Ora e protetto anche su UPDATE.
- Motivazione: gli utenti non devono poter soft-deletare prodotti con voti della community.

---

## VERIFICA: worthy-admin e service_role vs trigger

**Domanda**: service_role bypassa i trigger?

**Risposta**: **NO**. In PostgreSQL, i trigger BEFORE/AFTER si attivano SEMPRE, indipendentemente dal ruolo. `BYPASSRLS` (che ha service_role) bypassa solo le Row Level Security policies, non i trigger. Solo `ALTER TABLE ... DISABLE TRIGGER` puo disabilitare i trigger.

**Impatto su worthy-admin**: Tutte le operazioni admin su users e products passano attraverso i trigger protettivi. Grazie al fallback `is_service_role_or_internal()` (che legge il JWT e rileva `role='service_role'`), queste operazioni **continuano a funzionare senza modifiche a worthy-admin**.

### Codice worthy-admin attuale che modifica campi protetti:

**`worthy-admin/lib/actions/users.ts`** (via service_role):
```typescript
// updateTrustLevel → .update({ trust_level }) — FUNZIONA: JWT ha role='service_role'
// updateUserRole  → .update({ role })          — FUNZIONA: JWT ha role='service_role'
// banUser         → .update({ trust_level: 'banned' }) — FUNZIONA
// unbanUser       → .update({ trust_level: 'new' })    — FUNZIONA
```

**`worthy-admin/lib/actions/products.ts`** (via service_role):
```typescript
// approveProduct → .update({ verification_status: 'verified' }) — FUNZIONA
// rejectProduct  → .update({ verification_status, is_active: false }) — FUNZIONA
// updateProduct  → .update({ verification_status, ... }) — FUNZIONA
// deleteProduct  → .update({ is_active: false }) — FUNZIONA
// bulkApprove    → .update({ verification_status: 'verified' }) — FUNZIONA
```

**Nessuna modifica necessaria a worthy-admin.** Il fallback `is_service_role_or_internal()` gestisce correttamente tutte le operazioni service_role perche PostgREST imposta il JWT con `role='service_role'`.

### Flusso completo per operazione admin:
```
1. worthy-admin chiama supabase.from('users').update({role:'moderator'}).eq('id', userId)
2. PostgREST riceve con service_role key → SET request.jwt.claims = '{"role":"service_role",...}'
3. RLS: service_role ha BYPASSRLS → nessun check
4. BEFORE UPDATE trigger: protect_user_privileged_fields()
5. Check 1: worthy.skip_user_protection → NULL → skip
6. Check 2: is_service_role_or_internal() → JWT role='service_role' → TRUE → RETURN NEW
7. UPDATE procede normalmente
```

### Nota sulla session variable worthy.skip_user_protection:
Per ora non viene mai settata. Serve come meccanismo di bypass per future funzioni RPC admin-only che potrebbero dover operare in contesto non-service_role (es. cron job che aggiorna punti, trigger che cambia trust_level basato su contribuzioni). Quando servira, creare una funzione SECURITY DEFINER tipo:
```sql
CREATE FUNCTION admin_update_user_role(p_user_id uuid, p_role user_role)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM set_config('worthy.skip_user_protection', 'true', true);
  UPDATE users SET role = p_role WHERE id = p_user_id;
  PERFORM set_config('worthy.skip_user_protection', 'false', true);
END;
$$;
```

---

## Riepilogo file modificati

| File | Tipo modifica |
|------|--------------|
| `supabase/migrations/20260417000001_security_fix_helper_and_enum.sql` | Rewrite completo (dblink, fail-closed, no role=null) |
| `supabase/migrations/20260417000002_security_fix_users_protect_privileged.sql` | Rewrite completo (session var + service_role fallback) |
| `supabase/migrations/20260417000003_security_fix_products_protect_privileged.sql` | Rewrite completo (session var, set_config, is_active) |
| `supabase/migrations/20260417000004_security_fix_audit_trigger_searchpath.sql` | Nessuna modifica |
| `supabase/migrations/20260417000005_security_fix_users_select_restrict.sql` | security_barrier + WHERE banned |
| `supabase/migrations/20260417000006_security_fix_votes_reports_hardening.sql` | Nessuna modifica |
| `tests/rls_penetration_tests.sql` | Rewrite completo (anon fix, test aggiuntivi) |
