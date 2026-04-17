# RLS Security Audit Report — Worthy Database

**Data audit**: 2026-04-17
**Database**: Supabase `enophqzovmvhhwtfddnm`
**Repo**: `abusiness-dev/worthy-shared` (PUBBLICO)
**Auditor**: Security audit automatizzato + review manuale

---

## EXECUTIVE SUMMARY

**10 vulnerabilita trovate**: 4 CRITICHE, 3 ALTE, 3 MEDIE

### Le 3 piu critiche

1. **V-001** (users): Tabella utenti COMPLETAMENTE leggibile da chiunque (anon incluso). Email, ruolo admin, stato premium esposti. Violazione GDPR.
2. **V-002** (users): Privilege escalation — un utente autenticato puo fare `UPDATE users SET role='admin'` sul proprio profilo.
3. **V-003/V-004** (products): Score manipulation — un utente puo inserire prodotti con `verification_status='mattia_reviewed'` e modificare `worthy_score=100` direttamente.

### Fix applicati

6 migration di sicurezza in `supabase/migrations/20260417000001-000006`.

---

## INVENTARIO COMPLETO TABELLE

### 1. products

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI (`20260326000020`) |
| Policies | `products_select_public` (SELECT, PUBLIC, `USING (true)`) |
| | `products_insert_auth` (INSERT, authenticated, `WITH CHECK (auth.uid() = contributed_by)`) |
| | `products_update_own_recent` (UPDATE, authenticated, `USING (auth.uid() = contributed_by AND created_at > now() - interval '24 hours')`, `WITH CHECK (auth.uid() = contributed_by)`) |
| Chi legge | Chiunque (anon, authenticated) — inclusi prodotti soft-deleted |
| Chi scrive | Authenticated: INSERT (proprio), UPDATE (proprio, entro 24h). Nessun DELETE (soft-delete via is_active) |
| Rischio | **CRITICO** (V-003, V-004, V-009) |

### 2. brands

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `brands_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 3. categories

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `categories_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 4. badges

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `badges_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 5. users

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `users_select_public` (SELECT, PUBLIC, `USING (true)`) |
| | `users_update_own` (UPDATE, authenticated, `USING (auth.uid() = id)`, `WITH CHECK (auth.uid() = id)`) |
| Chi legge | Chiunque — TUTTI i campi di TUTTI gli utenti inclusi email, role, trust_level, is_premium, error_rate |
| Chi scrive | Authenticated: UPDATE proprio profilo — TUTTE le colonne inclusi role, points, is_premium |
| Rischio | **CRITICO** (V-001, V-002) |

### 6. price_history

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `price_history_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 7. mattia_reviews

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `mattia_reviews_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque — nessun filtro su published_at |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **MEDIO** (V-010) — se si aggiungono draft in futuro, sarebbero visibili |

### 8. product_votes

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `product_votes_select_public` (SELECT, PUBLIC, `USING (true)`) |
| | `product_votes_insert_auth` (INSERT, authenticated, `WITH CHECK (auth.uid() = user_id)`) |
| | `product_votes_update_own` (UPDATE, authenticated, `USING (auth.uid() = user_id)`, `WITH CHECK (auth.uid() = user_id)`) |
| Chi legge | Chiunque — tutti i voti con user_id, score, commenti |
| Chi scrive | Authenticated: INSERT/UPDATE propri voti. Nessun DELETE |
| Rischio | **ALTO** (V-007) — UPDATE permette cambio product_id |

### 9. product_reports

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `product_reports_insert_auth` (INSERT, authenticated, `WITH CHECK (auth.uid() = user_id)`) |
| | `product_reports_select_own` (SELECT, authenticated, `USING (auth.uid() = user_id)`) |
| Chi legge | Authenticated: solo propri report |
| Chi scrive | Authenticated: INSERT propri report — status non validato |
| Rischio | **MEDIO** (V-008) — INSERT con status='confirmed' possibile |

### 10. scan_history

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `scan_history_select_own` (SELECT, authenticated, `USING (auth.uid() = user_id)`) |
| | `scan_history_insert_own` (INSERT, authenticated, `WITH CHECK (auth.uid() = user_id)`) |
| | `scan_history_delete_own` (DELETE, authenticated, `USING (auth.uid() = user_id)`) |
| Chi legge | Authenticated: solo propria cronologia |
| Chi scrive | Authenticated: INSERT/DELETE propri record |
| Rischio | **BASSO** |

### 11. saved_products

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `saved_products_select_own`, `saved_products_insert_own`, `saved_products_delete_own` (tutti authenticated, `auth.uid() = user_id`) |
| Chi legge | Authenticated: solo propri |
| Chi scrive | Authenticated: INSERT/DELETE propri |
| Rischio | **BASSO** |

### 12. saved_comparisons

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `saved_comparisons_select_own`, `saved_comparisons_insert_own`, `saved_comparisons_delete_own` (tutti authenticated, `auth.uid() = user_id`) |
| Chi legge | Authenticated: solo propri |
| Chi scrive | Authenticated: INSERT/DELETE propri |
| Rischio | **BASSO** |

### 13. user_badges

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `user_badges_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 14. user_consents

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `user_consents_select_own`, `user_consents_insert_own`, `user_consents_update_own` (tutti authenticated, `auth.uid() = user_id`) |
| Chi legge | Authenticated: solo proprio record |
| Chi scrive | Authenticated: INSERT/UPDATE proprio record |
| Rischio | **BASSO** |

