# WORTHY — Gestione Database e Migrations

> Questo documento spiega CHI gestisce il database, COME si modifica lo schema,
> e PERCHÉ nessun altro progetto deve toccare la struttura del database.

---

## La regola d'oro

**Lo schema del database (tabelle, colonne, funzioni, trigger, indici, RLS, enum) si modifica SOLO tramite migration files in questa cartella. Mai a mano nella dashboard Supabase, mai dall'app, mai dalla dashboard admin.**

Se violi questa regola, perdi il controllo di cosa esiste nel database, quando è stato creato, e perché. A quel punto qualsiasi AI o sviluppatore che lavora su uno dei progetti può rompere tutto senza saperlo.

---

## Chi possiede cosa

```
worthy-shared/supabase/migrations/    ← UNICO proprietario dello schema DB
    │
    │   Definisce: tabelle, colonne, tipi enum, funzioni SQL,
    │   trigger, indici, RLS policies, materialized views,
    │   seed data, cron jobs
    │
    ├── worthy-app          ← SOLO lettura/scrittura DATI (righe)
    │                          Non crea tabelle, non modifica colonne,
    │                          non aggiunge funzioni, non tocca RLS
    │
    └── worthy-admin         ← SOLO lettura/scrittura DATI (righe)
                               Può fare query più potenti (service_role)
                               ma NON modifica lo schema
```

Pensa al database come a un edificio. Le migrations sono il progetto dell'architetto — decidono quante stanze ci sono, dove stanno le porte, dove passa l'impianto elettrico. L'app e la dashboard sono gli inquilini — usano le stanze, spostano i mobili (i dati), ma non buttano giù i muri.

---

## Struttura delle migrations

```
worthy-shared/
└── supabase/
    ├── config.toml                    # Config Supabase CLI
    ├── seed.sql                       # Dati iniziali (brand, categorie, badge)
    └── migrations/
        ├── 20260326000001_create_enums.sql
        ├── 20260326000002_create_brands.sql
        ├── 20260326000003_create_categories.sql
        ├── 20260326000004_create_users.sql
        ├── 20260326000005_create_products.sql
        ├── 20260326000006_create_price_history.sql
        ├── 20260326000007_create_mattia_reviews.sql
        ├── 20260326000008_create_product_votes.sql
        ├── 20260326000009_create_product_reports.sql
        ├── 20260326000010_create_scan_history.sql
        ├── 20260326000011_create_saved_products.sql
        ├── 20260326000012_create_saved_comparisons.sql
        ├── 20260326000013_create_badges.sql
        ├── 20260326000014_create_user_badges.sql
        ├── 20260326000015_create_user_consents.sql
        ├── 20260326000016_create_product_duplicates.sql
        ├── 20260326000017_create_audit_log.sql
        ├── 20260326000018_create_daily_worthy.sql
        ├── 20260326000019_create_indexes.sql
        ├── 20260326000020_create_rls_policies.sql
        ├── 20260326000021_create_functions.sql
        ├── 20260326000022_create_triggers.sql
        ├── 20260326000023_create_materialized_views.sql
        ├── 20260326000024_create_cron_jobs.sql
        └── ... (future migrations qui sotto)
```

Ogni file è numerato con timestamp. Supabase li esegue in ordine. Una migration eseguita non viene mai modificata — se devi cambiare qualcosa, crei una NUOVA migration.

---

## Il flusso di lavoro corretto

### Scenario: "Devo aggiungere un campo `color` alla tabella products"

**Passo 1: Crea la migration**

```bash
cd worthy-shared
supabase migration new add_color_to_products
```

Questo crea un file vuoto tipo:
`supabase/migrations/20260401120000_add_color_to_products.sql`

**Passo 2: Scrivi lo SQL**

```sql
-- 20260401120000_add_color_to_products.sql
ALTER TABLE products ADD COLUMN color text;
COMMENT ON COLUMN products.color IS 'Colore primario del prodotto (opzionale)';
```

**Passo 3: Testa in locale**

```bash
# Avvia Supabase locale (Docker)
supabase start

# Applica tutte le migrations in locale
supabase db reset

# Verifica che la colonna esista
# Apri http://localhost:54323 (Supabase Studio locale) e controlla
```

**Passo 4: Aggiorna i tipi TypeScript**

```bash
# Rigenera i tipi dal database locale
supabase gen types typescript --local > src/types/database.generated.ts

# Aggiorna il tipo Product in src/types/product.ts
# Aggiungi: color?: string | null;
```

**Passo 5: Pubblica il pacchetto condiviso**

```bash
npm version patch
npm publish
```

**Passo 6: Applica a produzione**

```bash
supabase link --project-ref enophqzovmvhhwtfddnm
supabase db push
```

**Passo 7: Aggiorna i client**

