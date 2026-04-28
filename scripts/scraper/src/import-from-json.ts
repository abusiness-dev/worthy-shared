import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { loadDbMappings } from "./config.js";
import type { RawProduct } from "./types.js";
import { processProduct } from "./pipeline/processor.js";
import { insertProduct } from "./pipeline/inserter.js";

interface ImportOptions {
  file: string;
  brandSlug: string;
  dryRun: boolean;
  limit: number | null;
  dedupeModelSku: boolean;
}

interface JsonRecord {
  brand?: string;
  category?: string;
  gender?: string;
  name?: string;
  price_eur?: string | number;
  composition?: string;
  country_of_production?: string;
  spinning_location?: string;
  weaving_location?: string;
  dyeing_location?: string;
  product_url?: string;
  photo_urls?: string;
  ean_barcode?: string;
}

function parseArgs(): ImportOptions {
  const args = process.argv.slice(2);
  const options: ImportOptions = {
    file: "",
    brandSlug: "",
    dryRun: false,
    limit: null,
    dedupeModelSku: false,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--file":
        options.file = args[++i];
        break;
      case "--brand-slug":
        options.brandSlug = args[++i];
        break;
      case "--dry-run":
        options.dryRun = true;
        break;
      case "--limit":
        options.limit = parseInt(args[++i], 10);
        break;
      case "--dedupe-model-sku":
        options.dedupeModelSku = true;
        break;
      case "--help":
        printHelp();
        process.exit(0);
    }
  }

  if (!options.file || !options.brandSlug) {
    console.error("ERROR: --file and --brand-slug are required.");
    printHelp();
    process.exit(1);
  }

  return options;
}

function printHelp(): void {
  console.log(`
Worthy Static JSON Import

Importa prodotti da un file JSON normalizzato (es. dump xlsx → json) e li
inserisce nel DB riusando la pipeline scraper (parse composition, scoring,
slug, dedup affiliate_url).

Usage: npx tsx src/import-from-json.ts --file <path> --brand-slug <slug> [options]

Required:
  --file <path>        Path assoluto al file JSON (array di record)
  --brand-slug <slug>  Slug del brand nel DB (es. "suitsupply")

Options:
  --dry-run            Parse + valida + log, NON insert in DB
  --limit <n>          Limita ai primi n record (utile per sample)
  --help               Mostra questo help

Schema record JSON atteso:
  {
    "brand": "...",
    "category": "...",          // categoria italiana (camicie, abiti, ecc.)
    "gender": "uomo" | "donna" | "unisex",
    "name": "...",
    "price_eur": "99.00" | 99,
    "composition": "70% Cotone, 30% Seta",
    "country_of_production": "..." | "",
    "spinning_location":     "..." | "",
    "weaving_location":      "..." | "",
    "dyeing_location":       "..." | "",
    "product_url": "https://...",
    "photo_urls": "url1|url2|url3",
    "ean_barcode": "..." | ""
  }
`);
}

function nullIfEmpty(s: string | undefined | null): string | undefined {
  if (s === undefined || s === null) return undefined;
  const trimmed = String(s).trim();
  return trimmed === "" ? undefined : trimmed;
}