### 15. product_duplicates

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | Nessuna (default deny) |
| Chi legge | Nessuno (solo service_role) |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** — manca defense-in-depth REVOKE (V-006) |

### 16. audit_log

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | Nessuna (default deny) |
| Chi legge | Nessuno (solo service_role) |
| Chi scrive | trigger_audit_log() SECURITY DEFINER (bypass RLS) |
| Rischio | **ALTO** (V-005, V-006) — trigger senza search_path, nessun REVOKE |

### 17. daily_worthy

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI |
| Policies | `daily_worthy_select_public` (SELECT, PUBLIC, `USING (true)`) |
| Chi legge | Chiunque |
| Chi scrive | Nessuno (solo service_role) |
| Rischio | **BASSO** |

### 18. user_brand_preferences

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI (`20260412000004`) |
| Policies | `user_brand_prefs_select_own`, `user_brand_prefs_insert_own`, `user_brand_prefs_delete_own` (tutti authenticated, `auth.uid() = user_id`) |
| Chi legge | Authenticated: solo propri |
| Chi scrive | Authenticated: INSERT/DELETE propri |
| Rischio | **BASSO** |

### 19. user_category_preferences

| Aspetto | Dettaglio |
|---------|-----------|
| RLS abilitato | SI (`20260412000004`) |
| Policies | `user_category_prefs_select_own`, `user_category_prefs_insert_own`, `user_category_prefs_delete_own` (tutti authenticated, `auth.uid() = user_id`) |
| Chi legge | Authenticated: solo propri |
| Chi scrive | Authenticated: INSERT/DELETE propri |
| Rischio | **BASSO** |

### Storage: avatars bucket

| Aspetto | Dettaglio |
|---------|-----------|
| RLS | Gestito da policy su storage.objects |
| Policies | `avatars_public_read` (SELECT, `bucket_id = 'avatars'`) |
| | `avatars_insert_own` (INSERT, authenticated, `bucket_id = 'avatars' AND foldername[1] = auth.uid()`) |
| | `avatars_update_own` (UPDATE, authenticated, stessa condizione) |
| | `avatars_delete_own` (DELETE, authenticated, stessa condizione) |
| Rischio | **BASSO** — path enforcement corretto |

---

## FUNZIONI SECURITY DEFINER

| Funzione | SECURITY DEFINER | SET search_path | File | Rischio |
|----------|-----------------|-----------------|------|---------|
| `trigger_audit_log()` | SI | **NO** | `20260326000022` / `20260328000001` | **ALTO** (V-005) |
| `handle_new_user()` | SI | `public, auth` | `20260408000001` | BASSO |
| `calculate_composition_score()` | NO | NO | `20260412000006` | BASSO (non SECURITY DEFINER) |
| `calculate_qpr()` | NO | NO | `20260326000021` | BASSO |
| `calculate_worthy_score()` | NO | NO | `20260412000006` | BASSO |
| `find_potential_duplicates()` | NO | NO | `20260326000021` | BASSO |
| `trigger_set_updated_at()` | NO | NO | `20260326000022` | BASSO |
| `trigger_calculate_worthy_score()` | NO | NO | `20260326000022` | BASSO |
| `recalculate_brand_avg_scores()` | NO | NO | `20260412000006` | BASSO |

---

## DETTAGLIO VULNERABILITA

### V-001 — users SELECT pubblico (CRITICO)

**Policy**: `users_select_public` in `20260326000020:64-65`
```sql
CREATE POLICY "users_select_public"
  ON users FOR SELECT
  USING (true);
```

**Impatto**: Qualsiasi client con la anon key (pubblica nel repo) puo eseguire:
```sql
SELECT email, role, trust_level, is_premium, points, error_rate FROM users;
```
- **GDPR**: email di tutti gli utenti esposti
- **Sicurezza**: account admin/moderator identificabili via `role`
- **Business**: stato premium di tutti gli utenti visibile
- **Gamification**: trust_level, points, error_rate esposti

**Fix**: Migration `20260417000005` — DROP policy, CREATE `users_select_own` (solo proprio record), CREATE VIEW `user_public_profiles` (solo campi sicuri).

### V-002 — users privilege escalation (CRITICO)

**Policy**: `users_update_own` in `20260326000020:68-72`
```sql
CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
```

**Impatto**: Un utente autenticato puo eseguire:
```sql
UPDATE users SET role = 'admin', is_premium = true, points = 999999
WHERE id = auth.uid();
```

**Fix**: Migration `20260417000002` — BEFORE UPDATE trigger che blocca modifiche a role, trust_level, points, is_premium, ecc. con RAISE EXCEPTION + audit log.

### V-003 — products INSERT con valori arbitrari (CRITICO)

**Policy**: `products_insert_auth` in `20260326000020:33-36`
```sql
CREATE POLICY "products_insert_auth"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = contributed_by);
```

