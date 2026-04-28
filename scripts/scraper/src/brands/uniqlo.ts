import { chromium, type Browser, type Page } from "playwright";
import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";

// Uniqlo IT è un frontend JS-heavy (Next.js). Niente API pubblica senza client ID
// → Playwright headless per renderizzare e leggere i dati.
//
// Estraiamo opportunisticamente dalle PDP: name, price, composition, photos,
// country_of_production. Filatura/tessitura/tintura sono raramente esposte per
// singolo SKU sul sito consumer → quando assenti restano undefined (→ null a DB).

// Path listing verificati sul sito live. Uniqlo IT usa slug inglesi.
// La categoria scraper ("base category") viene poi raffinata in processor.ts
// via refineCategory() sul nome prodotto (polo/maglione/cardigan/bomber/parka/...).
const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "/men/tops/t-shirts",
    felpe: "/men/jumpers",
    jeans: "/men/bottoms/jeans",
    pantaloni: "/men/bottoms/casual-trousers",
    giacche: "/men/outerwear",
    camicie: "/men/shirts-and-polos",
    polo: "/men/shirts-and-polos/polo-shirts",
    shorts: "/men/bottoms/shorts",
    intimo: "/men/innerwear",
    "top-sportivo": "/men/sport-utility-wear",
    canotta: "/men/airism",
  },
  donna: {
    "t-shirt": "/women/tops/t-shirts",
    felpe: "/women/jumpers",
    jeans: "/women/bottoms/jeans",
    pantaloni: "/women/bottoms",
    giacche: "/women/outerwear",
    camicie: "/women/shirts-and-blouses",
    shorts: "/women/bottoms",
    intimo: "/women/innerwear",
    "top-sportivo": "/women/sport-utility-wear",
    leggings: "/women/bottoms",
    canotta: "/women/airism",
  },
};

const BASE = "https://www.uniqlo.com/it/it";
const IMAGE_DOMAIN_ALLOWLIST = /^https?:\/\/[^/]*uniqlo\.com\//i;
const PRODUCT_URL_PATTERN = /\/(?:products|goods|E)\d+/i;
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

