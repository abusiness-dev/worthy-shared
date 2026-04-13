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
