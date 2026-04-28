// Elimina TUTTI i prodotti BERSHKA dal database.
// Le FK su products hanno ON DELETE CASCADE (price_history, saved_products, ecc.)
// quindi un singolo DELETE rimuove anche le tabelle dipendenti.
//
// Usage:
//   node src/delete-bershka-products.mjs

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const { data: brand, error: brandErr } = await supabase
  .from("brands")
  .select("id, slug, name")
  .eq("slug", "bershka")
  .single();
if (brandErr || !brand) {
  console.error("Brand 'bershka' non trovato:", brandErr?.message);
  process.exit(1);
}

const { count: before, error: cntErr } = await supabase
  .from("products")
  .select("*", { count: "exact", head: true })
  .eq("brand_id", brand.id);
if (cntErr) {
  console.error("Errore count:", cntErr.message);
  process.exit(1);
}

console.log(`Brand: ${brand.name} (${brand.id})`);
console.log(`Prodotti BERSHKA da eliminare: ${before}`);

if (before === 0) {
  console.log("Nessun prodotto da eliminare. Exit.");
  process.exit(0);
}

const { error: delErr } = await supabase
  .from("products")
  .delete()
  .eq("brand_id", brand.id);
if (delErr) {
  console.error("DELETE fallito:", delErr.message);
  process.exit(1);
}

const { count: after } = await supabase
  .from("products")
  .select("*", { count: "exact", head: true })
  .eq("brand_id", brand.id);

console.log(`\n=== Risultato ===`);
console.log(`Prima: ${before} prodotti BERSHKA`);
console.log(`Dopo:  ${after} prodotti BERSHKA`);
console.log(`Eliminati: ${before - (after ?? 0)}`);
