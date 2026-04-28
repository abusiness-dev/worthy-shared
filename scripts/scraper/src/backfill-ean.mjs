// Backfill ean_barcode su prodotti già inseriti, leggendo dal JSON sorgente
// e matchando per affiliate_url. Solo update se il record DB ha ean_barcode null.
//
// Usage:
//   node src/backfill-ean.mjs --file <path.json>

import "dotenv/config";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

const args = process.argv.slice(2);
let file = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--file") file = args[++i];
}
if (!file) {
  console.error("Usage: node backfill-ean.mjs --file <path.json>");
  process.exit(1);
}

const records = JSON.parse(readFileSync(resolve(file), "utf8"));
console.log(`Loaded ${records.length} records from ${file}`);

let updated = 0, skipped = 0, missing = 0, errors = 0;
let i = 0;
for (const rec of records) {
  i++;
  const ean = (rec.ean_barcode ?? "").trim();
  const url = (rec.product_url ?? "").trim();
  if (!ean || !url) { skipped++; continue; }

  const { data: existing, error: selErr } = await supabase
    .from("products")
    .select("id, ean_barcode")
    .eq("affiliate_url", url)
    .maybeSingle();
  if (selErr) { console.error("[ERR-SEL]", url, selErr.message); errors++; continue; }
  if (!existing) { missing++; continue; }
  if (existing.ean_barcode) { skipped++; continue; }

  const { error: updErr } = await supabase
    .from("products")
    .update({ ean_barcode: ean })
    .eq("id", existing.id);
  if (updErr) {
    if (updErr.code === "23505") {
      console.warn("[DUP-EAN]", ean, "for", rec.name);
    } else {
      console.error("[ERR-UPD]", existing.id, updErr.message);
    }
    errors++;
    continue;
  }
  updated++;
  if (updated % 200 === 0) console.log(`  progress: ${i}/${records.length} (updated=${updated})`);
}

console.log(`\n=== Backfill EAN summary ===`);
console.log(`Updated:          ${updated}`);
console.log(`Skipped (null/already): ${skipped}`);
console.log(`Missing in DB:    ${missing}`);
console.log(`Errors:           ${errors}`);