**Impatto**: Un utente puo inserire prodotti con:
```sql
INSERT INTO products (contributed_by, ..., verification_status, scan_count)
VALUES (auth.uid(), ..., 'mattia_reviewed', 99999);
```
I campi `verification_status` e `scan_count` NON vengono recalcolati dal trigger AFTER INSERT.

**Fix**: Migration `20260417000003` — BEFORE INSERT trigger che forza defaults + calcola score inline.

### V-004 — products UPDATE su campi score (CRITICO)

**Policy**: `products_update_own_recent` in `20260326000020:38-42`

**Impatto**: Entro 24h dall'inserimento, un utente puo:
```sql
UPDATE products SET worthy_score = 100, verdict = 'steal', verification_status = 'verified'
WHERE contributed_by = auth.uid();
```
Il trigger di scoring si attiva SOLO se composition, price, o category_id cambiano.

**Fix**: Migration `20260417000003` — BEFORE UPDATE trigger che blocca modifiche a campi score/verification.

### V-005 — trigger_audit_log senza search_path (ALTO)

**Funzione**: `trigger_audit_log()` in `20260328000001:4-6`
```sql
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
```
Manca `SET search_path`. Vulnerabile a search_path manipulation.

**Fix**: Migration `20260417000004` — ricrea con `SET search_path = public, pg_temp`.

### V-006 — Mancanza REVOKE defense-in-depth (ALTO)

**Tabelle**: audit_log, product_duplicates

RLS abilitato senza policy = default deny (corretto). Ma senza REVOKE esplicito, una policy aggiunta per errore esporrebbe immediatamente la tabella.

**Fix**: Migration `20260417000006` — REVOKE ALL su audit_log da anon/authenticated. REVOKE INSERT/UPDATE/DELETE su tabelle reference.

### V-007 — product_votes UPDATE product_id (ALTO)

**Policy**: `product_votes_update_own` in `20260326000020:105-109`

La policy controlla `auth.uid() = user_id` ma non impedisce la modifica di `product_id`. Un utente puo "trasferire" il proprio voto da un prodotto a un altro.

**Fix**: Migration `20260417000006` — BEFORE UPDATE trigger che blocca modifiche a product_id e user_id.

### V-008 — product_reports INSERT status (MEDIO)

**Policy**: `product_reports_insert_auth` in `20260326000020:115-118`

La policy non valida il campo `status`. Un utente puo inserire un report con `status = 'confirmed'` saltando la moderazione.

**Fix**: Migration `20260417000006` — BEFORE INSERT trigger che forza `status = 'pending'`.

### V-009 — products SELECT mostra soft-deleted (MEDIO)

**Policy**: `products_select_public` in `20260326000020:29-31`

`USING (true)` non filtra `is_active`. Prodotti soft-deleted visibili a tutti.

**Fix**: Migration `20260417000006` — ricrea con `USING (is_active = true)`.

### V-010 — mattia_reviews senza filtro published (MEDIO — DA RIVEDERE)

**Policy**: `mattia_reviews_select_public` in `20260326000020:86-88`

Attualmente `published_at` e `NOT NULL DEFAULT now()`, quindi non esistono draft. Ma se in futuro si rende `published_at` nullable per supportare draft, tutte le review sarebbero visibili prima della pubblicazione. Da rivedere quando si aggiunge la feature draft.

---

## CHECKLIST FINALE DI SICUREZZA

- [x] Ogni tabella ha RLS abilitato (19/19 tabelle)
- [x] Ogni tabella ha almeno una policy o e documentata come "service_role only" (product_duplicates, audit_log)
- [ ] Campi privilegiati (role, points, is_premium, trust_level, worthy_score, verification_status) sono read-only per authenticated tramite trigger BEFORE UPDATE (**FIX: migration 000002, 000003**)
- [ ] Nessuna policy usa USING (true) su operazioni di scrittura (**OK**: nessuna policy di scrittura usa USING(true))
- [ ] Tutte le funzioni SECURITY DEFINER hanno SET search_path esplicito (**FIX: migration 000004** per trigger_audit_log)
- [ ] Audit log e append-only anche per service_role (**PARZIALE**: no REVOKE UPDATE/DELETE da service_role — service_role e trusted)
- [ ] L'anon key puo solo leggere products, brands, categories, mattia_reviews, badges, daily_worthy, user_badges, price_history (**FIX: migration 000005** rimuove SELECT users da anon)
- [ ] L'auth.users table non e esposta in view pubbliche (**OK**: solo handle_new_user accede a auth.users, con SECURITY DEFINER)
- [ ] Nessuna funzione SECURITY DEFINER senza search_path (**FIX: migration 000004**)
- [ ] Defense-in-depth: REVOKE su tabelle service_role-only (**FIX: migration 000006**)
- [ ] Admin/moderator hanno policy SELECT per moderazione (**FIX: migration 000006** — product_duplicates_select_admin, product_reports_select_admin)
- [ ] Prodotti soft-deleted non visibili da SELECT (**FIX: migration 000006** — `USING (is_active = true)`)