```bash
# In worthy-app
cd ../worthy-app
npm update @worthy/shared

# In worthy-admin
cd ../worthy-admin
npm update @worthy/shared
```

Ora entrambi i progetti vedono il nuovo campo `color`, con il tipo corretto, senza che nessuno dei due abbia toccato lo schema direttamente.

---

## Cosa succede se qualcuno rompe la regola

### Scenario sbagliato 1: "Creo una tabella dalla dashboard Supabase a mano"

Vai nella dashboard Supabase, clicchi "New Table", crei `promotions`. Funziona? Sì, la tabella esiste. Ma:

- Non c'è nessun file migration che la descrive
- Se qualcuno fa `supabase db reset` in locale, la tabella non esiste
- Se un'AI lavora sull'app, non sa che `promotions` esiste (non è nei tipi)
- Se tra 3 mesi devi ricreare il database (nuovo ambiente staging, disaster recovery), `promotions` non viene ricreata
- Se un altro sviluppatore fa `supabase db push` con una migration che per caso ha lo stesso nome di una tua colonna, conflitto

### Scenario sbagliato 2: "L'AI della dashboard admin crea una funzione SQL"

Stai usando Cursor sulla dashboard admin. Chiedi all'AI di creare una funzione `get_top_contributors()`. L'AI genera un Server Action che fa `supabase.rpc('get_top_contributors')` e crea la funzione direttamente nel database con una query `CREATE FUNCTION`.

Problema: quella funzione non è in nessuna migration. Quando fai `supabase db reset` in locale, non esiste. Quando l'AI dell'app mobile prova a usarla, non sa che esiste. Se qualcuno fa `supabase db push` con flag `--reset`, viene cancellata.

### Scenario sbagliato 3: "L'AI dell'app aggiunge una colonna via ALTER TABLE"

Stai sviluppando l'app con Claude Code. Serve un campo `is_featured` su products. L'AI esegue `ALTER TABLE products ADD COLUMN is_featured boolean`. Funziona in quel momento, ma:

- La dashboard admin non ha il tipo aggiornato, non sa che `is_featured` esiste
- Il pacchetto condiviso ha tipi vecchi
- Non c'è migration, quindi l'ambiente locale e staging non hanno quella colonna

---

## Le regole per l'AI — Da aggiungere a ogni AI_CONTEXT.md

Queste regole sono già incluse nei file AI_CONTEXT dei tre progetti, ma le ribadisco qui:

### Per l'AI che lavora su worthy-app

```
NON creare tabelle, colonne, funzioni SQL, trigger, indici, o RLS policies.
NON eseguire ALTER TABLE, CREATE TABLE, CREATE FUNCTION, o DROP in nessun caso.
Se ti serve una modifica allo schema, FERMATI e dì all'utente:
"Questa modifica richiede una nuova migration in worthy-shared/supabase/migrations/.
Crea la migration lì, poi aggiorna i tipi in @worthy/shared, e infine torna qui."
```

### Per l'AI che lavora su worthy-admin

```
NON creare tabelle, colonne, funzioni SQL, trigger, indici, o RLS policies.
NON eseguire ALTER TABLE, CREATE TABLE, CREATE FUNCTION, o DROP in nessun caso.
Anche se hai la service_role key (accesso completo), il tuo potere è sui DATI (righe),
non sullo SCHEMA (struttura). Se ti serve una modifica allo schema, FERMATI e dì:
"Questa modifica richiede una nuova migration in worthy-shared/supabase/migrations/."
```

### Per l'AI che lavora su worthy-shared

```
Tu SEI il proprietario dello schema. Puoi creare migrations.
Ma segui SEMPRE questo flusso:
1. Crea un file migration con `supabase migration new nome_descrittivo`
2. Scrivi lo SQL nel file creato
3. Testa con `supabase db reset` in locale
4. Rigenera i tipi con `supabase gen types typescript --local`
5. Aggiorna i tipi custom se necessario
6. NON applicare a produzione senza conferma dell'utente

NON modificare migration files già esistenti (già eseguiti).
Se devi correggere una migration passata, crea una NUOVA migration che fa l'ALTER.
```

---

## Comandi essenziali

```bash
# Collegare il progetto Supabase
supabase link --project-ref enophqzovmvhhwtfddnm

# Avviare Supabase in locale (serve Docker)
supabase start

# Stato del database locale
supabase status

# Resettare il database locale (ricrea tutto dalle migrations)
supabase db reset

# Creare una nuova migration vuota
supabase migration new nome_descrittivo

# Vedere le migration pendenti (non ancora applicate in produzione)
supabase migration list

# Applicare le migration a produzione
supabase db push

# Generare tipi TypeScript dal database locale
supabase gen types typescript --local > src/types/database.generated.ts

# Generare tipi TypeScript dal database di produzione
supabase gen types typescript --project-id enophqzovmvhhwtfddnm > src/types/database.generated.ts

# Fare un diff tra schema locale e produzione
supabase db diff

# Vedere i log del database di produzione
supabase db logs
```

