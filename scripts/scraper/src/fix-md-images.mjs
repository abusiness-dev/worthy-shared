// Riordina photo_urls dei prodotti Massimo Dutti perché la prima immagine
// (hero) sia un model shot (o1..oN) o packshot (c), non una macro tessuto (r/t/w).
//
// Pattern URL Massimo Dutti: ".../<sku>-<suffix>/<sku>-<suffix>.jpg?ts=…"
// dove suffix è:
//   o1, o2, ... = outfit / model shot (PREFERITO come hero)
//   c           = packshot prodotto stesi su sfondo bianco
//   r           = "ravvicinata" / macro tessuto (sgranato per tinta unita)
//   t, w, pe    = dettagli/varianti
//
// Strategia: priorità o1..oN ASC → c → t → w → r → pe → unknown.
//
// Usage:
//   node src/fix-md-images.mjs            # dry-run
//   node src/fix-md-images.mjs --apply    # aggiorna DB

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const apply = process.argv.includes("--apply");

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

function suffix(url) {
  const m = url.match(/-([a-z0-9]+)\.jpg/i);
  return m ? m[1].toLowerCase() : "";
}

// Score: numero più basso = più "hero-ready". oN ordinati per N crescente
// così "o1" batte "o2", ecc.
function heroScore(url) {
  const s = suffix(url);
  // outfit: o1 = 1, o2 = 2, ...
  const om = s.match(/^o(\d+)$/);
  if (om) return parseInt(om[1], 10); // 1..50
  if (s === "c") return 100;          // packshot
  if (s === "t") return 200;          // dettaglio
  if (s.startsWith("t")) return 210;  // t1, t2, ...
  if (s === "w" || s.startsWith("w")) return 300;
  if (s === "r" || s === "r1") return 400; // macro tessuto (DEPRIORITATO)
  if (s === "pe") return 500;
  return 999;                          // unknown
}

const { data: brand } = await sb
  .from("brands")
  .select("id")
  .eq("slug", "massimo-dutti")
  .single();

const { data: products } = await sb
  .from("products")
  .select("id, name, photo_urls")
  .eq("brand_id", brand.id);

let toFix = 0;
let alreadyOk = 0;
let noPhotos = 0;
const sampleFix = [];

const updates = [];
for (const p of products) {
  if (!p.photo_urls || p.photo_urls.length === 0) {
    noPhotos++;
    continue;
  }
  const sorted = [...p.photo_urls].sort((a, b) => heroScore(a) - heroScore(b));
  // Confronto stringificato: se l'ordine cambia → da fissare.
  const same = sorted.every((u, i) => u === p.photo_urls[i]);
  if (same) {
    alreadyOk++;
    continue;
  }
  toFix++;
  if (sampleFix.length < 12) {
    sampleFix.push({
      name: p.name,
      before: suffix(p.photo_urls[0]),
      after: suffix(sorted[0]),
    });
  }
  updates.push({ id: p.id, photo_urls: sorted });
}

console.log(`=== MD photo_urls audit ===`);
console.log(`Totale prodotti:        ${products.length}`);
console.log(`Senza foto:             ${noPhotos}`);
console.log(`Già con hero corretta:  ${alreadyOk}`);
console.log(`Da riordinare:          ${toFix}`);

console.log(`\nSample 12 fix (suffix prima → dopo):`);
for (const f of sampleFix) {
  console.log(`  ${f.name.slice(0, 55).padEnd(57)} ${f.before.padEnd(6)} → ${f.after}`);
}

// Distribuzione cause
const beforeSuf = {};
for (const u of updates) {
  const cur = products.find((p) => p.id === u.id);
  const s = suffix(cur.photo_urls[0]) || "(none)";
  beforeSuf[s] = (beforeSuf[s] ?? 0) + 1;
}
console.log(`\nDistribuzione hero PRIMA del fix (suffix):`);
for (const [s, n] of Object.entries(beforeSuf).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${s.padEnd(10)} ${n}`);
}

if (!apply) {
  console.log(`\n(Dry-run: nessuna scrittura. Riesegui con --apply.)`);
  process.exit(0);
}

console.log(`\n→ Aggiornamento ${updates.length} prodotti…`);
let done = 0;
for (const u of updates) {
  const { error } = await sb.from("products").update({ photo_urls: u.photo_urls }).eq("id", u.id);
  if (error) {
    console.error(`  [ERR] ${u.id}: ${error.message}`);
    continue;
  }
  done++;
  if (done % 100 === 0) process.stdout.write(`  ${done}/${updates.length}\r`);
}
console.log(`\n✓ Aggiornati ${done}/${updates.length} prodotti.`);
