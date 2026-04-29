// Wrapper Massimo Dutti-specific: legge il dump XLSX di Massimo Dutti
// ("Database worthy/MASSIMO_DUTTI/MASSIMO_DUTTI.xlsx") e produce un JSON
// pronto per import-from-json.ts.
//
// Le 44 categorie italiane di MD non corrispondono né agli slug del DB né alle
// "base category" che processor.refineCategory() sa gestire: questa mappa le
// normalizza al formato atteso (base slug → refineCategory raffina via nome).
//
// Esclusioni:
//   - scarpe / borse / borse e nécessaire (richiesta utente)
//   - prezzi speciali / lino / made in italy / total look / vedere tutto / pelle
//     (catch-all e duplicati di marketing — i prodotti sono già nelle altre cat)
//   - profumi / libri / bigiotteria / occhiali / occhiali da sole / custodie /
//     custodie e astucci / portafogli e portatessere / cravatte / guanti
//     (categorie senza target Worthy)
//
// Inoltre: dedup per `product_url` base (rimossa la query string), perché lo
// stesso modello compare in più listings (es. "pantaloni" + "pantaloni e bermuda").
//
// Usage:
//   node src/xlsx-to-json-massimo-dutti.mjs <input.xlsx> <output.json>

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import xlsx from "xlsx";

const EXCLUDE = new Set([
  // su richiesta utente
  "scarpe",
  "borse",
  "borse e nécessaire",
  // catch-all / duplicati di marketing
  "prezzi speciali",
  "lino",
  "made in italy",
  "total look",
  "vedere tutto",
  "pelle",
  // accessori senza categoria Worthy
  "profumi",
  "libri",
  "bigiotteria",
  "occhiali",
  "occhiali da sole",
  "custodie",
  "custodie e astucci",
  "portafogli e portatessere",
  "cravatte",
  "guanti",
]);

// 44 categorie MD (lowercased) → base slug accettato da processor.refineCategory.
// Il refiner poi affina su nome (es. "felpa cappuccio", "cardigan", "trench").
const REMAP = {
  // top
  "magliette": "t-shirt",
  "polo": "polo",
  "top": "top",

  // maglieria / outerwear leggera
  "maglioni e cardigan": "maglieria",
  "blazer e gilet": "giacche",

  // camicie
  "camicie": "camicie",

  // outerwear
  "giacche camicie e blazer": "giacche",
  "trench e giacche": "giacche",
  "giacche e trench": "giacche",
  "giacche in pelle": "giacche",
  "mantelle": "giacche",

  // bottom
  "jeans": "jeans",
  "pantaloni": "pantaloni",
  "pantaloni e bermuda": "pantaloni",
  "gonne": "gonne",

  // dress
  "abiti": "abiti",
  "vestiti": "abiti",

  // intimo / homewear
  "lingerie": "intimo",
  "pigiama e abbigliamento intimo": "intimo",

  // mare
  "mare": "costume",
  "costumi da bagno": "costume",

  // accessori (slug DB diretti)
  "calzini": "calzini",
  "cinture": "cinture",
  "cappellini": "cappelli",
  "headscarves & scarves": "sciarpe",
};

function normalizeKey(s) {
  return String(s ?? "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

function baseUrl(u) {
  return String(u ?? "").split("?")[0].split("#")[0];
}

const args = process.argv.slice(2);
const input = args[0];
const output = args[1];
if (!input || !output) {
  console.error("Usage: node xlsx-to-json-massimo-dutti.mjs <input.xlsx> <output.json>");
  process.exit(1);
}

const wb = xlsx.read(readFileSync(resolve(input)), { type: "buffer" });
const sheetName = wb.SheetNames.includes("products") ? "products" : wb.SheetNames[0];
const ws = wb.Sheets[sheetName];
const rows = xlsx.utils.sheet_to_json(ws, { raw: true, defval: "" });

const out = [];
const excluded = [];
const unknown = [];
const dedupedSeen = new Set();
let dedupSkipped = 0;
const distribution = {};

for (let i = 0; i < rows.length; i++) {
  const r = rows[i];
  const category = normalizeKey(r.category);

  if (EXCLUDE.has(category)) {
    excluded.push({ row: i + 2, category, name: r.name });
    continue;
  }

  const base = REMAP[category];
  if (!base) {
    unknown.push({ row: i + 2, category, name: r.name });
    continue;
  }

  const url = baseUrl(r.product_url);
  if (!url) {
    unknown.push({ row: i + 2, category, name: r.name, reason: "missing product_url" });
    continue;
  }
  if (dedupedSeen.has(url)) {
    dedupSkipped++;
    continue;
  }
  dedupedSeen.add(url);

  distribution[base] = (distribution[base] ?? 0) + 1;

  out.push({
    brand: r.brand,
    category: base,
    gender: normalizeKey(r.gender),
    name: r.name,
    price_eur: r.price_eur,
    composition: r.composition,
    country_of_production: r.country_of_production,
    spinning_location: r.spinning_location,
    weaving_location: r.weaving_location,
    dyeing_location: r.dyeing_location,
    product_url: r.product_url,
    photo_urls: r.photo_urls,
    ean_barcode: r.ean_barcode,
  });
}

writeFileSync(resolve(output), JSON.stringify(out, null, 2));

console.log(`=== Massimo Dutti XLSX → JSON ===`);
console.log(`Sheet:                ${sheetName}`);
console.log(`Input rows:           ${rows.length}`);
console.log(`Excluded categories:  ${excluded.length}`);
console.log(`Unknown categories:   ${unknown.length}`);
console.log(`Dedup product_url:    ${dedupSkipped}`);
console.log(`Output rows:          ${out.length}`);

const exByCat = {};
for (const e of excluded) exByCat[e.category] = (exByCat[e.category] ?? 0) + 1;
console.log(`\nExcluded breakdown:`);
for (const [k, v] of Object.entries(exByCat).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(30)} ${v}`);
}

if (unknown.length) {
  console.log(`\nUnknown detail (REVIEW MAP):`);
  for (const u of unknown.slice(0, 25)) {
    console.log(`  row ${u.row} "${u.category}" — ${u.name}${u.reason ? " [" + u.reason + "]" : ""}`);
  }
  if (unknown.length > 25) console.log(`  … +${unknown.length - 25} altri`);
}

console.log(`\nDistribution (base category injected):`);
for (const [k, v] of Object.entries(distribution).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(20)} ${v}`);
}
console.log(`\nWrote: ${resolve(output)}`);