---

## Le migration iniziali — Cosa creare

Al primo setup, le migrations creano tutto lo schema da zero. Ecco l'ordine corretto (le tabelle con foreign key devono venire DOPO le tabelle a cui puntano):

```
001 → Enum types (trust_level, verification_status, scan_type, ecc.)
002 → brands (nessuna dipendenza)
003 → categories (nessuna dipendenza)
004 → badges (nessuna dipendenza)
005 → users (nessuna dipendenza)
006 → products (dipende da: brands, categories, users)
007 → price_history (dipende da: products)
008 → mattia_reviews (dipende da: products)
009 → product_votes (dipende da: products, users)
010 → product_reports (dipende da: products, users)
011 → scan_history (dipende da: products, users)
012 → saved_products (dipende da: products, users)
013 → saved_comparisons (dipende da: users)
014 → user_badges (dipende da: users, badges)
015 → user_consents (dipende da: users)
016 → product_duplicates (dipende da: products, users)
017 → audit_log (dipende da: users)
018 → daily_worthy (dipende da: products)
019 → Indexes (dopo che tutte le tabelle esistono)
020 → RLS policies (dopo tabelle + auth setup)
021 → Functions (scoring, duplicate detection, ecc.)
022 → Triggers (audit log, auto-update timestamps)
023 → Materialized views (brand_rankings, trending)
024 → Cron jobs (refresh views, cleanup)
```

---

## Seed data

I dati iniziali (brand di lancio, categorie, badge) vanno in `supabase/seed.sql`. Questo file viene eseguito automaticamente dopo le migrations quando fai `supabase db reset`.

```sql
-- seed.sql (esempio parziale)

-- Categorie
INSERT INTO categories (name, slug, icon) VALUES
  ('T-Shirt', 't-shirt', '👕'),
  ('Felpe', 'felpe', '🧥'),
  ('Jeans', 'jeans', '👖'),
  ('Pantaloni', 'pantaloni', '👖'),
  ('Giacche', 'giacche', '🧥'),
  ('Sneakers', 'sneakers', '👟'),
  ('Camicie', 'camicie', '👔'),
  ('Intimo', 'intimo', '🩲'),
  ('Accessori', 'accessori', '🧣');

-- Brand di lancio
INSERT INTO brands (name, slug, origin_country, market_segment) VALUES
  ('Zara', 'zara', 'Spagna', 'fast'),
  ('H&M', 'h-and-m', 'Svezia', 'fast'),
  ('Uniqlo', 'uniqlo', 'Giappone', 'fast'),
  ('Shein', 'shein', 'Cina', 'ultra_fast'),
  ('Bershka', 'bershka', 'Spagna', 'fast'),
  ('Pull&Bear', 'pull-and-bear', 'Spagna', 'fast'),
  ('Stradivarius', 'stradivarius', 'Spagna', 'fast'),
  ('Primark', 'primark', 'Irlanda', 'ultra_fast'),
  ('ASOS', 'asos', 'UK', 'fast'),
  ('Mango', 'mango', 'Spagna', 'fast'),
  ('COS', 'cos', 'Svezia', 'premium_fast'),
  ('Massimo Dutti', 'massimo-dutti', 'Spagna', 'premium_fast');

-- Badge
INSERT INTO badges (id, name, description, icon, points_required, benefit) VALUES
  ('fashion_scout', 'Fashion Scout', 'Hai iniziato a contribuire!', '🔍', 50, 'Badge visibile sul profilo'),
  ('style_expert', 'Style Expert', 'Contributor esperto', '⭐', 200, 'Accesso anticipato nuove review'),
  ('database_hero', 'Database Hero', 'Il database ti ringrazia', '🏆', 500, 'Prodotti senza revisione'),
  ('worthy_legend', 'Worthy Legend', 'Leggenda della community', '👑', 1000, 'Menzione stories Mattia'),
  ('top_contributor', 'Top Contributor', 'Top 10 del mese', '🥇', 0, 'Badge esclusivo + shoutout');
```

---

## Flusso visuale riassuntivo

```
1. Devi modificare il database?
   │
   ├─ NO (solo leggere/scrivere dati) → Lavora nel tuo progetto (app o admin)
   │
   └─ SÌ (nuova tabella, colonna, funzione, indice, RLS)
      │
      └─ Vai in worthy-shared/supabase/migrations/
         │
         ├─ Crea migration → Testa locale → Rigenera tipi → Pubblica @worthy/shared
         │
         ├─ Applica a produzione con `supabase db push`
         │
         └─ Aggiorna dipendenza in worthy-app e worthy-admin
```

Non ci sono eccezioni a questo flusso.
