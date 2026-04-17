# Schema Drift Report — Worthy Database

**Data audit**: 2026-04-17
**Metodologia**: Confronto tra schema ricostruito da 34 migration SQL, tipi TypeScript (`src/types/` + `database.generated.ts`), e tutte le query Supabase in worthy-app e worthy-admin.
**Nota**: Non e stato possibile eseguire `supabase db dump --linked` (Docker non disponibile). L'analisi si basa sul codice sorgente.

---

## Drift Trovati

### D-001 — `push_token` su tabella `users` (NON ESISTE)

| Campo | Dettaglio |
|-------|-----------|
| Colonna | `push_token` |
| Tabella | `users` |
| File | `worthy-app/hooks/useNotifications.ts:67` |
| Operazione | `.update({ push_token: token })` |
| Tipo drift | Colonna referenziata nel codice ma mai creata nelle migration |
| Impatto | L'UPDATE fallisce silenziosamente (Supabase ignora colonne extra in `.update()`) o con errore a seconda della versione del client |

**Azione richiesta**: Decidere se push_token va nel DB (creare migration `ALTER TABLE users ADD COLUMN push_token text`) o in un servizio esterno (rimuovere il codice).

### D-002 — `scanned_at` su tabella `scan_history` (NON ESISTE)

| Campo | Dettaglio |
|-------|-----------|
| Colonna | `scanned_at` |
| Tabella | `scan_history` (colonna corretta: `created_at`) |
| File 1 | `worthy-app/hooks/useUserPoints.ts:47` — `.order('scanned_at', { ascending: false })` |
| File 2 | `worthy-app/app/(tabs)/saved/index.tsx:114` — `new Date(sh.scanned_at).toLocaleDateString(...)` |
| Tipo drift | Errore di naming nel codice app |
| Impatto | File 1: ORDER BY su colonna inesistente, potrebbe causare errore o ordinamento non deterministico. File 2: `sh.scanned_at` e `undefined`, `new Date(undefined)` produce "Invalid Date" nell'UI. |

**Azione richiesta**: Rinominare `scanned_at` in `created_at` in entrambi i file.

### D-003 — `saved_at` su tabella `saved_products` (NON ESISTE)

| Campo | Dettaglio |
|-------|-----------|
| Colonna | `saved_at` |
| Tabella | `saved_products` (colonna corretta: `created_at`) |
| File | `worthy-app/hooks/useUserPoints.ts:63` — `.order('saved_at', { ascending: false })` |
| Tipo drift | Errore di naming nel codice app |
| Impatto | ORDER BY su colonna inesistente |

**Azione richiesta**: Rinominare `saved_at` in `created_at`.

---

## Verifica Incrociata

| Sorgente | push_token | scanned_at | saved_at |
|----------|-----------|------------|---------|
| Migration SQL | Assente | Assente | Assente |
| `database.generated.ts` | Assente | Assente | Assente |
| `src/types/scan.ts` | N/A | Assente (ha `created_at`) | N/A |
| `src/types/saved.ts` | N/A | N/A | Assente (ha `created_at`) |
| worthy-app codice | Presente (1 file) | Presente (2 file) | Presente (1 file) |
| worthy-admin codice | Assente | Assente | Assente |

**Conclusione**: Sono bug nel codice di worthy-app, non drift tra migration e database di produzione.

---

## Tabelle Non Utilizzate

| Tabella | worthy-app | worthy-admin | Note |
|---------|-----------|-------------|------|
| `price_history` | Non usata | Non usata | Feature non implementata. Schema e RLS corretti. |
| `saved_comparisons` | Non usata (usa AsyncStorage locale) | Non usata | Feature locale. Schema e RLS corretti. |
| `user_consents` | Non usata | Non usata | Feature GDPR prevista. Schema e RLS corretti. |

Nessun rischio di sicurezza — pronte per uso futuro.

---

## Impatto sulle Migration di Sicurezza

**Nessun impatto.** I 3 drift sono bug app-side che non influenzano le RLS policies. Le migration di sicurezza RLS possono procedere indipendentemente. Il fix dei drift e un task separato da eseguire in worthy-app.
