/**
 * Backfill country_of_production sui prodotti Lacoste già in DB,
 * leggendo il Made-In dai PDP via Playwright (Akamai blocca curl/fetch).
 *
 * Itera i prodotti Lacoste con country_of_production_iso2 IS NULL e prova
 * a estrarre il paese dalla scheda dettagli. Se fallisce N volte di fila
 * la pagina probabilmente non riporta il dato → si interrompe per non
 * sprecare richieste.
 *
 * Uso (dalla cartella scripts/scraper):
 *   tsx src/backfill-lacoste-country.ts                # dry-run
 *   tsx src/backfill-lacoste-country.ts --apply        # scrive in DB
 *   tsx src/backfill-lacoste-country.ts --apply --limit 50
 *   tsx src/backfill-lacoste-country.ts --headed       # apre la finestra (debug)
 *
 * Richiede SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY in .env.
 */

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright";

const BRAND_SLUG = "lacoste";
const NAV_TIMEOUT_MS = 25_000;
const PER_PRODUCT_DELAY_MS = 1_200;
const CONSECUTIVE_FAILURE_BUDGET = 30; // se 30 PDP consecutivi non hanno il Made-In, ferma

// ────────────────────────────────────────────────────────────────────
// Mappa nome paese (IT/EN/FR) → ISO2 (allineata a migration 20260427000002)
// ────────────────────────────────────────────────────────────────────

const COUNTRY_TO_ISO2: Array<{ patterns: RegExp[]; iso2: string }> = [
  { iso2: "IT", patterns: [/\bitaly\b/i, /\bitalia\b/i, /\bitalie\b/i] },
  { iso2: "FR", patterns: [/\bfrance\b/i, /\bfrancia\b/i] },
  { iso2: "PT", patterns: [/\bportugal\b/i, /\bportogallo\b/i] },
  { iso2: "ES", patterns: [/\bspain\b/i, /\bspagna\b/i, /\bespagne\b/i] },
  { iso2: "DE", patterns: [/\bgermany\b/i, /\bgermania\b/i, /\ballemagne\b/i] },
  { iso2: "GB", patterns: [/\bunited\s+kingdom\b/i, /\bregno\s+unito\b/i, /\broyaume[-\s]uni\b/i, /\bengland\b/i] },
  { iso2: "TR", patterns: [/\bturkey\b/i, /\bturchia\b/i, /\bturquie\b/i] },
  { iso2: "TN", patterns: [/\btunisia\b/i, /\btunisie\b/i] },
  { iso2: "MA", patterns: [/\bmorocco\b/i, /\bmarocco\b/i, /\bmaroc\b/i] },
  { iso2: "EG", patterns: [/\begypt\b/i, /\begitto\b/i, /\b[ée]gypte\b/i] },
  { iso2: "MU", patterns: [/\bmauritius\b/i, /\bmaurice\b/i] },
  { iso2: "MG", patterns: [/\bmadagascar\b/i] },
  { iso2: "VN", patterns: [/\bvietnam\b/i] },
  { iso2: "CN", patterns: [/\bchina\b/i, /\bcina\b/i, /\bchine\b/i] },
  { iso2: "IN", patterns: [/\bindia\b/i, /\binde\b/i] },
  { iso2: "BD", patterns: [/\bbangladesh\b/i] },
  { iso2: "PK", patterns: [/\bpakistan\b/i] },
  { iso2: "LK", patterns: [/\bsri\s+lanka\b/i] },
  { iso2: "ID", patterns: [/\bindonesia\b/i, /\bindon[eé]sie\b/i] },
  { iso2: "KH", patterns: [/\bcambodia\b/i, /\bcambogia\b/i, /\bcambodge\b/i] },
  { iso2: "PE", patterns: [/\bperu\b/i, /\bper[uù]\b/i, /\bp[eé]rou\b/i] },
  { iso2: "BR", patterns: [/\bbrazil\b/i, /\bbrasile\b/i, /\bbr[eé]sil\b/i] },
  { iso2: "MX", patterns: [/\bmexico\b/i, /\bmessico\b/i, /\bmexique\b/i] },
  { iso2: "RO", patterns: [/\bromania\b/i, /\broumanie\b/i] },
  { iso2: "BG", patterns: [/\bbulgaria\b/i, /\bbulgarie\b/i] },
];

function nameToIso2(name: string): string | null {
  const trimmed = name.trim();
  for (const { patterns, iso2 } of COUNTRY_TO_ISO2) {
    for (const p of patterns) if (p.test(trimmed)) return iso2;
  }
  return null;
}

// ────────────────────────────────────────────────────────────────────
// Estrazione Made-In dal PDP
// ────────────────────────────────────────────────────────────────────

