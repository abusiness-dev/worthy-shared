# scripts/

Script operativi una tantum per la manutenzione del database Worthy.
Non sono parte del pacchetto npm pubblicato, vengono eseguiti manualmente.

## cleanup-products.ts

Scansiona la tabella `products` e:

1. Raggruppa i prodotti per `(brand_id, nome normalizzato)` — case-insensitive,
   con collasso degli spazi. Nei gruppi con >1 prodotto, tiene quello con più
   campi compilati (composition, price, barcode, photo, ecc.) e segna gli altri
   per il soft-delete (`is_active = false`).
2. Segnala i prodotti incompleti (composition vuota o price ≤ 0). Questi sono
   **solo segnalati**, non eliminati: vanno corretti a mano.
3. Stampa un report dettagliato in **dry run**.
4. Chiede conferma interattiva via readline prima di applicare gli update.

### Come eseguirlo

```bash
# Dal root del repo, con service-role key (bypassa RLS):
SUPABASE_URL=https://enophqzovmvhhwtfddnm.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=eyJ... \
  npx ts-node scripts/cleanup-products.ts
```

### Prerequisiti

Lo script non è standalone, si appoggia alle dipendenze del package root:

```bash
npm i -D ts-node typescript
npm i @supabase/supabase-js
```

In alternativa si può usare `tsx` invece di `ts-node`:

```bash
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... npx tsx scripts/cleanup-products.ts
```

### Note

- Il service-role key va **solo** da variabile d'ambiente, mai committato.
- L'operazione è un **soft-delete** (`is_active = false`), non un DELETE fisico.
  Per un hard-delete servirebbe una migration dedicata che pulisca anche le FK
  (scan_history, saved_products, price_history, ecc.).
- Per deduplicazioni più sofisticate che migrano le relazioni al prodotto
  canonico, vedi la migration `20260404000001_deduplicate_products.sql`.

## Import massivi (scraper) e aggregati QPR

Dal refactor async (`20260610000011_async_qpr_aggregates.sql`) ogni scrittura su
`products` accoda O(1) il cluster `(category × comparison_tier)` in
`qpr_aggregate_dirty`; un cron lo drena ogni 2 min. Per un **import bulk** di molti
prodotti questo significa comunque un INSERT in coda per riga (innocuo) ma può
generare molte righe dirty. Pattern consigliato per gli import massivi via
service-role:

```sql
-- 1) Disabilita il marcatore per la durata del batch (service_role/owner):
ALTER TABLE products DISABLE TRIGGER trg_products_qpr_aggregates;

-- 2) … esegui l'import (INSERT/UPSERT dei prodotti) …

-- 3) Riabilita e ricalcola UNA volta gli aggregati toccati:
ALTER TABLE products ENABLE TRIGGER trg_products_qpr_aggregates;
SELECT public.drain_qpr_aggregate_dirty(100000);   -- svuota eventuale coda residua
-- in alternativa, ricalcolo completo (categorie + cluster) come nei backfill delle migration.
```

> Nota: gli import service-role **non** sono soggetti ai trigger BEFORE di validazione
> (`validate_product_content`/`validate_product_urls`) grazie a `is_service_role_or_internal()`;
> assicurati quindi che i dati importati siano già puliti (composizione array 1-8 fibre
> con somma ~100, EAN con checksum valido, URL https).
