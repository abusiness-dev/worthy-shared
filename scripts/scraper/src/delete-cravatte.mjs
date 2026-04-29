// Elimina i prodotti il cui nome contiene "cravatt" (cravatta/cravatte) per i
// brand massimo-dutti e mango. Le FK su products hanno ON DELETE CASCADE.
//
// Usage:
//   node src/delete-cravatte.mjs                # mostra count + sample, NON cancella
//   node src/delete-cravatte.mjs --apply        # cancella

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const apply = process.argv.includes("--apply");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const SLUGS = ["massimo-dutti", "mango"];

const { data: brands, error: bErr } = await supabase
  .from("brands")
  .select("id, slug, name")
  .in("slug", SLUGS);
if (bErr) {
  console.error("Brand lookup error:", bErr.message);
  process.exit(1);
}

for (const brand of brands) {
  const { data: rows, count, error } = await supabase
    .from("products")
    .select("id, name, price", { count: "exact" })
    .eq("brand_id", brand.id)
    .ilike("name", "%cravatt%");
  if (error) {
    console.error(`[${brand.slug}] select error:`, error.message);
    continue;
  }

  console.log(`\n=== ${brand.name} (${brand.slug}) ===`);
  console.log(`Cravatte trovate: ${count}`);
  for (const r of rows.slice(0, 8)) {
    console.log(`  - ${r.name} (${r.price}€)`);
  }
  if (rows.length > 8) console.log(`  … +${rows.length - 8} altri`);

  if (!apply) continue;
  if (count === 0) continue;

  const ids = rows.map((r) => r.id);
  const { error: delErr } = await supabase
    .from("products")
    .delete()
    .in("id", ids);
  if (delErr) {
    console.error(`[${brand.slug}] DELETE error:`, delErr.message);
    continue;
  }
  console.log(`[${brand.slug}] Eliminati ${ids.length} prodotti.`);
}

if (!apply) {
  console.log(`\n(Dry-run: nessuna cancellazione. Riesegui con --apply.)`);
}
