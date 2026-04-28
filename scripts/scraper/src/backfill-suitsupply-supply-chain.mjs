// Backfill weaving_location + weaving_iso2 sui prodotti Suitsupply leggendo
// dalla PDP (sezione "Tessitura"). Suitsupply non riporta il "Made in" sulle
// PDP standard; estraiamo solo il dato disponibile (weaving) per i prodotti
// sartoriali (giacche, abiti, pantaloni, camicie). I knitwear non hanno la
// sezione Tessitura e vengono skippati.
//
// Usage:
//   node src/backfill-suitsupply-supply-chain.mjs              # run completo
//   node src/backfill-suitsupply-supply-chain.mjs --limit 3 --dry-run

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { setTimeout as sleep } from "node:timers/promises";

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

const args = process.argv.slice(2);
let limit = null;
let dryRun = false;
let refreshLocations = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--limit") limit = parseInt(args[++i], 10);
  if (args[i] === "--dry-run") dryRun = true;
  if (args[i] === "--refresh-locations") refreshLocations = true;
}

const COUNTRY_MAP = {
  italia: "IT", italy: "IT",
  giappone: "JP", japan: "JP",
  svizzera: "CH", switzerland: "CH",
  germania: "DE", germany: "DE",
  portogallo: "PT", portugal: "PT",
  austria: "AT",
  francia: "FR", france: "FR",
  belgio: "BE", belgium: "BE",
  spagna: "ES", spain: "ES",
  "regno unito": "GB", "united kingdom": "GB", uk: "GB", britain: "GB", england: "GB", inghilterra: "GB",
  "stati uniti": "US", "united states": "US", usa: "US",
  cina: "CN", china: "CN",
  vietnam: "VN",
  india: "IN",
  turchia: "TR", turkey: "TR",
  romania: "RO",
  pakistan: "PK",
  bangladesh: "BD",
};

function normalizeCountry(raw) {
  if (!raw) return null;
  const cleaned = raw.toLowerCase().replace(/[.,;:!?()[\]{}"]/g, " ").replace(/\s+/g, " ").trim();
  if (!cleaned) return null;
  if (COUNTRY_MAP[cleaned]) return COUNTRY_MAP[cleaned];
  for (const [key, iso2] of Object.entries(COUNTRY_MAP)) {
    if (key.length >= 4 && cleaned.includes(key)) return iso2;
  }
  return null;
}

function stripTags(html) {
  return html.replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
}

// Estrae { location, iso2 } dalla PDP HTML, o null se non trovato.
function extractWeaving(html) {
  // Pattern A: <th>Tessitura</th> <td>...</td>
  const tableMatch = html.match(/<th[^>]*>\s*Tessitura\s*<\/th>\s*<td[^>]*>([\s\S]*?)<\/td>/i);
  if (tableMatch) {
    const text = stripTags(tableMatch[1]);
    if (text) {
      const lastComma = text.lastIndexOf(",");
      const country = lastComma >= 0 ? text.slice(lastComma + 1).trim() : text;
      const iso2 = normalizeCountry(country);
      if (iso2) return { location: text, iso2, source: "table" };
    }
  }

  // Pattern B: JSON-LD description "All season Pura lana - Vitale Barberis Canonico, Italia"
  const ldMatch = html.match(/"@type":"Product"[\s\S]*?"description":"([^"]+)"/);
  if (ldMatch) {
    const desc = ldMatch[1];
    const dashMatch = desc.match(/[-–—]\s*([^,]+),\s*([A-Za-zÀ-ÿ ]+?)$/);
    if (dashMatch) {
      const text = `${dashMatch[1].trim()}, ${dashMatch[2].trim()}`;
      const iso2 = normalizeCountry(dashMatch[2]);
      if (iso2) return { location: text, iso2, source: "jsonld" };
    }
  }

  // Pattern C: "Tessuto da Mill, Country —"
  const proseMatch = html.match(/Tessuto da\s+([^,<]+),\s*([A-Za-zÀ-ÿ ]+?)\s*[—–-]/i);
  if (proseMatch) {
    const text = `${proseMatch[1].trim()}, ${proseMatch[2].trim()}`;
    const iso2 = normalizeCountry(proseMatch[2]);
    if (iso2) return { location: text, iso2, source: "prose" };
  }

  return null;
}

async function fetchPdp(url, retry = 0) {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36" },
      redirect: "follow",
    });
    if (!res.ok) {
      if (res.status >= 500 && retry === 0) {
        await sleep(2000);
        return fetchPdp(url, retry + 1);
      }
      return { ok: false, status: res.status };
    }
    const html = await res.text();
    return { ok: true, html };
  } catch (err) {
    if (retry === 0) {
      await sleep(2000);
      return fetchPdp(url, retry + 1);
    }
    return { ok: false, error: err.message };
  }
}

