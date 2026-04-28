/**
 * Import del catalogo Lacoste IT da file Excel.
 *
 * Il file di partenza ha una riga per variante colore (1244 righe ≈ 361
 * modelli × ~3.4 colori). Convergiamo a 1 prodotto per modello (URL base senza
 * `?color=…`) e accumuliamo gli EAN delle varianti in `additional_eans`, così
 * una scansione barcode di qualunque colore risolve sullo stesso prodotto.
 *
 * Uso:
 *   cd scripts/scraper
 *   tsx src/seed-lacoste.ts                              # dry-run di default
 *   tsx src/seed-lacoste.ts --apply                      # esegue gli upsert
 *   tsx src/seed-lacoste.ts --xlsx /path/al/file.xlsx    # path custom
 *   tsx src/seed-lacoste.ts --apply --limit 20           # solo i primi 20 modelli
 *
 * Richiede SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY in `.env`.
 *
 * Output: report con conteggi per sub-category e elenco delle composizioni
 * non parsificate (skipped) per review manuale.
 */

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";
import * as path from "node:path";
import * as fs from "node:fs";
import { homedir } from "node:os";

// ────────────────────────────────────────────────────────────────────
// Config
// ────────────────────────────────────────────────────────────────────

const DEFAULT_XLSX = path.join(homedir(), "Desktop", "Database worthy", "LACOSTE", "LACOSTE.xlsx");
const BRAND_SLUG = "lacoste";

// ────────────────────────────────────────────────────────────────────
// Tipi
// ────────────────────────────────────────────────────────────────────

interface RawRow {
  brand: string;
  category: string;
  gender: "uomo" | "donna";
  name: string;
  price_eur: string | number;
  composition: string;
  product_url: string;
  photo_urls: string;
  country_of_production: string | null;
  spinning_location: string | null;
  weaving_location: string | null;
  dyeing_location: string | null;
  ean_barcode: string;
}

interface GroupedProduct {
  styleCode: string; // es. "L1212-00", "EF0201-00"
  baseUrl: string;
  category: string;
  gender: "uomo" | "donna";
  name: string;
  priceEur: number;
  compositionText: string;
  eans: string[];
  photoUrls: string[];
}

interface ParsedComposition {
  fiber: string;
  percentage: number;
}

// ────────────────────────────────────────────────────────────────────
// Mappa fibre IT/EN → fiber id (allineato a src/constants/fibers.ts)
// ────────────────────────────────────────────────────────────────────

const FIBER_MAP: Array<{ pattern: RegExp; id: string }> = [
  { pattern: /\bcashmere\b/i, id: "cashmere" },
  { pattern: /\b(seta|silk)\b/i, id: "silk" },
  { pattern: /\b(lana\s+merin|merino\s+wool)/i, id: "merino_wool" },
  { pattern: /\b(supima|cotone\s+supima|supima\s+cotton)\b/i, id: "supima_cotton" },
  { pattern: /\b(pima|cotone\s+pima|pima\s+cotton)\b/i, id: "pima_cotton" },
  { pattern: /\b(cotone\s+egizian|egyptian\s+cotton)/i, id: "egyptian_cotton" },
  { pattern: /\b(lino|linen)\b/i, id: "linen" },
  { pattern: /\b(cotone\s+(biologico|organico)|organic\s+cotton)\b/i, id: "organic_cotton" },
  { pattern: /\b(lyocell)\b/i, id: "lyocell" },
  { pattern: /\b(tencel)\b/i, id: "tencel" },
  { pattern: /\b(lana|wool)\b/i, id: "wool" },
  { pattern: /\b(cotone|cotton)\b/i, id: "cotton" },
  { pattern: /\b(modal)\b/i, id: "modal" },
  { pattern: /\b(cupro)\b/i, id: "cupro" },
  { pattern: /\b(viscos[ae])\b/i, id: "viscose" },
  { pattern: /\b(rayon)\b/i, id: "rayon" },
  { pattern: /\b(nylon)\b/i, id: "nylon" },
  { pattern: /\b(poliammid[ae]|polyamid[ae])\b/i, id: "polyamide" },
  {
    pattern: /\b(poliestere\s+riciclato|recycled\s+polyester)\b/i,
    id: "recycled_polyester",
  },
  { pattern: /\b(poliestere|polyester)\b/i, id: "polyester" },
  { pattern: /\b(acrilic[oa]|acrylic)\b/i, id: "acrylic" },
  { pattern: /\b(elastan[ne]?|elasthane?)\b/i, id: "elastane" },
  { pattern: /\b(spandex)\b/i, id: "spandex" },
];