const MADE_IN_PATTERNS: RegExp[] = [
  /Made\s+in\s*[:\s]\s*([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
  /Origine\s*[:\s]\s*([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
  /Origin\s*[:\s]\s*([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
  /Paese\s+di\s+(?:produzione|origine|fabbricazione)\s*[:\s]\s*([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
  /Pays\s+de\s+fabrication\s*[:\s]\s*([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
  /Fabriqué\s+en\s+([A-Za-zÀ-ÿ\s]+?)(?:[.,]|<|$)/i,
];

interface ExtractResult {
  raw: string | null;
  iso2: string | null;
}

async function extractMadeIn(page: Page): Promise<ExtractResult> {
  // Lacoste raggruppa il Made-In nella sezione "Cura del prodotto" o simili.
  // Strategia: scrolla per triggerare lazy-load, espandi accordion se serve,
  // poi prendi tutto il testo della pagina e applica i pattern.

  try {
    // Espandi eventuali accordion che potrebbero nascondere i dettagli
    const accordionSelectors = [
      "button[aria-expanded='false']",
      "[data-testid*='accordion'] button",
      ".product-details button",
      ".accordion__trigger",
    ];
    for (const sel of accordionSelectors) {
      const buttons = await page.$$(sel).catch(() => []);
      for (const b of buttons.slice(0, 10)) {
        await b.click({ timeout: 1500 }).catch(() => {});
      }
    }

    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(400);
  } catch {
    // best-effort, non bloccare
  }

  const text = await page.evaluate(() => document.body.innerText).catch(() => "");
  if (!text) return { raw: null, iso2: null };

  for (const pat of MADE_IN_PATTERNS) {
    const m = text.match(pat);
    if (m && m[1]) {
      const raw = m[1].trim().replace(/\s+/g, " ");
      const iso2 = nameToIso2(raw);
      if (iso2) return { raw, iso2 };
    }
  }

  return { raw: null, iso2: null };
}

// ────────────────────────────────────────────────────────────────────
// CLI
// ────────────────────────────────────────────────────────────────────

interface CliOptions {
  apply: boolean;
  headed: boolean;
  limit: number;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  const out: CliOptions = { apply: false, headed: false, limit: 0 };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--apply") out.apply = true;
    else if (args[i] === "--headed") out.headed = true;
    else if (args[i] === "--limit") out.limit = parseInt(args[++i], 10) || 0;
    else if (args[i] === "--help") {
      console.log("Usage: tsx src/backfill-lacoste-country.ts [--apply] [--headed] [--limit N]");
      process.exit(0);
    }
  }
  return out;
}

// ────────────────────────────────────────────────────────────────────
// Main
// ────────────────────────────────────────────────────────────────────

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

  const { data: brand } = await supabase.from("brands").select("id").eq("slug", BRAND_SLUG).maybeSingle();
  if (!brand) {
    console.error(`Brand "${BRAND_SLUG}" non trovato.`);
    process.exit(1);
  }

  let query = supabase
    .from("products")
    .select("id, name, affiliate_url, country_of_production_iso2")
    .eq("brand_id", brand.id)
    .is("country_of_production_iso2", null);

  const { data: products, error } = await query;
  if (error) {
    console.error("Errore fetch prodotti:", error.message);
    process.exit(1);
  }

  let toProcess = products ?? [];
  if (opts.limit > 0) toProcess = toProcess.slice(0, opts.limit);
  console.log(`→ ${toProcess.length} prodotti Lacoste senza country_of_production_iso2`);

  if (toProcess.length === 0) {
    console.log("Nulla da fare.");
    return;
  }

  console.log(`→ Avvio Chromium (${opts.headed ? "headed" : "headless"})…`);
  const browser: Browser = await chromium.launch({ headless: !opts.headed });
  const context: BrowserContext = await browser.newContext({
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    locale: "it-IT",
    viewport: { width: 1280, height: 900 },
  });
  context.setDefaultTimeout(NAV_TIMEOUT_MS);

  const page = await context.newPage();

  let extracted = 0;
  let consecutiveMisses = 0;
  let stoppedEarly = false;

  for (let i = 0; i < toProcess.length; i++) {
    const p = toProcess[i];
    if (!p.affiliate_url) continue;

    try {
      await page.goto(p.affiliate_url, { waitUntil: "domcontentloaded" });
      await page.waitForTimeout(800);
    } catch (e: any) {
      console.warn(`  [NAV-ERR] ${p.name}: ${e.message}`);
      consecutiveMisses++;
      continue;
    }

    const result = await extractMadeIn(page);
    if (result.iso2) {
      extracted++;
      consecutiveMisses = 0;
      console.log(`  [${i + 1}/${toProcess.length}] ✓ ${p.name} → ${result.raw} (${result.iso2})`);
      if (opts.apply) {
        const { error: upErr } = await supabase
          .from("products")
          .update({
            country_of_production: result.raw,
            country_of_production_iso2: result.iso2,
          })
          .eq("id", p.id);
        if (upErr) console.warn(`    [UPDATE-ERR] ${upErr.message}`);
      }
    } else {
      consecutiveMisses++;
      if (i < 5 || consecutiveMisses % 5 === 0) {
        console.log(`  [${i + 1}/${toProcess.length}] · ${p.name} → no Made-In trovato`);
      }
    }

    if (consecutiveMisses >= CONSECUTIVE_FAILURE_BUDGET) {
      console.warn(
        `\n[STOP] ${CONSECUTIVE_FAILURE_BUDGET} PDP consecutivi senza Made-In: probabile che Lacoste non lo pubblichi sul sito retail. Fermo qui per non sprecare richieste.`
      );
      stoppedEarly = true;
      break;
    }

    await page.waitForTimeout(PER_PRODUCT_DELAY_MS);
  }

  await browser.close();

  console.log("\n══════════════════════════════════════════════════════");
  console.log(`Estratti: ${extracted} / ${toProcess.length}`);
  if (stoppedEarly) console.log(`Interrotto in anticipo dopo ${CONSECUTIVE_FAILURE_BUDGET} miss consecutivi.`);
  if (!opts.apply) console.log("Dry-run: nessuna scrittura in DB. Riesegui con --apply.");
  console.log("══════════════════════════════════════════════════════");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
