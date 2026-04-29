// Rimuove TUTTI i prodotti scarpe e (con --apply) anche le categorie scarpe
// dal DB. Identifica le categorie il cui slug è "scarpe" o appartiene alla
// famiglia (sneakers, scarpe-eleganti, stivali, sandali, ecc.) basandosi sul
// nome/slug della categoria.
//
// Usage:
//   node src/delete-scarpe.mjs                 # dry-run: solo report
//   node src/delete-scarpe.mjs --apply         # cancella prodotti + categorie

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const apply = process.argv.includes("--apply");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Pattern per riconoscere categorie "scarpe": match sia su slug sia su name.
// Regex case-insensitive.
const SHOE_CAT_PATTERNS = [
  /^scarpe$/i,
  /^scarpe[- ]/i,         // scarpe-eleganti, scarpe sportive, ecc.
  /^sneaker/i,
  /^stival/i,             // stivali, stivaletti
  /^sandal/i,             // sandali
  /^mocass/i,             // mocassini
  /^ballerin/i,           // ballerine
  /^espadrill/i,
  /^infradito/i,
  /^calzature/i,
];

const isShoeCat = (cat) =>
  SHOE_CAT_PATTERNS.some(
    (re) => re.test(cat.slug ?? "") || re.test(cat.name ?? "")
  );

const { data: cats, error: catErr } = await supabase
  .from("categories")
  .select("id, slug, name");
if (catErr) {
  console.error("Errore lookup categorie:", catErr.message);
  process.exit(1);
}

const shoeCats = cats.filter(isShoeCat);
console.log(`=== Categorie scarpe identificate (${shoeCats.length}) ===`);
for (const c of shoeCats) console.log(`  ${c.slug.padEnd(24)} ${c.name}`);

if (shoeCats.length === 0) {
  console.log("Nessuna categoria scarpe nel DB. Exit.");
  process.exit(0);
}

const shoeCatIds = shoeCats.map((c) => c.id);

// Conta + sample prodotti per brand
const { data: prods, count, error: prodErr } = await supabase
  .from("products")
  .select("id, name, brand_id, category_id, brands!inner(slug, name)", { count: "exact" })
  .in("category_id", shoeCatIds);

if (prodErr) {
  console.error("Errore lookup prodotti:", prodErr.message);
  process.exit(1);
}

console.log(`\n=== Prodotti scarpe da eliminare: ${count} ===`);
const byBrand = {};
for (const p of prods) {
  const slug = p.brands.slug;
  byBrand[slug] = (byBrand[slug] ?? 0) + 1;
}
for (const [slug, n] of Object.entries(byBrand).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${slug.padEnd(20)} ${n}`);
}

console.log(`\nSample 10:`);
for (const p of prods.slice(0, 10)) {
  console.log(`  - [${p.brands.slug}] ${p.name}`);
}

if (!apply) {
  console.log(`\n(Dry-run: nessuna cancellazione. Riesegui con --apply.)`);
  process.exit(0);
}

// Cancellazione: prima i prodotti (hanno FK NOT NULL su category_id), poi
// le categorie (libere da riferimenti).
const prodIds = prods.map((p) => p.id);
console.log(`\n→ Eliminando ${prodIds.length} prodotti…`);
{
  // Batch da 500 per evitare URL troppo lunghe
  const BATCH = 500;
  let done = 0;
  for (let i = 0; i < prodIds.length; i += BATCH) {
    const chunk = prodIds.slice(i, i + BATCH);
    const { error } = await supabase.from("products").delete().in("id", chunk);
    if (error) {
      console.error("  DELETE products errore:", error.message);
      process.exit(1);
    }
    done += chunk.length;
    process.stdout.write(`  ${done}/${prodIds.length}\r`);
  }
  console.log();
}

console.log(`→ Eliminando ${shoeCats.length} categorie scarpe…`);
const { error: delCatErr } = await supabase
  .from("categories")
  .delete()
  .in("id", shoeCatIds);
if (delCatErr) {
  console.error("  DELETE categories errore:", delCatErr.message);
  console.error("  (Probabili prodotti residui che ancora referenziano la categoria.)");
  process.exit(1);
}

console.log(`\n✓ Eliminati ${prodIds.length} prodotti e ${shoeCats.length} categorie.`);