function normalizeFiber(label: string): string | null {
  for (const { pattern, id } of FIBER_MAP) {
    if (pattern.test(label)) return id;
  }
  return null;
}

// ────────────────────────────────────────────────────────────────────
// Mappatura categoria Excel + nome → sub-category slug nel DB
// ────────────────────────────────────────────────────────────────────

function mapCategorySlug(category: string, gender: "uomo" | "donna", name: string): string | null {
  const cat = category.trim().toLowerCase();
  const n = name.toLowerCase();

  switch (cat) {
    case "polo":
      return "polo";

    case "t-shirt":
      if (/\b(canotta|tank)\b/i.test(n)) return "canotta";
      if (/\b(oversize|oversized|loose)\b/i.test(n)) return "t-shirt-oversize";
      return "t-shirt-basic";

    case "felpe":
      if (/\b(cappuccio|hood|hoodie)\b/i.test(n)) return "felpa-cappuccio";
      if (/\b(cardigan)\b/i.test(n)) return "cardigan";
      return "felpa-girocollo";

    case "maglieria":
      if (/\b(cardigan)\b/i.test(n)) return "cardigan";
      return "maglione";

    case "giacche":
      if (/\b(trench)\b/i.test(n)) return "trench";
      if (/\b(cappotto|coat|overcoat)\b/i.test(n)) return "cappotto";
      if (/\b(piumino|down|puffer)\b/i.test(n)) return "piumino";
      if (/\b(blazer|harrington)\b/i.test(n)) return "blazer";
      if (/\b(parka)\b/i.test(n)) return "parka";
      if (/\b(bomber)\b/i.test(n)) return "bomber";
      return "giubbotto";

    case "pantaloni":
      // Bermuda/short prima di tutto (Lacoste ha molti bermuda in 'pantaloni')
      if (/\b(bermuda|short(s)?)\b/i.test(n)) return "shorts";
      if (/\b(jeans|denim)\b/i.test(n)) return "jeans-regular";
      if (/\b(cargo)\b/i.test(n)) return "cargo";
      if (/\b(jogger|jogging|sweatpant|tuta)\b/i.test(n)) return "jogger";
      if (/\b(elegant|sartori|tailored|plissett)/i.test(n)) return "pantaloni-eleganti";
      return "chinos";

    case "tute":
      return "tuta";

    case "camicie":
      return "camicia";

    case "costumi":
      return "costume";

    case "intimo homewear":
      return "intimo";

    case "abiti e gonne":
      if (/\b(gonna|skirt)\b/i.test(n)) return "gonna";
      return "vestito";

    default:
      return null;
  }
}

// ────────────────────────────────────────────────────────────────────
// Parser composizione: il file Lacoste a volte concatena multi-component
// (shell + lining + rib) in un'unica stringa. Logica: prendiamo solo il primo
// "blocco" la cui somma percentuali è ≤ 100. Esempi:
//   "100% Cotone"                                              → 100% cotton
//   "94% Cotone, 6% Elastan"                                   → 94% cotton + 6% elastane
//   "94% Cotone, 6% Elastane, 99% / Cotone, 1% Elastane, …"    → 94 + 6 (poi tronca)
//   "84% Cotone, 16% Poliestere, 100% Cotone, 98% Cotone, …"   → 84 + 16 (poi tronca)
// ────────────────────────────────────────────────────────────────────

