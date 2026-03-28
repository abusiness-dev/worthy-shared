# WORTHY-SHARED — PRD

> Versione 1.0 · Marzo 2026
> Pacchetto npm condiviso tra worthy-app e worthy-admin

---

## 1. Obiettivo

Pacchetto npm (`@worthy/shared`) che contiene tutto ciò che app mobile e dashboard admin condividono: tipi TypeScript, scoring engine, costanti, validazione, e la struttura delle migration del database.

**Supabase URL:** `https://enophqzovmvhhwtfddnm.supabase.co`
**Project ID:** `enophqzovmvhhwtfddnm`

---

## 2. Setup

- **Nome npm:** `@worthy/shared`
- **Linguaggio:** TypeScript strict mode
- **Build:** tsup (ESM + CJS)
- **Test:** Vitest

Zero dipendenze su React, React Native, Next.js, o qualsiasi framework UI. Logica pura che funziona ovunque.

---

## 3. Cosa contiene

### 3.1 Tipi TypeScript

Definizioni per ogni tabella del database. I tipi principali:

**Product:** id, ean_barcode (nullable), brand_id, category_id, name, slug, price, composition (array di {fiber, percentage}), country_of_production, care_instructions, photo_urls, label_photo_url, worthy_score (0-100), score_composition, score_qpr, score_fit, score_durability, verdict (enum), community_score, community_votes_count, verification_status (enum), scan_count, contributed_by, affiliate_url, is_active, created_at, updated_at.

**Brand:** id, name, slug, logo_url, description, origin_country, market_segment (enum: ultra_fast/fast/premium_fast/mid_range), avg_worthy_score, product_count, total_scans, created_at.

**User:** id, email, display_name, avatar_url, points, trust_level (enum: new/contributor/trusted/banned), role (enum: user/moderator/admin), products_contributed, products_verified, error_rate, streak_days, last_active_date, is_premium, premium_expires_at, created_at, updated_at.

**Category:** id, name, slug, icon, avg_price, avg_composition_score, product_count.

**MattiaReview:** id, product_id (unique), video_url, video_thumbnail_url, score_adjustment (-5 a +5), review_text, published_at.

**ProductVote:** id, product_id, user_id, score (1-10), fit_score (1-10 nullable), durability_score (1-10 nullable), comment, created_at. Unique su (product_id, user_id).

**ProductReport:** id, product_id, user_id, reason (enum: wrong_composition/wrong_price/wrong_brand/duplicate/other), description, status (enum: pending/confirmed/rejected), created_at.

**ScanHistoryEntry:** id, user_id, product_id (nullable), barcode, scan_type (enum: barcode/label/manual/search), found (bool), created_at.

**SavedProduct:** id, user_id, product_id, created_at. Unique su (user_id, product_id).

**SavedComparison:** id, user_id, product_ids (array di uuid), title, created_at.

**Badge:** id (string key), name, description, icon, points_required, benefit.

**UserBadge:** user_id, badge_id, earned_at. PK composita.

**UserConsent:** user_id (PK), tos_accepted, tos_accepted_at, tos_version, push_notifications, push_consent_at, analytics_consent, analytics_consent_at, updated_at.

**ProductDuplicate:** id, product_id, duplicate_of, similarity_score, status (enum: pending/confirmed_duplicate/not_duplicate), resolved_by, created_at, resolved_at.

**AuditLogEntry:** id, table_name, record_id, action (enum: insert/update/delete), user_id, old_data (jsonb), new_data (jsonb), ip_address, created_at.

**DailyWorthy:** id, product_id, featured_date, editorial_note, position, created_at.

**PriceHistory:** id, product_id, price, recorded_at, source (user/scraper/affiliate_feed).

Ogni tipo principale ha anche le varianti `Insert` (campi obbligatori per creazione) e `WithRelations` (con dati joinati).

### 3.2 Scoring engine

**Tabella fibre con punteggi (0-100):**
cashmere 98, seta 95, lana merino 92, cotone supima/pima/egiziano 90, lino 88, cotone biologico 85, lyocell/tencel 80, cotone standard 75, modal 72, viscosa/rayon 55, nylon 50, poliestere riciclato 48, poliestere vergine 30, acrilico 20. Elastan/spandex fino al 5% è neutro (non penalizza).

**calculateCompositionScore(composition[]):** media ponderata dei punteggi fibre per le loro percentuali. Output: 0-100.

**calculateQPR(compScore, price, avgCatScore, avgCatPrice):** rapporto qualità/prezzo normalizzato. Formula: `(compScore/price) / (avgCatScore/avgCatPrice) × 100`, poi sigmoid a 0-100.