// Estrae lo SKU code dall'URL per disambiguare slug duplicati. Supporta:
//   - SUITSUPPLY-style:  .../bomber-navy/J1127.html         → "J1127"
//   - BERSHKA-style:     .../mini-dress-l01132662-c0p207672443.html?colorId=500
//                        → "l01132662-c0p207672443-500" (path-SKU + colorId)
//
// Se path-SKU e colorId sono entrambi disponibili, vengono concatenati: la
// stessa modello-style appare con più colorId distinti (varianti colore), e
// il path-SKU da solo non distingue. Concat = key univoca.
function extractSkuFromUrl(url: string): string | null {
  // Path-SKU
  let pathSku: string | null = null;
  const mSimple = url.match(/\/([A-Za-z0-9]+)\.html(?:[?#].*)?$/);
  if (mSimple) {
    pathSku = mSimple[1];
  } else {
    const mWithDashes = url.match(/\/([A-Za-z0-9-]+)\.html(?:[?#].*)?$/);
    if (mWithDashes) {
      const parts = mWithDashes[1].split("-").filter((s) => /\d/.test(s));
      pathSku = parts.slice(-2).join("-") || null;
    } else {
      // COS-style: nessun .html, URL termina con -<id_numerico_lungo>
      // es. ".../product/button-detail-linen-v-neck-shirt-blue-1327610003" → "1327610003"
      // MANGO-style: separatore underscore, eventuale query "?c=NN"
      // es. ".../giacca-similpelle-tasche_27091189?c=76" → "27091189"
      const mNumericTail = url.match(/[-_](\d{6,})(?:[?#].*)?\/?$/);
      if (mNumericTail) {
        pathSku = mNumericTail[1];
      }
    }
  }

  // Query disambiguator (colorId / sku / ref)
  const mQuery = url.match(/[?&](?:colorId|sku|ref)=([A-Za-z0-9-]+)/);
  const queryId = mQuery ? mQuery[1] : null;

  if (pathSku && queryId) return `${pathSku}-${queryId}`;
  return pathSku ?? queryId;
}

// Disambigua i nomi duplicati nel batch aggiungendo lo SKU code in coda.
// Stesso nome + brand → stesso slug → constraint UNIQUE viola. Aggiungere
// lo SKU mantiene il nome leggibile e produce slug univoci a livello brand.
function disambiguateDuplicateNames(records: RawProduct[]): void {
  const counts = new Map<string, number>();
  for (const r of records) counts.set(r.name, (counts.get(r.name) ?? 0) + 1);
  for (const r of records) {
    if ((counts.get(r.name) ?? 0) > 1) {
      const sku = extractSkuFromUrl(r.productUrl);
      if (sku) r.name = `${r.name} ${sku}`;
    }
  }
}

// Estrae il Model SKU dall'URL BERSHKA ignorando il colorId, così varianti dello stesso
// modello in colori diversi condividono la stessa chiave di deduplicazione.
// Es. ".../asymmetric-mini-dress-l01480008-c0p208528514.html?colorId=406" → "l01480008-c0p208528514"
function extractModelSkuFromUrl(url: string): string | null {
  const m = url.match(/\/(l\d{8}-c0p\d+)\.html/);
  return m ? m[1] : null;
}

// Riduce il batch a un record per model_sku (prima occorrenza).
// Record con URL non-BERSHKA (senza pattern l\d{8}-c0p\d+) passano invariati.
function deduplicateByModelSku(records: JsonRecord[]): JsonRecord[] {
  const seen = new Set<string>();
  return records.filter((rec) => {
    const modelSku = extractModelSkuFromUrl(rec.product_url ?? "");
    if (!modelSku) return true;
    if (seen.has(modelSku)) return false;
    seen.add(modelSku);
    return true;
  });
}

function toRawProduct(rec: JsonRecord, lineIndex: number): RawProduct | null {
  const name = nullIfEmpty(rec.name);
  const productUrl = nullIfEmpty(rec.product_url);
  const compositionText = nullIfEmpty(rec.composition);
  const category = nullIfEmpty(rec.category);
  const priceRaw = rec.price_eur;

  if (!name || !productUrl || !compositionText || !category) {
    console.warn(
      `  [SKIP-INPUT] Record #${lineIndex} mancano campi obbligatori (name/product_url/composition/category)`
    );
    return null;
  }

  const price = typeof priceRaw === "number" ? priceRaw : parseFloat(String(priceRaw ?? ""));
  if (!Number.isFinite(price) || price <= 0) {
    console.warn(`  [SKIP-INPUT] Record #${lineIndex} "${name}" prezzo invalido: ${priceRaw}`);
    return null;
  }

  const genderRaw = (rec.gender ?? "uomo").toLowerCase();
  const gender: RawProduct["gender"] =
    genderRaw === "donna" ? "donna" : genderRaw === "unisex" ? "unisex" : "uomo";

  const photoUrls = (rec.photo_urls ?? "")
    .split("|")
    .map((u) => u.trim())
    .filter((u) => u.length > 0);

  return {
    name,
    price,
    compositionText,
    imageUrls: photoUrls,
    countryOfProduction: nullIfEmpty(rec.country_of_production),
    spinningLocation: nullIfEmpty(rec.spinning_location),
    weavingLocation: nullIfEmpty(rec.weaving_location),
    dyeingLocation: nullIfEmpty(rec.dyeing_location),
    productUrl,
    gender,
    category,
    eanBarcode: nullIfEmpty(rec.ean_barcode),
  };
}

async function main(): Promise<void> {
  const options = parseArgs();

  console.log("=== Worthy Static JSON Import ===");
  console.log(`File:       ${options.file}`);
  console.log(`Brand slug: ${options.brandSlug}`);
  console.log(`Dry run:    ${options.dryRun}`);
  if (options.limit !== null) console.log(`Limit:      ${options.limit}`);
  console.log("");

  const absPath = resolve(options.file);
  const raw = readFileSync(absPath, "utf8");
  const records: JsonRecord[] = JSON.parse(raw);
  if (!Array.isArray(records)) {
    throw new Error(`JSON root non è un array: ${absPath}`);
  }

  const sliced = options.limit !== null ? records.slice(0, options.limit) : records;

  const deduped = options.dedupeModelSku ? deduplicateByModelSku(sliced) : sliced;
  if (options.dedupeModelSku) {
    console.log(`Dedupe model SKU: ${sliced.length} → ${deduped.length} record unici\n`);
  } else {
    console.log(`Loaded ${sliced.length} record (di ${records.length} totali)\n`);
  }

  await loadDbMappings();

  // 1. Mapping JSON → RawProduct
  const rawProducts = deduped
    .map((rec, i) => toRawProduct(rec, i + 1))
    .filter((r): r is RawProduct => r !== null);

  // 1b. Disambigua nomi duplicati nel batch (es. "Bomber navy" x3 con SKU diverso)
  disambiguateDuplicateNames(rawProducts);

  // 2. processProduct → ScrapedProduct (parse composition, score, slug)
  const processed = rawProducts
    .map((r) => processProduct(r, options.brandSlug))
    .filter((p): p is NonNullable<typeof p> => p !== null);

  console.log(
    `\nMapping: ${rawProducts.length} raw, ${processed.length} validi dopo processing\n`
  );

  // Distribuzione finale per categoria slug DB
  const byCategory: Record<string, number> = {};
  for (const p of processed) {
    byCategory[p.categorySlug] = (byCategory[p.categorySlug] ?? 0) + 1;
  }
  console.log("Distribuzione categoria (slug DB):");
  for (const [slug, count] of Object.entries(byCategory).sort()) {
    console.log(`  ${slug.padEnd(30)} ${count}`);
  }
  console.log("");

  if (options.dryRun) {
    console.log("=== DRY-RUN: nessuna scrittura su DB ===");
    for (const p of processed.slice(0, 5)) {
      console.log(
        `  [SAMPLE] ${p.name} | ${p.price}€ | ${p.categorySlug} | comp:${p.scoreComposition} | qpr:${p.scoreQpr} | score:${p.worthyScore} | ${p.verdict}`
      );
    }
    console.log(`\nTotal validi: ${processed.length}`);
    return;
  }

  console.log("=== INSERT in DB ===\n");
  let inserted = 0;
  let skipped = 0;
  for (const p of processed) {
    // Per-product disambiguator: SKU dall'URL. Se collisione di slug (varianti
    // tipografiche di un nome non rilevate da disambiguateDuplicateNames),
    // l'inserter ritenterà con name+SKU.
    const sku = extractSkuFromUrl(p.productUrl);
    const ok = await insertProduct(p, { slugDisambiguator: sku ?? undefined });
    if (ok) inserted++;
    else skipped++;
  }
  console.log(
    `\n=== Summary ===\nInseriti: ${inserted}\nSkippati: ${skipped}\nTotale processati: ${processed.length}`
  );
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