function parseComposition(text: string): ParsedComposition[] | null {
  if (!text || typeof text !== "string") return null;

  // Estrae tutte le coppie "<num>% <fiber>" dal testo
  const pairs: Array<{ pct: number; fiber: string | null; raw: string }> = [];
  const regex = /(\d+(?:[.,]\d+)?)\s*%\s*\/?\s*([A-Za-zÀ-ÿ\s]+?)(?=,|\d+\s*%|$)/g;

  let match: RegExpExecArray | null;
  while ((match = regex.exec(text)) !== null) {
    const pct = parseFloat(match[1].replace(",", "."));
    const fiberLabel = match[2].trim();
    const fiber = normalizeFiber(fiberLabel);
    pairs.push({ pct, fiber, raw: fiberLabel });
  }

  if (pairs.length === 0) return null;

  // Accumula segmenti finché la somma ≤ 100 ± tolleranza.
  // Quando l'aggiunta di un segmento sforerebbe 100+1 (es. nuovo "100% Cotone"
  // dopo che abbiamo già 94+6), tronca: stiamo entrando nella sezione lining.
  const composition: ParsedComposition[] = [];
  let total = 0;
  for (const p of pairs) {
    if (!p.fiber) continue; // fibra non riconosciuta, ignora
    if (total + p.pct > 101) break;
    composition.push({ fiber: p.fiber, percentage: p.pct });
    total += p.pct;
    if (total >= 99.5) break; // chiuso, blocchiamo prima del lining
  }

  if (composition.length === 0) return null;

  // Merge fibre duplicate nel primo blocco (es. "70% Cotton, 30% Cotton")
  const merged = new Map<string, number>();
  for (const c of composition) {
    merged.set(c.fiber, (merged.get(c.fiber) ?? 0) + c.percentage);
  }

  return Array.from(merged.entries()).map(([fiber, percentage]) => ({
    fiber,
    percentage: Math.round(percentage * 10) / 10,
  }));
}

// ────────────────────────────────────────────────────────────────────
// Slug stabile: <brand>-<style-code>-<short-name>
// ────────────────────────────────────────────────────────────────────

function slugify(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-+/g, "-");
}

function extractStyleCode(url: string): string {
  // ".../EF0201-00.html?color=166"  → "ef0201"
  // ".../L1212-00.html"              → "l1212"
  const m = url.match(/\/([A-Z0-9]+)-\d+\.html/i);
  return m ? m[1].toLowerCase() : "";
}

function buildSlug(group: GroupedProduct): string {
  const code = group.styleCode;
  // Tronca il nome a max 60 caratteri di slug
  const nameSlug = slugify(group.name).slice(0, 60).replace(/-+$/, "");
  const parts = ["lacoste", code, nameSlug, group.gender].filter(Boolean);
  return parts.join("-").slice(0, 120);
}

// ────────────────────────────────────────────────────────────────────
// Excel → RawRow[]
// ────────────────────────────────────────────────────────────────────

function readExcel(file: string): RawRow[] {
  // XLSX.readFile non è esposto via ESM `import * as`; usiamo `read(buffer)`.
  const buf = fs.readFileSync(file);
  const wb = XLSX.read(buf, { type: "buffer" });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  return XLSX.utils.sheet_to_json<RawRow>(sheet, { defval: null });
}

// ────────────────────────────────────────────────────────────────────
// Group per URL base (dedup colore)
// ────────────────────────────────────────────────────────────────────

