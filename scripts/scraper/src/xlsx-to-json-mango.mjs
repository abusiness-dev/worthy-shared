// Wrapper Mango-specific: legge il dump XLSX di Mango (DB Worthy "Database
// worthy/MANGO/MANGO.xlsx") e produce un JSON pronto per import-from-json.ts.
// Le `category` italiane di Mango (es. "abiti e tute", "pullover e cardigan",
// "sciarpe e foulard") non corrispondono né agli slug del DB né alle "base
// category" che processor.refineCategory() sa gestire: questa mappa le
// normalizza al formato atteso (base slug → refineCategory raffina).
//
// Usage:
//   node src/xlsx-to-json-mango.mjs <input.xlsx> <output.json>

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import xlsx from "xlsx";

// Mappa per genere: chiave = stringa categoria nel XLSX (lowercased, trimmed,
// whitespace collapsed), valore = base category iniettata nel JSON. `null`
// significa skip esplicito.
const MANGO_CATEGORY_MAP = {
  donna: {
    "abiti e tute": "abiti",
    "bigiotteria": null,
    "borse": "borse",
    "camicie e bluse": "camicie",
    "cappotti": "cappotti",
    "giacche": "giacche",
    "giacchette": "giacche",
    "gilet": "giacche",
    "gonne": "gonne",
    "jeans": "jeans",
    "magliette": "t-shirt",
    "pantaloni": "pantaloni",
    "pullover e cardigan": "maglieria",
    "scarpe": "scarpe",
    "sciarpe e foulard": "sciarpe",
    "short e bermuda": "shorts",
    "tops": "top",
  },
  uomo: {
    "camicie": "camicie",
    "cravatte papillon e fazzoletti": "accessori",
    "felpe": "felpe",
    "giacche": "giacche",
    "jeans": "jeans",
    "magliette": "t-shirt",
    "pantaloni": "pantaloni",
    "polo": "polo",
    "pullover e cardigan": "maglieria",
    "shorts": "shorts",
  },
};

function normalizeKey(s) {
  return String(s ?? "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

const args = process.argv.slice(2);
const input = args[0];
const output = args[1];
if (!input || !output) {
  console.error("Usage: node xlsx-to-json-mango.mjs <input.xlsx> <output.json>");
  process.exit(1);
}

const wb = xlsx.read(readFileSync(resolve(input)), { type: "buffer" });
const sheetName = wb.SheetNames.includes("products") ? "products" : wb.SheetNames[0];
const ws = wb.Sheets[sheetName];
const rows = xlsx.utils.sheet_to_json(ws, { raw: true, defval: "" });

const out = [];
const skipped = [];
const unknown = [];
const distribution = {};

for (let i = 0; i < rows.length; i++) {
  const r = rows[i];
  const gender = normalizeKey(r.gender);
  const category = normalizeKey(r.category);

  const map = MANGO_CATEGORY_MAP[gender];
  if (!map) {
    unknown.push({ row: i + 2, gender, category, name: r.name });
    continue;
  }
  if (!(category in map)) {
    unknown.push({ row: i + 2, gender, category, name: r.name });
    continue;
  }
  const base = map[category];
  if (base === null) {
    skipped.push({ row: i + 2, gender, category, name: r.name });
    continue;
  }

  distribution[base] = (distribution[base] ?? 0) + 1;

  out.push({
    brand: r.brand,
    category: base,
    gender,
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

console.log(`=== Mango XLSX → JSON ===`);
console.log(`Sheet:        ${sheetName}`);
console.log(`Input rows:   ${rows.length}`);
console.log(`Output rows:  ${out.length}`);
console.log(`Skipped:      ${skipped.length} (mapping=null)`);
console.log(`Unknown:      ${unknown.length} (no mapping found)`);
if (skipped.length) {
  console.log(`\nSkipped detail:`);
  for (const s of skipped) {
    console.log(`  row ${s.row} [${s.gender}] "${s.category}" — ${s.name}`);
  }
}
if (unknown.length) {
  console.log(`\nUnknown detail (REVIEW MAP):`);
  for (const u of unknown) {
    console.log(`  row ${u.row} [${u.gender}] "${u.category}" — ${u.name}`);
  }
}
console.log(`\nDistribution (base category injected):`);
for (const [k, v] of Object.entries(distribution).sort((a, b) => b[1] - a[1])) {
  console.log(`  ${k.padEnd(20)} ${v}`);
}
console.log(`\nWrote: ${resolve(output)}`);
