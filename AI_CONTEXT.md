# WORTHY-SHARED — Contesto per AI

> Questo file serve a qualsiasi AI (Claude, Cursor, Copilot, ecc.) che lavora su questo progetto.
> Leggilo PRIMA di scrivere qualsiasi codice.

---

## Cos'è questo progetto

`worthy-shared` è il pacchetto npm condiviso tra l'app mobile Worthy (`worthy-app`) e la dashboard admin (`worthy-admin`). Contiene SOLO logica pura, tipi e costanti. NON contiene UI, NON contiene componenti visivi, NON contiene codice specifico per React Native o Next.js.

Questo pacchetto viene importato dagli altri due progetti come `@worthy/shared`. Ogni modifica qui si riflette in entrambe le app.

## Cosa contiene

- **Tipi TypeScript** — definizioni di tutte le tabelle del database (Product, Brand, User, Category, Vote, ecc.)
- **Scoring engine** — le funzioni che calcolano il Worthy Score (composizione, rapporto qualità/prezzo, score finale)
- **Costanti** — tabella punteggi fibre, lista badge, categorie, verdetti, limiti di validazione
- **Validazione** — regole di validazione per prodotti, composizioni, prezzi (usate sia dall'app che dalla dashboard)
- **Query Supabase tipizzate** — helper per le query più comuni
- **Migrations del database** — i file SQL che definiscono e modificano lo schema del database. Questo pacchetto è l'UNICO proprietario dello schema.

**IMPORTANTE:** Questo pacchetto è l'unica fonte di verità per lo schema del database. Né `worthy-app` né `worthy-admin` possono creare o modificare tabelle, colonne, funzioni, trigger, indici, o RLS. Le migrations vivono in `supabase/migrations/` e vengono applicate tramite Supabase CLI. Vedi `WORTHY_DATABASE_GUIDE.md` per il flusso completo.

## Stack tecnologico

- **Linguaggio:** TypeScript strict mode
- **Build:** tsup (o tsc) per compilare a ESM + CJS
- **Testing:** Vitest
- **Pubblicazione:** npm (pacchetto privato `@worthy/shared`) o GitHub Packages

## Database

Il database è PostgreSQL gestito da Supabase.

**Progetto Supabase di produzione:**
- **URL:** `https://enophqzovmvhhwtfddnm.supabase.co`
- **Project ID:** `enophqzovmvhhwtfddnm`
- **Dashboard:** `https://supabase.com/dashboard/project/enophqzovmvhhwtfddnm`
- **API REST:** `https://enophqzovmvhhwtfddnm.supabase.co/rest/v1/`
- **Auth:** `https://enophqzovmvhhwtfddnm.supabase.co/auth/v1/`
- **Storage:** `https://enophqzovmvhhwtfddnm.supabase.co/storage/v1/`
- **Edge Functions:** `https://enophqzovmvhhwtfddnm.supabase.co/functions/v1/`

Questo pacchetto NON si connette al database direttamente. Definisce solo i tipi che corrispondono allo schema e le query helper che i consumer (app e admin) usano con il loro client Supabase. Le API key (anon e service_role) NON vanno mai in questo pacchetto.

## Come generare i tipi dal database

I tipi TypeScript devono corrispondere allo schema reale del database. Supabase CLI può generarli automaticamente:

```bash
# Installa Supabase CLI se non presente
npm install -g supabase

# Login (serve un access token da supabase.com/dashboard/account/tokens)
supabase login

# Genera i tipi dal database di produzione
supabase gen types typescript --project-id enophqzovmvhhwtfddnm > src/types/database.generated.ts
```

Dopo la generazione, i tipi custom in `src/types/` (Product, Brand, ecc.) dovrebbero estendere o wrappare i tipi generati, NON duplicarli. Se lo schema del database cambia (nuova colonna, nuova tabella), rigenera i tipi e aggiorna le definizioni custom di conseguenza.

## Come collegare Supabase in locale per testing

```bash
# Avvia Supabase locale con Docker (per test senza toccare produzione)
supabase init
supabase start

# Questo crea un'istanza locale con URL tipo http://localhost:54321
# e chiavi locali stampate nel terminale

# Applica le migrations
supabase db push

# Per connetterti al progetto remoto di produzione
supabase link --project-ref enophqzovmvhhwtfddnm
```

Le tabelle principali sono:

- `users` — profilo utente, punti, trust level
- `brands` — brand con score medio
- `categories` — categorie prodotto
- `products` — prodotti con worthy score, composizione, verificazione
- `price_history` — storico prezzi
- `mattia_reviews` — video review di Mattia
- `product_votes` — voti community
- `product_reports` — segnalazioni dati errati
- `scan_history` — cronologia scansioni utente
- `saved_products` — prodotti salvati
- `saved_comparisons` — confronti salvati
- `badges` — definizione badge
- `user_badges` — badge sbloccati dagli utenti
- `user_consents` — consensi GDPR
- `product_duplicates` — duplicati potenziali
- `audit_log` — log modifiche
- `daily_worthy` — deal giornalieri (fase 2)

## Scoring engine — Come funziona

Il Worthy Score è 0-100, calcolato così:

```
Score = (Composizione × 0.35) + (QPR × 0.30) + (Vestibilità × 0.15) + (Durabilità × 0.15) + Aggiustamento Mattia (±5)
```

Lo score composizione si calcola dalla media ponderata dei punteggi delle fibre. Ogni fibra ha un punteggio fisso (es. cotone = 75, poliestere = 30, cashmere = 98). L'elastan sotto il 5% è neutro.

Il QPR (rapporto qualità/prezzo) confronta lo score composizione con il prezzo, normalizzato sulla media della categoria.

I verdetti sono: steal (86-100), worthy (71-85), fair (51-70), meh (31-50), not_worthy (0-30).

---

## REGOLE — Cosa puoi fare

- Aggiungere, modificare o rimuovere tipi TypeScript
- Modificare la logica dello scoring engine
- Aggiungere nuove fibre alla tabella punteggi
- Aggiungere nuove funzioni di validazione
- Aggiungere nuove query helper
- Aggiungere nuove costanti
- Scrivere e modificare test
- Aggiornare la versione del pacchetto in package.json

## REGOLE — Cosa NON puoi fare MAI

- **NON aggiungere dipendenze su React, React Native, Next.js, Expo, o qualsiasi framework UI.** Questo pacchetto è logica pura. Deve funzionare in qualsiasi ambiente JavaScript/TypeScript.
- **NON aggiungere codice che si connette al database.** Niente `createClient()`, niente URL Supabase, niente API key. I consumer (app e admin) gestiscono la connessione.
- **NON aggiungere codice specifico per una piattaforma** (no `Platform.OS`, no `window`, no `document`, no `process.env`). Il codice deve essere isomorfico.
- **NON cambiare i nomi dei tipi esportati senza verificare l'impatto sugli altri due progetti.** Un rename qui rompe sia `worthy-app` che `worthy-admin`.
- **NON modificare la formula dello scoring senza documentare la modifica.** Lo scoring è il core business — ogni cambio deve essere intenzionale e testato.
- **NON aggiungere API key, secret, URL di produzione, o qualsiasi dato sensibile.** Questo pacchetto è pubblicato su npm.
- **NON esportare funzioni async che fanno fetch/network call.** Solo logica sincrona pura (calcoli, validazione, trasformazioni dati).

## Struttura cartelle

```
src/
├── types/                  # Tipi TypeScript per ogni tabella
│   ├── product.ts          # Product, ProductInsert, ProductUpdate
│   ├── brand.ts            # Brand, BrandWithStats
│   ├── user.ts             # User, UserProfile, TrustLevel
│   ├── category.ts         # Category
│   ├── vote.ts             # ProductVote
│   ├── review.ts           # MattiaReview
│   ├── report.ts           # ProductReport, ReportReason
│   ├── badge.ts            # Badge, UserBadge
│   ├── scan.ts             # ScanHistoryEntry, ScanType
│   ├── daily.ts            # DailyWorthy
│   ├── consent.ts          # UserConsent
│   └── index.ts            # Re-export tutto
├── scoring/
│   ├── fiberScores.ts      # FIBER_SCORES: Record<string, number>
│   ├── calculateComposition.ts
│   ├── calculateQPR.ts
│   ├── calculateWorthyScore.ts
│   └── index.ts
├── constants/
│   ├── fibers.ts           # Lista fibre con nomi localizzati
│   ├── badges.ts           # Definizione badge e requisiti
│   ├── categories.ts       # Lista categorie con icone
│   ├── verdicts.ts         # Verdetti con colori e label
│   ├── limits.ts           # Rate limits, max values, soglie
│   └── index.ts
├── validation/
│   ├── productValidation.ts    # validateProduct(), validateComposition()
│   ├── compositionValidation.ts # isValidComposition(), sumPercentages()
│   ├── priceValidation.ts      # isValidPrice(), isPricePlausible()
│   └── index.ts
└── index.ts                # Entry point: export * from tutti i moduli
```

## Come testare

```bash
npm test              # Esegue tutti i test
npm run test:scoring  # Solo test dello scoring engine
npm run build         # Compila TypeScript
npm run lint          # ESLint
```

## Come pubblicare una nuova versione

```bash
npm version patch     # o minor/major
npm publish           # pubblica su npm
```

Dopo la pubblicazione, aggiornare la dipendenza in `worthy-app` e `worthy-admin`:
```bash
cd ../worthy-app && npm update @worthy/shared
cd ../worthy-admin && npm update @worthy/shared
```