function groupByModel(rows: RawRow[]): GroupedProduct[] {
  const groups = new Map<string, GroupedProduct>();

  for (const row of rows) {
    if (!row.product_url) continue;
    const baseUrl = row.product_url.split("?")[0];
    const styleCode = extractStyleCode(row.product_url);

    const photos = (row.photo_urls ?? "")
      .split("|")
      .map((u) => u.trim())
      .filter((u) => u.length > 0);

    const ean = String(row.ean_barcode ?? "").trim();

    const existing = groups.get(baseUrl);
    if (existing) {
      if (ean && !existing.eans.includes(ean)) existing.eans.push(ean);
      for (const p of photos) {
        if (!existing.photoUrls.includes(p)) existing.photoUrls.push(p);
      }
      // Mantieni il prezzo minimo trovato (varianti diverse possono avere
      // prezzi leggermente diversi: prendi il più basso come canonico)
      const newPrice = parseFloat(String(row.price_eur));
      if (Number.isFinite(newPrice) && newPrice < existing.priceEur) {
        existing.priceEur = newPrice;
      }
    } else {
      groups.set(baseUrl, {
        styleCode,
        baseUrl,
        category: row.category,
        gender: row.gender,
        name: String(row.name ?? "").trim(),
        priceEur: parseFloat(String(row.price_eur)) || 0,
        compositionText: String(row.composition ?? "").trim(),
        eans: ean ? [ean] : [],
        photoUrls: photos,
      });
    }
  }

  return Array.from(groups.values());
}

// ────────────────────────────────────────────────────────────────────
// Main
// ────────────────────────────────────────────────────────────────────

interface CliOptions {
  xlsx: string;
  apply: boolean;
  limit: number;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  const out: CliOptions = { xlsx: DEFAULT_XLSX, apply: false, limit: 0 };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--xlsx") out.xlsx = args[++i];
    else if (args[i] === "--apply") out.apply = true;
    else if (args[i] === "--limit") out.limit = parseInt(args[++i], 10) || 0;
    else if (args[i] === "--help") {
      console.log("Usage: tsx src/seed-lacoste.ts [--xlsx PATH] [--apply] [--limit N]");
      process.exit(0);
    }
  }
  return out;
}

