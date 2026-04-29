// Ispeziona le photo_urls dei prodotti Massimo Dutti per capire pattern
// di URL "macro tessuto" sgranato vs "modello".

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

const { data: brand } = await sb.from("brands").select("id").eq("slug", "massimo-dutti").single();

const { data: products } = await sb
  .from("products")
  .select("id, name, photo_urls, affiliate_url")
  .eq("brand_id", brand.id)
  .limit(30);

console.log(`Sample 30 prodotti MD — prima immagine:\n`);
for (const p of products) {
  const first = p.photo_urls?.[0] ?? "(no photos)";
  console.log(`  ${p.name.slice(0, 50).padEnd(52)} | ${first.slice(0, 110)}`);
}

// Aggrega i suffix dei file (parte tra "_" e ".jpg") per capire la varianza
const suffixCounts = {};
let totalUrls = 0;
let prodsWithUrls = 0;

const { data: all } = await sb
  .from("products")
  .select("photo_urls")
  .eq("brand_id", brand.id);

for (const p of all) {
  if (!p.photo_urls || p.photo_urls.length === 0) continue;
  prodsWithUrls++;
  for (const url of p.photo_urls) {
    totalUrls++;
    // Estrae es. ".../12345-o1.jpg" → suffix "o1" oppure ".../12345-r.jpg" → "r"
    const m = url.match(/-([a-z0-9]+)\.jpg/i);
    const suf = m ? m[1].toLowerCase() : "(no_suffix)";
    suffixCounts[suf] = (suffixCounts[suf] ?? 0) + 1;
  }
}

console.log(`\n\n=== Pattern suffix file (tutti i prodotti MD) ===`);
console.log(`Prodotti con foto: ${prodsWithUrls}`);
console.log(`URL totali: ${totalUrls}\n`);
const sorted = Object.entries(suffixCounts).sort((a, b) => b[1] - a[1]);
for (const [suf, n] of sorted) {
  console.log(`  ${suf.padEnd(20)} ${n}`);
}

// Mostra 5 esempi distintivi di prima immagine per ogni suffix top
console.log(`\n\n=== Esempi di "prima immagine" per suffix ===`);
const seenSuffixes = new Set();
for (const p of all) {
  if (!p.photo_urls?.[0]) continue;
  const first = p.photo_urls[0];
  const m = first.match(/-([a-z0-9]+)\.jpg/i);
  const suf = m ? m[1].toLowerCase() : "(no_suffix)";
  if (seenSuffixes.has(suf)) continue;
  seenSuffixes.add(suf);
  console.log(`  [${suf}] ${first}`);
  if (seenSuffixes.size >= 12) break;
}
