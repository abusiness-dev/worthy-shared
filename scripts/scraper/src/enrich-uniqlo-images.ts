import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { chromium } from "playwright";

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supabase = createClient(supabaseUrl, supabaseKey);

const IMAGE_RE = /^https?:\/\/[^/]*uniqlo\.com\//i;
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

function extractProductIdFromUrl(pageUrl: string): string | null {
  // /products/E455365-000/00 → 455365
  const m = pageUrl.match(/\/products\/E(\d+)/i);
  return m ? m[1] : null;
}

async function extractImages(page: any, productId: string | null): Promise<string[]> {
  await page.evaluate(() => window.scrollBy(0, 800));
  await page.waitForTimeout(1000);

  return page.evaluate(
    ({ pid }) => {
      const re = /^https?:\/\/[^/]*uniqlo\.com\//i;
      // Foto prodotto: /imagesgoods/<id>/(item|sub)/ + _3x4.jpg
      const PRODUCT_PATH_RE = /\/imagesgoods\/([^/]+)\/(item|sub)\//i;
      const SWATCH_PATH_RE = /\/(chip|thumb)\/|_chip\./i;

      const urls: string[] = [];
      const imgs = Array.from(document.querySelectorAll("img"));
      for (const img of imgs) {
        const candidates = [
          (img as HTMLImageElement).currentSrc,
          img.getAttribute("src") || "",
          img.getAttribute("data-src") || "",
        ];
        const srcset = img.getAttribute("srcset") || "";
        if (srcset) {
          const parts = srcset.split(",").map((s) => s.trim().split(" ")[0]);
          candidates.push(...parts);
        }
        for (const c of candidates) {
          if (c && re.test(c)) urls.push(c);
        }
      }

      const strippedQs = urls.map((u) => u.replace(/([?&])width=\d+/, "$1width=750"));
      const filtered = strippedQs.filter((u) => {
        const m = u.match(PRODUCT_PATH_RE);
        if (!m) return false;
        if (SWATCH_PATH_RE.test(u)) return false;
        if (pid && m[1] !== pid) return false;
        return true;
      });

      const deduped = [...new Set(filtered)];
      deduped.sort((a, b) => {
        const aIsItem = /\/item\//i.test(a) ? 0 : 1;
        const bIsItem = /\/item\//i.test(b) ? 0 : 1;
        if (aIsItem !== bIsItem) return aIsItem - bIsItem;
        const na = parseInt(a.match(/sub(\d+)/i)?.[1] ?? "0", 10);
        const nb = parseInt(b.match(/sub(\d+)/i)?.[1] ?? "0", 10);
        return na - nb;
      });

      return deduped.slice(0, 5);
    },
    { pid: productId }
  );
}

async function main() {
  const { data: brand } = await supabase
    .from("brands")
    .select("id")
    .eq("slug", "uniqlo")
    .single();
  if (!brand) throw new Error("Uniqlo brand not found");

  const { data: products, error } = await supabase
    .from("products")
    .select("id, name, affiliate_url, photo_urls")
    .eq("brand_id", brand.id)
    .order("created_at");
  if (error) throw error;

  const force = process.env.ENRICH_FORCE === "1" || process.env.ENRICH_FORCE === "true";
  const empty = force
    ? (products ?? [])
    : (products ?? []).filter((p) => !p.photo_urls || p.photo_urls.length === 0);
  console.log(
    `Found ${empty.length}/${products?.length ?? 0} Uniqlo products to process (force=${force}).`
  );

  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({
      userAgent: USER_AGENT,
      locale: "it-IT",
      viewport: { width: 1366, height: 900 },
    });
    const page = await context.newPage();

    const limit = parseInt(process.env.ENRICH_LIMIT ?? "0", 10);
    const batch = limit > 0 ? empty.slice(0, limit) : empty;
    console.log(`Processing ${batch.length} products (limit=${limit || "none"}).`);
    let updated = 0;
    let failed = 0;
    for (const p of batch) {
      if (!p.affiliate_url || !p.affiliate_url.includes("uniqlo.com")) {
        console.warn(`  [SKIP] ${p.name}: no uniqlo URL`);
        failed++;
        continue;
      }
      try {
        await page.goto(p.affiliate_url, {
          waitUntil: "domcontentloaded",
          timeout: 30_000,
        });
        try {
          await page.waitForLoadState("networkidle", { timeout: 10_000 });
        } catch {
          /* best-effort */
        }
        await page.waitForTimeout(800);

        const productId = extractProductIdFromUrl(p.affiliate_url);
        const images = (await extractImages(page, productId)).filter((u) => IMAGE_RE.test(u));
        if (images.length === 0) {
          console.warn(`  [NONE] ${p.name}: no images found`);
          failed++;
          continue;
        }

        const { error: upErr } = await supabase
          .from("products")
          .update({ photo_urls: images })
          .eq("id", p.id);
        if (upErr) {
          console.error(`  [ERR] ${p.name}: ${upErr.message}`);
          failed++;
        } else {
          updated++;
          console.log(`  [OK] ${p.name} → ${images.length} images`);
        }
      } catch (e: any) {
        console.warn(`  [ERR] ${p.name}: ${e.message}`);
        failed++;
      }
      await new Promise((r) => setTimeout(r, 500 + Math.random() * 500));
    }

    console.log(`\nDone. Updated ${updated}, failed ${failed}.`);
    await context.close();
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