async function main(): Promise<void> {
  const opts = parseArgs();

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env");
    process.exit(1);
  }
  const supabase = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log(`→ Lettura Excel: ${opts.xlsx}`);
  const rows = readExcel(opts.xlsx);
  console.log(`  ${rows.length} righe`);

  console.log(`→ Group by URL base…`);
  let groups = groupByModel(rows);
  if (opts.limit > 0) groups = groups.slice(0, opts.limit);
  const totalEans = groups.reduce((s, g) => s + g.eans.length, 0);
  console.log(`  ${groups.length} prodotti unici, ${totalEans} EAN totali`);

  // Risolvi brand_id e categoryIdMap
  console.log(`→ Lookup brand "${BRAND_SLUG}" e categories…`);
  const { data: brand } = await supabase
    .from("brands")
    .select("id")
    .eq("slug", BRAND_SLUG)
    .maybeSingle();

  if (!brand && opts.apply) {
    console.error(`Brand "${BRAND_SLUG}" non trovato. Applica prima la migration 20260429000002.`);
    process.exit(1);
  }
  // In dry-run il brand può non esistere ancora: usiamo placeholder per il payload.
  const brandId = (brand?.id as string | undefined) ?? "00000000-0000-0000-0000-000000000000";
  if (!brand) console.log("  (brand non in DB: dry-run procede con placeholder)");

  const { data: cats } = await supabase.from("categories").select("id, slug");
  const catIdBySlug = new Map<string, string>();
  for (const c of cats ?? []) catIdBySlug.set(c.slug as string, c.id as string);

  // Costruisci payload per insert
  type InsertPayload = {
    brand_id: string;
    category_id: string;
    name: string;
    slug: string;
    gender: "uomo" | "donna";
    price: number;
    composition: ParsedComposition[];
    photo_urls: string[];
    affiliate_url: string;
    ean_barcode: string | null;
    additional_eans: string[];
    is_active: boolean;
  };

  const payloads: InsertPayload[] = [];
  const subCategoryCounts = new Map<string, number>();
  const skippedComposition: GroupedProduct[] = [];
  const skippedCategory: GroupedProduct[] = [];
  const slugSeen = new Set<string>();

  for (const g of groups) {
    const subSlug = mapCategorySlug(g.category, g.gender, g.name);
    if (!subSlug) {
      skippedCategory.push(g);
      continue;
    }
    const categoryId = catIdBySlug.get(subSlug);
    if (!categoryId) {
      console.warn(`  [WARN] sub-category "${subSlug}" non in DB, skip "${g.name}"`);
      skippedCategory.push(g);
      continue;
    }

    const composition = parseComposition(g.compositionText);
    if (!composition || composition.length === 0) {
      skippedComposition.push(g);
      continue;
    }

    let slug = buildSlug(g);
    let suffix = 2;
    while (slugSeen.has(slug)) {
      slug = `${buildSlug(g)}-${suffix++}`;
    }
    slugSeen.add(slug);

    payloads.push({
      brand_id: brandId,
      category_id: categoryId,
      name: g.name,
      slug,
      gender: g.gender,
      price: g.priceEur,
      composition,
      photo_urls: g.photoUrls.slice(0, 12),
      affiliate_url: g.baseUrl,
      ean_barcode: g.eans[0] ?? null,
      additional_eans: g.eans.slice(1),
      is_active: true,
    });

    subCategoryCounts.set(subSlug, (subCategoryCounts.get(subSlug) ?? 0) + 1);
  }

  // Report
  console.log("\n══════════════════════════════════════════════════════");
  console.log(" REPORT");
  console.log("══════════════════════════════════════════════════════");
  console.log(`Pronti per insert:        ${payloads.length}`);
  console.log(`Skip categoria sconosciuta: ${skippedCategory.length}`);
  console.log(`Skip composizione vuota:   ${skippedComposition.length}`);
  console.log("\nDistribuzione sub-category:");
  const sorted = Array.from(subCategoryCounts.entries()).sort((a, b) => b[1] - a[1]);
  for (const [slug, n] of sorted) console.log(`  ${slug.padEnd(22)} ${n}`);
  console.log();

  if (skippedComposition.length > 0) {
    console.log(`Composizioni non parsificate (${skippedComposition.length}):`);
    for (const g of skippedComposition.slice(0, 15)) {
      console.log(`  • [${g.styleCode}] "${g.name}" → "${g.compositionText}"`);
    }
    if (skippedComposition.length > 15) console.log(`  … +${skippedComposition.length - 15} altri`);
    console.log();
  }

  if (skippedCategory.length > 0) {
    console.log(`Skip categoria (${skippedCategory.length}):`);
    for (const g of skippedCategory.slice(0, 10)) {
      console.log(`  • "${g.category}" / ${g.gender} / "${g.name}"`);
    }
    console.log();
  }

  if (!opts.apply) {
    console.log("Dry-run: nessuna modifica al DB. Riesegui con --apply per scrivere.");
    return;
  }

  // Insert in batch (Supabase non ha vero "batch", ma upsert su array è 1 round-trip)
  console.log(`→ Upsert ${payloads.length} prodotti in batch da 50…`);
  const BATCH = 50;
  let inserted = 0;
  let skippedDup = 0;
  let errored = 0;

  for (let i = 0; i < payloads.length; i += BATCH) {
    const chunk = payloads.slice(i, i + BATCH);
    const { data, error } = await supabase
      .from("products")
      .upsert(chunk, { onConflict: "slug", ignoreDuplicates: true })
      .select("id");

    if (error) {
      console.error(`  [ERR] batch ${i}-${i + chunk.length}:`, error.message);
      errored += chunk.length;
      continue;
    }
    const ins = data?.length ?? 0;
    inserted += ins;
    skippedDup += chunk.length - ins;
    process.stdout.write(`  ${i + chunk.length}/${payloads.length}\r`);
  }
  console.log();

  console.log("══════════════════════════════════════════════════════");
  console.log(`Inseriti: ${inserted}`);
  console.log(`Già presenti (skip slug): ${skippedDup}`);
  console.log(`Errori: ${errored}`);
  console.log("══════════════════════════════════════════════════════");
  console.log(
    "\nNota: il trigger trg_pc_recalc_v2 ricalcola automaticamente score_breakdown e worthy_score sui prodotti inseriti."
  );
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