export class UniqloScraper implements BrandScraper {
  readonly brandSlug = "uniqlo";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const path = CATEGORY_URLS[gender]?.[category.slug];
    if (!path) {
      console.log(`  [UNIQLO] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    const listingUrl = `${BASE}${path}`;
    console.log(`  [UNIQLO] Launching headless browser for ${listingUrl}`);

    let browser: Browser | null = null;
    try {
      browser = await chromium.launch({ headless: true });
      const context = await browser.newContext({
        userAgent: USER_AGENT,
        locale: "it-IT",
        viewport: { width: 1366, height: 900 },
      });
      const page = await context.newPage();

      const productUrls = await this.collectProductUrls(page, listingUrl, limit);
      console.log(`  [UNIQLO] Collected ${productUrls.length} product URLs`);

      const products: RawProduct[] = [];
      for (const url of productUrls) {
        try {
          const raw = await this.scrapePdp(page, url, gender, category.slug);
          if (raw) {
            products.push(raw);
            console.log(
              `  [UNIQLO] ✓ ${raw.name} | ${raw.price}€ | ${raw.compositionText}` +
                (raw.countryOfProduction ? ` | ${raw.countryOfProduction}` : "")
            );
          } else {
            console.warn(`  [UNIQLO] ✗ Skipped (missing fields): ${url}`);
          }
        } catch (e: any) {
          console.warn(`  [UNIQLO] ✗ PDP error ${url}: ${e.message}`);
        }
        await this.delay(500 + Math.random() * 1000);
      }

      await context.close();
      return products;
    } catch (e: any) {
      console.error(`  [UNIQLO] Fatal: ${e.message}`);
      return [];
    } finally {
      if (browser) await browser.close();
    }
  }

  private async collectProductUrls(
    page: Page,
    listingUrl: string,
    limit: number
  ): Promise<string[]> {
    await page.goto(listingUrl, { waitUntil: "domcontentloaded", timeout: 30_000 });
    // Attende idle o selettore lista. Fallback a timeout breve se networkidle non scatta.
    try {
      await page.waitForLoadState("networkidle", { timeout: 15_000 });
    } catch {
      /* continue even if networkidle never fires */
    }

    // Scroll-loop: Uniqlo usa lazy-load → scroll finché l'altezza pagina è stabile
    // (2 iterazioni senza crescita = fine listing). Safety cap a 50k px.
    let lastHeight = 0;
    let stableIterations = 0;
    const MAX_SCROLL_HEIGHT = 50_000;
    for (let i = 0; i < 40 && stableIterations < 2; i++) {
      const currentHeight = await page.evaluate(() => document.body.scrollHeight);
      if (currentHeight > MAX_SCROLL_HEIGHT) break;
      await page.evaluate(() => window.scrollBy(0, 2000));
      await page.waitForTimeout(1000);
      const newHeight = await page.evaluate(() => document.body.scrollHeight);
      if (newHeight === lastHeight) stableIterations++;
      else {
        stableIterations = 0;
        lastHeight = newHeight;
      }
    }

    const hrefs = await page.$$eval("a[href]", (anchors) =>
      anchors
        .map((a) => (a as HTMLAnchorElement).href)
        .filter(Boolean)
    );

    // Deduplica per product ID (E\d+) per scartare le varianti colore dello stesso SKU.
    const seenIds = new Set<string>();
    const urls: string[] = [];
    for (const raw of hrefs) {
      const clean = this.canonicalizeProductUrl(raw);
      if (!clean) continue;
      const id = this.extractProductId(clean);
      if (!id || seenIds.has(id)) continue;
      seenIds.add(id);
      urls.push(clean);
      if (urls.length >= limit) break;
    }
    return urls;
  }

  private extractProductId(url: string): string | null {
    const m = url.match(/\/products\/(E\d+)/);
    return m ? m[1] : null;
  }

  private canonicalizeProductUrl(href: string): string | null {
    if (!href) return null;
    if (!href.startsWith(BASE)) return null;
    if (!PRODUCT_URL_PATTERN.test(href)) return null;
    // Rimuove querystring e hash
    try {
      const u = new URL(href);
      return `${u.origin}${u.pathname}`;
    } catch {
      return null;
    }
  }

  private async scrapePdp(
    page: Page,
    url: string,
    gender: "uomo" | "donna",
    category: string
  ): Promise<RawProduct | null> {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30_000 });
    try {
      await page.waitForLoadState("networkidle", { timeout: 15_000 });
    } catch {
      /* best-effort */
    }

    // Uniqlo PDP ha accordion collassati per "Composizione", "Paese di produzione",
    // "Istruzioni lavaggio". Li espandiamo prima di leggere.
    await this.expandAccordions(page);

    // Strategia 1: __NEXT_DATA__ (dati strutturati di Next.js)
    const nextDataRaw = await page
      .locator("script#__NEXT_DATA__")
      .first()
      .textContent()
      .catch(() => null);

    let nextProduct: any = null;
    if (nextDataRaw) {
      try {
        const parsed = JSON.parse(nextDataRaw);
        nextProduct = this.findProductObject(parsed);
      } catch {
        /* malformed JSON, fallback */
      }
    }

    // Strategia 2: JSON-LD
    const jsonLdRaw = await page
      .locator('script[type="application/ld+json"]')
      .allTextContents()
      .catch(() => [] as string[]);
    const jsonLdProduct = this.pickJsonLdProduct(jsonLdRaw);

    // Strategia 3: DOM scraping come ultimo fallback
    const domName = await this.safeText(page, "h1");
    const domPriceText = await this.safeText(
      page,
      '[class*="price"], [data-test*="price"], [data-testid*="price"]'
    );
    const domCompositionText = await this.extractFromBodyLines(page, {
      anchors: ["composizione", "materiale", "material"],
      match: /\d{1,3}\s*%/,
    });
    const domMadeInText = await this.extractFromBodyLines(page, {
      anchors: ["paese di produzione", "made in", "prodotto in", "fabbricato in", "paese"],
      match: /[A-Za-zÀ-ÿ]{3,}/,
    });

    const name = this.sanitizeName(
      nextProduct?.name ?? jsonLdProduct?.name ?? domName
    );
    const price = this.sanitizePrice(
      nextProduct?.price?.current?.value ??
        nextProduct?.prices?.current?.value ??
        nextProduct?.price ??
        jsonLdProduct?.offers?.price ??
        jsonLdProduct?.offers?.lowPrice ??
        this.parseEuro(domPriceText)
    );
    const compositionText = this.sanitizeFreeText(
      nextProduct?.composition ??
        nextProduct?.material ??
        jsonLdProduct?.material ??
        domCompositionText,
      600
    );

    if (!name || !price || !compositionText) {
      const missing: string[] = [];
      if (!name) missing.push("name");
      if (!price) missing.push("price");
      if (!compositionText) missing.push("composition");
      console.warn(`  [UNIQLO] missing=[${missing.join(",")}] at ${url}`);
      return null;
    }

    // extractImagesFromDom è già filtrato per productId e slice-ready
    const domImages = await this.extractImagesFromDom(page, url);
    const finalImages = domImages.filter((u) => IMAGE_DOMAIN_ALLOWLIST.test(u)).slice(0, 5);

    const countryOfProduction = this.extractCountry(
      nextProduct,
      jsonLdProduct,
      domMadeInText
    );
    const supply = this.extractSupplyChain(nextProduct);

    return {
      name,
      price,
      compositionText,
      imageUrls: finalImages,
      countryOfProduction: countryOfProduction ?? undefined,
      spinningLocation: supply.spinning ?? undefined,
      weavingLocation: supply.weaving ?? undefined,
      dyeingLocation: supply.dyeing ?? undefined,
      productUrl: url,
      gender,
      category,
    };
  }

  /**
   * Scorre ricorsivamente l'albero __NEXT_DATA__ fino a trovare un oggetto che
   * assomigli a un prodotto (ha name + price o material).
   */
  private findProductObject(root: any): any | null {
    const queue: any[] = [root];
    let depth = 0;
    const maxNodes = 10_000;
    let visited = 0;
    while (queue.length && visited < maxNodes) {
      const node = queue.shift();
      visited++;
      if (!node || typeof node !== "object") continue;
      if (this.looksLikeProduct(node)) return node;
      for (const v of Object.values(node)) {
        if (v && typeof v === "object") queue.push(v);
      }
      if (++depth > 100_000) break;
    }
    return null;
  }

  private looksLikeProduct(obj: any): boolean {
    if (!obj || typeof obj !== "object") return false;
    const hasName = typeof obj.name === "string" && obj.name.length > 3;
    const hasPrice =
      typeof obj.price === "number" ||
      typeof obj.price === "string" ||
      (obj.price && typeof obj.price === "object" && "current" in obj.price) ||
      (obj.prices && typeof obj.prices === "object");
    const hasMaterial =
      typeof obj.material === "string" ||
      typeof obj.composition === "string" ||
      Array.isArray(obj.materials);
    return hasName && (hasPrice || hasMaterial);
  }

  private pickJsonLdProduct(raws: string[]): any | null {
    for (const raw of raws) {
      try {
        const parsed = JSON.parse(raw);
        const candidates = Array.isArray(parsed) ? parsed : [parsed];
        for (const c of candidates) {
          if (c && c["@type"] === "Product") return c;
          if (c && Array.isArray(c.itemListElement)) {
            for (const item of c.itemListElement) {
              if (item && item["@type"] === "Product") return item;
              if (item && item.item && item.item["@type"] === "Product") return item.item;
            }
          }
        }
      } catch {
        /* skip invalid JSON-LD */
      }
    }
    return null;
  }

  private extractImageUrls(nextProduct: any, jsonLdProduct: any): string[] {
    const out: string[] = [];
    const push = (v: any) => {
      if (typeof v === "string") out.push(v);
      else if (v && typeof v === "object") {
        if (typeof v.url === "string") out.push(v.url);
        else if (typeof v.src === "string") out.push(v.src);
      }
    };
    if (nextProduct) {
      const images = nextProduct.images || nextProduct.media || nextProduct.gallery;
      if (Array.isArray(images)) images.forEach(push);
    }
    if (jsonLdProduct) {
      const img = jsonLdProduct.image;
      if (Array.isArray(img)) img.forEach(push);
      else if (img) push(img);
    }
    // Deduplica preservando l'ordine
    const seen = new Set<string>();
    return out.filter((u) => {
      if (!u || seen.has(u)) return false;
      seen.add(u);
      return true;
    });
  }

  /**
   * Legge <img> dal DOM renderizzato e filtra per foto prodotto Uniqlo.
   * Pattern verificato: foto prodotto in /imagesgoods/<id>/(item|sub)/ — dimensioni
   * 369×492 tipiche. Swatch colori in /chip/ (34×34) → esclusi.
   * Uniqlo non espone __NEXT_DATA__/JSON-LD Product sulla PDP, quindi questo è
   * il canale principale in pratica.
   */
  private async extractImagesFromDom(page: Page, pageUrl: string): Promise<string[]> {
    try {
      await page.evaluate(() => window.scrollBy(0, 800));
      await page.waitForTimeout(800);

      const productId = pageUrl.match(/\/products\/E(\d+)/i)?.[1] ?? null;

      return await page.evaluate(
        ({ pid }) => {
          const re = /^https?:\/\/[^/]*uniqlo\.com\//i;
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

          const upgraded = urls.map((u) => u.replace(/([?&])width=\d+/, "$1width=750"));
          const filtered = upgraded.filter((u) => {
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
          return deduped;
        },
        { pid: productId }
      );
    } catch {
      return [];
    }
  }

  private extractCountry(
    nextProduct: any,
    jsonLdProduct: any,
    domText: string | null
  ): string | null {
    const candidates = [
      nextProduct?.countryOfOrigin,
      nextProduct?.country_of_origin,
      nextProduct?.madeIn,
      nextProduct?.made_in,
      jsonLdProduct?.countryOfOrigin,
      domText ? this.parseMadeIn(domText) : null,
    ];
    for (const c of candidates) {
      const clean = this.sanitizeLocation(c);
      if (clean) return clean;
    }
    return null;
  }

  private extractSupplyChain(nextProduct: any): {
    spinning: string | null;
    weaving: string | null;
    dyeing: string | null;
  } {
    // Uniqlo consumer PDP non espone tipicamente filatura/tessitura/tintura per SKU.
    // Leggiamo opportunisticamente chiavi note; se assenti → null.
    const spinning =
      this.sanitizeLocation(nextProduct?.spinningLocation) ??
      this.sanitizeLocation(nextProduct?.spinning_location) ??
      this.sanitizeLocation(nextProduct?.yarnOrigin) ??
      null;
    const weaving =
      this.sanitizeLocation(nextProduct?.weavingLocation) ??
      this.sanitizeLocation(nextProduct?.weaving_location) ??
      this.sanitizeLocation(nextProduct?.fabricOrigin) ??
      null;
    const dyeing =
      this.sanitizeLocation(nextProduct?.dyeingLocation) ??
      this.sanitizeLocation(nextProduct?.dyeing_location) ??
      null;
    return { spinning, weaving, dyeing };
  }

  private parseMadeIn(text: string): string | null {
    const m = text.match(/(?:made in|prodotto in|fabbricato in)\s+([A-Za-zÀ-ÿ\s,.-]{2,60})/i);
    return m ? m[1] : null;
  }

  private parseEuro(text: string | null): number | null {
    if (!text) return null;
    const m = text.match(/(\d{1,4}(?:[.,]\d{1,2})?)/);
    if (!m) return null;
    return parseFloat(m[1].replace(",", "."));
  }

  private sanitizeName(v: any): string | null {
    if (typeof v !== "string") return null;
    const clean = v.trim().replace(/\s+/g, " ").slice(0, 200);
    return clean.length >= 3 ? clean : null;
  }

  private sanitizePrice(v: any): number | null {
    const n = typeof v === "number" ? v : typeof v === "string" ? parseFloat(v) : NaN;
    if (!Number.isFinite(n) || n <= 0 || n > 10_000) return null;
    return Math.round(n * 100) / 100;
  }

  private sanitizeFreeText(v: any, maxLen: number): string | null {
    if (typeof v !== "string") return null;
    const clean = v.trim().replace(/\s+/g, " ").slice(0, maxLen);
    return clean.length > 0 ? clean : null;
  }

  private sanitizeLocation(v: any): string | null {
    if (typeof v !== "string") return null;
    const clean = v.trim().replace(/\s+/g, " ");
    if (clean.length === 0 || clean.length > 100) return null;
    if (!/^[A-Za-zÀ-ÿ\s,.()-]+$/.test(clean)) return null;
    return clean;
  }

  private async safeText(page: Page, selector: string): Promise<string | null> {
    try {
      const el = page.locator(selector).first();
      const txt = await el.textContent({ timeout: 2000 });
      return txt ? txt.trim().replace(/\s+/g, " ") : null;
    } catch {
      return null;
    }
  }

  /**
   * Scorre body.innerText, trova l'"anchor" (es. "Composizione..."), ritorna la
   * prima riga successiva (fino a ~15 righe) che matcha `match`. Fallback a prima
   * riga globale che matcha.
   */
  private async extractFromBodyLines(
    page: Page,
    cfg: { anchors: string[]; match: RegExp }
  ): Promise<string | null> {
    try {
      return await page.evaluate(
        ({ anchors, matchSource, matchFlags }) => {
          const matchRe = new RegExp(matchSource, matchFlags);
          const text = document.body?.innerText ?? "";
          const lines = text
            .split("\n")
            .map((l) => l.trim())
            .filter(Boolean);

          const anchorIdx = lines.findIndex((l) =>
            anchors.some((a) => l.toLowerCase().includes(a))
          );
          if (anchorIdx >= 0) {
            for (let i = anchorIdx + 1; i < Math.min(lines.length, anchorIdx + 15); i++) {
              if (matchRe.test(lines[i])) return lines[i].slice(0, 400);
            }
          }
          return null;
        },
        { anchors: cfg.anchors, matchSource: cfg.match.source, matchFlags: cfg.match.flags }
      );
    } catch {
      return null;
    }
  }

  private async expandAccordions(page: Page): Promise<void> {
    try {
      await page.evaluate(() => {
        // Forza <details> aperti
        document
          .querySelectorAll("details")
          .forEach((d) => ((d as HTMLDetailsElement).open = true));

        // Click su bottoni/summary con testo di sezioni prodotto rilevanti
        const re = /composi|materi|made in|prodotto in|paese|tessuto|istruzio|care/i;
        const clickable = Array.from(
          document.querySelectorAll(
            "button, [role='button'], summary, [aria-expanded]"
          )
        );
        for (const el of clickable) {
          const txt = (el.textContent || "").trim();
          if (re.test(txt)) {
            try {
              (el as HTMLElement).click();
            } catch {
              /* ignore */
            }
          }
        }
      });
    } catch {
      /* best-effort */
    }
    await page.waitForTimeout(1200);
  }

  private delay(ms: number): Promise<void> {
    return new Promise((r) => setTimeout(r, ms));
  }
}
