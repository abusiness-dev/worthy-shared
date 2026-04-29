// Cerca residui di "borse" nei prodotti del DB (la categoria 'borse' è già
// stata cancellata, ma il match per nome trova borse classificate altrove).
//
// Usage:
//   node src/delete-borse.mjs                # dry-run
//   node src/delete-borse.mjs --apply        # cancella

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const apply = process.argv.includes("--apply");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Pattern nome prodotto = borsa. Word-boundary per evitare falsi positivi
// (es. "imbottito"). Inclusi sinonimi italiani e inglesi comuni.
const BAG_PATTERNS = [
  /\bbors[ae]\b/i,        // borsa, borse
  /\bborsett/i,           // borsetta, borsetti
  /\btracoll/i,           // tracolla
  /\bzain[oi]\b/i,        // zaino, zaini
  /\bmarsupi/i,           // marsupio
  /\bpochette\b/i,
  /\bclutch\b/i,
  /\bshopper\b/i,
  /\btote\s+bag\b/i,
  /\bcrossbody\b/i,
  /\bhandbag\b/i,
  /\bbackpack\b/i,
  /\bduffle\b/i,
  /\bbeauty\s+case\b/i,
  /\bnécessaire\b/i,
  /\bbauletto\b/i,
];

const isBag = (name) => BAG_PATTERNS.some((re) => re.test(name));

// Pulling all products is heavy; usiamo una OR ilike server-side per pre-filtrare
// poi finire con regex per precisione. Costruisco un pattern OR con i sostantivi
// principali per ridurre il fetch.
const ILIKE_KEYWORDS = [
  "%bors%", "%tracoll%", "%zain%", "%marsup%", "%pochette%", "%clutch%",
  "%shopper%", "%tote bag%", "%crossbody%", "%handbag%", "%backpack%",
  "%duffle%", "%beauty case%", "%nécessaire%", "%necessaire%", "%bauletto%",
];

const orFilter = ILIKE_KEYWORDS.map((k) => `name.ilike.${k}`).join(",");

const { data: rows, error } = await supabase
  .from("products")
  .select("id, name, price, category_id, brands!inner(slug, name), categories!inner(slug)")
  .or(orFilter);

if (error) {
  console.error("Errore lookup:", error.message);
  process.exit(1);
}

// Affina con regex (rimuove falsi positivi)
const matches = rows.filter((r) => isBag(r.name));

console.log(`=== Borse trovate: ${matches.length} (su ${rows.length} pre-filter) ===`);

const byBrand = {};
const byCat = {};
for (const r of matches) {
  byBrand[r.brands.slug] = (byBrand[r.brands.slug] ?? 0) + 1;
  const c = r.categories.slug;
  byCat[c] = (byCat[c] ?? 0) + 1;
}

console.log(`\nPer brand:`);
for (const [slug, n] of Object.entries(byBrand).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${slug.padEnd(20)} ${n}`);
}
console.log(`\nPer categoria:`);
for (const [slug, n] of Object.entries(byCat).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${slug.padEnd(20)} ${n}`);
}

console.log(`\nSample 15:`);
for (const r of matches.slice(0, 15)) {
  console.log(`  - [${r.brands.slug}/${r.categories.slug}] ${r.name}`);
}

// Mostra anche i pre-filter che la regex ha SCARTATO (per audit)
const dropped = rows.filter((r) => !isBag(r.name));
if (dropped.length) {
  console.log(`\nScartati dal regex (${dropped.length}):`);
  for (const r of dropped.slice(0, 10)) {
    console.log(`  - [${r.brands.slug}] ${r.name}`);
  }
  if (dropped.length > 10) console.log(`  … +${dropped.length - 10} altri`);
}

if (!apply) {
  console.log(`\n(Dry-run: nessuna cancellazione. Riesegui con --apply.)`);
  process.exit(0);
}

if (matches.length === 0) {
  console.log("\nNiente da cancellare.");
  process.exit(0);
}

const ids = matches.map((r) => r.id);
console.log(`\n→ Eliminando ${ids.length} prodotti…`);
const BATCH = 500;
let done = 0;
for (let i = 0; i < ids.length; i += BATCH) {
  const chunk = ids.slice(i, i + BATCH);
  const { error: delErr } = await supabase.from("products").delete().in("id", chunk);
  if (delErr) {
    console.error("  DELETE errore:", delErr.message);
    process.exit(1);
  }
  done += chunk.length;
  process.stdout.write(`  ${done}/${ids.length}\r`);
}
console.log();

console.log(`\n✓ Eliminati ${ids.length} prodotti borsa.`);
