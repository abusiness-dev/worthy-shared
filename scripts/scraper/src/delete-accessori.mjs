// Identifica e (con --apply) rimuove TUTTI i prodotti accessori e le categorie
// accessori. Trattamento conservativo: il match "accessori" si basa su slug
// noti (borse, cinture, cappelli, sciarpe, accessori) + pattern.
// `intimo` e `calzini` sono apparel intimo, NON accessori → esclusi di default.
//
// Usage:
//   node src/delete-accessori.mjs                # dry-run
//   node src/delete-accessori.mjs --apply        # cancella prodotti + categorie

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const apply = process.argv.includes("--apply");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Slug categorie da considerare "accessori" (esclusi: intimo, calzini = apparel)
const ACCESS_SLUGS = new Set([
  "accessori",
  "borse",
  "cinture",
  "cappelli",
  "sciarpe",
  "occhiali",
  "occhiali-da-sole",
  "bigiotteria",
  "gioielli",
  "cravatte",
  "guanti",
  "portafogli",
  "custodie",
]);

const ACCESS_PATTERNS = [
  /^cappell/i,
  /^cintur/i,
  /^sciarp/i,
  /^bors/i,
  /^accessor/i,
  /^bijou|^bigiotteria|^gioiell/i,
  /^orolog/i,
  /^occhial/i,
  /^cravatt/i,
  /^guant/i,
  /^portafogl/i,
  /^custodi/i,
];

const isAccessCat = (cat) =>
  ACCESS_SLUGS.has(cat.slug) ||
  ACCESS_PATTERNS.some(
    (re) => re.test(cat.slug ?? "") || re.test(cat.name ?? "")
  );

const { data: cats, error: catErr } = await supabase
  .from("categories")
  .select("id, slug, name");
if (catErr) {
  console.error("Errore lookup categorie:", catErr.message);
  process.exit(1);
}

const accCats = cats.filter(isAccessCat);
console.log(`=== Categorie accessori identificate (${accCats.length}) ===`);
for (const c of accCats) console.log(`  ${c.slug.padEnd(24)} ${c.name}`);

if (accCats.length === 0) {
  console.log("Nessuna categoria accessori nel DB.");
  process.exit(0);
}

const accCatIds = accCats.map((c) => c.id);

const { data: prods, count, error: prodErr } = await supabase
  .from("products")
  .select("id, name, category_id, brands!inner(slug, name)", { count: "exact" })
  .in("category_id", accCatIds);

if (prodErr) {
  console.error("Errore lookup prodotti:", prodErr.message);
  process.exit(1);
}

console.log(`\n=== Prodotti accessori da eliminare: ${count} ===`);
const byBrand = {};
const byCat = {};
const catById = new Map(accCats.map((c) => [c.id, c.slug]));
for (const p of prods) {
  const slug = p.brands.slug;
  byBrand[slug] = (byBrand[slug] ?? 0) + 1;
  const cs = catById.get(p.category_id) ?? "?";
  byCat[cs] = (byCat[cs] ?? 0) + 1;
}
console.log(`\nPer brand:`);
for (const [slug, n] of Object.entries(byBrand).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${slug.padEnd(20)} ${n}`);
}
console.log(`\nPer categoria:`);
for (const [slug, n] of Object.entries(byCat).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${slug.padEnd(20)} ${n}`);
}

console.log(`\nSample 12:`);
for (const p of prods.slice(0, 12)) {
  const cs = catById.get(p.category_id) ?? "?";
  console.log(`  - [${p.brands.slug}/${cs}] ${p.name}`);
}

if (!apply) {
  console.log(`\n(Dry-run: nessuna cancellazione. Riesegui con --apply.)`);
  process.exit(0);
}

const prodIds = prods.map((p) => p.id);
console.log(`\n→ Eliminando ${prodIds.length} prodotti…`);
{
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

console.log(`→ Eliminando ${accCats.length} categorie accessori…`);
const { error: delCatErr } = await supabase
  .from("categories")
  .delete()
  .in("id", accCatIds);
if (delCatErr) {
  console.error("  DELETE categories errore:", delCatErr.message);
  process.exit(1);
}

console.log(`\n✓ Eliminati ${prodIds.length} prodotti e ${accCats.length} categorie.`);