// === MAIN ===

// Build query: in modalità refresh prendiamo tutti i prodotti (anche quelli con
// weaving_iso2 già popolato), così possiamo arricchire `weaving_location` con
// il mill name completo (es. "Vitale Barberis Canonico, Italia" invece di
// "Italia").
let query = supabase
  .from("products")
  .select("id, name, affiliate_url, weaving_location, weaving_iso2, brands!inner(slug)")
  .eq("brands.slug", "suitsupply")
  .eq("is_active", true);
if (!refreshLocations) {
  query = query.is("weaving_iso2", null);
}
const { data: products, error } = await query;

if (error) {
  console.error("Failed to load Suitsupply products:", error.message);
  process.exit(1);
}

const targets = limit ? products.slice(0, limit) : products;
console.log(`Loaded ${products.length} Suitsupply products without weaving_iso2 (processing ${targets.length})`);
console.log(dryRun ? "DRY RUN: no DB updates will be made\n" : "");

let updated = 0, skipped = 0, errors = 0, consecutiveErrors = 0;

for (let i = 0; i < targets.length; i++) {
  const p = targets[i];
  const url = p.affiliate_url;
  if (!url) { skipped++; continue; }

  const r = await fetchPdp(url);
  if (!r.ok) {
    errors++;
    consecutiveErrors++;
    console.error(`  [ERR] ${p.name} (${url}) → ${r.status || r.error}`);
    if (consecutiveErrors >= 5) {
      console.error("\nABORT: 5 consecutive fetch errors. Possible IP block.");
      break;
    }
    await sleep(500);
    continue;
  }
  consecutiveErrors = 0;

  const found = extractWeaving(r.html);
  if (!found) {
    skipped++;
    console.log(`  [SKIP] ${p.name}`);
    await sleep(500);
    continue;
  }

  // In refresh mode: skip se la location è già un nome di mill (contiene
  // qualcosa di più informativo del solo nome paese)
  if (refreshLocations && p.weaving_location && p.weaving_location === found.location) {
    skipped++;
    await sleep(500);
    continue;
  }

  const before = p.weaving_location ? ` (was: "${p.weaving_location}")` : "";
  console.log(`  [${found.source.toUpperCase()}] ${p.name} → ${found.location} (${found.iso2})${before}`);

  if (!dryRun) {
    const { error: updErr } = await supabase
      .from("products")
      .update({ weaving_location: found.location, weaving_iso2: found.iso2 })
      .eq("id", p.id);
    if (updErr) {
      errors++;
      console.error(`  [ERR-UPD] ${p.id}: ${updErr.message}`);
    } else {
      updated++;
    }
  } else {
    updated++;
  }

  if (updated > 0 && updated % 25 === 0) {
    console.log(`  progress: ${i + 1}/${targets.length} (updated=${updated})`);
  }
  await sleep(500);
}

console.log(`\n=== Backfill Suitsupply weaving summary ===`);
console.log(`Processed:  ${targets.length}`);
console.log(`Updated:    ${updated}${dryRun ? " (dry-run)" : ""}`);
console.log(`Skipped:    ${skipped} (no weaving in PDP)`);
console.log(`Errors:     ${errors}`);