**calculateWorthyScore({compositionScore, qprScore, fitScore?, durabilityScore?, mattiaAdjustment?}):** score finale pesato (composizione 35%, QPR 30%, vestibilità 15%, durabilità 15%) + aggiustamento Mattia (±5). Clamped a 0-100. Output: {score, verdict, breakdown}.

**verdictFromScore(score):** 86-100 → steal, 71-85 → worthy, 51-70 → fair, 31-50 → meh, 0-30 → not_worthy.

### 3.3 Costanti

**Punti gamification:** scansione prodotto esistente +2, aggiunta nuovo prodotto +15, conferma dati +5, segnalazione confermata +10, prima scansione del giorno +3, streak 7 giorni +25, referral +20.

**Rate limits:** 20 prodotti/giorno, 60 scansioni/ora, 30 voti/ora, 10 segnalazioni/giorno, 15 scan etichetta/ora.

**Limiti validazione:** nome prodotto 3-200 caratteri, prezzo 0.01-500€, composizione 1-8 fibre, somma percentuali 100% (±1% tolleranza).

**Badge:** Fashion Scout (50 punti), Style Expert (200 punti), Database Hero (500 punti), Worthy Legend (1000 punti), Top Contributor (top 10 mensile).

**Categorie iniziali:** T-Shirt, Felpe, Jeans, Pantaloni, Giacche, Sneakers, Camicie, Intimo, Accessori.

**Brand di lancio:** Zara, H&M, Uniqlo, Shein, Bershka, Pull&Bear, Stradivarius, Primark, ASOS, Mango, COS, Massimo Dutti.

### 3.4 Validazione

**validateProduct(data):** verifica tutti i campi obbligatori, nome nel range, prezzo nel range, brand_id e category_id validi. Output: {valid, errors[]}.

**validateComposition(fibers):** almeno 1 fibra, max 8, ogni percentuale > 0 e ≤ 100, somma = 100 (±1%), nessun duplicato. Output: {valid, errors[]}.

**validatePrice(price, composition):** prezzo nel range + check plausibilità (cashmere a €3 è implausibile, poliestere a €200 è implausibile). Output: {valid, plausible, warning?}.

**isValidEAN13(code), isValidUPC(code):** validazione check digit barcode.

### 3.5 Utility

**formatPrice(9.90)** → "€9,90"
**slugify("Pull&Bear")** → "pull-and-bear"

---

## 4. Migrations — Struttura

Le migrations sono file SQL in `supabase/migrations/`. Tu scrivi il SQL, questo PRD definisce solo l'ordine e le dipendenze.

| # | Cosa crea | Dipende da |
|---|---|---|
| 001 | Tutti i tipi enum | Nulla |
| 002 | brands | enum market_segment |
| 003 | categories | Nulla |
| 004 | badges | Nulla |
| 005 | users | enum trust_level, user_role |
| 006 | products | brands, categories, users, enum verification_status, verdict |
| 007 | price_history | products |
| 008 | mattia_reviews | products |
| 009 | product_votes | products, users |
| 010 | product_reports | products, users, enum report_reason, report_status |
| 011 | scan_history | products, users, enum scan_type |
| 012 | saved_products | products, users |
| 013 | saved_comparisons | users |
| 014 | user_badges | users, badges |
| 015 | user_consents | users |
| 016 | product_duplicates | products, users, enum duplicate_status |
| 017 | audit_log | users, enum audit_action |
| 018 | daily_worthy | products |
| 019 | Indici | Tutte |
| 020 | RLS policies | Tutte + auth |
| 021 | Functions (scoring, duplicate detection) | Tutte |
| 022 | Triggers (audit log, auto-update timestamps) | Functions + tabelle |
| 023 | Materialized views (brand_rankings, trending) | products, brands |
| 024 | Cron jobs (refresh views ogni 15 min) | Views |

**Seed data** (`supabase/seed.sql`): le 9 categorie, i 12 brand, i 5 badge, un utente admin di test.

---

## 5. Test richiesti

- Scoring: 100% cotone prezzo basso → score alto
- Scoring: 100% poliestere prezzo alto → score basso
- Scoring: elastan 3% neutro, elastan 10% penalizza
- Scoring: fibra sconosciuta → default 50
- Scoring: aggiustamento Mattia +5 su 98 → clamp a 100
- Validazione: composizione che somma 101% → errore
- Validazione: prezzo negativo → errore
- Validazione: barcode con check digit errato → invalido
- Validazione: cashmere a €3 → plausible = false
